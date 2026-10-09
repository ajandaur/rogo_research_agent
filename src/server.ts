import "dotenv/config";
import express from "express";
import { parseHistory, streamRun } from "./runs.ts";

if (!process.env.ANTHROPIC_API_KEY) {
  console.error(
    "\nANTHROPIC_API_KEY is not set.\nCopy .env.example to .env and add your key, then run `npm run dev` again.\n",
  );
  process.exit(1);
}

const app = express();
app.use(express.json());

/**
 * Body: {"messages": [{"role": "user" | "assistant", "content": string}, ...]}.
 * Responds with an SSE stream of agent events. Close the connection to cancel.
 */
app.post("/api/runs/stream", async (req, res) => {
  const parsed = parseHistory(req.body?.messages);
  if ("error" in parsed) {
    res.status(400).json({ error: parsed.error });
    return;
  }
  await streamRun(parsed.history, res);
});

const port = Number(process.env.PORT ?? 8787);
app.listen(port, () => {
  console.log(`Agent server listening on http://localhost:${port}`);
});
