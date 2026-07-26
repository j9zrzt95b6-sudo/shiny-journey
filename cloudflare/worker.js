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

function getUpdatedAt(payload) {
  const ms = Number(payload && payload._meta && payload._meta.updatedAt);
  return Number.isFinite(ms) && ms > 0 ? ms : 0;
}

function getClientBaseUpdatedAt(payload) {
  const fromLastSyncedAt = Number(payload && payload._meta && payload._meta.lastSyncedAt);
  if (Number.isFinite(fromLastSyncedAt) && fromLastSyncedAt > 0) return fromLastSyncedAt;
  const fromBaseUpdatedAt = Number(payload && payload._meta && payload._meta.baseUpdatedAt);
  if (Number.isFinite(fromBaseUpdatedAt) && fromBaseUpdatedAt > 0) return fromBaseUpdatedAt;
  return 0;
}

export default {
  async fetch(req, env) {
    if (req.method === "OPTIONS") return json(200, { ok: true });

    try {
      const url = new URL(req.url);
      const syncKey = (url.searchParams.get("key") || "smart-care-default").trim();
      if (!syncKey) return json(400, { ok: false, error: "missing key" });

      const kvKey = `smart-care:${syncKey}`;

      if (req.method === "GET") {
        const raw = await env.SMART_CARE_STATE.get(kvKey);
        const value = raw ? JSON.parse(raw) : null;
        return json(200, { ok: true, value: value || null });
      }

      if (req.method === "DELETE") {
        if (url.searchParams.get("confirm") !== "delete") {
          return json(400, { ok: false, error: "missing confirm=delete" });
        }
        await env.SMART_CARE_STATE.delete(kvKey);
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

        const raw = await env.SMART_CARE_STATE.get(kvKey);
        const existing = raw ? JSON.parse(raw) : null;
        const existingUpdatedAt = getUpdatedAt(existing);
        const incomingUpdatedAt = getUpdatedAt(body);
        const clientBaseUpdatedAt = getClientBaseUpdatedAt(body);
        const force = url.searchParams.get("force") === "1";

        if (!force && existingUpdatedAt > 0 && clientBaseUpdatedAt <= 0) {
          return json(409, { ok: false, error: "missing base version", serverUpdatedAt: existingUpdatedAt });
        }
        if (!force && existingUpdatedAt > 0 && clientBaseUpdatedAt < existingUpdatedAt) {
          return json(409, { ok: false, error: "stale base version", serverUpdatedAt: existingUpdatedAt });
        }

        const serverUpdatedAt = Date.now();
        const nextBody = {
          ...body,
          _meta: {
            ...(body._meta || {}),
            updatedAt: serverUpdatedAt,
            lastSyncedAt: serverUpdatedAt
          }
        };

        await env.SMART_CARE_STATE.put(kvKey, JSON.stringify(nextBody));
        return json(200, {
          ok: true,
          updatedAt: serverUpdatedAt,
          acceptedClientUpdatedAt: incomingUpdatedAt || 0,
          previousServerUpdatedAt: existingUpdatedAt
        });
      }

      return json(405, { ok: false, error: "method not allowed" });
    } catch (error) {
      return json(500, { ok: false, error: String(error && error.message ? error.message : error) });
    }
  }
};
