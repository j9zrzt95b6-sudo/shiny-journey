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

function resolveStorageBackend(env) {
  const d1 = env.DB || env.SMART_CARE_D1;
  const hasD1 = Boolean(d1);
  const hasKv = Boolean(env.SMART_CARE_STATE);
  const requireD1 = String(env.REQUIRE_D1 || "").trim() === "1";

  if (hasD1) {
    return { backend: "d1", reason: "d1_binding", d1 };
  }
  if (requireD1) {
    throw new Error("D1 is required but no D1 binding found (expected DB or SMART_CARE_D1).");
  }
  if (hasKv) {
    return { backend: "kv", reason: "missing_d1_binding", kv: env.SMART_CARE_STATE };
  }

  throw new Error("No storage configured. Bind DB (or SMART_CARE_D1) or SMART_CARE_STATE.");
}

async function loadStoredValue(env, kvKey, syncKey) {
  const storage = resolveStorageBackend(env);
  if (storage.backend === "d1") {
    const row = await storage.d1.prepare(
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
    return { value, backend: "d1", reason: storage.reason };
  }

  const raw = await storage.kv.get(kvKey);
  return { value: normalizeParsedPayload(raw), backend: "kv", reason: storage.reason };
}

async function storeValue(env, kvKey, syncKey, payload, updatedAt) {
  const storage = resolveStorageBackend(env);
  if (storage.backend === "d1") {
    await storage.d1.prepare(
      `INSERT INTO sync_state (sync_key, payload, updated_at)
       VALUES (?, ?, ?)
       ON CONFLICT(sync_key) DO UPDATE SET
         payload = excluded.payload,
         updated_at = excluded.updated_at`
    ).bind(syncKey, JSON.stringify(payload), updatedAt).run();
    return { backend: "d1", reason: storage.reason };
  }

  await storage.kv.put(kvKey, JSON.stringify(payload));
  return { backend: "kv", reason: storage.reason };
}

async function deleteValue(env, kvKey, syncKey) {
  const storage = resolveStorageBackend(env);
  if (storage.backend === "d1") {
    await storage.d1.prepare(
      "DELETE FROM sync_state WHERE sync_key = ?"
    ).bind(syncKey).run();
    return { backend: "d1", reason: storage.reason };
  }

  await storage.kv.delete(kvKey);
  return { backend: "kv", reason: storage.reason };
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
        const { value, backend, reason } = await loadStoredValue(env, kvKey, syncKey);
        return json(200, { ok: true, value: value || null, storage: backend, storageReason: reason });
      }

      if (req.method === "DELETE") {
        if (url.searchParams.get("confirm") !== "delete") {
          return json(400, { ok: false, error: "missing confirm=delete" });
        }
        const result = await deleteValue(env, kvKey, syncKey);
        return json(200, { ok: true, deleted: true, storage: result.backend, storageReason: result.reason });
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

        const result = await storeValue(env, kvKey, syncKey, nextBody, serverUpdatedAt);
        return json(200, {
          ok: true,
          storage: result.backend,
          storageReason: result.reason,
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
