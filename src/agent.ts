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
  | { type: "tool_failed"; name: string; ms: number; message: string };

export interface AgentResult {
  answer: string;
  iterations: number;
}

function textOf(message: Anthropic.Message): string {
  return message.content
    .filter((block): block is Anthropic.TextBlock => block.type === "text")
    .map((block) => block.text)
    .join("\n");
}

type ToolExecutor = (name: string, input: Record<string, unknown>) => Promise<unknown>;

/**
 * Runs every tool call from one model turn concurrently. Each call is wrapped so
 * it never rejects, which keeps results in the same order as `uses` (the API
 * requires a tool_result for every tool_use) and lets one failure not sink the rest.
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

export async function runAgent(
  question: string,
  onEvent: (event: AgentEvent) => void,
): Promise<AgentResult> {
  const messages: Anthropic.MessageParam[] = [{ role: "user", content: question }];

  let draft = "";
  let iterations = 0;

  while (iterations < MAX_ITERATIONS) {
    iterations++;
    onEvent({ type: "iteration", n: iterations });

    const response = await client.messages.create({
      model: MODEL,
      max_tokens: 16000,
      system: SYSTEM_PROMPT,
      tools: toolSchemas,
      messages,
    });

    messages.push({ role: "assistant", content: response.content });

    const toolUses = response.content.filter(
      (block): block is Anthropic.ToolUseBlock => block.type === "tool_use",
    );

    if (toolUses.length === 0) {
      draft = textOf(response);
      break;
    }

    const toolResults = await runToolCalls(toolUses, onEvent);
    messages.push({ role: "user", content: toolResults });
  }

  if (!draft) {
    draft =
      "I looked at a number of sources but ran out of research steps before I could pull the answer together. Try asking a narrower question.";
  }

  return { answer: draft, iterations };
}
