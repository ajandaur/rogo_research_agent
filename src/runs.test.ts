import { describe, expect, it } from "vitest";

// runs.ts imports agent.ts, which constructs an Anthropic client at import time.
process.env.ANTHROPIC_API_KEY ??= "test-key";
const { parseHistory } = await import("./runs.ts");

describe("parseHistory", () => {
  it("accepts an alternating conversation ending with the user", () => {
    const messages = [
      { role: "user", content: "Compare Acme and Globex" },
      { role: "assistant", content: "Acme is growing faster." },
      { role: "user", content: "And Initech?" },
    ];
    expect(parseHistory(messages)).toEqual({ history: messages });
  });

  it("rejects empty, misordered, non-text or assistant-final histories", () => {
    expect(parseHistory([])).toHaveProperty("error");
    expect(parseHistory(undefined)).toHaveProperty("error");
    expect(parseHistory([{ role: "assistant", content: "hi" }])).toHaveProperty("error");
    expect(parseHistory([{ role: "user", content: "  " }])).toHaveProperty("error");
    expect(parseHistory([{ role: "user", content: [{ type: "text", text: "x" }] }])).toHaveProperty(
      "error",
    );
    expect(
      parseHistory([
        { role: "user", content: "a" },
        { role: "assistant", content: "b" },
      ]),
    ).toHaveProperty("error");
  });
});
