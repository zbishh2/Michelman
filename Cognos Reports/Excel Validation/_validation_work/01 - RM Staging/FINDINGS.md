# Validation — Report 01: RM Staging at Shell Road 2026 (ODS)

**Result: page 1 top table is CLEAN — 8/8 rows, all columns exact (0 discrepancies).** Page 1 bottom table and page 2 could NOT be validated from the Excel export — see "Scope limits." (UPDATE 2026-07-06 ~21:10: user supplied a live Cognos screenshot showing the bottom Work-Order table (15 rows) — follow-up validation of `WorkOrder_Detail` against it is in progress; this file will be superseded by the updated findings.)

## Data as-of
- **Cognos export** `DEMO - RM Staging at Shell Road 2026.xlsx`: provided as exported 2026-07-06 ~20:45. No timestamp embedded (Cognos/IBM export strips docProps; `Company="IBM Incorporated"` confirms Cognos origin).
- **PBI model** `PBIDesktop-RM Staging at Shell Road 2026 (ODS)-54791`: refreshed from ODSPROD the same evening. Both are "as of refresh day" (`CAST(GETDATE() AS date)`). Consistency confirmed: `WorkOrder_Detail` Work Order Start dates span 7/6–7/8/2026 = a Monday-2026-07-06 refresh with the +2-business-day forward window. Same day as the export.

## Scope limits (structural finding)
The Cognos export is a **single worksheet** ("page", A1:D9) holding **only the top summary table**. Verified: no hidden sheets, no defined names, one `Sheet1.xml`. Separately, PBI `table_operations List` returns only `RM Requirements`, `WorkOrder_Detail`, and two auto date tables — **`Shortage_Detail` is absent from the live model** (only `Shortage_Detail.m` exists in repo, never loaded).

| Section | Cognos export | PBI model | Validated? |
|---|---|---|---|
| Page 1 top — RM requirements (4 cols) | Yes (8 rows) | Yes — `RM Requirements` (8 rows) | **Yes — clean** |
| Page 1 bottom — Work-order detail | No (in export); YES via user screenshot (15 rows) | Yes — `WorkOrder_Detail` | Follow-up in progress |
| Page 2 — Shortage Details | **No** | **No** — table not built | No source + not built. NOTE: the live Cognos rendering fits on ONE page (user screenshot) — the "page 2" may not correspond to anything Cognos actually renders. |

## Section 1 — Page 1 top table "Raw Material requirements" — CLEAN
- Row counts: **Cognos 8 · PBI 8**, matched on business key `RM`.
- **Fully matched rows: 8 / 8.** Per-column mismatch counts: `QTY OH in CINC`=0, `Total RM Needed`=0, `QTY Required from CIN2`=0.
- Residuals: **none** (no Cognos-only, no PBI-only rows).
- **REAL discrepancies: none.**
- **Cosmetic / normalization notes: none needed.** Tolerance 0.01 was set but not exercised — every value tied at full precision (e.g. POLYMINP `1418.096`/`2307.904`), not merely at rounding. No trailing spaces, no leading-zero/date-format issues in this table. `ME91735O` has a blank `QTY OH in CINC` on both sides (no CINC on-hand → `AVG`=NULL) — counted as match; its Total RM Needed = Qty Required from CIN2 = 4400 on both (no-on-hand → full-need branch).

Row-by-row (all 8 match exactly):

| RM | QTY OH in CINC | Total RM Needed | QTY Required from CIN2 |
|---|---|---|---|
| AC6 | 1212.6 | 1470 | 257.4 |
| AC680 | 1121.29 | 7806.4 | 6685.11 |
| AC950 | 2155.2 | 13332 | 11176.8 |
| AFEG8200G | 20720.15 | 42556.8 | 21836.65 |
| DMD5980I | 19461 | 32267.89 | 12806.89 |
| ME91735O | *(blank)* | 4400 | 4400 |
| POLYMINP | 1418.096 | 3726 | 2307.904 |
| XIRAN1440M | 581 | 13360 | 12779 |

### The old E20 rounding question — RESOLVED
Prior tracker status was "6/7 exact with one rounding diff (~E20)". With this same-evening refresh the table ties **8/8 exact** — no rounding residual anywhere, including the `Total RM Needed` / `QTY Required from CIN2` cells that would have shown it. Conclusion: the earlier diff was a **stale-refresh timing artifact** (export and model refreshed at different moments), **not a formula/rounding defect**. Nothing to fix.

## Section 2 — Page 1 bottom "Work-order detail" — follow-up validation in progress vs user screenshot (15 rows)
`WorkOrder_Detail` loaded fine: dump showed 100 rows (may be maxRows-truncated — re-pull requested), cols Work Order Start / WO Number / Raw Material / FG Item, dates 7/6–7/8/2026. Internal-consistency spot-check: every `Raw Material` across the dumped rows is one of the 8 short materials from the top table (as designed by the inner-join to the shortage subquery) — holds. NOTE: screenshot shows Cognos rows through Thursday 7/9 while the .m window computes +2 business days from Monday = Wed 7/8 — date-window analysis requested.

## Section 3 — Page 2 "Shortage Details" — NOT VALIDATED (cannot be, currently)
Two independent blockers: (1) no Cognos page-2 data exists (and the live rendering fits one page), and (2) the live PBI model has **no `Shortage_Detail` table** — only `Shortage_Detail.m` exists in the repo, never loaded/refreshed. Prior status was "built but never data-validated"; in the **current model it is not present at all**. To close: load `Shortage_Detail.m` into the model AND obtain a Cognos rendering of the page-2 list (if one exists at all).

## Cognos filters (for the report-out Notes sheet)
From BUILD.md + the `.m` native SQL (shared shortage logic across top table, bottom table, page 2):
- **Objective/scope:** RM to transfer to **CINC** from **CIN2**; parts required within the **next 2 business days**; material is **NOT** a finished-good MPF.
- Manufacturing branch `WAMMCU='CINC'`.
- Open WO statuses: `WASRST NOT IN ('93','94','95','97','99','MM','CD')`.
- Open RM `(WMUORG−WMTRQT)/10000 > 0`.
- FG parent item `WALITM NOT LIKE '%-%'`.
- Component `WMCPIL NOT LIKE '%H2O%'`.
- Raw-material whitelist `IBPRP4 IN ('RRC','REC','RCB','TOL','PKG','RBW')` (hard-coded per Cognos).
- Part requested-date window `WMDRQJ` (Julian→date) BETWEEN **today−7** and **today+N business days**, N = 4 Thu/Fri, 3 Sat, else 2.
- On-hand (CINC): `LILOTS IN (' ','-')`, `LIPQOH/10000 > 0`.
- **SHORT test:** on-hand NULL, 0, or `< SUM(OpenRM)`.
- **Parity quirks reproduced on purpose** (so PBI ties to live Cognos): (1) `Total RM Needed` double-counts when an item has stock in both `' '` and `'-'` lot statuses; (2) `QTY OH in CINC` uses **AVG** across lot statuses, not SUM. Corrected formulas in BUILD.md §5, intentionally not applied.
- Legacy inactive: `IOH CIN2` had a disabled `use="prohibited"` filter prohibiting `POLYMINP` — currently inactive (POLYMINP does appear, row 8).

## Output files
`_validation_work\01 - RM Staging\`: `cognos_page.csv` (8), `pbi_RM Requirements.csv` (8), `pbi_WorkOrder_Detail.csv` (100, possibly truncated — re-pull pending), `comparison_rm_requirements.csv` (all 1s), `residuals.csv` (empty).

*(Archived by orchestrator from val-01's final message — subagent report-file writes were hook-blocked.)*

---
# ADDENDUM (2026-07-06 ~21:20) — Work-Order table validated vs live Cognos screenshot; page-2 resolved
- **Bottom table CONTENT matches Cognos exactly: 15/15 rows, all 4 columns** (comparison_workorder_detail.csv, all flags 1; Mon 1 / Tue 1 / Wed 5 / Thu 8).
- **Deployed-lags-repo drift found:** deployed WorkOrder_Detail = 135 rows (COUNTROWS; earlier 100 was the file cap) because the deployed query lacks the short-material INNER JOIN that repo WorkOrder_Detail.m has; report.json has no compensating visual filter, so the deployed page renders 135 vs Cognos 15. No duplicate rows (DISTINCT not a factor); PBI filtered to the 8 short materials = exactly the 15 Cognos rows. **FIXED 2026-07-06 by orchestrator: repo query pushed into live partition via MCP; needs jumpbox refresh -> expect 15 rows.**
- **Date window: NOT a bug.** Window filters WMDRQJ (requested date) to [today-7 .. today+2bd] = [6/29..7/8]; displayed column is WASTRT (WO start), which legitimately reaches Thu 7/9 on both sides. BUILD.md's "+2 = Wed" describes the requested-date window. No action.
- **Page 2 resolved:** live Cognos renders ONE page (user screenshot) — no Shortage Details page exists to match. PBIP defines a page-2 bound to a Shortage_Detail table that is absent from the deployed model (would render empty). Recommendation: drop PBI page 2 for parity, or load Shortage_Detail.m as an internal aid (user decision).
- residuals.csv now lists the 120 PBI-only non-short rows (diagnosis: missing join, fixed); pbi_WorkOrder_Detail.csv now full 135 rows.
