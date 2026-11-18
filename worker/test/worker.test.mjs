// Run: node --test worker/test/   (no dependencies; Anthropic and KV are faked)
import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/worker.js";

function makeKV() {
  const m = new Map();
  return {
    m,
    async get(k) { return m.has(k) ? m.get(k) : null; },
    async put(k, v) { m.set(k, v); },
  };
}

function env(over = {}) {
  return { ANTHROPIC_API_KEY: "sk-test", APP_KEY: "app-key", ROOMPRINT_KV: makeKV(),
    MAX_SCANS_PER_DEVICE_PER_DAY: "2", MAX_SCANS_PER_DAY: "150", ...over };
}

async function call(e, { path = "/scan", method = "POST", key = "app-key", device = "dev-1", frames = "3", body } = {}) {
  const pending = [];
  const ctx = { waitUntil: (p) => pending.push(p) };
  const headers = { "content-type": "application/json" };
  if (key) headers["X-Roomprint-Key"] = key;
  if (device) headers["X-Roomprint-Device"] = device;
  if (frames) headers["X-Roomprint-Frames"] = frames;
  const msg = body ?? JSON.stringify([{ role: "user", content: [{ type: "text", text: "Room: Kitchen" }] }]);
  const req = new Request("https://scan.test" + path, method === "GET" ? { method, headers } : { method, headers, body: msg });
  const res = await worker.fetch(req, e, ctx);
  await Promise.all(pending);
  return { status: res.status, json: await res.json() };
}

function fakeAnthropic(text, { status = 200, stop = "end_turn" } = {}) {
  const sent = [];
  globalThis.fetch = async (url, init) => {
    sent.push({ url, body: init.body instanceof Blob ? await init.body.text() : init.body });
    if (status !== 200) return new Response("overloaded", { status });
    return new Response(JSON.stringify({ content: [{ type: "text", text }], stop_reason: stop,
      usage: { input_tokens: 40000, output_tokens: 1200 } }), { status: 200 });
  };
  return sent;
}

const fullAnswer = JSON.stringify({ items: [
  { name: "French-door refrigerator", brand: "LG", model: "LRFXS2503S", serial: "", quantity: 1, value: 2300, confidence: "high", frame: 1, notes: "" },
  { name: "Bar stools", quantity: 3, value: 140, confidence: "medium", frame: 9, notes: "" },
] });

test("health reports version and config", async () => {
  const r = await call(env(), { path: "/health", method: "GET" });
  assert.equal(r.status, 200);
  assert.equal(r.json.ok, true);
  assert.equal(r.json.configured, true);
  assert.match(r.json.version, /^\d{4}-\d{2}-\d{2}$/);
});

test("wrong key is refused", async () => {
  fakeAnthropic(fullAnswer);
  const r = await call(env(), { key: "nope" });
  assert.equal(r.status, 401);
});

test("a good scan returns normalized items and counts once", async () => {
  const e = env();
  const sent = fakeAnthropic(fullAnswer);
  const r = await call(e);
  assert.equal(r.status, 200);
  assert.equal(r.json.items.length, 2);
  assert.equal(r.json.items[1].frame, 0, "frame outside 0..2 falls back to 0");
  assert.equal(r.json.truncated, false);
  const day = new Date().toISOString().slice(0, 10);
  assert.equal(e.ROOMPRINT_KV.m.get(`scans:${day}:dev-1`), "1");
  assert.equal(e.ROOMPRINT_KV.m.get(`scans:${day}:all`), "1");
  const wrapped = JSON.parse(sent[0].body);
  assert.equal(wrapped.max_tokens, 16000);
  assert.ok(wrapped.system.includes("home-contents inventories"));
  assert.equal(wrapped.messages[0].role, "user");
});

test("a cut-off answer keeps every complete item", async () => {
  const e = env();
  const cut = fullAnswer.slice(0, fullAnswer.indexOf("Bar stools") + 30);
  fakeAnthropic(cut, { stop: "max_tokens" });
  const r = await call(e);
  assert.equal(r.status, 200);
  assert.equal(r.json.items.length, 1);
  assert.equal(r.json.items[0].name, "French-door refrigerator");
  assert.equal(r.json.truncated, true);
});

test("strings with braces don't confuse the salvage", async () => {
  const tricky = '{"items":[{"name":"Shelf {wall}","value":90,"notes":"say \\"hi\\" }"},{"name":"Lamp","val';
  fakeAnthropic(tricky, { stop: "max_tokens" });
  const r = await call(env());
  assert.equal(r.status, 200);
  assert.equal(r.json.items.length, 1);
  assert.equal(r.json.items[0].name, "Shelf {wall}");
});

test("an empty list is not counted against the phone", async () => {
  const e = env();
  fakeAnthropic(JSON.stringify({ items: [] }));
  const r = await call(e);
  assert.equal(r.status, 200);
  assert.equal(r.json.items.length, 0);
  const day = new Date().toISOString().slice(0, 10);
  assert.equal(e.ROOMPRINT_KV.m.get(`scans:${day}:dev-1`), undefined, "the phone's allowance is untouched");
  assert.ok(e.ROOMPRINT_KV.m.get(`usage:${day}`), "the tokens spent are still recorded");
});

test("model overload is a friendly 502 and not counted", async () => {
  const e = env();
  fakeAnthropic("", { status: 529 });
  const r = await call(e);
  assert.equal(r.status, 502);
  assert.match(r.json.error, /overloaded/);
  const day = new Date().toISOString().slice(0, 10);
  assert.equal(e.ROOMPRINT_KV.m.get(`scans:${day}:dev-1`), undefined);
});

test("per-phone daily cap", async () => {
  const e = env();
  fakeAnthropic(fullAnswer);
  assert.equal((await call(e)).status, 200);
  assert.equal((await call(e)).status, 200);
  const third = await call(e);
  assert.equal(third.status, 429);
  assert.match(third.json.error, /today's scan limit/);
});

test("frame count header is validated", async () => {
  fakeAnthropic(fullAnswer);
  assert.equal((await call(env(), { frames: "0" })).status, 400);
  assert.equal((await call(env(), { frames: "81" })).status, 400);
});
