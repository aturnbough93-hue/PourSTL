# PourSTL Bar Assistant Worker

The Worker answers general cocktail and bartending questions through Workers AI.
The Bar Assistant in both the iPhone app and PourSTL Web uses local rules.
Neither app calls the Worker, and it has no access to either app's stored data.
Each accepted API question starts a single model turn without conversation history.

## API

Send a `POST /v1/assistant/turn` with `Content-Type: application/json` and an
`Authorization: Bearer <token>` header. Keep the token in a trusted server or
operator environment. Use a random UUIDv4 as `conversationId` and reuse it for
turns that should appear together in the Cloudflare Agents dashboard. The question
can be up to 2,000 characters. The JSON body can be up to 8 KiB.

```json
{
  "conversationId": "538ab8a5-221d-40b5-98cd-179da28f4839",
  "question": "How do I scale a Negroni for six servings?"
}
```

The response is JSON with an `answer` string. The conversation ID groups traces
only. Answer generation uses the current question.

## Local validation

Run from this directory with Node.js 22.18 or later.

```sh
npm ci
npm run format:check
npm run typecheck
npm test
```

`npm test` builds with Wrangler in dry-run mode and exercises the bundled Worker
against a stubbed Workers AI binding. It requires no Cloudflare account or
credentials.

## Cloudflare tracing

The Worker uses Workers AI through AI SDK v7. Workers tracing uses Cloudflare's
[default sampling rate of 100%](https://developers.cloudflare.com/workers/observability/traces/#sampling).
Message recording is enabled for every model turn.
Tool payload recording is enabled, but no tools are configured. Messages include
the system prompt, caller question, and model answer, so do not send personal or
confidential information. Trace identity uses the fixed agent name
`pourstl-bar-assistant`, fixed agent ID `pourstl-bar-assistant-worker`, and the
caller's random conversation ID.

When deploying this Worker, configure a high-entropy `BAR_ASSISTANT_TOKEN` as a
Worker secret in the same Workers AI account. After deployment, send two test
questions with the same random conversation ID and a third with a new ID. In the
[Cloudflare Agents dashboard](https://dash.cloudflare.com/?to=/:account/agents),
confirm that the first two turns share a session and the third starts a separate
session. Each turn should have one `invoke_agent pourstl-bar-assistant` span
with a nested `chat` span.

## Production deployment

The Worker is deployed as `pourstl-bar-assistant` in the Cloudflare account that
owns the pourstl.com zone, at
`https://assistant.pourstl.com/v1/assistant/turn`. That hostname is a Workers
custom domain. The `workers.dev` route and Preview URLs are off. Traces are
enabled at 100% sampling, and Workers Logs are disabled.

`BAR_ASSISTANT_TOKEN` is set as a Worker secret and is not stored in this
repository. To rotate it, set a new value with
`npx wrangler secret put BAR_ASSISTANT_TOKEN` from this directory and update the
callers. To redeploy, run `npx wrangler deploy` while signed in to that account.
