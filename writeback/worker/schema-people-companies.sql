-- Michelman Writeback — company-scoped edit rights + comment audit trail
--
-- Edit permission model (agreed with Zack 2026-07-28):
--   admin role      -> manages the People list / reason codes, and may edit EVERY company
--   listed company  -> may edit any row whose Order Company matches
--   no companies    -> read-only
-- The admin/editor/restricted role no longer gates editing; only `admin` still means anything.
--
-- Company is stored canonically as the 5-char zero-padded JDE code ('00010'). The Worker
-- normalizes input, so an admin may type 10, 0010 or 00010 and get the same row.
--
-- Both grids can derive a row's company WITHOUT a new field binding: the Order Line ID is
-- "<company>,<order>,<type>,<line>" (e.g. "00010,74,CM,4.000"), so the company is the first
-- comma segment. revision_overrides.order_line_id carries the same shape.
--
-- Apply with:
--   cd writeback/worker
--   npx wrangler d1 execute michelman-writeback --remote --file=./schema-people-companies.sql

CREATE TABLE IF NOT EXISTS people_companies (
  person_key TEXT NOT NULL,
  company    TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (person_key, company)
);

CREATE INDEX IF NOT EXISTS idx_people_companies_company
  ON people_companies(company);

-- ── Comment audit trail ────────────────────────────────────────────────────
-- Sibling of override_history. One row per create / edit / delete of a line comment,
-- keeping the before and after text so an admin can see what was changed, not just that
-- something was. order_line_id is denormalized so the log survives a hard-deleted comment.
CREATE TABLE IF NOT EXISTS comment_history (
  history_id    INTEGER PRIMARY KEY AUTOINCREMENT,
  order_line_id TEXT NOT NULL,
  comment_id    INTEGER,
  actor_email   TEXT,
  changed_at    TEXT NOT NULL DEFAULT (datetime('now')),
  action        TEXT NOT NULL,
  old_value     TEXT,
  new_value     TEXT
);

CREATE INDEX IF NOT EXISTS idx_comment_history_line_changed
  ON comment_history(order_line_id, changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_comment_history_changed
  ON comment_history(changed_at DESC);
