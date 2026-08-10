# Report 09 "Ivan FC 2023" — Validation: CLEAN (no rebuild defects; all diffs = live-JDE drift)

**IMPORTANT:** PBI model was refreshed 2026-07-05 17:04 (per Work_Orders[DATE]/Inventory[NOW] GETDATE stamps), NOT the evening of 7/6 — the 7/6 jumpbox refresh apparently did not reach this pbix. Cognos export 2026-07-06 20:43 → ~27.6h gap. ALL discrepancies below are consistent with that gap; re-refresh + quick re-compare recommended for the report-out.

## Row counts & match rates (full data; truncation handled)
| Table | Cognos | PBI | Exact match | Rate |
|---|---|---|---|---|
| Inventory | 85 | 85 | 81 | 95.3% |
| Work_Orders | 416 | 413 | 411 | 98.8% |
| Sales_Order_Summary | 24 | 22 | 17 | 70.8% |
| Inventory_HP | 226 | 243 | 215 | 95.1% |
| Safety_Stock_HP | 140 | 140 | 140 | 100% |

## Discrepancies — all drift, none structural
- Inventory: 4 NYS2104/ME92040 lots moved SING↔SNG4 / STGP↔OUTGOING (85=85 both sides).
- Work_Orders: 3 new future-dated SING WOs (4583752/755/758); WO 4581990 status 93→97, WO 4583595 status 20→32 (derived STATE rule applied identically both sides).
- Sales: 2647987 status advanced; 2660394 hold C1→OC (2 lines); 2726427 line split 40000→39600+400; +2 new orders 2734010/2737083; PBI-only 2719259 closed out of window.
- Inventory_HP (PBI +17): 24 PBI-only rows are QOH=0 allocation/transit lots that cleared next day; 7 Cognos-only are new NYS2104.S-OP transit lots. Status filter shows no over-inclusion bug.
- Column mismatches hit ONLY volatile fields (qty/status/date/hold) — never a decode, country, CSR/TM, UOM, or KG/LB conversion. Safety_Stock_HP perfect 140/140 → rebuild logic correct.

## Fan-out (page 2) — verified correct
413 rows = one per WO-line × component. AVG(WAUORG) OVER renders constant Quantity Requested across a WO's components (WO 4570478 = 11923.7 on BRIJS2.S/BRIJS20.S both sides); Cognos shows the identical fan-out (416 w/ drift). KG rows tie: P7 ISSUED LB = KG/0.453593; P7 REMAINING = ORDERED LB − ISSUED LB.

## Truncation handling
MCP DAX result files hard-cap at 100 rows regardless of maxRows (tested). Large tables paged by Branch Plant / 2nd Item and reassembled; on-disk pbi_*.csv = 85/413/22/243/140 = COUNTROWS. Match rates computed on FULL tables.

## Cognos filters (for Notes sheet)
- Inventory: Branch in (SHAN,MUM3,SING,SNG4,AUBA,AUB2); on-hand>0; Bulk in 31-item whitelist.
- Work_Orders: component 2nd item in (BRIJS2.E,BRIJS20.E,BRIJS2.S,BRIJS20.S); Issued+Ordered>0; Start ≥ 2025-11-01; 2nd Item NOT LIKE '%-%'; WAUOM in (LB,KG); WASRST not in (MM); outer QtyRequested>0.
- Sales_Order_Summary: SDLNTY='S'; SDPQOR>0; SDNXTR not in (570,580,620,999); SDMCU in 6 branches; country decode PRODCTL.F0005 (DRSY='00 ', DRRT='CN'); final inner-join Branch+2nd Item.
- Inventory_HP: Status IS NULL or in (T,B,Q,H); Branch in 6; Bulk whitelist.
- Safety_Stock_HP: SELECT DISTINCT F4102/F554101/F4101 (IBSAFE grain); Branch in 6; Bulk whitelist.

*(Archived by orchestrator from val-09's final message — subagent report-file writes were hook-blocked.)*
