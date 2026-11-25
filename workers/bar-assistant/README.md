# PourSTL Bar Assistant Worker

The Worker answers general cocktail and bartending questions through Workers AI.
It runs separately from the offline iOS Bar Assistant and the static Pages site.
Each request is one model turn. The Worker has no access to iOS inventory, saved
recipes, or previous questions.

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

The Worker uses Workers AI through AI SDK v7. Workers tracing samples every
request at Cloudflare's default rate of 100%. Each model turn records messages
and can record tool payloads when tools are added. Messages include the system
prompt, caller question, and model answer, so send content suitable for storage
in the Cloudflare account. Trace identity uses the fixed agent name
`pourstl-bar-assistant`, fixed agent ID `pourstl-bar-assistant-worker`, and the
caller's random conversation ID.

When deploying this Worker, configure a high-entropy `BAR_ASSISTANT_TOKEN` as a
Worker secret in the same Workers AI account. After deployment, submit a test
question and look for the `invoke_agent pourstl-bar-assistant` turn and its
`chat` span in the [Cloudflare Agents dashboard](https://dash.cloudflare.com/?to=/:account/agents).
