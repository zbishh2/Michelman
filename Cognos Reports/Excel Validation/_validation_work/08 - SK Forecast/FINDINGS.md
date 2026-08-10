# Report 08 — Ivan SK 2023 Forecast — Sales History PASSES (98.07%); 3 real parity findings; Forecast UNVALIDATED

Data as-of: Cognos export 2026-07-06 20:44:40; PBI refreshed 20:50:50 (~6-min gap, live F4211). Both cover Promised 2026-03-02 → 2026-12-10. First live test of the DW_LEGACY→JDE reverse-map — it holds.

## Sheets
- `Sales History_2` = 881 rows x 25 cols (validated). "Order Number" printed twice (cols 6 & 20); PBI holds once — cosmetic (add field twice in visual).
- `Forecast_1` = BLANK ("No Data Available") — confirmed; unvalidatable.

## Count reconciliation — 895 PBI vs 881 export — CLEAN, +14 fully explained
Matched on business key: 864/881 = 98.07%. Cognos-only 17 + PBI-only 31 = 17 rescheduled 1:1 pairs (6-min drift) + 14 brand-new orders (2718622, 2734692/739/848, 2736904/05/941/42, 2737252, 2737445, AUBA 26001256/261/262/264) — net +14 exact. **F42119 union working; BUILD risk #2 closed.** Aggregate qtys tie within the drift (~0.8% = the 14 new + 17 reschedules).

## Per-column (864 matched rows)
- TM Name 469 REAL (format) · Ordered Qty KGs 143 REAL (factor) · Ordered Qty LBs 4 REAL (EA factor) · Next Status 16 + Open Indicator 9 (point-in-time; Open Indicator derivation CONFIRMED correct) · all other 18 cols 0.
- Zero-mismatch includes highest-risk reverse-maps: Country Name (F0005 00/CN decode — risk #9 resolved), Global Parent/GP Name (ABAN86 self-join), Customer Name, Revenue BU, Ordered Qty + Ordering UOM (SDPQOR/10000, SDUOM transaction UOM — risk #10 resolved; SALES_FACTOR=1 validated).

## REAL discrepancies (root-caused)
1. **TM Name (469 rows)** — Cognos DW "First Last" vs JDE ABALPH "Last, First" (e.g. [Krist Vanderstiggel] vs [Vanderstiggel, Krist]; nickname diffs exist: Dave vs David; some source names comma-less: "Agarwal Deepak"). Correct PERSON resolved; string order differs. Fix option: reformat ABALPH — decision needed (nicknames won't fully tie).
2. **Ordered Quantity KGs (143 rows, LB-primary)** — .m uses q*0.453593; Cognos uses q/2.2045992 = q*0.45359719. Evidence: ord 2608667 3800u → 1723.6693182 (C) vs 1723.6534 (PBI); 2569143 36000u → 16329.498804 vs 16329.348 (Δ up to ~0.17 KG). **Fix: LB → q / 2.2045992 in KG CASE.**
3. **Ordered Quantity LBs (4 rows, EA-primary 251194NX.S-B1)** — .m uses q*44; Cognos 44.091984 (= 20 × 2.2045992). Ord 2696135 qty1 → 44.091984 vs 44; 2723604 qty23 → 1014.115632 vs 1012. **Fix: EA → q × 44.091984.** (EA→KG 20 is correct; KG→LB 2.2045992 confirmed correct on main path.)

## Forecast page — UNVALIDATED (profile only)
768 rows; Requested 2026-07-04→07-25; 82 items; 155 customers; branches CIN2 436 / AUBA 196 / MUM3 84 / SNG4 36 / CINC 16 (correctly includes CINC/CIN2 — SK-specific vs report 10). Internally coherent; F3460 field maps (FTFQT /10000 scaling, FTDRQJ, FTAN8) untestable without JDE human check. Carries same LB→KG factor drift if ever tied.

## Cognos filters (SK-specific)
- IMBULK IN (~99-item SK whitelist: PR3460/PR5980I/PR5985/DPI*/MF*/MP*/24xxxPX/25xxxNX...), both pages.
- Sales History window: DUE_DATE >= 2026-03-01 (FC=2025-11-01), <= EOMONTH(sysdate+180). Confirmed min 2026-03-02.
- Forecast branches: FTMCU IN (AUBA,AUB2,SING,SNG4,MUM3,SHAN,CINC,CIN2,CIN4).
- SDPQOR/10000>0; SDCNDJ=0; next status incl. 999; SDLNTY NOT LIKE '%F%'; GST exclusion CASE.

## Artifacts
cognos_sales_history.csv (881), pbi_Sales_History.csv (895; 9 paginated DAX windows to beat the ~100-row CSV cap), comparison_sales_history.csv, residuals.csv, pbi_Forecast_profile.md, compare.py.

Net rec: Sales History production-ready; substantive fixes = the two conversion factors (+ optional TM name-reorder). None affect row counts.

*(Archived by orchestrator from val-08's full findings — subagent report-file writes were hook-blocked.)*
