-- Michelman Writeback — board_comments (Ivan item 48 / Portia's request)
--
-- A running discussion thread pinned to a REPORT PAGE, not to a sales order line.
-- line_comments is keyed by Orders[Order Line ID] and answers "why did this line slip";
-- this table answers "what are we doing about OTIF this month" and has no order grain at
-- all, which is why it is a separate table rather than a nullable column on line_comments.
--
-- board_key namespaces threads so the same visual can be dropped on another page later
-- without the posts bleeding across. Default matches the Summary tab it ships on.
--
-- Apply with:
--   cd writeback/worker
--   npx wrangler d1 execute michelman-writeback --remote --file=./schema-board-comments.sql

CREATE TABLE IF NOT EXISTS board_comments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  board_key TEXT NOT NULL DEFAULT 'summary-shipped-as-promised',
  body TEXT NOT NULL,
  actor_email TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT,
  deleted_at TEXT
);

-- Newest-first read of a single board is the only hot query the visual makes.
CREATE INDEX IF NOT EXISTS idx_board_comments_board_created
  ON board_comments(board_key, created_at DESC)
  WHERE deleted_at IS NULL;
