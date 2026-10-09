# Rogo Research — harness notes

Node/Express agent server (`src/`) + SwiftUI iOS client (`ios/`). See README.md for setup.

## Rules
- Small atomic commits, one logical change each, imperative subject ("Add …", "Remove …").
- Stage explicit paths: `git add <paths>`. Never `git add -A` / `git add .`.
- Never commit `.env` (holds the API key; it is gitignored — keep it that way).
- iOS: no Swift packages. SwiftUI + Swift Concurrency only, iOS 17, Swift 6 strict concurrency.
- Every async path handles cancellation: server passes an `AbortSignal` through the agent loop and model calls; iOS checks `Task.isCancelled` / propagates `CancellationError` and ignores events from stale runs.
- New Swift files go in `ios/RogoResearch/` or `ios/RogoResearchTests/`; the project uses synchronized folders, so no pbxproj edits.
- Checks: `npm run typecheck && npm test`; iOS build + tests via Xcode.

## Endpoints
- `POST /api/runs` body `{"messages":[{"role":"user"|"assistant","content":string}]}` (alternating, starts and ends with `user`) → `201 {"runId"}` or `400 {"error"}`.
- `GET /api/runs/:id/events` → SSE stream. 404 unknown run, 409 if already subscribed. One subscriber; events before attach are buffered. No replay / `Last-Event-ID`. Subscriber disconnect aborts the run. `: ping` heartbeat every 15s.
- `POST /api/runs/:id/cancel` → `202`, idempotent; 404 unknown run.

## Event protocol
Each SSE frame: `id:` per-run integer from 1, `event:` type, `data:` JSON. Exactly one terminal event (`done` or `error`), then the stream closes.

| event | data |
| --- | --- |
| `tool_started` | `{toolUseId, name, input, label}` |
| `tool_finished` | `{toolUseId, name, durationMs}` |
| `tool_failed` | `{toolUseId, name, durationMs, message}` (sent instead of `tool_finished`) |
| `text_delta` | `{text}` (may arrive across several turns) |
| `done` | `{stopReason: "end_turn" \| "max_iterations"}` |
| `error` | `{code: "cancelled" \| "upstream" \| "internal", message}` |

Server: tool calls in a turn run concurrently (`Promise.all`, results kept in order); failures go back to the model as `tool_result` with `is_error: true`; company lookups match name or ticker case-insensitively; model text is streamed with `client.messages.stream`; no editor pass.

## iOS architecture
- `Networking/SSEParser` — standalone, byte-level, testable (not `bytes.lines`, which drops blank lines).
- `Networking/AgentEvent` — decodes SSE frames into a typed enum.
- `Networking/AgentService` — `AgentServicing` protocol + `URLSessionAgentService`; injected so the view model can be tested with a mock.
- `Chat/ChatViewModel` — `@MainActor @Observable`, explicit `RunState` (`idle`, `starting`, `streaming(runID)`, `failed(message)`); `send`, `cancel`, `retry`, `newConversation`.
- `Chat/ChatModels` — messages hold ordered parts (`text` / `tools`) so preamble text and tool rows interleave correctly.
- `Markdown/MarkdownParser` + `MarkdownView` — block-level parser (headings, paragraphs, bullets, tables); tables render as a horizontally scrolling `Grid`; inline styles via `AttributedString`.
- Tests: SSE parser, markdown parser, view model with a scripted mock service.
