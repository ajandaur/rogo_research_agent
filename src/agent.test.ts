import type Anthropic from "@anthropic-ai/sdk";
import { describe, expect, it } from "vitest";

// agent.ts constructs an Anthropic client at import time, which requires a key.
process.env.ANTHROPIC_API_KEY ??= "test-key";
const { runToolCalls } = await import("./agent.ts");
const { ToolError } = await import("./tools.ts");

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

function toolUse(id: string, name: string): Anthropic.ToolUseBlock {
  return { type: "tool_use", id, name, input: {} } as Anthropic.ToolUseBlock;
}

describe("runToolCalls", () => {
  it("runs calls concurrently and returns results in tool_use order", async () => {
    const delays: Record<string, number> = { slow: 60, medium: 30, fast: 5 };
    let inFlight = 0;
    let maxInFlight = 0;

    const results = await runToolCalls(
      [toolUse("a", "slow"), toolUse("b", "medium"), toolUse("c", "fast")],
      () => {},
      async (name) => {
        inFlight++;
        maxInFlight = Math.max(maxInFlight, inFlight);
        await sleep(delays[name]);
        inFlight--;
        return { name };
      },
    );

    expect(maxInFlight).toBe(3);
    expect(results.map((r) => r.tool_use_id)).toEqual(["a", "b", "c"]);
    expect(results.map((r) => JSON.parse(r.content as string).name)).toEqual([
      "slow",
      "medium",
      "fast",
    ]);
  });

  it("marks a failed call is_error without failing the others", async () => {
    const events: string[] = [];

    const results = await runToolCalls(
      [toolUse("a", "ok"), toolUse("b", "broken")],
      (event) => events.push(`${event.type}:${"name" in event ? event.name : ""}`),
      async (name) => {
        if (name === "broken") throw new ToolError("no financials found");
        return { ok: true };
      },
    );

    expect(results[0]).toMatchObject({ tool_use_id: "a" });
    expect(results[0].is_error).toBeUndefined();
    expect(results[1]).toMatchObject({
      tool_use_id: "b",
      is_error: true,
      content: "no financials found",
    });
    expect(events).toContain("tool_failed:broken");
    expect(events).not.toContain("tool_end:broken");
  });
});
