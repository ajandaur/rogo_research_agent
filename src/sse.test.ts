import { describe, expect, it } from "vitest";
import { formatSSE } from "./sse.ts";

describe("formatSSE", () => {
  it("frames id, event and JSON data, terminated by a blank line", () => {
    expect(formatSSE(3, "text_delta", { text: "hi" })).toBe(
      'id: 3\nevent: text_delta\ndata: {"text":"hi"}\n\n',
    );
  });

  it("keeps multi-line text on one data line", () => {
    const frame = formatSSE(1, "text_delta", { text: "a\n\nb" });
    expect(frame.split("\n")).toEqual([
      "id: 1",
      "event: text_delta",
      'data: {"text":"a\\n\\nb"}',
      "",
      "",
    ]);
  });
});
