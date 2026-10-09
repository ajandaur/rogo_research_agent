/**
 * Server-sent events framing. JSON.stringify never emits raw newlines, so each
 * payload fits on a single `data:` line.
 */

export function formatSSE(id: number, event: string, data: unknown): string {
  return `id: ${id}\nevent: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}
