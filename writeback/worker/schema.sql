-- Michelman Writeback — D1 schema
-- ONE database (michelman-writeback) serving both custom visuals:
--   Revision Log Editor  → revision_overrides / override_history / dropdown_reason_codes
--   Order Line Comments  → line_comments
-- Shared support: people (roles) + user_layout (per-user column order).
-- See writeback/ARCHITECTURE.md for the source-of-truth spec.

-- ── Revision overrides (Revision Log Editor) ───────────────────────────────
-- One row per overridden promised-date revision EVENT. revision_key is an
-- OPAQUE composite string produced identically by the visual field-well column
-- and the model:  OrderLineID | <ChangeDate yyyy-MM-dd> | <ChangeTime int text>
-- e.g. "00010,74,CM,4.000|2026-03-14|143502". It contains commas and pipes,
-- so it is only ever carried in the JSON body, never in a URL path.
-- order_line_id / change_date / change_time are denormalized parts kept for
-- readability and debugging only.
CREATE TABLE IF NOT EXISTS revision_overrides (
  revision_key TEXT PRIMARY KEY,
  order_line_id TEXT,
  change_date TEXT,
  change_time TEXT,
  revision_reason_override TEXT,
  note TEXT,
  exclude_flag INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_revision_overrides_order_line_id
  ON revision_overrides(order_line_id);

-- ── Line comments (Order Line Comments) ────────────────────────────────────
-- Comment thread per sales-order line (Orders[Order Line ID] grain).
-- Soft delete via deleted_at; the latest non-deleted comment per line folds
-- into the model at refresh.
CREATE TABLE IF NOT EXISTS line_comments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_line_id TEXT NOT NULL,
  body TEXT NOT NULL,
  actor_email TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT,
  deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_line_comments_order_line_id
  ON line_comments(order_line_id)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_line_comments_created
  ON line_comments(created_at);

-- ── People / roles ─────────────────────────────────────────────────────────
-- Maps USERPRINCIPALNAME() email → role (admin / editor / restricted).
-- editor+ may write revision overrides; any active listed person may comment;
-- admin manages people + reason codes.
CREATE TABLE IF NOT EXISTS people (
  person_key TEXT PRIMARY KEY,
  person_name TEXT NOT NULL,
  display_name TEXT,
  email TEXT,
  role TEXT,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_people_email
  ON people(email);

-- ── Override history (field-level audit) ───────────────────────────────────
-- One row per changed field on each revision-override PUT.
CREATE TABLE IF NOT EXISTS override_history (
  history_id INTEGER PRIMARY KEY AUTOINCREMENT,
  revision_key TEXT NOT NULL,
  actor_email TEXT,
  changed_at TEXT NOT NULL DEFAULT (datetime('now')),
  field TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT
);

CREATE INDEX IF NOT EXISTS idx_override_history_revision_key_changed_at
  ON override_history(revision_key, changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_override_history_changed_at
  ON override_history(changed_at DESC);

-- ── Reason-code dropdown (admin-maintained; visual dropdown source) ─────────
-- Seeded from the reason-code dim (UDC 42/RR). `code` is the UDC value stored
-- in revision_overrides.revision_reason_override; a `code` rename cascades
-- there so existing overrides keep pointing at the renamed code.
CREATE TABLE IF NOT EXISTS dropdown_reason_codes (
  code_id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  label TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_dropdown_reason_codes_active_sort
  ON dropdown_reason_codes(active, sort_order, code);

-- ── Per-user table layout (column order) ───────────────────────────────────
-- Composite key (email, visual_id); visual_id ∈ {revisions, comments}.
-- host.persistProperties does not survive the Power BI Service for viewers,
-- so each user's column reordering lives here instead.
CREATE TABLE IF NOT EXISTS user_layout (
  email TEXT NOT NULL,
  visual_id TEXT NOT NULL,
  column_order TEXT NOT NULL DEFAULT '[]',
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (email, visual_id)
);
