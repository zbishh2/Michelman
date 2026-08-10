# Cognos source collection — Report 16

- **Migration tracker Report ID: 142** ("Migration Report Status - Remaining Reports_7_13_26.xlsx", Reports Detail row 22 + "Code to Validate LTL over 20k" tab)
- **Report name:** LTL report over 20k lbs
- **Cognos path:** Public Folders > Michelman Reporting > Customer Service
- **Prior owner:** Lilly (LillySc) — handed to Zack 2026-07-14.
- **Tracker status at handover:** "Data issues need researched", 90%.
- **Notes column:** "See notes in Code to Validate tab, join changed to include line and order num"
- **DECISION (Zack, 2026-07-14): full from-scratch rebuild through our standard pipeline.** The SQL files below are REFERENCE ONLY — the build derives from the Cognos original (XML + generated SQL), routed SSAS→EDW→ODS per the standing rule. Lilly's rewrite is a useful second opinion on JDE mappings, not the source of truth.

## Collected so far (extracted from the migration workbook, tab "Code to Validate LTL over 20k")

| File | What it is |
|---|---|
| `LTL rewrite (Lilly 2026-07-06).sql` | Lilly's rewritten T-SQL (from her 7/6/26 email) — PRODDTA.F4211 + F42140 CSR + F0101, with a **cross-server join** to `[EDWPROD].[EDW].[dbo].[vw_CAM_ID]` for CSR name override |
| `LTL.0.sql` | Old Cognos-generated SQL (Oracle, DW-era) — the original report's main query (`Report7`) |
| `User Details.1.sql` | Old Cognos-generated SQL — `DW_LEGACY.USER_DETAILS` CAM-ID lookup (the Cognos-side analogue of `vw_CAM_ID`) |

## Known semantic deltas between old Cognos SQL and Lilly's rewrite (verify at intake)

1. **>20,000 filter moved**: old = `SDPQOR/10000 > 20000` per-row in WHERE (pre-aggregation); rewrite = `HAVING SUM(...) > 20000` post-GROUP BY. Group keys include Order_Line in both, but confirm equivalence on multi-row groups.
2. **CSR name**: rewrite adds `COALESCE(vw_CAM_ID.CSRName, F42140-CSR name)` — the old report ran the USER_DETAILS lookup as a *separate* query. Tracker note "join changed to include line and order num" — confirm what join and which keys against Lilly.
3. Cross-server `EDWPROD` reference only works from a connection with that linked server (ODSPROD has it — `vw_CAM_ID` precedent exists). Alternative: two queries + PQ merge.

## Intake checklist

1. [~] Cognos screenshot — shown in chat 2026-07-15; **file still needs saving to `Intake\`** (agents read from disk only). Not required to build; needed to lock the pick-date format + confirm the grouped-matrix look.
2. [x] Full Cognos report specification XML — `Intake\XML.txt`, 20,315 bytes, untruncated (`grep -c truncated`=0, closes on `</report>`). Copied byte-identical to `Report XML.xml`.
3. [x] Generated SQL — captured 2026-07-15 from the live Cognos popup → `Intake\Generated SQL.txt`. **Confirmed byte-identical to the workbook "OLD report code"** (`LTL.0.sql` + `User Details.1.sql`): the DEPLOYED report still runs the old logic (per-row `SDPQOR/10000>20000` in WHERE, separate `DW_LEGACY.USER_DETAILS` lookup). Extracted to standard-named `Report.0.sql` + `CAM ID.1.sql`; `Query1.2.sql` documents the render-time join + burst. Lilly's rewrite is a PROPOSED fix, not the live report.
4. [ ] Rendered output export (row-count target) — **still pending**; no validation target on disk. `00_verify_tables.sql` block 5 computes today's live count so the build has a number. Supply the xlsx captured minutes apart from a refresh (tight-capture rule).
5. [x] Prompts/parameters; expired-date-ceiling check — **no prompts**, all filters static; **no date literals** → genuinely LIVE, no expired-ceiling risk. Confirmed against XML `detailFilters`.

## Spec status (2026-07-15)

**SPEC COMPLETE.** Deliverables in folder root: `Report XML.xml`, `Report.0.sql`, `CAM ID.1.sql`, `Query1.2.sql`, `LTL_Over_20k.m` + `.commented.m` (ODS route), `00_verify_tables.sql`, `BUILD.md`. Build agent authors the PBIP next.

## Probe/refresh status (2026-07-16)

**ALL 6 PROBE CATEGORIES PASS** (refreshed on jumpbox, read via MCP DAX — BUILD.md §10). Main PBIP refreshed (9:17 AM EDT): **5 rows, value-identical to the probe spot-check**. Per-row vs HAVING-SUM = provably identical today (no multi-row lines, diff 0). CSR fan-out exists globally (4 ship-tos, 2 rows/1 rep each) but touches none of today's rows; would double the qty if one qualifies — Cognos identical, disclose only.

## Validation status (2026-07-16, tight capture 09:41 vs PBI 09:17)

**DETAIL GRAIN VALIDATED 5/5** (BUILD.md §11; export + screenshot filed in `Intake\`). One live-drift cell (order 2744344 status 530→535 in the gap). **FINDING: Cognos "- Total" footers are AVERAGES** (Jul-20 32,800; Overall 38,820 — the Query1 `Average()` re-wrap surfaces in footers). **DECIDED (Dave Bubash, Teams 9:53 AM — after Zack raised the defect): KEEP AS AVERAGE** for Cognos parity; matrix value flipped to `Avg` in visual.json same day (Desktop must be closed without saving + reopened to pick it up). Date: **keep clean `MMM d, yyyy`** (midnight suffix not carried). Intake checklist items 1 (screenshot) and 4 (export) now [x].

## Build status (2026-07-15)

**BUILT.** `PBIP\LTL Report Over 20k lbs.pbip` (matrix + title + Last Refreshed card + CSR Name slicer) and `PROBE\R16 Probe.pbip` (11 probe tables) authored comment-free; both semantic models **lint-clean, 0 errors** (MCP ConnectFolder — main 2 tables/1 measure, probe 11 tables). Partition M verified byte-equivalent to `LTL_Over_20k.m`. See `BUILD.md` §9 for the full build record, matrix-subtotal-label deviation ("<value> - Total" not reproducible in a native matrix), and jumpbox to-dos. Awaiting jumpbox probes + first refresh + pending validation xlsx/screenshot.

- **Burst analysis:** this is a burst report; `CAM ID`/`Query1`/`USER_DETAILS` = pure per-CSR distribution plumbing. The visible page shows only `Report` columns → **PBI does NOT need USER_DETAILS.** Burst replaced by a CSR slicer (recommended) / RLS / subscriptions — open decision.
- **Route:** ODS PRODDTA (faithful port of the deployed SQL; report 04 precedent). SSAS is *viable* (models a `CSR for Sales Orders` dim wired to `Sales`) but its CSR comes from a different source than F42140 → deferred pending a jumpbox bake-off (mandate-preferred fast-follow).
- **Key open decisions:** burst replacement style; per-row vs HAVING-SUM >20k semantics (deployed = per-row, built as such); CSR source (F42140 vs enrichment); 23-carrier hard-coded exclusion.
