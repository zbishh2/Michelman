# Report 03 — CM Sales Orders < 560 (SO under 560) — Validation Findings

**VALIDATED CLEAN on all functional dimensions. One real finding: Inventory Plant untrimmed in the LIVE model (repo .m already fixed, fix not applied/refreshed into live partition).**

## Export structure
Single sheet `page`, 4 rows x 33 cols = header + 3 data rows. Flat expansion of the Cognos master-detail grid (per-item aggregates ride each group's LAST physical row in cols 28-33). Cols 1-11 SO block; 12-19 Inventory; 20-27 WO; 28-33 footer aggregates. Reconstructed: U501-OP (CIN2) = 1 SO line, 0 inv, 0 WO. U701-OP (CIN2) = 1 SO line, 2 inventory lots, 0 WO.

## Gate / item-set — EXACT MATCH (core claim)
Cognos set = PBI [Show Item]=1 set = {U501-OP, U701-OP}. COUNTROWS cross-checked at maxRows=100000. gate_items.csv lists all 5 whitelisted items with gate decisions:
- U501-OP: 18450 vs blank -> show ✓ | U701-OP: 18000 vs 8100 -> show ✓
- DPE3500-T2 (2300 vs 18400), U2022-OP (4950 vs 12600), U502-OP (5400 vs 9000) -> correctly hidden.

## Match rates
Gate 5/5 · SO detail 22/22 cells · Inventory 16/16 after trim (14/16 raw — Plant) · WO 0/0 · Subtotals 12/12. AVAIL math ties (450+7650=8100; blank-status lots use OnHand-Commit).
Latent note: PBI `Inventory Lot Count` = COUNTROWS vs Cognos CountDistinct(AVAILABLE) — agree today (distinct AVAIL values); would diverge if two lots shared an AVAIL value.

## REAL discrepancy (1) — Inventory Plant untrimmed in LIVE model
Live partition selects `ib.IBMCU AS [Plant]` without LTRIM/RTRIM -> "        CIN2" (CHAR(12)); repo `Inventory_Availability.m` line 43 already fixed. Impact: display-only (WHERE/joins trimmed, row set + qtys + gate correct); SO block Plant IS trimmed so blocks render inconsistently. Fix: apply repo .m to live partition + refresh.

## Residuals.csv (5 rows) = 1 REAL (Plant, logged per lot x2) + 3 COSMETIC (Location "F11"/"F42" trailing-pad by design; Status "" vs " "; Customer ABALPH CHAR padding).

## CF note
Not encoded in export; moot this snapshot (both items status 540, promised 2026-07-21). BUILD.md 525-vs-530/535 CF question unexercised — planner-intent item, not data defect.

## Cognos filters (BUILD.md)
- SO: SDNXTR IN (525..550 list) AND SDLNTY='S' AND SDLITM IN (Brent CM whitelist) AND no lot AND Promised <= today+21 AND SDMCU IN (CINC,CIN2,CIN4); joins F0101 ship-to/sold-to + F0010.
- Inventory: IBMCU IN (CINC,CIN2,CIN4) AND LIPQOH/10000>0 AND (LILOTS<>'' OR (LIPQOH-LIHCOM)/10000>0).
- WO: WASRST IN (20,30,32,35,40,45,50,90) AND WAUORG/10000>0 AND Requested <= today+31 AND WAMMCU IN (CINC,CIN2,CIN4).
- Gate (DAX): show iff Ordered > Available OR available blank/0.

## Data as-of
Cognos export 2026-07-06 ~20:43 (live JDE); PBI refreshed same evening, validated ~21:04-21:09. Windows GETDATE()-relative, same-day — aligned.

*(Archived by orchestrator from val-03's final message — subagent report-file writes were hook-blocked.)*
