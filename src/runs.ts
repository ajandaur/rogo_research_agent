/**
 * Runs the agent for one request and streams its events back as SSE on the
 * same response. Closing the connection cancels the run.
 */

import Anthropic from "@anthropic-ai/sdk";
import type { Response } from "express";
import { runAgent, type AgentEvent } from "./agent.ts";
import { formatSSE } from "./sse.ts";

export async function streamRun(history: Anthropic.MessageParam[], res: Response) {
  const controller = new AbortController();
  res.on("close", () => {
    if (!res.writableEnded) {
      log("client disconnected, cancelling");
      controller.abort();
    }
  });

  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache, no-transform",
    Connection: "keep-alive",
  });
  res.flushHeaders();

  let nextId = 1;
  const send = (event: string, data: unknown) => {
    if (!res.writableEnded) res.write(formatSSE(nextId++, event, data));
  };

  log(`started: ${lastUserText(history)}`);
  try {
    const result = await runAgent(history, {
      signal: controller.signal,
      onEvent: (event) => forward(event, send),
    });
    send("done", { stopReason: result.stopReason });
    log("done");
  } catch (err) {
    if (controller.signal.aborted) {
      log("cancelled");
    } else if (err instanceof Anthropic.APIError) {
      console.error(err);
      send("error", { code: "upstream", message: "The model request failed." });
    } else {
      console.error(err);
      send("error", { code: "internal", message: "Something went wrong on the server." });
    }
  }
  res.end();
}

/** Maps internal agent events to wire events, logging tool activity. */
function forward(event: AgentEvent, send: (event: string, data: unknown) => void) {
  switch (event.type) {
    case "iteration":
      log(`iteration ${event.n}`);
      break;
    case "tool_start":
      log(`→ ${event.name} ${JSON.stringify(event.input)}`);
      send("tool_started", {
        toolUseId: event.toolUseId,
        name: event.name,
        input: event.input,
        label: event.label,
      });
      break;
    case "tool_end":
      log(`← ${event.name} (${event.ms}ms)`);
      send("tool_finished", { toolUseId: event.toolUseId, name: event.name, durationMs: event.ms });
      break;
    case "tool_failed":
      log(`! ${event.name}: ${event.message}`);
      send("tool_failed", {
        toolUseId: event.toolUseId,
        name: event.name,
        durationMs: event.ms,
        message: event.message,
      });
      break;
    case "text_delta":
      send("text_delta", { text: event.text });
      break;
  }
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

function log(message: string) {
  console.log(`[run] ${message}`);
}

function lastUserText(history: Anthropic.MessageParam[]): string {
  const content = history.at(-1)?.content;
  return typeof content === "string" ? content : "";
}
