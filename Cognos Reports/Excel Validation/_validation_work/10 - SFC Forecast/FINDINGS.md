# Report 10 — Ivan SFC2023 Forecast — Sales History count FAIL (deployed-lags-repo); reverse-map CLEAN on overlap; Forecast UNVALIDATED

Data as-of: Cognos export 2026-07-06 20:44; PBI refreshed 20:54 (~10 min apart).

## Sales History counts
Cognos `Sales History_2`: 907 rows · PBI: 21 rows · matched keys 19 · Cognos-only 888 · PBI-only 2.

## ROOT CAUSE (pinned): deployed partition = OLD F4211-only query
Deployed M (modified 2026-07-05 21:24) reads `FROM PRODDTA.F4211 sd` with NO F42119 union; repo Sales_History.m HAS the union (added 7/5) but was never deployed/refreshed. Cognos split = 887 closed (999) + 20 open; PBI = 21 open, zero closed — the entire purged history is missing. Same deployed-lags-repo drift as reports 01/03/08 tonight. **FIXED 2026-07-06 by orchestrator: repo union query pushed into the live partition via MCP; needs jumpbox refresh, expect ~900+ rows, then re-validate.**

## On the 19 overlapping rows — reverse-map verdict
- CLEAN (0 mismatches): Country Name, Global Parent, Global Parent Name, Customer Code/Name, Revenue BU. KG/LB/Qty tie exactly (KG 252,500; LB 556,661.31; factor 2.2045992; SALES_FACTOR=1 confirmed).
- **TM Name — 14/19 differ, format-only:** JDE ABALPH "Cheng, Ethan" vs Cognos DW "Ethan Cheng" (also Aranjo/Lee examples). Correct person resolved; needs a name-order reformat decision to tie for the report-out.
- Next Status 4/19 = snapshot drift (Cognos DW lags live F4211: 535->540 etc.). Open-order residuals: PBI-only 2734010/2737083 (new), Cognos-only 2719259 (shipped/cancelled) — freshness drift.

## Forecast page
Cognos sheet `Forecast_1` EMPTY — blank confirmed; UNVALIDATED by design. Deployed Forecast partition MATCHES repo (no drift). PBI profile: 124 rows; Requested 2026-07-04→07-25 (4 weekly buckets, 31 rows ea, 49,685.75 KG each); 6 bulk items; 9 2nd-items; 20 customers; branches SNG4/MUM3; all KG; TM all "Not Available"; sum 198,743; min 1 / max 9,891.75. MF*-prefixed F3460 fields still `-- TODO verify`; tiny values (1, 1.75 KG) flag the /10000 scaling risk — needs a JDE/F3460 human check.

## Cognos filters (Sales History)
- SDLNTY NOT LIKE '%F%'; SDCNDJ=0; SDPQOR/10000>0 (SALES_FACTOR=1)
- Promised (SDPDDJ) >= 2025-11-01 AND <= EOMONTH(GETDATE()+180d)
- Bulk whitelist: JS168.S, ME91735.S, ME92040.S, PP05S.S, ME91240G.S, MG7140.S, TSPP01.S, ME87235.S, ME90640.S, 211018IX.S, PP236A.S, NYS2104.S, JS168.E, BRIJS2.S, BRIJS20.S, BRIJS2.E, BRIJS20.E (verbatim dup entries kept)
- GST exclusion: CASE WHEN IMGBLK='-' THEN SDLITM ELSE IMGBLK END NOT IN (IGST,CGST,SGST,CVD,ADD)
- BUDGET_FACTOR -> no-op on F4211

Artifacts: cognos_sales_history.csv (907), pbi_Sales_History.csv (21), pbi_Forecast.csv (100-of-124 sample), comparison_sales_history.csv, residuals.csv, column_mismatches.csv, pbi_Forecast_profile.md.

*(Archived by orchestrator from val-10's final messages — subagent report-file writes were hook-blocked.)*
