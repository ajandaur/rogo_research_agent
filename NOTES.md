# Notes

## What I changed

- **Faster answers.** For GLBX vs ITCH, the 4 tool calls went from ~2.5s (one after another) to ~0.8s (in parallel), and model calls went from 3 to 2.
- **Removed the editor pass.** It was an extra model call that re-sent the whole transcript, blocked streaming, and could change numbers it never researched.
- **Tool calls in one turn run in parallel.** Failures go back to the model as `is_error`, so it can correct course.
- **Companies resolve by exact name or ticker, in any case** ("glbx"). Partial names like "Acme" still go through search, since two companies match.
- **One streaming endpoint, `POST /api/runs/stream`.** It sends server-sent events for tool progress and text, then `done` or `error`. Closing the connection cancels the run, so Stop on iOS is just cancelling a `Task`. I built separate start/stream/cancel endpoints first, then cut them because one request was enough.
- **iOS chat app:** live tool status, streaming markdown (tables scroll sideways), Stop, Retry after an error or a Stop, follow-up questions with history, and New conversation. One system-prompt line asks for phone-friendly answers.

## Not done yet

- **Surviving dead zones comes first.** Today a dropped connection cancels the run and shows Retry. Next:
  - Keep runs alive on the server (back to separate endpoints).
  - Reconnect with `Last-Event-ID` when signal returns.
  - Use `beginBackgroundTask` to keep the stream going when the phone is locked.
  - Send a push notification when the answer is ready after a long outage.
- **Follow-ups don't carry tool results**, so they re-fetch data the earlier answer already used.
- **UI polish:**
  - Text updates aren't batched (about 160 per answer).
  - Auto-scroll pulls you back down if you scroll up mid-answer.
  - Markdown skips nested lists and code blocks.

## Tooling

- Built with Claude Code; the harness config is in `CLAUDE.md`. I used the SwiftUI Pro and Swift Concurrency Pro review skills to check for performance and concurrency issues.
