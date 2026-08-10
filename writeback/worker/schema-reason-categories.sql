-- Michelman Writeback — Classification picklist for the Reason Code Editor
--
-- `reason_dim.category` (header "Classification (Dec 2024)") was free text, which let
-- near-duplicates in: the seed found "Operations" alongside "Operations (??)". This table
-- is the managed list of allowed values; the visual renders the column as a dropdown and
-- admins maintain the choices behind the "Classifications" button.
--
-- Deliberately NOT a foreign key on reason_dim.category: historical rows must keep
-- resolving even if a choice is retired, exactly like reason_dim.active vs the fact rows.
-- The Worker enforces membership on write instead (PUT /reason-dim rejects an unknown
-- classification), and a rename cascades to reason_dim + logs into reason_dim_history.
--
-- Apply with:
--   cd writeback/worker
--   npx wrangler d1 execute michelman-writeback --remote --file=./schema-reason-categories.sql

CREATE TABLE IF NOT EXISTS reason_categories (
  name       TEXT PRIMARY KEY,
  sort_order INTEGER NOT NULL DEFAULT 1000,
  active     INTEGER NOT NULL DEFAULT 1,
  updated_by TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_reason_categories_active_sort
  ON reason_categories(active, sort_order, name);

-- ── Preseed from whatever reason_dim already holds ─────────────────────────
-- Seeding from the live data (rather than a hand-written list) guarantees no existing
-- row starts out with an off-list value. Ordered so the common ones sort first; the
-- "(??)" variant seeds too, so nothing is silently dropped — rename it onto Operations
-- from the Classifications dialog and the one affected code follows.
INSERT INTO reason_categories (name, sort_order, updated_by)
SELECT DISTINCT trim(category), 1000, 'seed'
FROM reason_dim
WHERE category IS NOT NULL AND trim(category) <> ''
ON CONFLICT(name) DO NOTHING;

UPDATE reason_categories SET sort_order = 10 WHERE name = 'Sales';
UPDATE reason_categories SET sort_order = 20 WHERE name = 'SC';
UPDATE reason_categories SET sort_order = 30 WHERE name = 'Operations';
UPDATE reason_categories SET sort_order = 40 WHERE name = 'Procurement';
UPDATE reason_categories SET sort_order = 50 WHERE name = 'R&D';
