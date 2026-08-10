# Validation Findings — Report 02: Shell and Kemper - 530 Report

**Verdict: CLEAN.** Every Cognos export row reproduced exactly in Power BI (100% cell match). The only difference is one extra order line in PBI, fully explained by live-data drift.

## Data-as-of
- **Cognos export:** `Shell and Kemper - 530 Report.xlsx` (sheet `page`), exported 2026-07-06 ~20:41.
- **PBI:** `Shell_Kemper_530` on `PBIDesktop-CM Overview LIVE-54787`, dumped 2026-07-06 ~21:03 (refreshed same evening, AFTER the Cognos export).
- Both LIVE JDE/ODS; small forward drift in PBI expected.

## Row counts
| Source | Data rows | ERROR-owner rows |
|---|---|---|
| Cognos export | 43 | 12 |
| PBI `Shell_Kemper_530` | 44 | 12 |

- Match key `(Order#, Line#, Bulk, Item, Work Ctr)`; no duplicate keys either side.
- **Matched keys: 43** — every Cognos row found its PBI twin. Only in Cognos: **0**. Only in PBI: **1** (benign, below).

## Cell-level match rate (matched rows)
- **903 / 903 cells = 100.00%** across all 21 columns.
- **Per-column mismatch counts: ZERO in every column** (Promised Ship, Requested, Plant, Ship To, CS, Order#, Line#, Bulk, Item, Description, Owner, Planner, Status, Primary Qty, Primary UOM, Secondary Qty, Secondary UOM, Order Date, CSR Name, Work Ctr, MPF).
- Normalizations logged: dates → ISO (PBI carries `12:00:00 AM` time vs Cognos midnight — cosmetic); `Order#`/`Planner`/`Line#`/`Primary Qty`/`Secondary Qty` compared numerically (0.01 tol, no diffs); text trimmed; `Description` placeholder `' '` and blank CSR/Work Ctr normalize identically.

## REAL discrepancies
**None on matched rows.** The sole residual is one PBI-only row:

**ONLY_PBI — key `(2737445, 1, MT242AF, MT242AF-PL, <no work ctr>)`** → **LIVE-DATA DRIFT, not a scope issue.**
- Owner **Lance** (planner 335951, a **valid/non-error** row), Ship To "SMC Conway - Conway, AR", Plant CIN2, Promised Ship 2026-07-14, Requested 2026-07-07, **Order Date 2026-07-06 (booked today)**.
- Root cause: the line's own Order Date is the export day itself, and the PBI refresh ran *after* the 20:41 Cognos export. The order line was created in JDE in the intervening window, so it appears only in the later (PBI) snapshot. Timestamps support drift; it is NOT a query/mapping/scope defect (it satisfies every filter — company 00010, status 530, valid item/branch — which is precisely why it shows up once it exists). Re-exporting Cognos now would pick it up.

## Error-count reconciliation (export vs 1,299 vs 16 vs PBI)
- **The export carries NO "Number of Errors" card** — the `page` sheet is the 21-column detail list only; no count field/title/merged cell. (A stray `16` in the sheet is a **Secondary Qty data value**, not a counter — coincidence.)
- **Meaningful count = 12 today:** 12 ERROR-owner rows in the export, and PBI's `[Number of Errors]` measure returns **12** — exact tie.
- **1,299** = the known Cognos fan-out artifact (COUNT inflated once per un-collapsed Routing13 row). It is a live-dashboard card value, absent from this detail export, so nothing to reconcile against it here beyond noting it stands documented.
- **16** was the 7/5 distinct-error snapshot; on live data the ERROR population has since fallen to **12**. Both PBI and Cognos agree at 12 today, so the drop is real upstream data movement, not a system discrepancy.
- Dominant unmapped planner **302796** correctly decodes to ERROR on both sides. Distinct owners today (both sides): David Kramer, ERROR, Lance, Tammy (Brent/Eric/Mark Tilley have no open 530 lines this snapshot — expected).

## Cosmetic notes (not counted as discrepancies)
- Date time-component (`12:00:00 AM` PBI vs midnight export).
- `Description` empty placeholder rendered as space `' '` both sides; blank CSR Name / Work Ctr consistent.
- Duplicate `Qty`/`UOM` header labels in export match PBI field order.

## Cognos filters (per BUILD.md) — all confirmed reflected in the data
- Company `SDKCOO = '00010'`.
- Next Status `SDNXTR = '530'` (every row = 530; upstream MAIN8 pulls 525–550 then FINAL narrows to 530).
- `2nd Item (SDLITM) IS NOT NULL` (drops routing-only side of the FULL OUTER JOIN).
- Routing13 whitelist work centers + `CWDOCO = 0` + period-end-date `> today+31`, branches `CINC`/`CIN2`, `IBLITM NOT LIKE '%-%'`.
- Planner→Owner decode (else ERROR) applied identically.
- Parity quirks honored with no value impact: quantities via `AVG` (collapse to line grain = SUM here), `FULL OUTER JOIN`-behaving-as-left-join, Routing13 reduced to `DISTINCT`.

## Output files (in `_validation_work\02 - 530 Report\`)
- `cognos_page.csv` (43 rows), `pbi_Shell_Kemper_530.csv` (44 rows), `comparison.csv` (Cognos | 1/0 flags | PBI), `residuals.csv` (the one PBI-only row + diagnosis), `compare.py`.

*(Archived by orchestrator from val-02's final message — subagent report-file writes were hook-blocked.)*
