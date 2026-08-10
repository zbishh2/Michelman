-- Michelman Writeback — seed for the Executive Scorecard "Develop People" board (2026-08-03)
--
-- Section 4 of the Executive Scorecard page ("4. Develop People, Capability & Org Readiness") was
-- a static textbox: four KPI lines lifted off the client slide with nothing in the semantic model
-- behind them. It has been replaced by the Actions & Comments visual so leadership can maintain
-- the list themselves instead of it going stale between slide revisions.
--
-- board_key = 'exec-scorecard-people'. That is a DIFFERENT board from the OTIF Summary tab's
-- 'summary-shipped-as-promised' — same visual, same Worker, separate thread. Nothing crosses over.
--
-- These four rows are the verbatim slide text, so they carry no author: actor_email is NULL and
-- the visual renders "Unknown". Reattribute with a one-line UPDATE if you'd rather they show a
-- name. Bodies use the visual's markdown dialect (**bold**, "- " bullets) — see richtext.tsx.
--
-- created_at is set explicitly and descending, because the board reads
-- ORDER BY created_at DESC, id DESC. That keeps the feed in the slide's own top-to-bottom order
-- on first view rather than inverting it.
--
-- Apply with:
--   cd writeback/worker
--   npx wrangler d1 execute michelman-writeback --remote --file=./seed-board-exec-scorecard.sql
--
-- Re-running this would duplicate the four posts. The DELETE below makes it idempotent: it clears
-- only previously-seeded rows on this board (actor_email IS NULL), never anything a real user
-- posted. Deletes hard rather than soft so re-seeding doesn't accumulate tombstones.

DELETE FROM board_comments
WHERE board_key = 'exec-scorecard-people'
  AND actor_email IS NULL;

INSERT INTO board_comments (board_key, body, region, actor_email, created_at) VALUES
  ('exec-scorecard-people',
   '✓ **Critical leadership roles filled by 6/30**
- Aubange Site Leader — Joel Betrand
- Quality Manager Americas — Bill Frame
- Process Engineer Americas — Ian Karbowski
- Singapore Site Leader, Interim — Huan Lin Ng',
   NULL, NULL, '2026-08-03 12:00:04'),

  ('exec-scorecard-people',
   '✓ **Cascade goals & conduct Quarterly check-ins**',
   NULL, NULL, '2026-08-03 12:00:03'),

  ('exec-scorecard-people',
   '✓ **Behavior Recognition: 6 recognitions per quarter**',
   NULL, NULL, '2026-08-03 12:00:02'),

  ('exec-scorecard-people',
   '**Engagement / capability metrics improving**',
   NULL, NULL, '2026-08-03 12:00:01');
