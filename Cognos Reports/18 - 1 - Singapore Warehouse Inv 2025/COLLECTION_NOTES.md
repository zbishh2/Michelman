# Cognos source collection — Report 18

- **Report name:** 1 - Singapore Warehouse Inv 2025
- **Migration tracker Report ID:** TBD — capture from the migration workbook row when known
- **Cognos path:** TBD — the `1 - ` prefix matches the Ivan / Cogan Excel AD HOC family (reports 13/14), so likely Production and Shipping; confirm
- **Prior owner / handover context:** TBD
- **Assigned to Zack 2026-07-17.** Folder scaffolded same day; only the output export collected so far.

## Collected so far

| File | What it is |
|---|---|
| `Intake\Cognos export 1 - Singapore Warehouse Inv 2025 (filed 2026-07-17).xlsx` | Output export (source run date unknown; the Lot Status sheet's constant `DATE` column = **2026-07-16**, which reads as the run's `current_timestamp` → capture likely 2026-07-16) |

## Export anatomy (profiled 2026-07-17)

Four sheets. Sheets 1/3/4 share the same 16 columns; sheet 2 adds a 17th (`DATE`, constant 2026-07-16 = run stamp).

Common columns: Inventory Date, Branch Plant, Global Bulk Item, Bulk Item, 2nd Item Number, Stock Type Code, Location, Lot Number, Lot Status, Master Planning Family, Quantity on Hand, Primary Unit of Measure, Quantity on Hand KGs, Extended Cost for Quantity On Hand USD, Weekday, MANUFACTURING REGION.

| Sheet | Rows | Snapshot dates | Branch plants | Lot statuses | Weekdays |
|---|---|---|---|---|---|
| `Singapore Inventory_1` | 23,284 | 32 (2026-03-18 → 2026-07-15) | SING 12,148 / SNG4 11,136 | `-` dominant (19,981) + A/H/E/P/L/B/T/Q | WED + SUN |
| `Lot Status_2` | 32,189 | **71 (2026-01-16 → 2026-07-14)** | ALL regions: CIN2/CINC/AUBA/SING/SNG4/AUB2 | **no `-` rows** — held/non-blank statuses only (E/A/L/B/H/P/Q/T/R/Z) | FRI + SUN + TUE |
| `Americas Inventory_3` | 68,053 | 32 (2026-03-18 → 2026-07-15) | CIN2 43,478 / CINC 24,558 / CIN4 17 | `-` dominant (60,019) | WED + SUN |
| `Aubange Inventory_4` | 28,092 | 32 (2026-03-18 → 2026-07-15) | AUBA 21,159 / AUB2 6,933 | `-` dominant (24,617) | WED + SUN |

Read-across:
- **This is a dated snapshot HISTORY report** (twice-weekly Wed+Sun snapshots for the three regional sheets; the Lot Status sheet has a longer, differently-cadenced window Fri/Sun/Tue back to mid-January). Not a live/current-only report.
- Column set is near-identical to **report 14's `Inventory` table** (EDW `BIQL.FactInventorySnapshot_History_Filtered`) — Inventory Date + Weekday + KGs + Extended Cost USD + MANUFACTURING REGION all match that lineage. **Likely route = EDW snapshot fact** (ODS F41021 is current-only and cannot reproduce history — same reasoning as report 14). Despite the "Singapore" title, the export covers ALL regions.
- `Lot Status_2` = a restricted-status (non-blank lot status) trend across all branches — presumably a "held/quarantined inventory over time" page.
- Report 14 carry-overs to watch: KG/LB conversion lineage, cost/FX basis, `-1` sentinel conversion factors, snapshot-date coverage/cadence, render-DISTINCT duplicates on the snapshot view (report 14 loaded ~71 identical copies per row before `SELECT DISTINCT`).

## Intake checklist (per `_PROGRESS.md` standard)

1. [x] Screenshots NOT needed — the 4-sheet xlsx export is complete render evidence (report-15 precedent)
2. [x] Full report specification XML → `Intake\XML.txt` (filed 2026-07-17; complete root-to-close, no truncation)
3. [x] Cognos generated SQL for every query object → `Intake\Queries.txt` (all 4 queries, Oracle)
4. [x] Output export (run 2026-07-17 — the Lot Status `DATE` col = `to_date(sysdate-1)` = 2026-07-16, so run date is the 17th, correcting the earlier guess)
5. [x] **No prompts/parameters at all. No expired ceiling — defect C1 CLEARED**: date windows are rolling `sysdate`-relative (`>= sysdate-365/3` ≈ 121.67 days for the 3 regional pages, `>= sysdate-365/2` = 182.5 days for Lot Status), which exactly reproduces the observed 2026-03-18 / 2026-01-16 lower bounds. "2025" in the title is legacy naming only.
6. [ ] Tracker row: report ID, owner, status/notes from the migration workbook — still TBD
7. [x] Source package confirmed: **Data Warehouse / DW_LEGACY** (`modelPath = Data Warehouse`, model mod time 2018-07-31) — same no-connection situation as 08/10/12/14 → reroute required

## Intake findings (2026-07-17, from XML + generated SQL)

- **4 queries ↔ 4 pages 1:1** (Singapore - Inventory / Lot Status Data / Americas - Inventory / Aubange - Inventory), each ONE flat `list` (no grouping, no listGroups), 16 cols (Lot Status adds 17th `DATE` = `to_date(sysdate-1)`, format `dateStyle=medium displayOrder=DMY` → `d MMM, yyyy`). Sort on all pages: Inventory Date, Global Bulk Item, Bulk Item, 2nd Item Number, Branch Plant (all asc).
- **Source star:** `DW_LEGACY.INVENTORY_ON_HAND` (+`_MEASURES`) ⋈ `ITEM` ⋈ `ALL_TIME` ⋈ `FIN_CURRENCY_CONVERSION`. Grain after Cognos GROUP BY = date|branch|item|location|lot|status (SUMs are render-DISTINCT-style rollups).
- **Common filters:** `QUANTITY_ON_HAND > 0`; `MASTER_PLANNING_FAMILY not in ('H2O','PKG')`; `INVENTORY_DATE <> DATE '2025-05-07'` (bad-snapshot blacklist, ALL 4 queries); Aubange ALSO excludes `2024-08-21`. Port both literals verbatim.
- **Per-page deltas:** regional pages = branch subset + Weekday in (SUN, WED) + ~4-month window; Lot Status = ALL 7 branches + `LOT_STATUS not in ('-')` + Weekday in (SUN, TUE, FRI) + 6-month window.
- **Measures:** QOH = sum(QUANTITY_ON_HAND); KGs = sum(QOH × `CONVERSION_FACTOR_KG`) — **report-14's `-1` sentinel gotcha applies**; USD cost = sum(QOH × UNIT_COST × `FROM_TO_EXCHANGE_RATE`) with FX join `FROM_CURRENCY_CODE = measure currency`, `TO='USD'`, `RATE_TYPE_CODE='-'`, effective-date window — **the exact FX lineage report 14's EDW `DimCurrencyExchangeRates` join failed to reproduce (all cross-currency rows blank). The pending `Probe-R14-FX-Factors.ps1` jumpbox probe results directly gate this report's USD column for AUBA/SING/EU currencies.**
- **`MANUFACTURING REGION`** = report-side decode (SING/SNG4→Singapore, AUBA/AUB2→Aubange, else Americas) — trivial CASE, not a dim column.
- Formats: QOH + KGs `numberFormat decimalSize=0`; USD `currencyFormat USD decimalSize=0`; red bold headers + 1pt black borders (house 13/14 style); `noDataHandler` per list (standard non-reproduced LOW).
- **Rolling windows are refresh-time-bound** (like report 06's 90-day window) — surface as-of via Last Refreshed card + Service refresh cadence disclosure.
- **Route recommendation: EDW `BIQL.FactInventorySnapshot_History_Filtered`** (report 14 precedent — the only SQL-Server source with dated snapshot history; SSAS has no dated inventory snapshot perspective, ODS F41021 is current-only). Twice-weekly snapshot cadence (Wed+Sun vs Fri/Sun/Tue) must be verified in EDW — does the snapshot view even HAVE all weekdays, or only certain days?
