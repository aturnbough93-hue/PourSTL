import assert from "node:assert/strict";
import { after, test } from "node:test";
import { fileURLToPath } from "node:url";
import { convertV4MiniflareOptions, Miniflare } from "miniflare";

const testToken = "local-test-token";
const question = "How much Campari goes into a Negroni?";
const body = JSON.stringify({
  question,
  conversationId: "538ab8a5-221d-40b5-98cd-179da28f4839",
});
const options = {
  modules: true,
  compatibilityDate: "2026-11-05",
  compatibilityFlags: ["nodejs_compat"],
};
const worker = {
  ...options,
  scriptPath: fileURLToPath(new URL("../dist/index.js", import.meta.url)),
  serviceBindings: { AI: { name: "model", entrypoint: "Model" } },
};
const mf = new Miniflare(
  convertV4MiniflareOptions({
    workers: [
      {
        ...worker,
        name: "assistant",
        bindings: { BAR_ASSISTANT_TOKEN: testToken },
      },
      { ...worker, name: "unconfigured", unsafeDirectSockets: [{}] },
      {
        ...options,
        name: "model",
        script: `
        import { WorkerEntrypoint } from "cloudflare:workers";

        export class Model extends WorkerEntrypoint {
          async run(model, input) {
            if (model !== "@cf/meta/llama-3.3-70b-instruct-fp8-fast") {
              throw new Error("Unexpected model");
            }
            const question = input.messages.find(({ role }) => role === "user")?.content;
            if (question === "Provider failure") {
              throw new Error("Private provider error");
            }
            if (question !== ${JSON.stringify(question)}) {
              throw new Error("Unexpected prompt");
            }
            return Response.json({ response: "Use one ounce of Campari." });
          }
        }

        export default {};
      `,
      },
    ],
  }),
);
after(() => mf.dispose());

const url = "http://localhost/v1/assistant/turn";
const headers = {
  authorization: `Bearer ${testToken}`,
  "content-type": "application/json",
};

test("returns a model answer and disables HTTP caching", async () => {
  const res = await mf.dispatchFetch(url, { method: "POST", body, headers });
  assert.equal(res.status, 200, await res.clone().text());
  assert.equal(res.headers.get("Cache-Control"), "no-store");
  assert.deepEqual(await res.json(), { answer: "Use one ounce of Campari." });
});

test("rejects unknown routes and wrong methods", async () => {
  const notFound = await mf.dispatchFetch("http://localhost/");
  assert.equal(notFound.status, 404);
  const wrongMethod = await mf.dispatchFetch(url);
  assert.equal(wrongMethod.status, 405);
  assert.equal(wrongMethod.headers.get("Allow"), "POST");
});

test("requires a configured token and valid credentials", async () => {
  const unconfigured = await mf.unsafeGetDirectURL("unconfigured");
  const unavailable = await fetch(new URL("/v1/assistant/turn", unconfigured), {
    method: "POST",
  });
  assert.equal(unavailable.status, 503);
  const unauthorized = await mf.dispatchFetch(url, {
    method: "POST",
    body,
    headers: { ...headers, authorization: "Bearer invalid" },
  });
  assert.equal(unauthorized.status, 401);
  assert.equal(unauthorized.headers.get("WWW-Authenticate"), "Bearer");
});

test("rejects invalid and oversized requests", async () => {
  for (const [input, expected] of [
    ["{", 400],
    [JSON.stringify({ question, conversationId: "user@example.invalid" }), 400],
    [body.replace(question, " ".repeat(2)), 400],
    [body.replace(question, "a".repeat(2_001)), 400],
    [" ".repeat(8_193), 413],
  ] as const) {
    const response = await mf.dispatchFetch(url, {
      method: "POST",
      headers,
      body: input,
    });
    assert.equal(response.status, expected);
  }
  const nonJson = await mf.dispatchFetch(url, {
    method: "POST",
    body,
    headers: { ...headers, "content-type": "text/plain" },
  });
  assert.equal(nonJson.status, 415);
});

test("keeps provider errors out of the response", async () => {
  const res = await mf.dispatchFetch(url, {
    method: "POST",
    headers,
    body: body.replace(question, "Provider failure"),
  });
  assert.equal(res.status, 502);
  assert.deepEqual(await res.json(), { error: "Assistant could not answer" });
});
