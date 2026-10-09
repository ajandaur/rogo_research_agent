/**
 * The research agent: a tool-use loop over the mocked research tools.
 */

import Anthropic from "@anthropic-ai/sdk";
import { companies } from "./data.ts";
import { executeTool, toolSchemas } from "./tools.ts";

const MODEL = process.env.ROGO_MODEL ?? "claude-sonnet-5";
const MAX_ITERATIONS = 12;

const client = new Anthropic();

const SYSTEM_PROMPT = `You are Rogo Research, an assistant that answers questions about companies for financial analysts.

Use the tools to look up companies, profiles, financials and source documents. Answer the analyst's question.

Your answer is read on a phone. Lead with the direct answer in a sentence or two, then support it. Use short paragraphs, bullet lists and ### headings only when they help. Use a markdown table only for genuinely tabular figures, with at most 4 columns. No nested lists or HTML.

Our coverage universe:
${companies
  .map(
    (c) =>
      `- ${c.name} (${c.ticker}) — ${c.sector}, HQ ${c.hq}, ${c.employees} employees. ${c.description}`,
  )
  .join("\n")}
`;

export type AgentEvent =
  | { type: "iteration"; n: number }
  | { type: "tool_start"; name: string; input: unknown }
  | { type: "tool_end"; name: string; ms: number }
  | { type: "tool_failed"; name: string; ms: number; message: string }
  | { type: "text_delta"; text: string };

export interface AgentResult {
  answer: string;
  iterations: number;
  stopReason: "end_turn" | "max_iterations";
}

function textOf(message: Anthropic.Message): string {
  return message.content
    .filter((block): block is Anthropic.TextBlock => block.type === "text")
    .map((block) => block.text)
    .join("\n");
}

type ToolExecutor = (name: string, input: Record<string, unknown>) => Promise<unknown>;

/**
 * Runs every tool call from one model turn concurrently. Promise.all keeps
 * results in the same order as `uses`. Each call catches its own errors and
 * returns an is_error tool_result, so one failure doesn't reject Promise.all
 * and discard the other results. The API needs a tool_result for every tool_use.
 */
export async function runToolCalls(
  uses: Anthropic.ToolUseBlock[],
  onEvent: (event: AgentEvent) => void,
  execute: ToolExecutor = executeTool,
): Promise<Anthropic.ToolResultBlockParam[]> {
  return Promise.all(
    uses.map(async (use): Promise<Anthropic.ToolResultBlockParam> => {
      const startedAt = Date.now();
      onEvent({ type: "tool_start", name: use.name, input: use.input });

      try {
        const output = await execute(use.name, use.input as Record<string, unknown>);
        onEvent({ type: "tool_end", name: use.name, ms: Date.now() - startedAt });
        return { type: "tool_result", tool_use_id: use.id, content: JSON.stringify(output) };
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        onEvent({ type: "tool_failed", name: use.name, ms: Date.now() - startedAt, message });
        return { type: "tool_result", tool_use_id: use.id, content: message, is_error: true };
      }
    }),
  );
}

export interface RunAgentOptions {
  signal: AbortSignal;
  onEvent: (event: AgentEvent) => void;
}

/**
 * Runs the agent over a conversation. `history` is the prior turns plus the new
 * question (it must end with a user message); it is copied, not mutated.
 * Aborting `signal` stops the in-flight model request and rejects before the
 * next turn starts.
 */
export async function runAgent(
  history: Anthropic.MessageParam[],
  { signal, onEvent }: RunAgentOptions,
): Promise<AgentResult> {
  const messages: Anthropic.MessageParam[] = [...history];

  let draft = "";
  let iterations = 0;

  while (iterations < MAX_ITERATIONS) {
    signal.throwIfAborted();
    iterations++;
    onEvent({ type: "iteration", n: iterations });

    const stream = client.messages.stream(
      {
        model: MODEL,
        max_tokens: 16000,
        system: SYSTEM_PROMPT,
        tools: toolSchemas,
        messages,
      },
      { signal },
    );
    stream.on("text", (text) => onEvent({ type: "text_delta", text }));
    const response = await stream.finalMessage();

    messages.push({ role: "assistant", content: response.content });

    const toolUses = response.content.filter(
      (block): block is Anthropic.ToolUseBlock => block.type === "tool_use",
    );

    if (toolUses.length === 0) {
      draft = textOf(response);
      break;
    }

    // Mock tools can't be interrupted mid-sleep; drop their results if cancelled meanwhile.
    const toolResults = await runToolCalls(toolUses, onEvent);
    signal.throwIfAborted();
    messages.push({ role: "user", content: toolResults });
  }

  if (!draft) {
    draft =
      "I looked at a number of sources but ran out of research steps before I could pull the answer together. Try asking a narrower question.";
    onEvent({ type: "text_delta", text: draft });
    return { answer: draft, iterations, stopReason: "max_iterations" };
  }

  return { answer: draft, iterations, stopReason: "end_turn" };
}
