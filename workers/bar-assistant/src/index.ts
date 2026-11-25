import { createHash, timingSafeEqual } from "node:crypto";
import * as ai from "ai";
import { createAI, type AISettings } from "agents/models/ai-sdk";
import { wrapAISDK } from "agents/observability/ai";

interface Env {
  AI: NonNullable<AISettings["binding"]>;
  BAR_ASSISTANT_TOKEN?: string;
}

const tracedAI = wrapAISDK(ai, { storeMessages: true, storeTools: true });
const modelId = "@cf/meta/llama-3.3-70b-instruct-fp8-fast";
const system =
  "You are the PourSTL Bar Assistant. Help with cocktails, recipe scaling, ingredient substitutions, and bartending technique. Answer concisely and state assumptions about ingredients or serving size. You cannot access the user's inventory or saved recipes. Do not guess quantities or claim that an ingredient is safe for a dietary restriction.";
const maxBodyBytes = 8_192;
const maxQuestionLength = 2_000;
const uuidV4 =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function json(data: object, status = 200, headers?: Record<string, string>) {
  return Response.json(data, {
    status,
    headers: { "Cache-Control": "no-store", ...headers },
  });
}

function authorized(header: string | null, token: string) {
  const credential = header?.match(/^Bearer (\S+)$/i)?.[1];
  if (!credential) return false;

  const expected = createHash("sha256").update(token).digest();
  const provided = createHash("sha256").update(credential).digest();
  return timingSafeEqual(expected, provided);
}

async function readTurn(request: Request) {
  const reader = request.body?.getReader();
  if (!reader) return null;

  const body = new Uint8Array(maxBodyBytes);
  let length = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      if (length + value.byteLength > maxBodyBytes) {
        void reader.cancel().catch(() => {});
        return "too-large";
      }
      body.set(value, length);
      length += value.byteLength;
    }

    const data: unknown = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(
        body.subarray(0, length),
      ),
    );
    if (typeof data !== "object" || data === null) return null;

    const { question, conversationId } = data as Record<string, unknown>;
    if (typeof conversationId !== "string" || !uuidV4.test(conversationId)) {
      return null;
    }
    if (typeof question !== "string") return null;
    const prompt = question.trim();
    if (!prompt || prompt.length > maxQuestionLength) return null;

    return { prompt, conversationId: conversationId.toLowerCase() };
  } catch {
    return null;
  } finally {
    reader.releaseLock();
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (new URL(request.url).pathname !== "/v1/assistant/turn") {
      return json({ error: "Not found" }, 404);
    }
    if (request.method !== "POST") {
      return json({ error: "Method not allowed" }, 405, { Allow: "POST" });
    }
    if (!env.BAR_ASSISTANT_TOKEN) {
      return json({ error: "Assistant unavailable" }, 503);
    }
    if (
      !authorized(request.headers.get("Authorization"), env.BAR_ASSISTANT_TOKEN)
    ) {
      return json({ error: "Unauthorized" }, 401, {
        "WWW-Authenticate": "Bearer",
      });
    }
    const mediaType = request.headers.get("Content-Type")?.split(";")[0].trim();
    if (mediaType?.toLowerCase() !== "application/json") {
      return json({ error: "Expected application/json" }, 415);
    }

    const turn = await readTurn(request);
    if (turn === "too-large") return json({ error: "Request too large" }, 413);
    if (!turn) {
      return json(
        { error: "Provide a question and a random UUIDv4 conversationId" },
        400,
      );
    }

    try {
      const workersAI = createAI({ binding: env.AI });
      const { text } = await tracedAI.generateText({
        model: workersAI(modelId),
        system,
        prompt: turn.prompt,
        maxOutputTokens: 550,
        maxRetries: 0,
        runtimeContext: {
          agentId: "pourstl-bar-assistant-worker",
          conversationId: turn.conversationId,
        },
        telemetry: {
          functionId: "pourstl-bar-assistant",
          includeRuntimeContext: { agentId: true, conversationId: true },
        },
      });
      const answer = text.trim();
      if (answer) return json({ answer });
    } catch {
      // Provider errors can include request data. Keep them out of HTTP responses.
    }
    return json({ error: "Assistant could not answer" }, 502);
  },
};
