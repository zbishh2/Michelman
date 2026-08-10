# Cognos source collection — Report 15

- **Migration tracker Report ID: 144** ("Migration Report Status - Remaining Reports_7_13_26.xlsx", Reports Detail row 14)
- **Report name:** Open Orders Live – Data
- **Cognos path:** Public Folders > Michelman Reporting > Customer Service > US CSRs
- **Prior owner:** Lilly (LillySc) — handed to Zack 2026-07-14. Supporting docs live in Lilly's folder on Corpjump03 (Users folder).
- **Tracker status at handover:** "Completed \ Needs validated", 90%.
- **Notes column:** "Validation file in Lilly's folder"
- **DECISION (Zack, 2026-07-14): full from-scratch rebuild through our standard pipeline.** Lilly's prior PBI build is NOT the baseline — her process differs from ours. Her file/validation workbook are optional cross-check material only, never a build source.

## Intake checklist

1. [n/a] Cognos screenshot(s) — **none collected; not needed.** The xlsx export IS the render evidence (four named sheets render `No Data Available`; `Other_5` = 394 data rows).
2. [x] Full Cognos report specification XML → `Report XML.xml` (split out of `Intake\Queries + XML.txt`; **untruncated**, ends clean at `</report>`).
3. [x] Generated SQL for every query object → `Tammy.0.sql` `Nae.1.sql` `Kim.2.sql` `Shannon.3.sql` `Other.4.sql` (5/5).
4. [x] Rendered output export → `Intake\Open Orders - Live Data.xlsx` (5 sheets; `Other_5` 394 rows × 15 cols, header row 2). Validation target = `Other_5`.
5. [ ] Lilly's existing PBI file + validation workbook (Corpjump03) — **not collected; optional cross-check only** (per Zack's decision this is a from-scratch rebuild, not a baseline). Skip unless a cross-check is wanted.
6. [x] Prompts/parameters — **NONE** in this report. Expired-date-ceiling (C1) check: **none found** (only open-status filter + Kim's rolling `sysdate+30`).

## Spec package built (2026-07-15)

- **Source route:** ODS PRODDTA (JDE), SQL Server — SSAS rejected (no cube fact at this grain), EDW rejected (F4201 header attrs not pre-joined). Precedent = report 04.
- **Table design:** ONE table `Open Orders` (`OpenOrders.m` / `.commented.m`) + derived `CSR Page` column feeding all 5 pages; Kim's `+30` = hidden `Kim Window` 0/1 helper column + `Kim Window = 1` Kim-page filter (NOT a relative-date filter — orchestrator change, see BUILD.md §4). See `BUILD.md` §6.
- **Deliverables in root:** `BUILD.md`, `Report XML.xml`, 5× `*.sql`, `OpenOrders.m`, `OpenOrders.commented.m`, `00_verify_tables.sql`.
- **DEFECT (parity-now, reproduced):** the four hard-coded CSR names are stale → four pages empty, all 394 orders on `Other`. Fix (live CSR slicer) disclosed in BUILD.md §8, not applied.

## PBIP BUILT (2026-07-15)

- **Main PBIP:** `PBIP\Open Orders - Live Data.pbip` — tables `Open Orders` (import, `OpenOrders.m` verbatim) + `Last Refreshed`; 5 pages (Tammy/Nae/Kim/Shannon/Other), each a flat `tableEx` (15 cols, §3 order), static "Open Orders - Live Data" header, `Last Refreshed` card, page filter on `CSR Page` (+ `Kim Window = 1` on Kim), sort Promised Ship asc → Order asc. Every column `summarizeBy: none`; `CSR Name` / `CSR Page` / `Kim Window` hidden; auto date/time off; PBIR schema 1.0.0.
- **Probe PBIP:** `PROBE\R15 Probe.pbip` — 6 tables (Column Existence, CSR Fan-Out, Live CSR List, CSR-Less Dropped Lines, Count Parity, Scaling Spot Check) mirroring the 6 blocks of `00_verify_tables.sql`.
- **Lint:** both semantic models loaded via powerbi-modeling MCP `ConnectFolder` with **0 errors** (main = 2 tables/1 measure; probe = 6 tables).
- **Left for the human:** run `00_verify_tables.sql` on the jumpbox (or refresh `R15 Probe.pbip`) → paste to `probe_results.txt` → first refresh of the main PBIP → validate `Other` page vs xlsx (tight-capture). Remember the 2.0.0→1.0.0 `definition.pbir` knock-down if the jumpbox Desktop re-stamps on copy-back.

## Collected so far

Full intake present in `Intake\` (the migration workbook had no code tab; SQL+XML were captured directly into `Queries + XML.txt`). Spec complete — awaiting build agent + jumpbox probe run.
