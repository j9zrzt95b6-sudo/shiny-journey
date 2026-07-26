import { getStore } from "@netlify/blobs";

const CORS_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET,POST,DELETE,OPTIONS",
  "access-control-allow-headers": "content-type"
};

function json(statusCode, payload) {
  return new Response(JSON.stringify(payload), {
    status: statusCode,
    headers: CORS_HEADERS
  });
}

function resolveRuntimeStore(context) {
  if (context?.blobs?.getStore) return context.blobs.getStore("smart-care-state");
  if (context?.netlify?.blobs?.getStore) return context.netlify.blobs.getStore("smart-care-state");
  if (context?.netlifyBlobs?.getStore) return context.netlifyBlobs.getStore("smart-care-state");
  return null;
}

function getUpdatedAt(payload) {
  const ms = Number(payload && payload._meta && payload._meta.updatedAt);
  return Number.isFinite(ms) && ms > 0 ? ms : 0;
}

export default async function handler(req, context) {
  if (req.method === "OPTIONS") return json(200, { ok: true });

  try {
    const url = new URL(req.url);
    if (url.searchParams.get("_debug") === "1") {
      return json(200, {
        ok: true,
        contextKeys: Object.keys(context || {}),
        netlifyKeys: Object.keys(context?.netlify || {}),
        hasContextBlobs: !!context?.blobs?.getStore,
        hasNetlifyBlobs: !!context?.netlify?.blobs?.getStore,
        hasNetlifyBlobsAlt: !!context?.netlifyBlobs?.getStore,
        hasEnvBlobsToken: !!process.env.NETLIFY_BLOBS_TOKEN
      });
    }

    const store = resolveRuntimeStore(context) || getStore("smart-care-state");

    const syncKey = (url.searchParams.get("key") || "smart-care-default").trim();
    if (!syncKey) return json(400, { ok: false, error: "missing key" });

    if (req.method === "GET") {
      const value = await store.get(syncKey, { type: "json" });
      return json(200, { ok: true, value: value || null });
    }

    if (req.method === "DELETE") {
      if (url.searchParams.get("confirm") !== "delete") {
        return json(400, { ok: false, error: "missing confirm=delete" });
      }
      await store.delete(syncKey);
      return json(200, { ok: true, deleted: true });
    }

    if (req.method === "POST") {
      let body;
      try {
        body = await req.json();
      } catch {
        return json(400, { ok: false, error: "invalid json" });
      }
      if (!body || typeof body !== "object") return json(400, { ok: false, error: "invalid body" });

      const existing = await store.get(syncKey, { type: "json" });
      const existingUpdatedAt = getUpdatedAt(existing);
      const incomingUpdatedAt = getUpdatedAt(body);
      const force = url.searchParams.get("force") === "1";

      if (!force && existingUpdatedAt > 0 && incomingUpdatedAt <= 0) {
        return json(409, { ok: false, error: "missing updatedAt", serverUpdatedAt: existingUpdatedAt });
      }
      if (!force && existingUpdatedAt > 0 && incomingUpdatedAt < existingUpdatedAt) {
        return json(409, { ok: false, error: "stale write", serverUpdatedAt: existingUpdatedAt });
      }

      await store.setJSON(syncKey, body);
      return json(200, { ok: true, updatedAt: incomingUpdatedAt || existingUpdatedAt || Date.now() });
    }

    return json(405, { ok: false, error: "method not allowed" });
  } catch (error) {
    return json(500, { ok: false, error: String(error && error.message ? error.message : error) });
  }
}
