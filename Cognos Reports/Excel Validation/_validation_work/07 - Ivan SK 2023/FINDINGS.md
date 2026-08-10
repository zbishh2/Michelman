# Report 07 — 1 - Ivan SK 2023 — Validation: CLEAN

Data as-of: Cognos export 2026-07-06 20:44:21; PBI refreshed 20:50:08 (~6 min apart).

## Match rates (page: Cognos rows / PBI rows / % exact)
- P1 Inventory: 308 / 307 / 99.68%
- P2 Work Order: 216 / 216 / 100%
- P3 Sales Orders: 52 / 52 / 100%
- P4 Inventory HP: 134 / 134 / 99.25%
- P5 Safety Stock HP: 75 / 75 / 100%

Only 2 residuals, both the SAME lot (SING / 251194NX.S / lot 4583186 / loc C03) whose on-hand fell 30.5 KG -> 0 in the ~6 min between export and refresh: drops off P1 (on-hand>0), reads 0 vs 30.5 on P4. Live-data drift, not a defect. Note: build-time expected counts (303/213/152) were stale; live counts 307/216/134 tie the fresh export.

## Method note
MCP DAX result files hard-cap at 100 rows regardless of maxRows; large tables paged by Branch Plant into sub-100 chunks and concatenated; on-disk pbi_*.csv = full tables, verified vs COUNTROWS.

## Cognos filters (BUILD.md), per page
- P1 Inventory: Branch in {AUBA,AUB2,SING,SNG4,MUM3,SHAN,CINC,CIN2,CIN4}; on-hand>0; Bulk in 99-item SK whitelist.
- P2 Work Order: component 2nd item in 8-item list (PR3460{,.E}, PR5980I{,.E,.S}, PR5985{,.E,.S}); Issued+Ordered>0; Start >= 2026-03-01; 2nd item NOT LIKE '%-%'; WAUOM in (LB,KG); WASRST not in (MM); outer QtyRequested>0.
- P3 Sales Orders: SDLNTY='S'; SDPQOR>0; SDNXTR not in (570,580,620,999); SDMCU in 12 branches (9 above + BARC,CIND,CINR); item-info side stays at 6 APAC/EMEA plants (LEFT-join-as-inner quirk); Bulk in 99-item whitelist.
- P4 Inventory HP: Status IS NULL or in (T,B,Q,H); Branch in 9 plants; Bulk in 13-item HP whitelist.
- P5 Safety Stock HP: SELECT DISTINCT; Branch in 9 plants; Bulk in 21-item HP whitelist.

*(Archived by orchestrator from val-07's final messages — subagent report-file writes were hook-blocked.)*
