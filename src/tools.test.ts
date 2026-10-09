import { describe, expect, it } from "vitest";
import { describeTool, executeTool, resolveCompany, ToolError } from "./tools.ts";

describe("describeTool", () => {
  it("names the resolved company", () => {
    expect(describeTool("getFinancials", { company: "glbx" })).toBe("Pulling Globex Inc financials");
    expect(describeTool("searchDocuments", { query: "risk", company: "UMBR" })).toBe(
      "Searching Umbrella Health documents for “risk”",
    );
  });
});

describe("resolveCompany", () => {
  it("matches names case-insensitively", () => {
    expect(resolveCompany("acme corp")?.ticker).toBe("ACME");
    expect(resolveCompany("  UMBRELLA HEALTH ")?.ticker).toBe("UMBR");
  });

  it("matches tickers case-insensitively", () => {
    expect(resolveCompany("ACME")?.name).toBe("Acme Corp");
    expect(resolveCompany("glbx")?.name).toBe("Globex Inc");
  });

  it("does not resolve partial or unknown names", () => {
    expect(resolveCompany("Globex")).toBeUndefined();
    expect(resolveCompany("Umbrella")).toBeUndefined();
    expect(resolveCompany("Hooli")).toBeUndefined();
  });
});

describe("tools accept tickers", () => {
  it("getFinancials resolves a ticker", async () => {
    const record = (await executeTool("getFinancials", { company: "itch" })) as {
      company: string;
    };
    expect(record.company).toBe("Initech");
  });

  it("searchDocuments filters by ticker", async () => {
    const docs = (await executeTool("searchDocuments", {
      query: "revenue",
      company: "UMBR",
    })) as { company: string }[];
    expect(docs.length).toBeGreaterThan(0);
    expect(docs.every((d) => d.company === "Umbrella Health")).toBe(true);
  });

  it("unknown companies raise ToolError", async () => {
    await expect(executeTool("getCompanyProfile", { company: "Hooli" })).rejects.toBeInstanceOf(
      ToolError,
    );
  });
});
