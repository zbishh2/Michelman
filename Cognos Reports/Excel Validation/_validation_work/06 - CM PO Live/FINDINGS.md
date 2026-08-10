# Validation — Report 06 "CM PO Live"

**Result: CLEAN.** All 19 Cognos rows tie 1:1 to the 19 PBI rows; every displayed data cell matches (247/247 = 100.00%). No real discrepancies, no regressions.

## Data as-of
- Cognos export `CM - PO Live.xlsx`: 2026-07-06 ~20:42 (live JDE).
- PBI `CM_PO_Live` on `PBIDesktop-CM Overview LIVE-54787`: refreshed same evening, queried ~21:04.
- Rolling 90-day floor (`Promised Date >= GETDATE()-90`) → both captured in the same window, no drift.

## Counts
| | Rows |
|---|---|
| Cognos export (data rows) | 19 |
| PBI `CM_PO_Live` (`COUNTROWS`) | 19 |
| Matched on PO # + Line # | 19 |
| Only in Cognos | 0 |
| Only in PBI | 0 |

Join key = (Purchase Order Number, Line Number); unique on both sides.

## Per-column mismatch counts (all 13 displayed columns)
Company 0 · Branch 0 · PO # 0 · Line # 0 · Bulk Item 0 · Item 0 · QTY 0 · Open QTY 0 · 2nd QTY 0 · Next Status 0 · Requested Date 0 · Promised Date 0 · Vendor Name 0.
(REGION is on the PBI table only as the slicer source, not a displayed column per BUILD.md §2 — excluded from the compare.)

## REAL discrepancies
**None.** Fully clean.

## Process note (not a data issue)
First `EVALUATE 'CM_PO_Live'` returned only 10 rows — that was a default output row cap on the MCP tool, not a data gap. Re-ran with `maxRows:1000` + a `COUNTROWS` check → confirmed 19. Anyone re-validating this connection should set an explicit maxRows.

## Normalizations (cosmetic, no value differences)
- Dates: PBI `M/D/YYYY 12:00:00 AM` datetime and Excel datetimes both normalized to ISO `YYYY-MM-DD`; midnight time on both.
- Quantities: numeric compare, trailing-zero-insensitive; fractional values (41.1111, 15.5447, 9381.8184, etc.) matched to 4 dp.
- Next Status: `400` on every row both sides.
- Row order ignored (keyed compare). PBI natural table order isn't sorted; Promised-Date-ascending is a visual property (BUILD.md §3/§6.4), not testable from the raw table query — expected, not a defect.

## Cosmetic / formatting (out of data-parity scope, BUILD.md §3)
Header red/bold, blue title, black cell borders, right-align on QTY/Open QTY/2nd QTY/Next Status, medium date format, `#,0` whole-number qty format — visual layer, not checked here.

## Cognos filters (BUILD.md) verified against returned data
- **Open QTY > 0** — true on all 19 rows. ✔
- **Promised Date ≥ today − 90** — earliest returned = 2026-07-15, inside window. ✔
- **Bulk-item whitelist (75 codes)** — every returned Bulk Item (U101/U501/U701/HP1632/MDU4075B.E/U502.E/DPE3500/MDU2012B.E/NP4LF.S) is in the hard-coded `IN(...)` list. ✔
- **Region prompt** — optional single-select slicer on `CM_PO_Live[REGION]`, default all; rows span Americas / Aubange / Singapore. ✔
- **Promised-date range prompt** — optional Between slicer; unset in this export → base population. ✔

## Parity quirks (deliberate, BUILD.md §6) — no observable effect here
Double-SUM + Item-Branch fan-out are no-ops at one-line-per-PO grain (QTY = Open QTY on all 19 rows, no inflation). Degenerate LEFT-JOIN-as-INNER consistent with 0 unmatched rows either side.

## Regression check
Consistent with the 7/5 full-panel validation (all rows tied 1:1). Live row membership shifted vs 7/5 (rolling window), but the rebuild still reproduces Cognos exactly.

## Artifacts (in `_validation_work\06 - CM PO Live\`)
- `cognos.csv` — parsed export (19 rows)
- `pbi_CM_PO_Live.csv` — PBI table dump (19 rows, incl. REGION)
- `comparison.csv` — per-row 1/0 match flags, all 13 columns
- `residuals.csv` — header only (0 residual cells)

*(Archived by orchestrator from val-06's final message — subagent report-file writes were hook-blocked.)*
