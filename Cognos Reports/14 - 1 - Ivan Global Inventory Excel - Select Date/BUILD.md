# Report 14 — 1 - Ivan Global Inventory Excel - **Select Date** — Build Spec

Tracker outline `1.27.27.2`. Cognos path: `Public Folders > Michelman Reporting > Production and Shipping > 1 - Ivan Global Inventory Excel - Select Date`.

This is the **as-of ("Select Date")** sibling of report 13 (`1 - Ivan LIVE Global Inventory Excel`, outline 1.27.27.1). **It is NOT a structural clone of 13** — see §0.

Author the PBIP in **PBIR format** (like reports 02/03). Production `.m` files are comment-free; a `<name>.commented.m` master sits alongside each.

---

## 0. Divergence vs report 13 (read first)

The team-lead intake hypothesised report 14 is "a near-clone of 13 that adds a date prompt — reuse 13's `.m`, hoist the date to a param." **That hypothesis is false. Do not reuse report 13's queries.**

| | Report 13 (LIVE) | Report 14 (Select Date) |
|---|---|---|
| Cognos query objects | `Inv Summary`, `PO Summary`, `Sales Summary`, `Work Orders`, `WO Parts List` (5) | `Inventory`, `Escor Inventory`, `Escor Lot Info` (3) |
| Pages | 6 | 4 (Summary, Inventory Data, Escor Inventory, Escor Lot Details) |
| Semantics | inventory **right now** | inventory **as of a chosen date** |
| Cognos package | JDE Live Data | **Data Warehouse** (Oracle `DW_LEGACY`, `Inventory On Hand Star Schema`) |
| Chosen route | ODS/PRODDTA `F41021` (current) | **EDW `FactInventorySnapshot_History_Filtered`** (dated) |

The two reports share only the "Ivan Global Inventory" name and the general column vocabulary (region, bulk item, master planning family, lot status, KG/LB, USD/EUR). Their SQL, grain, pages, and source package are all different. Report 14 is a **date-parameterised snapshot** report over the Oracle Data Warehouse package — the same lineage as delivered reports 08/10 (which also came from `DW_LEGACY`).

**Consequence for the date prompt:** you cannot "hoist a date param" onto report 13's ODS `F41021` query. `F41021` stores only *current* on-hand — its numbers do not change when you filter a date. An as-of date is only answerable from a **historised** table. That single fact drives the routing below.

---

## 1. Intake completeness

**COMPLETE — no gaps.** All four generated-SQL files present; `Report XML.md` is the untruncated copy (the `.xml` has a `…6181 tokens truncated…` marker mid-file, fully recovered from the `.md`); `Report Output.xlsx` covers all four pages with row counts. No screenshot was collected (collection ended without one); the xlsx is the validation target, so the missing screenshot is not an intake gap.

| Cognos query object | Generated SQL | Feeds page(s) | xlsx sheet (data rows, as of 2026-07-12) |
|---|---|---|---|
| `Inventory` | `Inventory.0.sql` (crosstab agg), `Inventory.1.sql` (detail) | Summary (crosstab), Inventory Data (list) | `Summary_1` (41 grid rows, 11 lot-status cols); `Inventory Data_2` (**4,163**) |
| `Escor Inventory` | `Escor Inventory.2.sql` | Escor Inventory (list) | `Escor Inventory_3` (**48**) |
| `Escor Lot Info` | `Escor Lot Info.3.sql` | Escor Lot Details (list) | `Escor Lot Details_4` (**1,663**) |

`Inventory` produces two SQL statements because one query drives two containers at two grains (the Summary crosstab aggregates the same rows the Inventory Data list shows in detail). In Power BI this collapses to **one** table (`Inventory`); the crosstab is just an aggregation of it. So 4 SQL files → **3 PBI tables**.

**The prompt.** Both `Inventory` and `Escor Inventory` carry `[Inventory Date] = ?Date?`; the generated SQL bakes it as `"INVENTORY_ON_HAND"."INVENTORY_DATE" = CAST( ( :PQ1 ) AS TIMESTAMP )`. The collection-day literal resolved to **2026-07-12** (every `Inventory Date` cell in the xlsx = 12 Jul 2026). Parameterise it — do not hard-code 2026-07-12. `Escor Lot Info` has **no** date filter and **no** quantity filter — it is a pure lot-master list and is **date-independent** (its 1,663 rows do not move with the prompt).

**As-of is a snapshot filter, not a ledger computation.** `DW_LEGACY.INVENTORY_ON_HAND` is itself a **periodic snapshot fact** keyed by `INVENTORY_DATE`; `INVENTORY_DATE = @AsOf` selects that day's stored position. No Cardex/F4111 roll-forward is involved. This is important: the EDW equivalent must also be a *snapshot* table, not live `F41021`.

---

## 2. Source routing — **EDW** (SSAS and ODS both rejected)

Evaluated SSAS → EDW → ODS per the team mandate.

### 2.1 SSAS `BIQLTabular_v2` (Live Connection) — REJECTED
- The cube is JDE-lineage and models **current** positions; it has no dated inventory-snapshot fact that can answer "as of an arbitrary past date." A Live Connection also forbids local tables, so the region decode / KG-LB / FX derivations below could not be added.
- Prior finding stands: the **Item Location File (F41021) is in no `v2.xmla` perspective** — the location/lot/GL-class grain this report needs is not cube-exposed.
- Verdict: cannot express select-a-date as-of inventory. Reject.

### 2.2 EDW SQL Server — **CHOSEN**
- `dbo.FactInventorySnapshot_History` is a **type-2 historised** inventory snapshot (SCD2 `StartDate`/`StopDate`) at **date × item × branch × location × lot** grain — exactly the Cognos detail grain, and it answers any as-of date via `@AsOf` between `StartDate` and `StopDate`. This is the **SQL-side equivalent of the Oracle `INVENTORY_ON_HAND` snapshot** the Cognos report already reads — a much closer analog than live `F41021`.
- **2026-07-22 repoint (report 18 sweep):** the build originally used `BIQL.FactInventorySnapshot_History_Filtered`, but report 18 proved (probes P9/P13) that the view is just the dbo table joined to the pruned calendar spine `BIQL.DimCalendarInventorySnapshot` — daily dates for the current+prior month only, month-ends before that. A "Select Date" older than ~2 months would silently miss its snapshot. The dbo table keeps daily intervals back to 2021-06, and R18 validated that the direct interval join (`@AsOf BETWEEN StartDate AND ISNULL(StopDate,'9999-12-31')`, with the **CompanySKey=2 +1-day timezone shift** from the view definition) reproduces the view row-for-row on shared dates. The `.m` files now read `dbo` directly with that shift.
- Report 13's spec rejected the EDW snapshot facts for the **LIVE** report because they "don't reproduce lot+location+cost-component grain 1:1." That objection was about A1/B1/C1/C2 **cost components** (which report 13 shows and 14 does not) and about preferring the live grain for a live report. **Neither applies here:** report 14 shows only Extended Cost USD/EUR (`QOH × unit cost × FX`), which `FactInventorySnapshot` carries as `AmountUnitCost` / `AmountValueAtCost`; and report 14 *needs* history, which only EDW has.
- Every Cognos column maps to EDW (see §5). Enrichment views exist for the two things the fact does not carry inline: `BIQL.DimItemUOMConversionLBKG` (KG/LB factors) and `BIQL.DimCurrencyExchangeRates` (USD/EUR FX).
- Verdict: **the only SQL Server source with dated inventory history, and the closest structural match to the Cognos source. Route = EDW.**

### 2.3 ODS `PRODDTA` `F41021` — REJECTED (as primary)
- This is report 13's route. `F41021` is **current-only** — no history dimension — so it structurally cannot answer a past as-of date. It is the correct source for the LIVE twin and the wrong source here.

### 2.4 The excluded option — Oracle `DW_LEGACY` direct
- A 1:1 port of the four Oracle statements against `DW_LEGACY` would give guaranteed parity, but the project has **repeatedly declined an Oracle gateway** (reports 08/10/11/12 all rebuilt on SQL Server for exactly this reason). We follow that decision. **If EDW parity proves infeasible (see §7 risk), the fallback conversation is "provision a `DW_LEGACY` gateway," which is a human decision — not a silent switch.**

---

## 3. The date parameter → PBI design

Cognos re-runs the whole report per selected date (prompt semantics = "pick a date, re-execute"). Mirror that:

**Recommended — Option A (Power Query parameter):** a date parameter `AsOfDate` (type `date`, default = the latest available snapshot date, or `Date.From(DateTime.LocalNow())`). The three snapshot-dependent queries interpolate it into the `@AsOf` predicate. Changing the date = set the parameter and refresh — identical semantics to the Cognos prompt, smallest model, guaranteed single-date parity against the xlsx. This is what the `.m` files below implement.

**Optional upgrade — Option B (date slicer):** load a bounded window of snapshot dates (e.g. trailing 90 days, or month-ends only) with a real `Snapshot Date` column, and drive a **single-select** date slicer in-visual (the pattern reports 08/10 used for their Between slicers). No refresh needed to change the date, at the cost of a larger model and a pre-chosen window. Recommend deferring to Option B only if the business wants click-to-change dates; validate Option A first.

Either way the `Escor Lot Info` query takes **no** date input.

---

## 4. Pages / visuals

Dates render **day-first**: `displayOrder="DMY"` + `dateStyle="medium"` ⇒ `formatString: d MMM, yyyy` (comma, no leading zero — per project date-format decision). Integer facts: `#,0` (`decimalSize="0"`). USD cells: `$#,0`; EUR cells: `€#,0` (VBA formatString — the currency symbol is a literal). All list headers are bold red in Cognos (`color:red;font-weight:bold`) with 1pt black cell borders — reproduce with a table style; these are **cosmetic header styles, not data-driven CF**, so no PBIR values-CF selectors are involved anywhere in this report.

### Page 1 — `Summary` (crosstab → **matrix**)
Source: `Inventory` table. Cognos crosstab `Crosstab1`.
- **Rows:** `REGION` ▸ `Master Planning Family`, with a **per-`REGION` subtotal** row labelled `Total` (Cognos `Total(Master Planning Family)`, `aggregateMethod="total"`). Region and family both sorted ascending.
- **Columns:** `Lot Status` (ascending). The xlsx shows 11 status groups on 2026-07-12: `-, A, B, E, H, L, P, Q, R, T, Z`.
- **Values (nested under each Lot Status):** `OH LBs` then `OH USD` — i.e. `[Quantity on Hand LBs]` (label **OH LBs**, `#,0`) and `[Extended Cost for Quantity On Hand USD]` (label **OH USD**, `$#,0`).
- Grand `Total` row present (xlsx last row: LBs 6,794,588 / USD 9,370,995 on 2026-07-12).
- Set the two value fields to aggregate **Sum**; set `summarizeBy: none` on `Lot Status`, `REGION`, `Master Planning Family` (identifiers) so the matrix does not silently re-aggregate them.

### Page 2 — `Inventory Data` (list → flat **tableEx**)
Source: `Inventory` table. 25 columns, **in this exact order**. Header = Cognos `label` where present (shown in **bold** below), else the field name.

1. Inventory Date `d MMM, yyyy`
2. REGION
3. Branch Plant
4. Global Bulk Item
5. Bulk Item
6. 2nd Item Number
7. Stock Type Code
8. GL Class Code
9. Location
10. Lot Number
11. Supplier Lot Number
12. Lot Status
13. Master Planning Family
14. **On Hand** (`Quantity on Hand`, `#,0`)
15. **UOM** (`Primary Unit of Measure`)
16. **OH KGs** (`Quantity on Hand KGs`, `#,0`)
17. **OH LBs** (`Quantity on Hand LBs`, `#,0`)
18. **OH USD** (`Extended Cost for Quantity On Hand USD`, `$#,0`)
19. **OH EUR** (`Extended Cost for Quantity On Hand EUR`, `€#,0`)
20. On Hand Date `d MMM, yyyy`
21. Lot Expiry Date `d MMM, yyyy`
22. Memo Lot 1
23. Memo Lot 2
24. Commodity Class Description
25. Commodity Sub Class Description

Sort (Cognos `sortList`): REGION ▸ Global Bulk Item ▸ Bulk Item ▸ 2nd Item Number, all ascending. Rows on 2026-07-12: **4,163**.

### Page 3 — `Escor Inventory` (list → flat **tableEx**)
Source: `Escor Inventory` table. 20 columns in order:

1. Inventory Date `d MMM, yyyy`
2. Branch Plant
3. Global Bulk Item
4. Bulk Item
5. 2nd Item Number
6. Last Receipt Date `d MMM, yyyy`
7. Location
8. Lot Number
9. On Hand Date `d MMM, yyyy`
10. Lot Expiry Date `d MMM, yyyy`
11. Sell by Date `d MMM, yyyy`
12. Supplier Lot Number
13. Memo Lot 1
14. Memo Lot 2
15. Lot Status
16. Master Planning Family
17. Quantity on Hand KGs (`#,0`)
18. Quantity on Hand LBs (`#,0`)
19. Quantity on Hand (`#,0`)
20. Primary Unit of Measure

Sort: Branch Plant ▸ Last Receipt Date, ascending. Rows on 2026-07-12: **48**. No `label` overrides on this page — headers = field names. Note the KG/LB here are **plain sums** (no negative-quantity `×20/×44` guard, unlike the Inventory query — see §6).

### Page 4 — `Escor Lot Details` (list → flat **tableEx**)
Source: `Escor Lot Info` table. **Date-independent** (no as-of filter). 9 columns in order:

1. Branch Plant
2. Bulk Item
3. 2nd Item Number
4. Item Short ID
5. Lot Number
6. Supplier Lot Number
7. Memo Lot 1
8. Memo Lot 2
9. On Hand Date `d MMM, yyyy`

Sort: On Hand Date ascending. Rows: **1,663** (does not vary with the date prompt). `SELECT DISTINCT` in the Cognos SQL — keep it (see §6). Note: the xlsx shows some `On Hand Date = 1900-01-01`, i.e. null/placeholder lot dates — expected, sort puts them first.

---

## 5. Column → EDW mapping (`Inventory` query)

Base (since the 2026-07-22 sweep): `dbo.FactInventorySnapshot_History snap` filtered to `@AsOf BETWEEN snap.StartDate AND ISNULL(snap.StopDate,'9999-12-31')` — with the **CompanySKey=2 +1-day interval shift** — plus `(QOH > 0 OR ItemCostSKey <> -1)` (cost carriers, dropped again post-window), branch and family lists below. Outer derived-table `GROUP BY` + `SUM` mirrors the Cognos grain. Joins: `DimItem it` on `ItemSKey`, `DimLot lot` on `LotSKey`, `DimCompany co` on `CompanySKey` (for FX from-currency), `#lbf` (materialized from `DimItemUOMConversionLBKG`) on `ItemNumShort`(+`BusinessUnit`), FX twice from `BIQL.DimCurrencyExchangeRatesUSDDaily` (company currency→USD, and EUR→USD for the EUR triangulation).

| Cognos item (label) | Source expression | Notes / confidence |
|---|---|---|
| Inventory Date | `@AsOf` constant | the parameter value |
| REGION | `CASE snap.BusinessUnit` decode → Americas/Aubange/Singapore/India/China | verbatim from SQL |
| Branch Plant | `RTRIM(snap.BusinessUnit)` | |
| Global Bulk Item | `it.ItemGlobalBulk` | |
| Bulk Item | `it.ItemBulk` | |
| 2nd Item Number | `it.ItemNum2nd` | Oracle used the measure's `ITEM_NUMBER_2ND`; `DimItem.ItemNum2nd` is the same 2nd number — **verify** it matches the measure grain |
| Stock Type Code | `it.StockingType` | |
| GL Class Code | `snap.CategoryGLF41021` | F41021 location GL class = Oracle `INVENTORY_ON_HAND.GL_CLASS_CODE` |
| Location | `RTRIM(snap.Location)` | |
| Lot Number | `RTRIM(snap.LotNum)` | |
| Supplier Lot Number | `lot.SupplierLotNum` | |
| Lot Status | `snap.LotStatusCode` | Oracle used the measure's `LOT_STATUS` (position-level). **TODO verify** vs `lot.LotStatusCode` (lot-master) — they can differ |
| Master Planning Family | `it.MasterPlanningFamily` | |
| Quantity on Hand (**On Hand**) | `snap.QuantityOnHandPrimaryUOM` | already primary-UOM scaled (DW measure, no JDE implied-decimal here) |
| Primary UOM | `snap.UOMPrimary` | |
| Quantity on Hand KGs (**OH KGs**) | KG-primary: identity; LB-primary: `×0.45359237`; else dim factor with the `×20` sentinel guard | validated vs xlsx 2026-07-14 (`.m` FIX #5) |
| Quantity on Hand LBs (**OH LBs**) | LB-primary: identity; KG-primary: `×2.20462262`; else dim factor with the `×44` sentinel guard | validated vs xlsx 2026-07-14 (`.m` FIX #5) |
| Extended Cost USD (**OH USD**) | `QOH × (AmountUnitCost, else item/branch carrier cost) × USDDaily [Exchange Rate]` (identity for USD companies) | R18-proven pattern (`.m` FIX #6c/d); see §7.1 |
| Extended Cost EUR (**OH EUR**) | same cost core × `(local→USD) ÷ (EUR→USD)` triangulation (identity for EUR companies) | **VERIFY vs xlsx** — R14-specific; see §7.2 |
| On Hand Date | `lot.OnHandDate` | |
| Lot Expiry Date | `lot.LotExpirationDate` | |
| Memo Lot 1 / 2 | `lot.MemoLot1` / `lot.MemoLot2` | |
| Commodity Class Description | `it.CommodityClassCodesDesc` | Oracle `PRP1` category description |
| Commodity Sub Class Description | `it.CommoditySubClassCodesDesc` | Oracle `PRP2` category description |

**Branch list** (`snap.BusinessUnit IN`): `CINC, CIN2, CIN4, AUBA, AUB2, SING, SNG4, MUM3, SHAN`.
**Master Planning Family list** (Cognos list has dupes; distinct set): `ATP, ETP, FBW, FCB, FEC, FRC, RAW, RBW, RCB, REC, RRC, RWW, TOL, WAG`.

**Escor Inventory** query = same base, replace the family/branch filter with `it.ItemGlobalBulk = 'ESC5200'`, keep `QOH>0` + as-of; KG/LB are **plain** `snap.QOH*lbkg.KG` / `*lbkg.LB` (no negative guard); `Last Receipt Date = snap.LastReceiptDate`; `Sell by Date = lot.SellByDate`; `Lot Status = lot.LotStatusCode` (Oracle sourced it from the lot master here, not the measure). No USD/EUR cost columns on this page.

**Escor Lot Info** query = `DimLot lot` ⋈ `DimItem it` on `ItemSKey`, `SELECT DISTINCT`, filter `it.ItemBulk IN ('ESC5200','ESC5200.E','ESC5200.S')`. No snapshot, no date, no qty. `Item Short ID = lot.ItemNumShort`. **TODO verify** `DimLot` holds all historical lots for these items (target 1,663).

---

## 6. Oracle→T-SQL / Power BI porting notes (applied in the `.m` files)

- **Power BI native-query wrapper** (`SELECT * FROM (<q>)`): no CTEs, no `ORDER BY` — sorts live in the visual (§4). The `.m` files are single `SELECT`s, no `WITH`.
- **`SELECT DISTINCT`** kept on `Escor Lot Info` (Cognos SQL has it) — without it the `DimLot`⋈`DimItem` join fans out.
- **The Oracle `×44`/`×20` CASE is a SENTINEL guard, not a negative-quantity guard** (`.m` FIX #5): DW stores `CONVERSION_FACTOR_KG/LB = -1` for "no conversion" and the guard turns sentinel rows into 20 KG / 44 LB per unit. Reproduced on the `Inventory` query's dim-factor tail; **not** present on `Escor Inventory` (plain products) — do not add it there.
- **Grain = Cognos group-and-sum** (2026-07-22): both snapshot queries are derived-table + `GROUP BY` + `SUM(QOH/KGs/LBs[/USD/EUR])` over the exact Cognos group keys — the r17 RULE B lesson. `SELECT DISTINCT` (the earlier fix for the `_Filtered` view's identical-row fan-out) under-merges genuine multi-row groups; the dbo repoint removed the fan-out at the source.
- **CompanySKey=2 shift + carrier-borrow** ported verbatim from report 18 (see §2.2 and §7) — do not simplify either away.
- **No expired date ceiling.** Every date bound is either the parameter (`@AsOf`) or the SCD2 `StartDate/StopDate` — there is **no** hard-coded `DATE '2026-06-30'`-style literal like defect C1 on reports 08/10. This report is genuinely date-parameterised, not silently expired.
- **No JDE implied-decimal scaling.** Quantities/costs come from DW measures already in primary UOM and cost units — the `/10000` / `/1000` scaling that plagued the JDE-native reports (08/10/12/13) does **not** apply. The xlsx confirms clean values (e.g. 14,000 LB → 14,000 OH LBs, 6,350 OH KGs). **Validate anyway** against the xlsx.
- **Blank/trim:** apply `LTRIM(RTRIM(...))` to `BusinessUnit`, `Location`, `LotNum` (fixed-width `nchar`). Oracle `trim(x)=''` ⇒ `IS NULL` semantics are not needed here (no such predicate in these four SQLs).
- **3-part naming / reachability:** all sources are `EDW`; use two-part `BIQL.<obj>` on the EDW connection (`Sql.Database("<EDW server>", "EDW")`). Confirm the exact EDW server name against a delivered EDW report before building.

---

## 7. Parity risk — status after the 2026-07-22 report-18 sweep

This is the **first report in the batch to source from EDW rather than the JDE/ODS lineage.** Report 13's numbers came from `DW_LEGACY` (Oracle); report 14's come from `FactInventorySnapshot` (SQL EDW). Report 18 (Singapore Warehouse Inv, turned in 2026-07-17) validated exactly this territory to the penny, and its findings are now swept into 14's queries (`.m` FIX #6). Updated status:

1. **OH USD — RESOLVED PATTERN (pending R14's own refresh).** R18 proved: where `ItemCostSKey <> -1`, `snap.AmountUnitCost` ties to Cognos exactly; `ItemCostSKey = -1` lots have embedded cost 0 and must **borrow the item/branch carrier cost** from a sibling snapshot row (window MAX, inner filter widened to `QOH>0 OR ItemCostSKey<>-1`, carriers dropped again before GROUP BY). FX: `BIQL.DimCurrencyExchangeRates` holds **only CHF→EUR** (the old join silently NULLed every non-USD company); the live source is `BIQL.DimCurrencyExchangeRatesUSDDaily` — ISO `CurrencyCodeFrom`, per-day `CalendarDate` (weekend-flat), direct **multiplier** `[Exchange Rate]` (local × rate = USD). SING/SNG4/CIN* companies are USD-functional (identity 1.0); Aubange is EUR. Both fixes are applied.
2. **OH EUR — OPEN (R14-specific; R18 had no EUR column).** USDDaily only quotes →USD, so EUR is **triangulated**: local→EUR = (local→USD) ÷ (EUR→USD), identity for EUR companies. Oracle used a direct local→EUR `'-'` rate; triangulation can differ in late decimals. Validate the EUR column against the xlsx; if it won't tie, probe `DimCurrencyCrossRatesCalc` (sampled by R18 probe P10) for a direct cross rate.
3. **INR/CNY FX coverage — OPEN (R14-specific).** MUM3 (India) and SHAN (China) are in scope here but weren't in R18; if their companies are not USD-functional, confirm USDDaily carries INR→USD / CNY→USD rows at the as-of date. A NULL `[Exchange Rate]` NULLs the cost — visible immediately in validation.
4. **OH KGs / OH LBs — validated 2026-07-14** vs the xlsx (FIX #5 constants for KG/LB-primary rows; dim factors + ×20/×44 sentinel guard for the EA/GM tail). Unchanged by the sweep.
5. **Snapshot date coverage — RESOLVED.** `dbo.FactInventorySnapshot_History` keeps daily SCD2 intervals back to 2021-06 (R18 probe P9), so 2026-07-12 is retained and any future Select Date works. (The old `_Filtered` route would have lost daily dates older than ~2 months — that was the repoint's whole point.)
6. **Grain — aligned to Cognos 2026-07-22.** Both Cognos SQLs are `GROUP BY` + `SUM` (not `DISTINCT`); the queries now group-and-sum over the exact Cognos group keys. This is the likely closer of the old 4,119-distinct vs 4,163-xlsx gap (DISTINCT collapsed byte-identical rows but kept multi-row groups split; GROUP BY reproduces Cognos' summed rows).

**Validation is deterministic:** refresh on the jumpbox at `AsOfDate = 2026-07-12` and tie against `Report Output.xlsx` (4,163 / 48 / 1,663 rows; Summary grand Total LBs 6,794,588 / USD 9,370,995) — no fresh Cognos capture needed. If OH USD/EUR or the row counts cannot be reconciled on EDW, escalate the `DW_LEGACY` gateway question (§2.4) rather than shipping wrong numbers.

---

## 8. PBIR authoring checklist
- Author in **PBIR** (`definition/` folder form), like reports 02/03.
- Pages 2–4 = flat `tableEx`; page 1 = `pivotTable`/matrix (rows REGION▸Master Planning Family + per-region `Total`, columns Lot Status, values OH LBs + OH USD).
- `summarizeBy: none` on every identifier/text column and on `Lot Status`/`REGION`/`Master Planning Family` (matrix headers) — a stray `summarizeBy: sum` on an identifier corrupts the matrix.
- **No values-level CF** in this report (header colours are style, not data CF) — so the `dataViewWildcard` selector trap does not arise; do not add CF selectors.
- Label renames via `displayName` (On Hand, UOM, OH KGs, OH LBs, OH USD, OH EUR). Avoid duplicate `nativeQueryRef` (render error).
- Date `formatString: d MMM, yyyy`; integers `#,0`; USD `$#,0`; EUR `€#,0`.
- Add the standard `Last Refreshed` card (project convention) — this is a refresh-time as-of when using Option A.

## 9. Expected row counts (validation target, as-of 2026-07-12)
| Page | Rows |
|---|---|
| Summary (matrix grid) | 41 rows × 11 lot-status column groups; grand Total LBs 6,794,588 / USD 9,370,995 |
| Inventory Data | 4,163 |
| Escor Inventory | 48 |
| Escor Lot Details | 1,663 (date-independent) |

## 9.1 VALIDATION ROUND 1 — 2026-07-22 (jumpbox refresh @ AsOfDate = 2026-07-12, post-sweep queries confirmed in the loaded model)

Method: full `Inventory` table exported via ADOMD (`Microsoft.AnalysisServices.AdomdClient` namespace — note the DLL is *named* `Microsoft.PowerBI.AdomdClient.dll` but keeps the original type namespace; PS 5.1, not pwsh 7), key-level compare vs `Report Output.xlsx` on (Branch Plant, 2nd Item Number, Location, Lot Number, Lot Status). **Gotcha: the xlsx renders blank `Location` as `-`** — normalize before joining or ~530 rows false-mismatch.

**Headline: 4,116 of 4,163 xlsx keys matched (98.9%); only 5 QOH diffs on shared keys** — spine, CompanySKey=2 shift, grain, and row population are right. `Escor Inventory` = 48 rows, QOH exact, KGs/LBs within 0.001% (conversion-constant rounding). `Escor Lot Info` 1,583 (vs xlsx 1,663 incl. render dups — the previously accepted value). **Zero NULL costs anywhere ⇒ §7.2 EUR triangulation and §7.3 INR/CNY coverage both CLOSED**: EUR diffs occur only on rows whose USD also differs (i.e. cost-driven, not FX-driven) — the triangulated rate reproduces Oracle's direct local→EUR within 0.5% wherever the cost basis agrees.

Residual diff classes (evidence in `scratchpad` compare run; re-derivable any time):
1. **47 missing / 10 extra keys** (≈1.1%, e.g. `PH00102E.S-TL` across SNG4/SHAN/MUM3, `RC39RXT`, item-rename pairs like `ME71152.S-PD`→`ME71152.S`): SCD1 dim drift over the 10 days since capture — current `DimItem` family/2nd-number over frozen facts. **Cognos has the same semantics** (Oracle `ITEM` is also current-at-run-time), so a Cognos re-run @7/12 today would drift identically; unfalsifiable per the tight-capture rule.
2. **5 QOH diffs, 4 of them AUBA** (650 / −200 / 167 / 3.4; plus one AUBA lot with status E→`-`): plausibly the CompanySKey=2 (+1-day) alignment vs Oracle's day-stamping **for Aubange, which R18 never export-validated** (only Singapore was). Tiny; watch, don't churn.
3. **19 GM/EA LB rows, net −1.24M LBs** — dominated by 2 SING `ETHAL.S` GM lots the xlsx shows as 880,000 / 374,880 LBs (= the DW `-1`-sentinel ×44-per-unit artifact; physically 20,000 g ≈ 44 lbs, which is what we compute). EDW's UOM dim has real factors where DW_LEGACY stored `-1`, so the sentinel behavior is **not reproducible from EDW — and our numbers are physically correct where Cognos's are garbage**. Needs a disclosure decision (R11 "we're-more-correct, disclosed" precedent), not a code fix.
4. **418 USD (and mirrored EUR) diffs on shared keys, net −$535k / −€468k** — concentrated: 10 SNG4 `ESC5200.S` lots at −$17.6k each (EDW `AmountUnitCost` 3.29/KG vs Oracle `UNIT_COST` 4.09/KG, systematic), `TWN60NK` −$30k (no costed carrier in EDW where Oracle had cost), `MFHS4200.S-PD` +$33.6k (our carrier-borrow fills what Cognos shows as $0). This is R18's "100FGK carrier drift" class at larger scale: **the two warehouses disagree on unit cost for a minority of lots**. Not fixable from EDW; the honest options are disclose-with-note or the §2.4 DW_LEGACY gateway escalation.

## 9.2 TIGHT CAPTURE — 2026-07-22 (fresh Cognos export, filed as `Cognos export (tight capture 2026-07-22).xlsx`)

Zack re-ran the Cognos report same-day as the jumpbox refresh. Two findings:

1. **The three snapshot sheets came back EMPTY at the 2026-07-12 prompt** — Oracle `DW_LEGACY.INVENTORY_ON_HAND` has already purged that date (the date-independent Escor Lot Details still returned rows, so the prompt executed). Consequences: (a) the §9.1 xlsx targets are now **unreproducible from Cognos** — our EDW dbo route (daily back to 2021-06) outlives the source's own retention, which is a selling point, not a defect; (b) a tight-capture validation of the snapshot pages must use a **date Oracle still retains** (e.g. yesterday): run the Cognos prompt and set `AsOfDate` to the same date, capture both within minutes.
2. **The Escor Lot Info "1,583 EXACT" claim from 2026-07-14 is FALSIFIED.** The fresh export has **1,663 distinct rows, zero dups** (the old "1,663 = 1,583 + render dups" theory is dead — Cognos list-pagination dups do not appear in this export). We are genuinely missing **80 ESC5200-family lots** (SING 43, AUBA 21, AUB2 10, CINC 3, CIN2 3); 79 of 80 are ancient (On Hand Date 2011–2013), one is 2025-12-03. Root cause = `DimLot` retention **or** stale `ItemSKey`→`ItemBulk` mapping — probe §6 of `00_verify_tables.sql` (run on jumpbox) decides which; fix = re-key the join or reroute this one table to ODS `F4108` (Cognos's own lineage). The 4 multi-row (BP, Lot) keys match on both sides.

## 10. Open questions for the human
- **D-14a (routing sign-off):** EDW is the only SQL Server source that can do as-of; confirm we build on `dbo.FactInventorySnapshot_History` rather than provisioning an Oracle `DW_LEGACY` gateway for guaranteed parity. (Recommend: build on EDW, validate at `AsOfDate = 2026-07-12` against the xlsx, escalate only if it won't tie. Report 18 already validated this exact source/FX/cost stack to the penny for Singapore, so confidence is much higher than when this question was first raised.)
- **D-14b (date UX):** Option A parameter (refresh-to-change, exact Cognos semantics) vs Option B single-select date slicer (click-to-change, bounded window). Built as A; recommend validating A before considering B.
- **D-14c (cost/FX basis):** ~~confirm `AmountUnitCost` currency basis and the FX rule~~ **RESOLVED for USD 2026-07-22** by the report-18 sweep (`AmountUnitCost` + carrier-borrow + `USDDaily` multiplier — see §7.1). **Still open for EUR** (triangulation vs Oracle's direct local→EUR rate, §7.2) and for **INR/CNY coverage** (§7.3) — both are settled by the 2026-07-12 validation refresh, not by a human call, unless they fail to tie.
- **D-14d (lot status source):** Inventory-page `Lot Status` — position-level (`snap.LotStatusCode`) vs lot-master (`lot.LotStatusCode`)? Oracle used the position measure on the Inventory page and the lot master on the Escor pages, and **the build follows Oracle on both** (position on Inventory, master on Escor). Only revisit if the human wants the two pages consistent *contra* Cognos.

## 11. DAX VALIDATION LAYER — 2026-07-22 (for the Rohit validation walkthrough)

Zack will present validation in DAX, not SQL — every hard-to-tie piece is rebuilt in the model on raw
base tables with real relationships and `RELATED()`/aggregate equivalents, tying out against the
untouched production queries. Full walkthrough in **`DAX VALIDATION.md`**.

- **7 new tables** (comment-free, raw single-source SELECTs — every join lives in the model):
  `Snapshot` (dbo fact slice covering AsOf and AsOf+1 windows, 9 BUs, no other filters),
  `Item`, `Lot`, `Company`, `FX Rate` (USDDaily @ AsOf), `UOM Conversion`, and `Missing Lots`
  (static 80-pair probe table — supersedes §6 of `00_verify_tables.sql`; its `Verdict` calc column
  answers retention-vs-re-key directly after refresh).
- **5 relationships** (`relationships.tmdl`, new file): Snapshot→Item/Lot/Company, Company→FX Rate,
  and inactive Lot→Item (ambiguous with the Snapshot path; Lot uses LOOKUPVALUE).
- **On `Snapshot`:** the Cognos WHERE clause as boolean columns (`In Interval` with the CompanySKey=2
  +1-day `Interval Match Date`, `Has Item/Lot/Company Match` = INNER JOIN semantics, `In Family Scope`,
  `In Inner Query`, `In Report`, `In Escor Report`); carrier-borrow as `MAXX(FILTER(...))` with a
  `Cost Source` label column; FX + EUR triangulation; the `#lbf` factor pick as `FILTER`/`TOPN` with a
  `Weight Source` label column (sentinel ×20/×44 rows self-identify); guarded and no-guard KG/LB columns.
- **33 measures** in Tie-Out folders: `X (DAX)` vs `X (SQL)` (production tables mapped via TREATAS on
  Region/BP/Location/Lot/2nd Item) vs `X Delta` for QOH/KGs/LBs/USD/EUR/Rows, the Escor trio, and
  Lot Info row counts incl. `Missing Lots Found in DimLot`. `Rows (DAX)` proves the GROUP BY grain via
  a 19-column SUMMARIZE. All deltas should be 0.00 at every slice.
- **New report page "DAX Validation"** (page `14a1050000000000e005`): tie-out grid by Region/BP,
  Missing-Lots probe grid, Escor/Lot-Info counts.
- Lint: MCP ConnectFolder loads clean (11 tables / 33 measures / 5 relationships). **Needs one jumpbox
  refresh** (7 new tables) before the page populates. Layer is additive — production queries untouched —
  and can be deleted wholesale after sign-off.

## 12. SSAS PERSPECTIVE COVERAGE INVESTIGATION — 2026-07-22 (revises §2's "SSAS rejected")

§2 rejected SSAS on "no dated inventory snapshot + F41021 in no perspective." That was wrong on the
first count: **BIQLTabular_v2 HAS a dated snapshot star — the `Inventory Snapshot` perspective**
(13 tables; fact `BIQL.TbInventorySnapshotFCR_Detail` → Branch / `Calendar Inventory Snapshot`
(`BIQL.TbCalendarSnapshot`) / Cost Method / Item Branch / Lot, plus Selected UOM/Currency selector
tables and 159 prebuilt measures). Full extraction: scratchpad `v2_r14_tables.txt` (from `Extra\v2.xmla`).

**What maps (column-for-column):**
- Fact: `Lot Status Code` (F41021.LILOTS = the position status the Inventory page uses),
  `CategoryGLF41021` (GL class), `Location`, `LotNum`, `UOMPrimary`, `Last Receipt Date`, QOH +
  every sub-quantity, `AmountValueAtCost` + A1/B1/C1/C2/D1/X1 unit costs by Cost Method, and
  **visible `Conversion KG` / `Conversion LB` / `Conversion TM` columns per row**.
- **UOM switching built in**: `[Qty On Hand]` SWITCHes on the Selected-UOM slicer (primary/UMA/UMB/UMC
  = the KGs/LBs columns without our #lbf machinery).
- **Currency switching built in**: `[Amt Value At Cost Input]` SWITCHes Local / **USD** / **EUR** —
  USD via `Currency Rates`[ToRateDaily] (active CurrencyASKey rel), **EUR via a DIRECT local→EUR
  relationship** (inactive CurrencyBSKey + USERELATIONSHIP) — i.e. the model already solved FX, and
  its EUR is Oracle-style direct, not our USD triangulation.
- `Lot` = `BIQL.TbLot` (F4108): Supplier Lot Num, Memo Lot 1/2, On Hand / Sell By / Expiration dates,
  master Lot Status — everything Escor Lot Details and the lot columns need. **Different lineage from
  BIQL.DimLot — may retain the 80 lots DimLot lost (probe §7c).**
- `Item Branch` (124 cols): Item Bulk, Item Global Bulk, Item Num 2nd, Stocking Type,
  Master Planning Family, Commodity Class/Sub Descs — both report filters and all item columns.
- `Branch` has Region/Division category-code decodes (F0006.MCRP01/02) — may replace the hard-coded
  region CASE (probe §7d).

**The one structural limit — date coverage (probe §7a = the decider):** the fact keys to
`TbCalendarSnapshot`, almost certainly the same pruned spine R18 found (current+prior month daily,
month-ends earlier). If so, SSAS answers "Select Date" only ~2 months back + month-ends — vs our dbo
route's daily-since-2021-06. Note Cognos itself now retains LESS than that (§9.2: 7/12 already
purged), so SSAS ≥ Cognos parity in practice; only the dbo build beats both.

**Other open items:** company-2 (+1-day) alignment inside FCR_Detail (§7b), CostMethod row fan-out
(measures average it out; flat lists must use measures, §7b), carrier-borrow behavior of
`AmountValueAtCost` for ItemCostSKey=-1 lots (validate vs xlsx), cost basis = same EDW warehouse so
the §9.1 418-row Oracle disagreement would persist identically. Live Connection (SSAS 2019, team
mandate) = slicer-date UX (Option B semantics — no PQ parameter), no local tables (the §11 DAX
validation layer could NOT ride along; validation would use report-level measures only).

**Verdict:** all four pages are buildable on the `Inventory Snapshot` perspective **for the dates the
spine retains** — Summary matrix (Region×Lot Status, LBs/USD via Selected-UOM/Currency measures),
Inventory Data + Escor Inventory flat lists (dimension columns + measures, visual filter QOH>0,
Escor = Item Global Bulk 'ESC5200'), Escor Lot Details (flat `Lot` list filtered to ESC family).
Probes §7a-e decide; if the spine is pruned, the human call is: SSAS variant (team-preferred, less
history) vs current EDW dbo build (full history) vs shipping both like 08/10.

### 12.1 PROBE §7a RESULT — 2026-07-22 (SSMS DAX on SSASPROD) — **SSAS REJECTED, FINAL**

`SUMMARIZECOLUMNS('Calendar Inventory Snapshot'[Calendar Date], "FactRows", COUNTROWS('Inventory
Snapshot'))` returned **exactly two dates**: 2026-07-22 (688,247 rows) and 2026-07-23 (80,704 rows).
The fact is a **current-position snapshot only** — no history at all, worse than the R18
pruned-spine hypothesis. A "Select Date" report cannot be served by a single-day fact, so §2's
routing is final: **EDW `dbo.FactInventorySnapshot_History` remains the source; no SSAS variant.**

- Bonus: the 7/23 cohort (~80k rows, dated tomorrow) is almost certainly the company-2 (+1-day)
  block — §7b effectively confirmed in passing: the shift exists inside FCR_Detail too.
- §7d/§7e moot. **§7c ALSO DEAD (same day, `07c_tblot_probe.sql` on EDWPROD): all 80/80 lots
  MISSING from `BIQL.TbLot` too** — the gap is EDW-wide, not a DimLot lineage quirk.

### 12.2 THE 80-LOT GAP CLOSED AS DISCLOSURE — 2026-07-22 (`07c2_f4108_ods_probe.sql` on ODSPROD)

**All 80/80 lots MISSING from ODS `PRODDTA.F4108` (exact branch+lot).** Lot-only fallback: a single
lot number, 616054, exists in F4108 at all — and only at AUBA/AUB2, not the CIN2 branch Cognos lists
it under. Full chain now probed: BIQL.DimLot ✗ → BIQL.TbLot ✗ → ODS F4108 ✗. **The lots exist only
in Cognos's Oracle DW — JDE has purged them (79 of 80 are 2011-2013 vintage). No SQL Server source
can reproduce them; supersedes §9.2's "re-key vs reroute" question — neither applies. FINAL:
disclosed known diff** (Missing Lots [Verdict] string in the TMDL updated to match; same
we-outlive-the-source framing as the §9.2 retention selling point, opposite direction).

Disclosure line for the report-out / Dave note: *"Escor Lot Details: Cognos lists 80 lots (79 from
2011-2013, 1 from 2025-12) that no longer exist in JDE's lot master — its Oracle warehouse retains
purged history. PBI reflects the live lot master (1,583 vs 1,663 rows). Verified against EDW and
ODS F4108 directly, 2026-07-22."* The single 2025-12-03 lot is the only eyebrow-raiser; if Dave
asks, it was likely deleted/merged in JDE after the Oracle DW captured it.

## 9.3 TIGHT CAPTURE #2 — exported 2026-07-22, prompt date 2026-07-21 (filed as `Cognos export (tight capture 2026-07-22, AsOf 2026-07-21).xlsx`)

All four pages populated (Oracle retains 7/21); **zero duplicate rows on any page** (confirms §9.2:
the render-dup theory is dead for exports). Validation targets @ `AsOfDate = 2026-07-21`:

| Page | Rows | Checksums |
|---|---|---|
| Summary | 41 data rows | last region (Singapore) Total `-` col: LBs 6,585,440.86 / USD 9,321,435.54 |
| Inventory Data | **4,175** (distinct) | QOH 16,906,508.18 · LBs 25,905,366.47 · USD 39,188,615.36 · EUR 34,339,946.71 |
| Escor Inventory | **47** (was 48 @7/12) | KGs 679,389.80 · LBs 1,497,782.20 · QOH 716,051.53 |
| Escor Lot Details | **1,663** (date-independent, same as §9.2) | 80-lot gap target unchanged |

Timing note: the 7/21 snapshot was written by last night's DW load and is now immutable — only SCD1
dims drift, so a same-day jumpbox refresh is a valid tight capture (no minutes-apart urgency for the
snapshot pages).

**NEXT: set `AsOfDate = 2026-07-21` on the jumpbox, refresh ALL tables** (also brings the §11 DAX
validation layer + `Missing Lots` probe live), reopen locally → run the key-level compare vs these
targets + read the §11 deltas and the Missing-Lots verdicts off the model.

## 9.4 VALIDATION ROUND 2 — 2026-07-22 (jumpbox refresh @ AsOfDate = 2026-07-21 vs tight capture #2 — BOTH SIDES SAME DAY, 7/21 snapshot immutable)

Model loaded 4,136 Inventory rows / 47 Escor / 1,583 Lot Info. Key compare (same ADOMD method, blank
Location AND blank Lot normalized vs Cognos '-'):

- **Escor Inventory: 47 = 47 EXACT** (KGs/LBs within rounding).
- **Inventory: 4,117 of 4,175 xlsx keys shared (98.6%).** Because the capture is tight, the residuals
  are now PROVEN stable cross-warehouse artifacts, not time drift:
  1. **10 status-only diffs** — SING `AMAZONP.S` INCOMING lots: Cognos status `A`, ours blank. New-lot
     status derivation timing between warehouses.
  2. **~47 truly missing / ~7 truly extra** — nightly **load-window skew**: recent-activity lots the two
     warehouses snapped on opposite sides of late-day movements (missing: CIN2-heavy — `RC39RXT` 31.5k,
     `SMAX3LS`, `JONZNO`, `JON63LS`; extra: CINC `ME67235` 'T' 47.1k, `ME91735` 'L' 44.3k, `HL723-OP`
     13.2k, `ML270R` 11.4k). NOT a status filter — T/L statuses exist on both sides (74 L / 12 T in
     xlsx). Same class as r17's "DW nightly-echo" precedent; irreproducible, disclose.
  3. **7 QOH diffs on shared keys** (incl. the HL723/HL723-OP location/item split at CINC).
  4. **19 sentinel LB rows, net −1.56M LBs** — identical class to §9.1 (ETHAL.S 880,000/374,880 rendered
     LBs = DW −1-sentinel ×44; ours physically correct). Stable across dates.
  5. **USD 417 rows −$536,434 / EUR 408 rows −$467,991** — the SAME lots at the SAME amounts as §9.1
     (10× SNG4 `ESC5200.S` @ −$17,600, `TWN60NK` −$30,258, `MFHS4200.S-PD` +$33,293 where Cognos shows
     $0). Cost-basis disagreement (EDW AmountUnitCost vs Oracle UNIT_COST) is now proven **static** —
     it will reproduce identically at any date. Disclose or D-14a gateway; no code fix exists on EDW.
- **Lot Info: 1,583 vs 1,663 — the 80-lot gap reproduces exactly** (stable target for probe §6 / the
  Missing Lots table).
- **DAX layer refresh was PARTIAL**: only `Snapshot` (63,619 rows) + `FX Rate` (4 currencies) loaded;
  `Item` / `Lot` / `Company` / `UOM Conversion` / `Missing Lots` are EMPTY (calc columns error until
  they load). Local refresh attempt confirmed EDW is firewalled from the laptop — **next jumpbox
  refresh must approve/refresh ALL tables**, then the §11 deltas + Missing-Lots verdicts light up.

## 13. DATE UX CONVERTED: PARAMETER → SLICER — 2026-07-22 (D-14b RESOLVED as Option B, rolling 13 months)

Zack's call: a PQ parameter defeats a report literally named "Select Date" (Service users can't change
it without a refresh). Converted to the events-in-progress pattern:

- **`Snapshot` is now THE report fact**: interval-grain (SCD2 rows, no per-date explosion), loaded for a
  **rolling 13-month window** (`StopDate IS NULL OR StopDate >= today − 13 months`, computed in M at
  refresh). `FX Rate` widened to the same window. **Sizing unknown until first refresh** — if the row
  count is unreasonable, shrink the window in both partitions.
- **New disconnected `Select Date` table** (M calendar, 13 months, sorted desc) + single-select dropdown
  slicer on pages 1-3. **No selection = latest date** (measures use `MAX('Select Date'[Date])`).
- **All date-dependent logic moved from calculated columns to measures** (folder *Report Engine* on
  `Snapshot`): `On Hand` / `OH KGs` / `OH LBs` / `OH USD` / `OH EUR` / `Escor On Hand` / `Escor OH KGs`
  / `Escor OH LBs` / `Inventory Date` / `Escor Inventory Date` / `Output Rows` / `Cost Source`. Each
  measure re-derives the Cognos WHERE at the selected date: interval match **with the CompanySKey=2
  +1-day shift**, Has-Match join booleans, family scope, QOH>0; carrier-borrow = `MAXX(FILTER(ALL(...)))`
  escaping visual context; FX + EUR triangulation via `LOOKUPVALUE` at the selected date. Removed
  calc columns: As-Of Date, Interval Match Date, In Interval, In Inner Query, In Report, In Escor
  Report, FX cols, Unit Cost (Borrowed/Used), Cost Source, Extended Cost USD/EUR. **Date-independent
  columns stay** (RELATED dims, Has-Match, family flag, KG/LB factors + Quantity KGs/LBs ± guard,
  Weight Source). Company→FX relationship REMOVED (FX is multi-date now; uniqueness broke).
- **Pages 1-3 rebuilt onto `Snapshot`**: matrix = Region▸MPF × Lot Status (Position) with OH LBs/OH USD
  measures; Inventory Data + Escor Inventory lists = dimension columns + Report-Engine measures with
  original display names pinned (`displayName`); blank-measure rows drop out, and the visual's row
  merging reproduces the GROUP BY grain (r17 pattern). Escor page uses `Lot Status (Master)` +
  no-guard KG/LB measures (parity). Page 4 (Escor Lot Details) untouched.
- **Validation story unchanged**: `Inventory` / `Escor Inventory` / `Escor Lot Info` + `AsOfDate`
  parameter STAY in the model as the frozen SQL reference until sign-off. Tie-out `(DAX)` measures now
  alias the Report-Engine measures — **slicer @ 2026-07-21 with AsOfDate pinned @ 2026-07-21 must show
  all deltas 0.00** (§9.3 targets tie the SQL side; the DAX Validation page then proves engine ≡ SQL).
  After sign-off: delete the three SQL tables + parameter + tie-out (SQL)/Delta measures.
- Lint: ConnectFolder clean — 12 tables / 45 measures / 4 relationships; all 15 report JSONs parse.
- Open: slicer sync across pages (deliberately per-page for now); refresh-size probe on first jumpbox
  refresh; totals row styling on measure columns.

**NEXT REFRESH (jumpbox): close Desktop WITHOUT saving first** (open copy predates §13), copy repo PBIP
over, refresh ALL tables (approve every native-query prompt — §9.4's five empty DAX-layer tables must
load this time), copy back, reopen.

## 13.1 FULL REFRESH LANDED — 2026-07-22 evening (readout via MCP on the open Desktop copy)

**All 12 tables loaded.** Sizes: `Snapshot` **434,852** interval rows (13-mo window — manageable, no
shrink needed), FX Rate 1,954, Select Date 396, and §9.4's five empties now populated: Item 40,054 /
Lot 569,933 / Company 25 / UOM Conversion 316,525 / Missing Lots 80. Frozen SQL side matches §9.4
exactly (Inventory 4,136 / Escor 47); Escor Lot Info 1,584 (was 1,583 — one new lot since 7/21).

**DEFECT found by first evaluation + FIXED LIVE via MCP: `Snapshot[KG per Primary Unit (Dim)]` and
`[LB per Primary Unit (Dim)]` were in SemanticError** — the shared pattern `VAR pick =
IF(COUNTROWS(exact) > 0, exact, fallback)` is illegal DAX (IF cannot return a table; "multiple
columns cannot be converted to a scalar"). Undetectable at lint time (calc columns only evaluate
with data); it took down all four Quantity KGs/LBs columns + every weight tie-out downstream.
Rewrite: TOPN each candidate table separately, keep IF scalar —
`IF(COUNTROWS(exact) > 0, MINX(bestExact, [KG per Primary Unit]), MINX(bestFallback, ...))`
(dataType pinned Double). Applied to BOTH columns via MCP + Calculate-only refresh (no source
access needed). Note: the model/on-disk Missing Lots [Verdict] string is the pre-probe wording ("reroute to ODS
F4108") — factually superseded by §12.2 (all 80 read "Not in DimLot", consistent with the probes);
§12.2 is authoritative for the walkthrough.

## 13.2 SLICER ENGINE ≡ SQL TIE-OUT — **PASSED 2026-07-22** (slicer @7/21 vs AsOfDate param @7/21)

All deltas 0.00 at display precision (residuals are float dust, 1e-5 to 1e-10):

| Measure | DAX engine | SQL frozen | Delta |
|---|---|---|---|
| Rows | 4,136 | 4,136 | 0 |
| QOH | 16,832,865.32 | 16,832,865.32 | 4e-9 |
| KGs / LBs | — | — | 5e-5 / 3e-5 |
| USD | 38,439,170.37 | 38,439,170.37 | 7e-6 |
| EUR | 33,697,264.37 | 33,697,264.37 | 4e-6 |
| Escor QOH/KGs/LBs | — | — | ~0 (1e-10..5e-7) |
| Lot Info Rows | 1,584 | 1,584 | 0 (Cognos 1,663 = §12.2 disclosure) |

[Inventory Date]/[Escor Inventory Date] both resolve 7/21 (company-2 shift active). Missing Lots:
80 total, 0 found in DimLot (measure blank) — matches §12.2. **§13's promise holds: engine ≡ SQL.**

**PERF FIX (same session, after the tie-out first timed out at 200s):** `[OH USD]`/`[OH EUR]`
re-scanned `ALL('Snapshot')` (434k rows) **per zero-cost row** for carrier-borrow. Hoisted the
borrow-candidate pool into a top-level `VAR borrowPool` (computed once per evaluation; per-row
lookup now filters the small pool). Identical algebra — deltas re-verified byte-identical after
the rewrite; full-population USD+EUR now evaluates in seconds. `[Cost Source]` untouched (its
borrow VAR is lazy — only zero-cost rows pay the scan; revisit only if the validation page drags).

**⚠️ MCP edits pending Ctrl+S in Desktop: KG/LB (Dim) column fix (§13.1) + OH USD/OH EUR rewrite.**
~~Remaining to ship: eyeball pages 1-4 render + slicer UX in Desktop~~ → §9.5. **Saved 2026-07-22
evening (fixes persisted; Desktop restarted, insta-load confirms borrowPool fix live).**

## 9.5 VALIDATION ROUND 3 — 2026-07-22 evening vs FRESH Cognos export `(3).xlsx` (prompt 7/21) — **ALL RESIDUALS = KNOWN CLASSES, NO NEW DEFECTS**

Capture #3 checksums are byte-identical to capture #2 on every column (7/21 snapshot immutable) —
§9.4's analysis carries over. Key-level (ADOMD full-table export vs xlsx, key =
Branch|Bulk|2nd|Location|Lot, '-' normalized):

- **Inventory: 4,129/4,175 keys shared** (c-only 46 / m-only 7 = nightly load-window skew, incl.
  lot-location moves like HL723 4584132 split across locations). **QOH arithmetic closes exactly:**
  17,678 (7 shared-key diffs) + 172,449 (c-only) − 116,484 (m-only) = 73,643 = total QOH delta.
  10 status diffs = the known SING AMAZONP.S INCOMING 'A'-vs-blank set, exactly.
- **Value-diff buckets:** ≤1 = float/export noise (nets ≈ 0). Big KG/LB = **15/18 GM-EA sentinel
  rows, net 701k KGs / 1.58M LBs** (ETHAL.S, REAL, NAOH025N... — disclosure #3, R11 precedent).
  Big USD/EUR = **cost-basis class, 241 rows net $540k / €470k** — same lots as §9.4 (12+ SNG4
  ESC5200.S @ exactly $17,600 each = 4.09-vs-3.29/KG, TWN60NK $30.3k, MFHS4200.S-PD −$33.3k =
  D-14a disclosure). EUR mid-bucket (1,517 rows net −€3.4k) = triangulation-vs-direct rounding.
- **Escor Inventory: 47 = 47 keys EXACT, no gaps.** Residuals: ~30 rows LB off by ~0.5 in 48,501
  (1e-5 — KG→LB factor precision, cosmetic) + 3 lots with lot-master drift (619139/619255 status
  Q-vs-blank + memo truncation, 617170 '-'-vs-'L' + memo text = cross-warehouse SCD1 drift).
- **Escor Lot Details: PERFECT modulo the disclosure — Cognos-only set == THE 80 disclosed pairs
  80/80 exactly** (both sides gained new lot 27001348/27001368 since #2), model-only 0, duplicate
  multiplicity mismatches 0. 1,664 − 80 = 1,584 = model.

**Round-3 verdict AS OF THE KEY/QUANTITY/COST COLUMNS: parity-clean, residuals = documented
disclosures.** SUPERSEDED IN PART by §9.6 — the report-out workbook's per-column formulas forced
the first-ever compare of the attribute columns and found a real defect.

## 9.6 DEFECT: ITEM ATTRIBUTES AT WRONG GRAIN — found 2026-07-22 evening building the report-out workbook, **FIX APPLIED, needs jumpbox refresh**

Per-column compare vs capture #3 (never checked in rounds 1-3, which keyed on branch/item/location/
lot + quantities/costs/status): on the 4,129 shared keys —
- **Master Planning Family: 2,209 mismatches (53%!)** — Cognos RRC/RCB/REC/RBW where we say RAW
  (1,363), Cognos FRC/FEC/FCB/TOL/FBW where we say ETP/ATP/WAG (~750).
- **Stock Type Code: 981**, **Commodity Class Desc: 121**, **Commodity Sub Class Desc: 164**.
- Supplier Lot 81 / Memo1 50 / Memo2 149 = lot-master SCD1 drift (known class, not this defect).

**Root cause (from the Cognos-generated Oracle SQL):** `MASTER_PLANNING_FAMILY` is stamped on
**`INVENTORY_ON_HAND` itself** and `STOCK_TYPE_CODE`/PRP1/PRP2 come from an ITEM dim resolved
**per inventory row (branch grain)** — the R11 lesson (F4102, not F4101). Our queries read all four
from item-grain `BIQL.DimItem`. The MPF **filter** was also at item grain, so some of the 46/7 row
gaps may be filter casualties, not load-window drift. This is also why the Summary matrix "PBI-only
rows" appeared (Americas|ETP 2.0M LBs etc.) and why Cognos's matrix legitimately lacks them.

**Fix (applied to Inventory.m/.commented + Escor_Inventory.m/.commented + both TMDL partitions +
Snapshot partition; MCP ConnectFolder lint CLEAN 12/45/4):** new `#ib` temp table = deduped
**`BIQL.TbItemBranch`** (ItemSKey + Business Unit grain; the exact object the BIQLTabular_v2 cube
loads as 'Item Branch'; ROW_NUMBER dedupe materialized per the #temp rule) LEFT JOINed on
ItemSKey+BU; Stock Type / MPF / both Commodity descs now sourced from it; MPF IN-list filter moved
to `ib.MPF`. Snapshot table: the four columns converted RELATED-calc → native SQL columns
(EnableFolding now false — batch query); `In Family Scope` expression unchanged (same column name).

~~NEXT: close Desktop WITHOUT SAVING, jumpbox refresh-all, copy back~~ → DONE, see §9.7.

## 9.7 POST-FIX VERIFICATION + REPORT-OUT WORKBOOK — 2026-07-23 — **§9.6 FIX CONFIRMED, WORKBOOK SHIPPED**

Jumpbox refresh landed (Inventory 4,178 / Escor 47 / Lot Info 1,584 / Snapshot 434,995 interval
rows). Key-level + per-column compare vs capture #3 (ADOMD export off the refreshed local Desktop):

- **Attribute grain defect DEAD: MPF 2,209 → 0, Stock Type 981 → 0, Commodity Class 121 → 0,
  Sub Class 164 → 0.** Shared keys grew 4,129 → 4,161 (status-in-key) / 4,173 (status-out-of-key)
  — the old item-grain MPF filter was indeed dropping real rows; membership gap now just
  2 c-only / 5 m-only load-window-skew rows.
- **§13.2 tie-out re-passes**: pinned `'Select Date'[Date]=DATE(2026,7,21)` via CALCULATETABLE
  (unpinned, the engine resolves to the new latest date 7/22 — deltas there are date mismatch, not
  defect). Rows 4,178 = 4,178 (both engines gained the same 42 recovered rows vs pre-fix 4,136);
  all deltas float dust (1e-5..1e-10). Lot Info 1,584 = 1,584.
- **Summary matrix**: 0 PBI-only Region/MPF combos (pre-fix "Americas|ETP" ghost rows gone).
  Cognos `Total` rows are PER-REGION subtotals (confirmed — no grand total row). Aubange/China/
  India subtotals tie to rounding; Singapore −1.24M LBs + Americas −0.31M = the GM/EA sentinel
  class rolled up (disclosure #3), NOT the old FBW matrix-skew theory.

**Report-out workbook REGENERATED**: `Excel Validation\_report_out\14 - 1 - Ivan Global Inventory
Excel - Select Date.xlsx` (builder: session scratchpad `build_wb14.py`; standard layout — Notes +
4 Comparison sheets [Cognos|Compare|PBI] with live EXACT/tolerance formulas + RS tab). Excel COM
full-recalc: **0 formula errors; zero FALSE on all item-attribute columns**; residual FALSEs all
documented classes (USD 605/EUR 590 cost-basis @0.1% tol, Supplier Lot 82/Memo1 53/Memo2 152/
OH Date 110/Expiry 308 SCD1 drift, Lot Status 10 = AMAZONP.S, KGs 25/LBs 26 incl. sentinel rows;
Escor 47=47 w/ 14 drift FALSEs; Lot Details 1,584 aligned + 80 disclosed in RS). Notes sheet
carries the disclosure list (cost basis D-14a, sentinel factors, SCD1 drift, purged lots).

**STATUS: validation COMPLETE — ready for sign-off** (walkthrough + ship/decision on the frozen
SQL tie-out tables per §13's post-sign-off cleanup note).

**§9.7a Memo Lot 2 wrong-column check (2026-07-23, Zack question):** F4108 has THREE memo lots
(IOLOT1/2/3 per v2.xmla TbLot lineage) so a shift was plausible — but on shared keys **782
non-blank ML2 values match EXACTLY vs 44 differ** (ML1 2,038 exact; Lot Details ML2 798 vs 5),
and model values never equal Cognos's ML1 or Supplier Lot (zero cross-column identity) → **same
field, not a wrong column**. The 152 diffs decompose: 102 model-populated/Cognos-blank (memos
added in JDE after the Oracle DW captured the lot — incl. 'REQC LE 16/07/26' July-16 edits), 44
edited-later text ('MI: 38.4 AA: 15 T:' → 'T:77%' completion), 6 Cognos-only (cleared/changed).
Direction: we're more current; Cognos's lot dim looks insert-current/update-blind. Conclusive
raw-JDE tie-breaker staged = `07d_memo_lot_probe.sql` (11 sample lots, IOLOT1/2/3 + IOUPMJ;
SSAS TbLot DAX as backup if ODS is update-stale). SSASPROD confirmed unreachable locally.

**§9.7b OH USD 605-FALSE decomposition (2026-07-23, Zack question):**
- **A. 7 rows** where QOH also differs = the known load-window-skew rows (USD follows qty).
- **B. 2 rows** we cost / Cognos zeroes (MUM3 MFHS4200.S-PD, net −$34.1k) = carrier-borrow fills.
- **C. 5 rows** Cognos costs / we zero (TWN60NK $30.3k, PHADAN05311.S ×2, MP4932.E-PD,
  DPV9200.E-B1; net +$33.3k) — ItemCostSKey=-1 lots where NO carrier exists to borrow. B and C
  nearly net out ($33.3k vs −$34.1k).
- **D/E. 284 rows** 0.1–2% relative. Sub-case: **ALL 90 MUM3 rows share ONE uniform ratio 0.998**
  = INR→USD FX-rate difference (~0.2%), rate-source/date not unit cost. Rest = small basis diffs.
- **F. 307 rows** >2% relative = the true cost-basis class, **net $527k of the $546k total** —
  headline: 12 SNG4 ESC5200.S lots at exactly +$17,600 each (ratio 1.2432 = 4.09 vs 3.29/KG).
- **STRUCTURAL: all 325 disagreeing item+branch groups carry exactly ONE constant cognos/model
  ratio** — both sides are internally consistent; they disagree on the item's UNIT COST (or MUM3's
  FX rate), ruling out any quantity/factor/join bug on our side. This is D-14a precisely.
- Who's right is a JDE question: probe staged = `07e_usd_cost_probe.sql` (F4105 all cost methods
  + F4102.IBCSIN for the 10 headline items; verdict key in file). Until run: disclosure stands.

**§9.7c Workbook v2 — Rohit-explainable (2026-07-23):** rebuilt with (a) a **"Validation note"
column** at the right edge of every Comparison sheet — every row with any FALSE carries a
plain-English cause naming the exact columns (cost rows include the per-item constant ratio);
(b) a **"Diff Breakdown" sheet** (first tab after Notes) totaling every FALSE by cause: 13 classes,
counts, net USD, columns affected, example key, one-line explanation (headline: Unit-cost basis
501 rows +$538k / MUM3 FX 90 / lot-master drift 489+9+7 / sentinel 20 / skew 7 / borrow 2 vs
no-carrier 5 / AMAZONP.S 10 / Summary roll-up 26). Excel-COM verified: 1,969+83+14+9 FALSE cells,
**0 rows with a FALSE and no note**. Builder = `build_wb14.py` (WB14_STAGE env stages to
scratchpad). Staged copy verified; swap into `_report_out` blocked while the old workbook is open
in Excel — close it and copy `wb14_staged.xlsx` over.


---

## 14. SSAS IMPORT VARIANT — `1 - Ivan Global Inventory Excel - Select Date (SSAS Import)\`

The source-native sibling of this build. Everything is `SSASPROD / BIQLTabular_ISH` native DAX
import; the report derives nothing. Five tables: `Inventory` (all retained snapshot dates x the
nine plants x the 14-family scope, cost method `07`, QOH > 0), `Escor Inventory` (`ESC5200`
global bulk; the Cognos page carries no branch or family filter, so neither does the query),
`Escor Lot Info` (lot master joined to the `ESC5200`/`.E`/`.S` item branches on
`ItemBranchISKey`, `DISTINCT` per the Cognos `SELECT DISTINCT`), `Select Date` (calculated
`DISTINCT` of imported `Inventory Date` — the slicer offers only dates the report can render),
and `Last Refreshed`. No UOM Conversion, FX Rate, Company, or interval-measure machinery: weights
are the model's `[Qty On Hand KG]`/`[Qty On Hand LB]`, costs are `[Total Ext Cost IC USD]` and
`[Total Ext Cost IC]` at the EUR selector code, evaluated per row.

Facts the queries encode:

- The ISH cost measures read `SELECTEDVALUE('Calendar Inventory Snapshot'[Calendar Date])`, and
  the fact-to-calendar relationship is single-direction — a bare row-context transition leaves the
  calendar empty and the measures blank. Each cost projection therefore anchors the row's own
  snapshot date onto the calendar with `TREATAS`. `PROBE SSAS\probe_G4_cost_calendar_context.dax`
  compares bare vs anchored.
- `Item Branch` is date-versioned (`ItemBranchISDateKey` grain), so item attributes resolve as of
  the snapshot date. The `Escor Lot Info` join collapses it to distinct `ItemBranchISKey` first,
  and joins with the lineage-strip idiom (`& ""`), because the key is non-unique in the history
  table.
- `REGION` is the one report-side derivation: the 9-to-5 `SWITCH` from the EDW build, held until
  the `Branch[Region (Inventory)]` cube column lands (request with Jim, `R14 ISH\CUBE_CHANGE_Region.md`).
- The display bulk items are the F554101 pair (`Item Num Global Bulk`/`Item Num Bulk`); the F4102
  pair is imported hidden for the lineage comparison probe.

Probe gate — run `PROBE SSAS\*.dax` on SSASPROD before the first refresh:
`probe_G3_currency_codes` (EUR selector literal, built as `3`), `probe_G1_branch_region`
(retire the SWITCH?), `probe_G2_bulk_pairs` (F554101 vs F4102), `probe_G4_cost_calendar_context`,
`probe_D14a_cost_basis` (`07` vs `CostingSelectionInventory` — can close the §9.7b cost-basis
disclosure), `probe_R1_day_shift`, `probe_R5_zero_cost` (carrier-borrow need), `probe_R6_sizing`
(all-dates import volume; the fallback is a date-window predicate in the two fact partitions).

Known scope difference to state to Dave/Rohit: ISH retains ~133 approved snapshot dates
(month-end before 2026-06, daily after) versus the EDW build's ~1,890 reconstructed daily dates.
Cognos itself retains fewer dates than ISH (§9.2). The slicer only offers real dates, so the
limit is visible, never silent.

After the first refresh: pick the latest date in the slicer once in Desktop and save (the
variant ships with no pinned date so it cannot go stale), then tie out against
`Cognos export (tight capture 2026-07-22, AsOf 2026-07-21).xlsx` at the 7/21 snapshot:
4,175 / 47 / 1,663 rows, QOH 16,906,508.18, LBs 25,905,366.47, USD 39,188,615.36,
EUR 34,339,946.71.
