# Rogo Research Agent — iOS engineering exercise

This is a small, working research agent. An analyst asks a question about a company;
the agent calls a few research tools and answers. The agent runs as a local server,
and there is an empty iOS project for its app.

It was prototyped quickly. It works, and it is not finished. Imagine you are asked to
get an MVP iOS app in the hands of customers quickly.

## Your task

**Build the iOS chat app for this agent, and improve whatever you believe would have
the highest impact.** Use SwiftUI or UIKit; we prefer SwiftUI. The whole repo is yours
to change, the server included.

Possible areas include:

- **The app experience** — what the analyst sees while the agent works, how answers
  read on a phone (tables, long answers), follow-up questions, errors and retries
- **Input and navigation** — the composer, keyboard handling, scrolling through a
  conversation as it grows, starting over
- **Networking and lifecycle** — slow responses, dropped connections, the app going
  to the background, cancelling a question
- **What the app needs from the server** — the API the app talks to is yours to
  change: its shape, what it sends and when, and what the agent does behind it
- **Engineering quality** — state management, concurrency, testability, error
  handling, on both sides

You do **not** need to address every area. We care much more about the quality of your
decisions than the amount of code you write. A focused, well-reasoned change to two
areas beats a shallow pass over all five.

**Please spend no more than 90–120 minutes.** Stop when the time is up, even mid-thought.
We would rather see what you chose to do first.

**You may use any AI coding tools you normally use** — Claude Code, Cursor, Codex,
whatever your setup is. We use them too. You will be asked to explain the code you
submit, including code a tool generated for you.

We will discuss your approach and implementation in the interview.

## Setup

Requires Xcode 16.3+ and Node 22 (or Node 20.19+).

```bash
npm install
cp .env.example .env   # then paste in the API key we sent you
npm run dev            # agent server on http://localhost:8787
```

Then open `ios/RogoResearch.xcodeproj` and run the `RogoResearch` scheme on a simulator.
The server logs its tool calls to the terminal, which is usually the fastest way to see
what the agent is actually doing.

## Try it

Some questions to start with:

- "Compare Acme and Globex and tell me which one appears to be growing faster."
- "What are the biggest risks Umbrella Health flags in its filings?"
- "How is Initech's subscription transition going?"
- "Which company in the universe is growing fastest?"
- "Is GLBX a better business than ITCH?"

## The code

| Path | What it is |
| --- | --- |
| `ios/` | Xcode project with an empty app and test target |
| `src/server.ts` | Express server, one `POST /api/chat` endpoint |
| `src/agent.ts` | The agent loop — system prompt, tool-use loop, final answer |
| `src/tools.ts` | Tool schemas and tool execution |
| `src/data.ts` | All the research data. Fictional, local, deterministic |

There are five fictional companies. The tools are backed entirely by `src/data.ts` —
no network calls, no credentials beyond the model key, nothing to set up. Each tool
sleeps for a few hundred milliseconds to stand in for a real API.

The simulator reaches the server at `http://localhost:8787`. On a physical device, use
your Mac's LAN address.

### Scripts

| Command | What it does |
| --- | --- |
| `npm run dev` | Runs the agent server on port 8787 |
| `npm run typecheck` | `tsc --noEmit` |
| `npm test` | Runs Vitest |

The model defaults to `claude-sonnet-5`. Set `ROGO_MODEL` in `.env` to change it.

## Submitting

Commit your work on a branch and send us the repo (or a zip, or a PR — whatever is
easiest). If you want to leave notes on what you changed and why, add a short
`NOTES.md`. Bullet points are fine; please don't write a design document. If you
used a configuration for your harness please include it in the submission (i.e. `agents.md`)

If you noticed something you deliberately chose *not* to fix, that is worth a line
too — we will ask about it either way.
