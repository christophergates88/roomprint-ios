// Roomprint scan service — a Cloudflare Worker.
//
// POST /scan
//   headers: X-Roomprint-Key: <APP_KEY>, X-Roomprint-Device: <uuid>, X-Roomprint-Room: <name>, X-Roomprint-Frames: <count>
//   body:    the Claude "messages" array as JSON, built by the app:
//            [{"role":"user","content":[{"type":"text","text":"Frame 0 ..."},{"type":"image","source":{...}}, ...]}]
//   → { items: [{ id, name, brand, model, serial, quantity, value, confidence, frame, notes }], model, usage }
// GET /health → { ok: true }
//
// The Worker never parses the frames: it wraps the app's messages array with the model, limits and the
// system prompt (so the app cannot change those) and forwards the bytes. That keeps CPU time near zero,
// which matters on the free plan. Frames are not stored anywhere; KV holds only daily counters.
// Secrets: ANTHROPIC_API_KEY, APP_KEY. Vars: MODEL, MAX_FRAMES, MAX_BODY_MB, MAX_SCANS_PER_DEVICE_PER_DAY, MAX_SCANS_PER_DAY.

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

const SYSTEM_PROMPT = `You build home-contents inventories for insurance claims from walkthrough video frames of ONE room.
You receive frames in time order, each with any label text the phone's OCR read from that frame.

Your job: list every distinct belonging of meaningful value visible across the frames, as the owner's insurer would want it.
Rules:
- One entry per distinct physical object (or per identical set, with quantity). The same object seen in several frames is ONE entry: pick the frame that shows it best.
- Include furniture, electronics, appliances, exercise and sports gear, tools, instruments, art, rugs, lighting, decor worth over about $25, and sets of smaller things as one line ("Books, about 60", "Kitchen utensils, set").
- Skip the building itself (walls, windows, built-in cabinets, flooring, ceiling fans that are part of the house), consumables, trash, and people or pets.
- brand/model/serial: ONLY from what is legible in a frame or in the OCR text. Never guess a brand or model from appearance alone; leave them empty instead. OCR text can contain errors, so copy model and serial strings carefully and only when they clearly belong to that object.
- value: estimated replacement cost in US dollars for ONE unit, new, today, as a whole number. Be realistic for the visible brand/quality; when unsure, use a typical mid-range price for that kind of item.
- quantity: how many identical units (chairs, dumbbells, etc.).
- confidence: "high" when the object and its value are clear, "medium" when the object is clear but the value is a rough estimate, "low" when the object itself is uncertain.
- frame: the index (0-based, as given) of the frame that shows the object best.
- notes: short, only when useful (e.g. "two matching nightstands", "serial partly hidden").
Return ONLY a JSON object: {"items":[{"name":"","brand":"","model":"","serial":"","quantity":1,"value":0,"confidence":"high|medium|low","frame":0,"notes":""}]}. No prose, no markdown fences.`;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true, model: env.MODEL || "claude-sonnet-5-5", configured: Boolean(env.ANTHROPIC_API_KEY && env.APP_KEY) });
    }
    if (request.method !== "POST" || url.pathname !== "/scan") {
      return json({ error: "not found" }, 404);
    }
    if (!env.ANTHROPIC_API_KEY || !env.APP_KEY) {
      return json({ error: "service not configured" }, 503);
    }
    if (request.headers.get("X-Roomprint-Key") !== env.APP_KEY) {
      return json({ error: "unauthorized" }, 401);
    }
    const device = (request.headers.get("X-Roomprint-Device") || "").slice(0, 64);
    const frameCount = parseInt(request.headers.get("X-Roomprint-Frames") || "0", 10);
    const maxFrames = parseInt(env.MAX_FRAMES || "80", 10);
    if (!device || !Number.isFinite(frameCount) || frameCount < 1 || frameCount > maxFrames) {
      return json({ error: `need X-Roomprint-Device and 1-${maxFrames} frames` }, 400);
    }
    const maxBytes = Math.round(parseFloat(env.MAX_BODY_MB || "14") * 1024 * 1024);
    const declared = parseInt(request.headers.get("content-length") || "0", 10);
    if (declared > maxBytes) {
      return json({ error: "too many or too large frames" }, 413);
    }

    // Daily caps protect the credit balance from a runaway or hostile client.
    const day = new Date().toISOString().slice(0, 10);
    if (env.ROOMPRINT_KV) {
      const perDevice = parseInt(env.MAX_SCANS_PER_DEVICE_PER_DAY || "6", 10);
      const global = parseInt(env.MAX_SCANS_PER_DAY || "150", 10);
      const dKey = `scans:${day}:${device}`;
      const gKey = `scans:${day}:all`;
      const [dCount, gCount] = await Promise.all([env.ROOMPRINT_KV.get(dKey), env.ROOMPRINT_KV.get(gKey)]);
      const d = parseInt(dCount || "0", 10);
      const g = parseInt(gCount || "0", 10);
      if (d >= perDevice) {
        return json({ error: "This phone has reached today's scan limit. Try again tomorrow." }, 429);
      }
      if (g >= global) {
        return json({ error: "The scan service is busy today. Try again tomorrow." }, 429);
      }
      ctx.waitUntil(Promise.all([
        env.ROOMPRINT_KV.put(dKey, String(d + 1), { expirationTtl: 172800 }),
        env.ROOMPRINT_KV.put(gKey, String(g + 1), { expirationTtl: 172800 }),
      ]));
    }

    // Read the app's messages array as bytes (I/O, not CPU) and wrap it without parsing it.
    const messagesBytes = await request.arrayBuffer();
    if (messagesBytes.byteLength > maxBytes || messagesBytes.byteLength < 2) {
      return json({ error: "too many or too large frames" }, 413);
    }
    const model = env.MODEL || "claude-sonnet-5-5";
    const head = `{"model":${JSON.stringify(model)},"max_tokens":4000,"system":${JSON.stringify(SYSTEM_PROMPT)},"messages":`;
    const body = new Blob([head, messagesBytes, "}"], { type: "application/json" });

    let resp;
    try {
      resp = await fetch(ANTHROPIC_URL, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-api-key": env.ANTHROPIC_API_KEY,
          "anthropic-version": ANTHROPIC_VERSION,
        },
        body,
      });
    } catch (e) {
      return json({ error: "Couldn't reach the model service. Try again in a minute." }, 502);
    }
    if (!resp.ok) {
      const detail = await resp.text().catch(() => "");
      let friendly = `The model service returned ${resp.status}.`;
      if (resp.status === 400) friendly = "The scan request was rejected (bad frames?). Try a shorter video.";
      if (resp.status === 401) friendly = "The scan service's API key is missing or wrong.";
      if (resp.status === 429) friendly = "The model service is rate-limited right now. Try again in a minute.";
      if (resp.status === 529 || resp.status === 503) friendly = "The model service is overloaded. Try again in a minute.";
      return json({ error: friendly, detail: detail.slice(0, 300) }, resp.status === 429 ? 429 : 502);
    }
    const data = await resp.json();
    const text = (data.content || []).filter((c) => c.type === "text").map((c) => c.text).join("\n");
    const parsed = extractJSON(text);
    if (!parsed || !Array.isArray(parsed.items)) {
      return json({ error: "The model returned something unexpected. Try again.", raw: text.slice(0, 400) }, 502);
    }
    const items = parsed.items.map((it, i) => normalizeItem(it, i, frameCount)).filter(Boolean);
    return json({ items, model, usage: data.usage || null });
  },
};

function normalizeItem(it, i, frameCount) {
  const name = String(it.name || "").trim().slice(0, 80);
  if (!name) return null;
  const qty = Math.max(1, Math.min(500, parseInt(it.quantity, 10) || 1));
  const value = Math.max(0, Math.min(1_000_000, Math.round(Number(it.value) || 0)));
  let frame = parseInt(it.frame, 10);
  if (!Number.isFinite(frame) || frame < 0 || frame >= frameCount) frame = 0;
  const conf = ["high", "medium", "low"].includes(it.confidence) ? it.confidence : "medium";
  return {
    id: `s${i}`,
    name,
    brand: String(it.brand || "").trim().slice(0, 60),
    model: String(it.model || "").trim().slice(0, 60),
    serial: String(it.serial || "").trim().slice(0, 60),
    quantity: qty,
    value,
    confidence: conf,
    frame,
    notes: String(it.notes || "").trim().slice(0, 160),
  };
}

function extractJSON(text) {
  if (!text) return null;
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return null;
  }
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}
