-- Manual KPIs — the Executive Scorecard's section 3 (Drive Continuous Improvement).
-- These KPIs have no model backing (capital projects, SC days on hand, inventory
-- healthiness, C2C/FMB milestones), so the values, targets and trend verdicts are
-- maintained by hand in the Scorecard KPIs visual and served straight from D1 —
-- no refresh dependency, edits appear on the next visual poll.
--
-- Apply: npx wrangler d1 execute michelman-writeback --remote -y --file schema-manual-kpis.sql

CREATE TABLE IF NOT EXISTS manual_kpis (
  kpi_key     TEXT PRIMARY KEY,          -- stable slug; the visual never shows it
  kpi         TEXT NOT NULL,             -- display label
  target      TEXT,                      -- display text ("≥ 90%", "70–94", "Milestones met")
  value       TEXT,                      -- display text; free-form ("On-Time: 63% · Budget: 100%")
  -- Same vocabulary the model-backed Trend column speaks. CHECK-constrained like
  -- board_comments.region: a typo must not create a fourth silent verdict. NULL = no verdict.
  trend       TEXT CHECK (trend IN ('Improving', 'Needs Improvement', 'Steady') OR trend IS NULL),
  sort_order  INTEGER NOT NULL DEFAULT 1000,
  active      INTEGER NOT NULL DEFAULT 1, -- 0 = retired row, kept for history
  updated_by  TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT
);

-- Field-level audit, mirrors reason_dim_history.
CREATE TABLE IF NOT EXISTS manual_kpi_history (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  kpi_key     TEXT NOT NULL,
  actor_email TEXT,
  changed_at  TEXT NOT NULL DEFAULT (datetime('now')),
  field       TEXT NOT NULL,
  old_value   TEXT,
  new_value   TEXT
);

CREATE INDEX IF NOT EXISTS idx_manual_kpi_history_key
  ON manual_kpi_history (kpi_key, changed_at);
