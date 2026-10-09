/**
 * The agent's tools. These stand in for the real research APIs — same shapes,
 * local data, plus a little latency so the app behaves like the real thing.
 */

import type Anthropic from "@anthropic-ai/sdk";
import { companies, documents, financials, type Company } from "./data.ts";

/** Thrown when a tool cannot service a request. */
export class ToolError extends Error {}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

export const toolSchemas: Anthropic.Tool[] = [
  {
    name: "searchCompanies",
    description:
      "Search the coverage universe for companies matching a name. Returns the company name, ticker and sector for each match.",
    input_schema: {
      type: "object",
      properties: {
        query: { type: "string", description: "A company name or part of one." },
      },
      required: ["query"],
    },
  },
  {
    name: "getCompanyProfile",
    description:
      "Get a company's profile: description, sector, headquarters, headcount, business segments and the filings we hold.",
    input_schema: {
      type: "object",
      properties: {
        company: { type: "string", description: "The company name or ticker." },
      },
      required: ["company"],
    },
  },
  {
    name: "getFinancials",
    description:
      "Get annual and quarterly financials for a company: revenue, gross margin, operating income, net income and free cash flow.",
    input_schema: {
      type: "object",
      properties: {
        company: { type: "string", description: "The company name or ticker." },
      },
      required: ["company"],
    },
  },
  {
    name: "searchDocuments",
    description:
      "Keyword search over earnings call transcripts, filing excerpts and press releases.",
    input_schema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Keywords to search for." },
        company: {
          type: "string",
          description: "Optional. Restrict the search to one company.",
        },
      },
      required: ["query"],
    },
  },
];

/**
 * Finds a company by its exact name or ticker, ignoring case and surrounding
 * whitespace. Partial names ("Acme") are deliberately not resolved: they are
 * ambiguous, and searchCompanies exists for that.
 */
export function resolveCompany(query: string): Company | undefined {
  const needle = String(query).trim().toLowerCase();
  return companies.find(
    (c) => c.name.toLowerCase() === needle || c.ticker.toLowerCase() === needle,
  );
}

async function searchCompanies(query: string) {
  await sleep(250);
  const needle = String(query).trim().toLowerCase();
  const matches = companies.filter(
    (c) => c.name.toLowerCase().includes(needle) || c.ticker.toLowerCase() === needle,
  );
  return matches.map((c) => ({
    name: c.name,
    ticker: c.ticker,
    sector: c.sector,
  }));
}

async function getCompanyProfile(company: string) {
  await sleep(450);
  const match = resolveCompany(company);
  if (!match) {
    throw new ToolError(`no profile found for "${company}"`);
  }
  return match;
}

async function getFinancials(company: string) {
  await sleep(800);
  const name = resolveCompany(company)?.name;
  const record = financials.find((f) => f.company === name);
  if (!record) {
    throw new ToolError(`no financials found for "${company}"`);
  }
  return record;
}

async function searchDocuments(query: string, company?: string) {
  await sleep(700);

  const terms = String(query).trim().split(/\s+/).filter(Boolean);
  // The upstream document index rejects long queries.
  if (terms.length > 6) {
    throw new ToolError(
      `document search accepts at most 6 terms (received ${terms.length})`,
    );
  }

  let pool = documents;
  if (company) {
    const match = resolveCompany(company);
    if (!match) {
      throw new ToolError(`no company found for "${company}"`);
    }
    pool = documents.filter((d) => d.company === match.name);
  }

  const scored = pool.map((doc) => {
    const haystack = `${doc.title} ${doc.body}`.toLowerCase();
    let score = 0;
    for (const term of terms) {
      if (haystack.includes(term.toLowerCase())) score += 1;
    }
    return { doc, score };
  });

  return scored
    .filter((s) => s.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, 5)
    .map((s) => s.doc);
}

export async function executeTool(
  name: string,
  input: Record<string, unknown>,
): Promise<unknown> {
  switch (name) {
    case "searchCompanies":
      return searchCompanies(input.query as string);
    case "getCompanyProfile":
      return getCompanyProfile(input.company as string);
    case "getFinancials":
      return getFinancials(input.company as string);
    case "searchDocuments":
      return searchDocuments(input.query as string, input.company as string | undefined);
    default:
      throw new ToolError(`unknown tool "${name}"`);
  }
}
