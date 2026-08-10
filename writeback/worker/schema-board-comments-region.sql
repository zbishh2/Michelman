-- Michelman Writeback — region tag on board comments (Yvonne's request, 2026-07-28)
--
-- The Actions & Comments board on the Summary / Shipped as Promised tab carries one thread for
-- the whole business. Yvonne wants to read just her part of it, so each post now names the
-- region it is about and the visual can filter down to one.
--
-- Region, not company: the ask was worded as "each company … Americas, EMEA or Asia", but those
-- three are REGIONS. 'Dim Region' in the semantic model is the company -> region map that
-- already backs the per-region OTIF measures:
--     00010 -> Americas    00020 -> EMEA    00030 / 00034 / 00035 -> Asia
-- Storing the region keeps one post per region instead of one per JDE company, which is what
-- the three-way ask actually described. Values are constrained to that vocabulary so a typo
-- can't create a fourth silent bucket.
--
-- NULL region = "All regions": a post that concerns everyone. Those stay visible under every
-- filter selection rather than vanishing when a region is picked, and every pre-existing row is
-- NULL, so no back-fill guesswork about who old posts were meant for.
--
-- Apply with:
--   cd writeback/worker
--   npx wrangler d1 execute michelman-writeback --remote --file=./schema-board-comments-region.sql

-- SQLite has no ADD COLUMN IF NOT EXISTS. This is written to run exactly once; re-running it
-- fails with "duplicate column name: region", which is a safe, non-destructive error.
ALTER TABLE board_comments ADD COLUMN region TEXT
  CHECK (region IS NULL OR region IN ('Americas', 'EMEA', 'Asia'));

-- The visual's read is board + region + newest-first; this replaces the board-only index as the
-- covering one for a filtered read, and still serves the unfiltered read as a prefix scan.
CREATE INDEX IF NOT EXISTS idx_board_comments_board_region_created
  ON board_comments(board_key, region, created_at DESC)
  WHERE deleted_at IS NULL;
