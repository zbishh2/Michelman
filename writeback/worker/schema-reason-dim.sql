-- Michelman Writeback — Reason Code dimension schema (additive migration)
-- The `reason_dim` table is the EDITABLE reason-code dimension. It REPLACES the
-- SharePoint spreadsheet "OTIF and Revision Reason Codes.v2_Final.xlsm" as the
-- source of truth for BOTH the reason-code list AND which codes count as an OTIF
-- miss. The model loads it directly (edw_model/ReasonDim.m -> 'Reason Codes'
-- table), FactScheduleChange[RevisionReason] relates to [Code], and
-- [Is OTIF Relevant] reads [OTIF] (= "X" iff otif=1 here). Maintained in the
-- Reason Code Editor custom visual. See writeback/ARCHITECTURE.md.
--
-- Supersedes the short-lived otif_hit_codes table (dropped below; it only ever
-- held today's parity seed, no real user data).

DROP TABLE IF EXISTS otif_hit_codes;
DROP TABLE IF EXISTS otif_hit_history;

-- ── Reason code dimension (Reason Code Editor visual) ──────────────────────
-- One row per reason code (UDC 42/RR). `otif` is THE driver: 1 => a revision
-- with this code is an OTIF miss. `active` is dimension-row validity (0 =
-- retired / "do not use"; still kept so historical fact rows resolve). `otif`
-- and `active` are independent.
-- The review_530 / review_540 / typical_hit flags and the old_classification /
-- usage_examples / region_note text columns are carried over verbatim from the
-- SharePoint workbook (sheet "Reason Codes 20181017") so no source data is lost.
-- For an existing DB, migrate-reason-dim-columns.sql adds + backfills them.
CREATE TABLE IF NOT EXISTS reason_dim (
  code TEXT PRIMARY KEY,
  description TEXT,
  long_description TEXT,
  exemption_criteria TEXT,
  otif INTEGER NOT NULL DEFAULT 0,
  category TEXT,
  review_530 INTEGER NOT NULL DEFAULT 0,
  review_540 INTEGER NOT NULL DEFAULT 0,
  typical_hit INTEGER NOT NULL DEFAULT 0,
  old_classification TEXT,
  usage_examples TEXT,
  region_note TEXT,
  active INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 1000,
  updated_by TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_reason_dim_otif ON reason_dim(otif);
CREATE INDEX IF NOT EXISTS idx_reason_dim_active_sort
  ON reason_dim(active, sort_order, code);
CREATE INDEX IF NOT EXISTS idx_reason_dim_review
  ON reason_dim(review_530, review_540);

-- ── Reason dim history (field-level audit) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS reason_dim_history (
  history_id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL,
  actor_email TEXT,
  changed_at TEXT NOT NULL DEFAULT (datetime('now')),
  field TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT
);

CREATE INDEX IF NOT EXISTS idx_reason_dim_history_code_changed_at
  ON reason_dim_history(code, changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_reason_dim_history_changed_at
  ON reason_dim_history(changed_at DESC);
