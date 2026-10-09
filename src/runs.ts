/**
 * In-memory agent runs, streamed to one SSE subscriber each.
 *
 * A run starts as soon as it is created. Events produced before the client
 * opens the event stream are buffered and flushed when it attaches, so nothing
 * is lost in the gap between POST /api/runs and GET /events. This is not
 * replay: a run accepts exactly one subscriber, and a dropped stream cancels it.
 */

import { randomUUID } from "node:crypto";
import Anthropic from "@anthropic-ai/sdk";
import type { Response } from "express";
import { runAgent, type AgentEvent } from "./agent.ts";
import { formatSSE, SSE_PING } from "./sse.ts";

/** Abort runs nobody subscribes to. */
const SUBSCRIBE_TIMEOUT_MS = 30_000;
/** Keep finished runs briefly so a late subscriber still gets the outcome. */
const RETAIN_FINISHED_MS = 60_000;
const HEARTBEAT_MS = 15_000;

interface Run {
  id: string;
  controller: AbortController;
  nextEventId: number;
  pending: string[];
  subscriber?: Response;
  finished: boolean;
  subscribeTimer: NodeJS.Timeout;
  heartbeat?: NodeJS.Timeout;
}

const runs = new Map<string, Run>();

export function createRun(history: Anthropic.MessageParam[]): string {
  const id = randomUUID();
  const run: Run = {
    id,
    controller: new AbortController(),
    nextEventId: 1,
    pending: [],
    finished: false,
    subscribeTimer: setTimeout(() => {
      log(run, "no subscriber, cancelling");
      run.controller.abort();
    }, SUBSCRIBE_TIMEOUT_MS),
  };
  runs.set(id, run);
  log(run, `started: ${lastUserText(history)}`);

  runAgent(history, { signal: run.controller.signal, onEvent: (e) => onAgentEvent(run, e) })
    .then((result) => finish(run, "done", { stopReason: result.stopReason }))
    .catch((err) => {
      if (run.controller.signal.aborted) {
        finish(run, "error", { code: "cancelled", message: "The run was cancelled." });
      } else if (err instanceof Anthropic.APIError) {
        console.error(err);
        finish(run, "error", { code: "upstream", message: "The model request failed." });
      } else {
        console.error(err);
        finish(run, "error", { code: "internal", message: "Something went wrong on the server." });
      }
    });

  return id;
}

export type AttachResult = "attached" | "not_found" | "already_attached";

export function attach(runId: string, res: Response): AttachResult {
  const run = runs.get(runId);
  if (!run) return "not_found";
  if (run.subscriber) return "already_attached";

  clearTimeout(run.subscribeTimer);
  run.subscriber = res;

  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache, no-transform",
    Connection: "keep-alive",
  });
  res.flushHeaders();
  for (const frame of run.pending) res.write(frame);
  run.pending = [];

  if (run.finished) {
    res.end();
    return "attached";
  }

  run.heartbeat = setInterval(() => res.write(SSE_PING), HEARTBEAT_MS);
  res.on("close", () => {
    clearInterval(run.heartbeat);
    if (!run.finished) {
      log(run, "subscriber disconnected, cancelling");
      run.controller.abort();
    }
  });
  return "attached";
}

/** Returns false if the run doesn't exist. Cancelling a finished run is a no-op. */
export function cancelRun(runId: string): boolean {
  const run = runs.get(runId);
  if (!run) return false;
  if (!run.finished && !run.controller.signal.aborted) {
    log(run, "cancel requested");
    run.controller.abort();
  }
  return true;
}

function onAgentEvent(run: Run, event: AgentEvent) {
  // Once cancelled, the client has moved on; don't stream stragglers.
  if (run.controller.signal.aborted) return;

  switch (event.type) {
    case "iteration":
      log(run, `iteration ${event.n}`);
      break;
    case "tool_start":
      log(run, `→ ${event.name} ${JSON.stringify(event.input)}`);
      send(run, "tool_started", {
        toolUseId: event.toolUseId,
        name: event.name,
        input: event.input,
        label: event.label,
      });
      break;
    case "tool_end":
      log(run, `← ${event.name} (${event.ms}ms)`);
      send(run, "tool_finished", {
        toolUseId: event.toolUseId,
        name: event.name,
        durationMs: event.ms,
      });
      break;
    case "tool_failed":
      log(run, `! ${event.name}: ${event.message}`);
      send(run, "tool_failed", {
        toolUseId: event.toolUseId,
        name: event.name,
        durationMs: event.ms,
        message: event.message,
      });
      break;
    case "text_delta":
      send(run, "text_delta", { text: event.text });
      break;
  }
}

function send(run: Run, event: string, data: unknown) {
  const frame = formatSSE(run.nextEventId++, event, data);
  if (run.subscriber) {
    run.subscriber.write(frame);
  } else {
    run.pending.push(frame);
  }
}

function finish(run: Run, event: "done" | "error", data: unknown) {
  if (run.finished) return;
  send(run, event, data);
  run.finished = true;
  log(run, event === "done" ? "done" : `error ${JSON.stringify(data)}`);

  clearTimeout(run.subscribeTimer);
  clearInterval(run.heartbeat);
  run.subscriber?.end();
  setTimeout(() => runs.delete(run.id), RETAIN_FINISHED_MS).unref();
}

/**
 * Validates a client-sent conversation: non-empty, text-only, roles alternating
 * from user to user. Returns the history or a message for a 400.
 */
export function parseHistory(
  value: unknown,
): { history: Anthropic.MessageParam[] } | { error: string } {
  if (!Array.isArray(value) || value.length === 0) {
    return { error: "messages must be a non-empty array" };
  }

  const history: Anthropic.MessageParam[] = [];
  for (const [i, item] of value.entries()) {
    const expected = i % 2 === 0 ? "user" : "assistant";
    if (item?.role !== expected) {
      return { error: `messages[${i}].role must be "${expected}"` };
    }
    if (typeof item.content !== "string" || item.content.trim() === "") {
      return { error: `messages[${i}].content must be a non-empty string` };
    }
    history.push({ role: expected, content: item.content });
  }

  if (history.at(-1)!.role !== "user") {
    return { error: "the last message must be from the user" };
  }
  return { history };
}

function log(run: Run, message: string) {
  console.log(`[run ${run.id.slice(0, 8)}] ${message}`);
}

function lastUserText(history: Anthropic.MessageParam[]): string {
  const content = history.at(-1)?.content;
  return typeof content === "string" ? content : "";
}
