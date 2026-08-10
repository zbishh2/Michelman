# Report 04 — CM Open Sales Orders LIVE — Validation Findings

**VERDICT: CLEAN.** 38/38 rows match 1:1 across all 16 visible columns. Zero real discrepancies, zero cosmetic-only mismatches. 100% match rate.

## Data as-of
- **Cognos export:** `CM - Open Sales Orders Live.xlsx`, exported 2026-07-06 ~20:42 (live JDE, no prompts entered). 1 sheet (`page`), header row 1, data rows 2–39.
- **PBI model:** `CM_Open_Sales_Orders` on `PBIDesktop-CM Overview LIVE-54787`, refreshed same evening. Queried 2026-07-06 21:04. Live-vs-live same evening — no drift.

## Counts
| | Rows |
|---|---|
| Cognos export (data rows) | 38 |
| PBI `CM_Open_Sales_Orders` | 38 |
| Distinct business keys | 38 |
| Fully-matched rows (all 16 cols) | **38** |
| **Match rate** | **100%** |

**Re: "PBI had 36 on 7/5, now 38."** No anomaly — the live open-order book grew by 2 lines over ~24h (new orders land, shipped/closed lines drop off at status 999). Both sides pulled the same evening agree at 38. Method caveat: first `EVALUATE` was silently truncated to **10 rows** (default maxRows cap in the DAX tool); caught via `COUNTROWS` = 38, re-pulled with maxRows=100000. The 38 is confirmed two ways.

## Match method
- **Business key:** `(Order #, Line #, Item)` — grain is order line × (branch, 2nd item) per BUILD.md §2. No duplicate keys either side; 38 distinct keys.
- **Per-column 1/0 flags** across all 16 columns (in `comparison.csv`).
- **Normalizations (cosmetic, logged):** dates PBI `m/d/yyyy 12:00:00 AM` vs Cognos ISO → both midnight, identical; numbers parsed to float w/ 0.01 tolerance — fractional qtys (order 26001058 = 145.5049 / 3.6376) matched exactly; text whitespace-collapsed + trimmed.
- **REGION** excluded from comparison — PBI-only hidden slicer column, not in the Cognos visible list (BUILD.md §8).

## Per-column mismatch counts — ALL ZERO
Company 0 · Branch 0 · Order # 0 · Line # 0 · Customer PO 0 · Order Date 0 · Requested 0 · Promised Ship 0 · Item 0 · Next Status 0 · Primary Qty 0 · Primary UOM 0 · Secondary Qty 0 · Secondary UOM 0 · Customer Name 0 · TM Name 0

## REAL discrepancies
**None.**

## Rows beyond the first Cognos page (the 7/5 pagination gap)
**Closed and clean.** First full 38-row comparison; the ~18 rows never previously checked all tie 1:1. Company split: 00010 = 18 rows (CIN2 / Americas), 00020 = 20 rows (AUBA / Aubange). No missing rows, no extra rows, no tail divergence. Both companies present (confirms the "no company filter" design vs report 02).

## TM Name / 'Unassigned' fallback
Works correctly. The 3 Michelman Int'l Belgium lines — orders **2645790, 2701152, 2737269** — resolve to `Unassigned` on both sides (no F42140 sales-rep match). All other rows carry matching rep names (Hankins, Chabanne, Vanderstappen, Schloerb, Jeffers, Mahy, Patton, Vast, Vanderstiggel). Zero TM Name mismatches.

## Other parity checks verified
- **Double-SUM fan-out quirk (BUILD.md §5 quirk 1):** quantities match exactly — no item in this book maps to multiple whitelisted bulk codes, so no inflation to diverge on. Parity behavior held.
- **Sub-line survival:** order **26000959** appears twice (Line # 1 and 1.001) on both sides from `SDLNID/1000.0` scaling; both rows match (qty 3000/3 each).
- **Next Status ≠ 999:** all rows open (statuses 525–570 observed); no closed lines leaked.

## Cosmetic notes (not data issues)
- DAX export renders dates as `m/d/yyyy 12:00:00 AM`; visual uses medium-DMY (`24 Aug 2026`) — display formatting only.
- Customer Name internal double-spaces (e.g. "William Barnet  & Son", "Johns Manville - Waterville, OH(River)") appear identically in the source on both sides — not a transform artifact.

## Cognos filters (from BUILD.md, for reference)
- `SDNXTR NOT IN ('999')` (open orders) — the **only** baked filter.
- **No** company filter (both 00010 and 00020 appear).
- Bulk-item whitelist: 76-code `Bulk_Item IN (...)` list (incl. DPE3500.E, JS037, HP401, HSCF410, UNYTEC201).
- Optional prompts, NOT applied in this export (default = all): Promised-Ship date range; Region single-select.

## Output files (in `_validation_work\04 - Open SO Live\`)
- `cognos.csv` — 38 parsed export rows
- `pbi_CM_Open_Sales_Orders.csv` — full 38-row EVALUATE
- `comparison.csv` — Cognos cols | 16 per-column 1/0 flags | PBI cols, sorted by visual sort (Promised Ship ▲, Order # ▲, Line # ▲); every flag = 1
- `residuals.csv` — header only (no residuals)

*(Archived by orchestrator from val-04's final message — subagent report-file writes were hook-blocked.)*
