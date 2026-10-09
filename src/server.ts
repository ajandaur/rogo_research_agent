import "dotenv/config";
import express from "express";
import { attach, cancelRun, createRun, parseHistory } from "./runs.ts";

if (!process.env.ANTHROPIC_API_KEY) {
  console.error(
    "\nANTHROPIC_API_KEY is not set.\nCopy .env.example to .env and add your key, then run `npm run dev` again.\n",
  );
  process.exit(1);
}

const app = express();
app.use(express.json());

/** Start a run. Body: {"messages": [{"role": "user" | "assistant", "content": string}, ...]} */
app.post("/api/runs", (req, res) => {
  const parsed = parseHistory(req.body?.messages);
  if ("error" in parsed) {
    res.status(400).json({ error: parsed.error });
    return;
  }
  res.status(201).json({ runId: createRun(parsed.history) });
});

/** Stream a run's events as SSE. One subscriber per run. */
app.get("/api/runs/:id/events", (req, res) => {
  switch (attach(req.params.id, res)) {
    case "not_found":
      res.status(404).json({ error: "run not found" });
      break;
    case "already_attached":
      res.status(409).json({ error: "run already has a subscriber" });
      break;
    case "attached":
      break;
  }
});

app.post("/api/runs/:id/cancel", (req, res) => {
  if (!cancelRun(req.params.id)) {
    res.status(404).json({ error: "run not found" });
    return;
  }
  res.status(202).end();
});

const port = Number(process.env.PORT ?? 8787);
app.listen(port, () => {
  console.log(`Agent server listening on http://localhost:${port}`);
});
