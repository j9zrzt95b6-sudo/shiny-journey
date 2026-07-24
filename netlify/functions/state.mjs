import { getStore } from "@netlify/blobs";

const store = getStore("smart-care-state");

const CORS_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET,POST,OPTIONS",
  "access-control-allow-headers": "content-type"
};

function json(statusCode, payload) {
  return new Response(JSON.stringify(payload), {
    status: statusCode,
    headers: CORS_HEADERS
  });
}

export default async function handler(req) {
  if (req.method === "OPTIONS") return json(200, { ok: true });

  try {
    const url = new URL(req.url);
    const syncKey = (url.searchParams.get("key") || "smart-care-default").trim();
    if (!syncKey) return json(400, { ok: false, error: "missing key" });

    if (req.method === "GET") {
      const value = await store.get(syncKey, { type: "json" });
      return json(200, { ok: true, value: value || null });
    }

    if (req.method === "POST") {
      let body;
      try {
        body = await req.json();
      } catch {
        return json(400, { ok: false, error: "invalid json" });
      }
      if (!body || typeof body !== "object") return json(400, { ok: false, error: "invalid body" });

      await store.setJSON(syncKey, body);
      return json(200, { ok: true });
    }

    return json(405, { ok: false, error: "method not allowed" });
  } catch (error) {
    return json(500, { ok: false, error: String(error && error.message ? error.message : error) });
  }
}
