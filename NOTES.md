# Notes

## What I changed and why

- **Latency (GLBX vs ITCH):** the 4 tool calls went from **~2.5s one after another** (450 + 802 + 451 + 800ms) to **~0.8s in parallel**. Model calls dropped from 3 (two research turns plus the editor) to 2. Before, nothing showed until the end. Now tool progress appears within about a second, and the answer streams in as it's written.
- **Removed the editor pass.** It was a whole extra model call after the answer was finished, re-sending the full research transcript. It added seconds, made streaming impossible (the text you'd watch would be thrown away and rewritten), and gave a second model the chance to drop caveats or change numbers it never researched.
- **Tool calls in one model turn now run in parallel**, and results go back in order. Failed tool calls are marked `is_error` so the model knows to correct itself rather than treating the error text as data.
- **Companies resolve by name or ticker, ignoring case** ("glbx", "Initech"). Partial names like "Acme" still go through search on purpose, because Acme Corp and Acme Robotics are both real candidates.
- **One streaming endpoint:** `POST /api/runs/stream` returns server-sent events: tool started/finished/failed, text deltas, then `done` or `error`. Closing the connection cancels the run on the server. I first built separate start/stream/cancel endpoints, then cut them. The app gets the same behaviour from one request, and on iOS, "Stop" is just cancelling a Swift `Task`.
- **Answers are formatted for a phone.** One line in the system prompt asks for a direct answer first, short sections, and tables of at most 4 columns. The app renders headings, paragraphs, bullets and tables; wide tables scroll sideways instead of squeezing.
- **iOS app:** a chat screen with live tool status rows, streaming text, Stop, Retry (after an error *or* a Stop), New conversation, and suggested questions. Follow-up questions send the earlier completed turns as history. The pieces worth testing have unit tests: on the server, company lookup, `runToolCalls` (result order, concurrency, error results) and history validation; in the app, the SSE parser, markdown parser and view model.
- **Known weak spot: losing the connection loses the answer.** With one streaming request, the connection *is* the run. If the phone loses signal, or iOS suspends the app, the server cancels the run and the app shows an error with Retry. I chose that to keep the scope small (and so the server doesn't pay for answers nobody sees). For MDs moving through dead zones it's the first thing I'd change (next section).

## Deliberately not done

- **Next step: let the answer survive a dropped connection.**
  - **Server:** keep running after a disconnect and hold each run's events for a few minutes. Every event already has an increasing `id` for this. This means going back to separate start / stream / cancel endpoints. I first built that and cut it because it only covered a small gap; surviving dead zones is a much better reason to have it.
  - **App:** on a network error, show "Reconnecting…" instead of an error. Wait for signal (`NWPathMonitor`), then reconnect with `Last-Event-ID` and continue where the answer left off. Retry is only the fallback once the run has expired. "Stop" stays an explicit cancel.
  - **App going to the background:** wrap the run in `beginBackgroundTask`, which gives the app about 30 seconds of extra time. That's enough for most answers to finish while the phone is locked.
  - **Longer outages:** send a push notification when the answer is ready.
  - A background `URLSession` doesn't help here: it only delivers whole downloads at the end, so it can't stream.
- **Follow-ups don't carry tool results**, only the question and final answer text, so a follow-up re-fetches data it already had. Conversations aren't saved between launches.
- **UI polish left out:**
  - Every text delta (~160 per answer) updates the UI and re-parses that one message. That's fine at this size; batching would be next.
  - Auto-scroll follows new text, which also pulls you back down if you scroll up mid-answer.
  - Markdown covers what the agent produces. Nested lists, code blocks and links aren't styled specially, and a table shows as plain text for a moment until its separator line streams in.

## Tooling

- Built with Claude Code. Harness config is in `CLAUDE.md`. I also used the SwiftUI Pro and Swift Concurrency Pro review skills to check the app for performance and concurrency issues.
