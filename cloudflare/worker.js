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

function normalizeParsedPayload(raw) {
  if (!raw) return null;
  if (typeof raw === "object") return raw;
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch {
    return null;
  }
}

async function loadStoredValue(env, kvKey, syncKey) {
  const d1 = env.DB || env.SMART_CARE_D1;
  if (d1) {
    const row = await d1.prepare(
      "SELECT payload, updated_at FROM sync_state WHERE sync_key = ?"
    ).bind(syncKey).first();
    const value = normalizeParsedPayload(row && row.payload);
    if (value && (!value._meta || !Number(value._meta.updatedAt))) {
      value._meta = {
        ...(value._meta || {}),
        updatedAt: Number(row && row.updated_at) || 0,
        lastSyncedAt: Number(row && row.updated_at) || 0
      };
    }
    return { value, backend: "d1" };
  }

  if (!env.SMART_CARE_STATE) {
    throw new Error("No storage configured. Bind DB (or SMART_CARE_D1) or SMART_CARE_STATE.");
  }

  const raw = await env.SMART_CARE_STATE.get(kvKey);
  return { value: normalizeParsedPayload(raw), backend: "kv" };
}

async function storeValue(env, kvKey, syncKey, payload, updatedAt) {
  const d1 = env.DB || env.SMART_CARE_D1;
  if (d1) {
    await d1.prepare(
      `INSERT INTO sync_state (sync_key, payload, updated_at)
       VALUES (?, ?, ?)
       ON CONFLICT(sync_key) DO UPDATE SET
         payload = excluded.payload,
         updated_at = excluded.updated_at`
    ).bind(syncKey, JSON.stringify(payload), updatedAt).run();
    return "d1";
  }

  if (!env.SMART_CARE_STATE) {
    throw new Error("No storage configured. Bind DB (or SMART_CARE_D1) or SMART_CARE_STATE.");
  }

  await env.SMART_CARE_STATE.put(kvKey, JSON.stringify(payload));
  return "kv";
}

async function deleteValue(env, kvKey, syncKey) {
  const d1 = env.DB || env.SMART_CARE_D1;
  if (d1) {
    await d1.prepare(
      "DELETE FROM sync_state WHERE sync_key = ?"
    ).bind(syncKey).run();
    return "d1";
  }

  if (!env.SMART_CARE_STATE) {
    throw new Error("No storage configured. Bind DB (or SMART_CARE_D1) or SMART_CARE_STATE.");
  }

  await env.SMART_CARE_STATE.delete(kvKey);
  return "kv";
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
        const { value, backend } = await loadStoredValue(env, kvKey, syncKey);
        return json(200, { ok: true, value: value || null, storage: backend });
      }

      if (req.method === "DELETE") {
        if (url.searchParams.get("confirm") !== "delete") {
          return json(400, { ok: false, error: "missing confirm=delete" });
        }
        const backend = await deleteValue(env, kvKey, syncKey);
        return json(200, { ok: true, deleted: true, storage: backend });
      }

      if (req.method === "POST") {
        let body;
        try {
          body = await req.json();
        } catch {
          return json(400, { ok: false, error: "invalid json" });
        }
        if (!body || typeof body !== "object") return json(400, { ok: false, error: "invalid body" });

        const { value: existing } = await loadStoredValue(env, kvKey, syncKey);
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

        const backend = await storeValue(env, kvKey, syncKey, nextBody, serverUpdatedAt);
        return json(200, {
          ok: true,
          storage: backend,
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
