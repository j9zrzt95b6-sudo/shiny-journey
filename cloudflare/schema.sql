CREATE TABLE IF NOT EXISTS sync_state (
  sync_key TEXT PRIMARY KEY,
  payload TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sync_state_updated_at
  ON sync_state(updated_at);
