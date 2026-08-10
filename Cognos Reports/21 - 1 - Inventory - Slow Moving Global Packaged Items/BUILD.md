# Report 21 — 1 - Inventory - Slow Moving Global Packaged Items — BUILD SPEC

**Cognos path:** `Michelman Reporting / Production and Shipping / Cogan Excel AD HOC Reports`
**Portal folder ID:** `i52030381F2354AC6818EE9527C4297C8`
**Report name (XML `reportName`):** `1 - Inventory - Slow Moving Global Packaged Items`
**Cognos package:** `/content/package[@name='Data Warehouse']/model[@name='model']` — Oracle `DW_LEGACY`,
stars **Inventory On Hand** and **Order Activity**. `RS_modelModificationTime = 2018-07-31`.
**Assigned:** Zack, 2026-08-06. **Stage:** 🟨 REFRESHED AND VALIDATED (#22, #23) — PBIP + 3 `.m`
delivered, refreshed twice on the jumpbox, validated against the tight capture both times. The one
open code change is **#22(a)**: the EA-primary weight fix (`BIQL.FactSalesDetail` +
`Unit_Weight_Adj`), awaiting the open/closed interlock and a further refresh. Probes **P1 and P5
are closed**, **P2b** is the only one left and it is not blocking. Build notes and corrections are in §7 entries
**#12–#21**. Read before trusting the text above them: **#13** (the line-number truncation is now
reproduced ON PURPOSE — D-21a decided for parity), **#14** (LB→KG must *multiply* by
`0.453597189`), **#17(g)** (§4.5's sample DAX never fires), **#18** (`Open Indicator` is
`StatusCodeNext`, **not** `SalesTableSource` — which is disproved, and #16 is superseded), **#19**
(§4.1/§4.2's `CAST(... AS date) - <int>` is **invalid T-SQL** and would have failed the first
refresh), and **#21** (path-length blocker — **#17(h) is superseded**).

⚠ **The PBIP artifact is named `Slow Moving Packaged Items`, not the Cognos report name.** The full
name does not fit under the 256-character path limit from this folder; see §7 **#21** before
renaming it. The three **page** names are unchanged.

Three independent queries → three pages → three flat lists. No joins between them in Cognos; the
slow-moving analysis is assembled by hand in Excel. Sheet 3 is the spine (every active packaged
item-branch), sheet 1 is what is in stock, sheet 2 is what has moved in the last 365 days.

Author the PBIP in **PBIR** (like reports 02/03/14/17/18). Production `.m` files are comment-free;
a `<name>.commented.m` master sits alongside each (§1 repo rule).

**Do NOT build the PBIP from this file** — a separate build agent consumes this spec.

---

## 0. Intake integrity — and the fact that shapes everything below

| Artifact | Status | Notes |
|---|---|---|
| Native (Oracle) SQL, all 3 queries | **COMPLETE** | `Intake\Query + XML - NATIVE SQL (filed 2026-08-06).txt` lines 2–24. Real Oracle syntax, `sysdate` resolved. More trustworthy than the IBM-Cognos-SQL form reports 19/20 arrived in. |
| Report XML | **COMPLETE, untruncated** | Same file, lines 27–170, closes on `</report>`. 3 queries ↔ 3 pages, 1:1. Every page one flat `<list>` — no `listGroup`, no crosstab, no totals, no prompts. |
| Rendered export (xlsx) | **PRESENT — TIGHT CAPTURE** | `Intake\Cognos export - tight capture 2026-08-06.xlsx`, 3 sheets, `DATE` column = 2026-08-06 ⇒ `INVENTORY_DATE` = **2026-08-05**. Profiled in full (§7). |
| Screenshots | Not collected — not needed | The 3-sheet xlsx is complete render evidence. |

**Completeness verdict: nothing is missing.** Every question the team lead flagged as open was
settled locally against the SQL mirror (§9 of the root `CLAUDE.md`); see §2 and the validation log
in §7. The mirror was refreshed **2026-08-05**, the export pulled **2026-08-06** — one day apart,
which is as tight as a local comparison can be.

### 0.1 The insight: this report is three *different* GL-class populations, not one

Every one of the three queries filters `GL_CLASS_CODE = 'IN32'` — that predicate *is* the
definition of "Global Packaged Items". But the Cognos SQL takes it from **two different tables**:

| Query | Cognos source | EDW column (MEASURED, §7 log #1/#2) |
|---|---|---|
| 1 Inventory | `INVENTORY_ON_HAND.GL_CLASS_CODE` | `BIQL.FactInventorySnapshot*.CategoryGLF41021` |
| 2 Shipments | `ITEM.GL_CLASS_CODE` | `BIQL.TbItemBranch.[Category GL F4101]` |
| 3 Items | `ITEM.GL_CLASS_CODE` | `BIQL.TbItemBranch.[Category GL F4101]` |

**They are genuinely different populations and must not be unified.** Measured on the mirror:
`CategoryGLF41021` and `[Category GL F4101]` disagree on **54 of 4,235** in-scope inventory
positions (1.3%), and the disagreement is *material* — the fact-level column includes the
water/utility items (`SH2O`, `SH2OF`, `DIH2O*`) whose on-hand quantities run to **99.98 billion**.
The export's single largest `Quantity on Hand` value is **99,979,021,880.0025** on `CINC / SH2OF`;
using `[Category GL F4101]` on query 1 drops that row and collapses the sheet's QOH total from
304 billion to 7.5 million. Using `[Category GL F4102]` on query 3 *adds* 36 water/packaging
item-branches the export does not have.

Get this wrong and every number on the affected sheet changes silently. **Build exactly the table
above.**

---

## 1. Source route — **EDW SQL Server** (decided; SSAS provisional-only, ODS rejected)

Evaluated SSAS → EDW → ODS per the standing mandate (`CLAUDE.md` §1).

- **SSAS `BIQLTabular_v2` (Live) — NOT RECOMMENDED, and the local evidence is weak.** A live
  connection would need **one** perspective covering inventory-on-hand **+** order activity **+**
  item master. `Supply and Demand` is the only plausible candidate (it carries `Inventory
  Snapshot`, `Sales`, `Item Branch`, `Lot`, `Customer Ship To`). ⚠ **That reading comes off the
  local `ssasprod.bim`, which dumps the STALE `BIQLTabular`, not `BIQLTabular_v2`** — so any SSAS
  conclusion here is **provisional and must be re-checked on the jumpbox before it is relied on**.
  Independently of the perspective question, a live connection forbids the local KG/LB
  renormalisation (§2.4) and the net-of-cancel derivation (§2.5), both of which are required for
  parity. Do not route this report to SSAS without re-checking `v2` and re-reading §2.4/§2.5.
- **EDW SQL Server — CHOSEN.** Every column the report needs exists and was measured (§3, §7). All
  three source objects are present in the local snapshot, so the probes ran on this machine.
- **ODS `PRODDTA` — REJECTED as the route,** but used as *corroborating evidence* for the
  conversion-factor finding (§2.4). `F41021` is current-only and carries no decoded item
  attributes; `F4211`+`F42119` would have to be re-unioned by hand when EDW already does it.

Connection style: `Sql.Database("EDWPROD", "EDW")`, two-part `BIQL.<obj>` / `dbo.<obj>` names,
native T-SQL via `Value.NativeQuery(..., null, [EnableFolding=false])`. Every source query carries
**`WITH (NOLOCK)`** (root `CLAUDE.md` §9).

---

## 2. The five settled questions (all measured — do not re-derive)

### 2.1 GL class code — SETTLED, see §0.1

Query 1 → `snap.CategoryGLF41021` (`nchar(4)`). Queries 2/3 → `ib.[Category GL F4101]`
(`nchar(4)`). Trim before comparing: both are `nchar`, so `LTRIM(RTRIM(x)) = 'IN32'`.

### 2.2 `ON_HAND_DATE` and `LOT_EXPIRY_DATE` — **SOURCEABLE** (the biggest flagged risk, closed)

Both live on **`BIQL.DimLot`** (equally on `dbo.DimLot`, and as `[On Hand Date]` / `[Lot Expiration
Date]` on `BIQL.TbLot`):

| Cognos | EDW | Type |
|---|---|---|
| `ITEM_LOT_NUMBERS.ON_HAND_DATE` | `BIQL.DimLot.OnHandDate` | `date` |
| `ITEM_LOT_NUMBERS.LOT_EXPIRY_DATE` | `BIQL.DimLot.LotExpirationDate` | `date` |

Join `LEFT JOIN BIQL.DimLot l ON l.LotSKey = snap.LotSKey`. Measured: **zero NULLs** across all
2,072 in-scope positions, i.e. the join never drops and never blanks. `BIQL.DimLot` also carries
`BestBeforeDate`, `SellByDate`, `LotEffectivityDate` if the requester later wants them.

**Fidelity is good but not perfect, and the gap runs in our favour** (§7 log #5): on the 1,959
positions common to both sides, `OnHandDate` agrees on 92.8% and `LotExpirationDate` on 87.3%.
Of the disagreements, **137 are rows where Cognos shows the JDE zero-date `1900-01-01` and EDW has
a real date** — recently-created lots (2026-05 → 2026-08) that the legacy DW's lot dimension has
not picked up. Another 109 are real-vs-real expiry differences (30 of them exactly ±1 day, 79
larger — consistent with retest-driven expiry extensions landing in EDW first). This is a
**Cognos-side staleness gap, not a rebuild defect**; disclose it, do not "fix" it.

### 2.3 Which inventory table — **`BIQL.FactInventorySnapshot_History_Filtered`**, filtered to yesterday

| Object | Rows (mirror) | Grain | Verdict |
|---|---|---|---|
| `BIQL.FactInventorySnapshot_History_Filtered` | 13,349,051 | one row per position **per calendar date**, `CalendarDate` 2021-06-30 → 2026-08-05 | **CHOSEN** |
| `BIQL.FactInventorySnapshot` | 120,086 | current day only (`CurrentDateByTimeZone`) | rejected — see below |
| `dbo.FactInventorySnapshot_History` | 2,029,747 | physical SCD2 interval (`StartDate`/`StopDate`) | rejected — needs a date spine |

Report 18 §14.4 cracked the lineage and it applies verbatim: `_Filtered` is
`BIQL.DimCalendarInventorySnapshot` LEFT JOINed to `dbo.FactInventorySnapshot_History` on
`CASE WHEN CompanySKey = 2 THEN DATEADD(DAY,1,SNDT.CalendarDate) ELSE SNDT.CalendarDate END
BETWEEN StartDate AND ISNULL(StopDate, <today>)`. Report 18 had to abandon `_Filtered` because its
calendar spine keeps only **current + previous month daily, month-ends before that** — fatal for a
4-to-6-month rolling history. **Report 21 wants a single day (yesterday), which is always inside
the daily window.** So the retention gap that forced report 18 onto `dbo` is irrelevant here, and
we get the view's decoded columns and its per-company timezone handling for free. Take the view.

`BIQL.FactInventorySnapshot` is rejected because its `CalendarDate` is *today* (per company), not
yesterday, and today is a partial intraday load.

⚠ **The `CompanySKey = 2` timezone shift is visible in the data and you must plan around it.**
Measured on the mirror (refreshed 2026-08-05):

| `CalendarDate` | Branches present in `_Filtered` |
|---|---|
| 2026-08-04 | all seven — AUB2, AUBA, CIN2, CIN4, CINC, SING, SNG4 |
| 2026-08-05 | AUB2, AUBA, SING, SNG4 **only** |

The EMEA/Asia companies advance a day ahead of the Americas ones. The predicate
`snap.CalendarDate = DATEADD(DAY, -1, CAST(GETDATE() AS date))` is still the right port of Oracle
`to_date(sysdate) - 1` (a clean truncate-then-subtract "yesterday"), and at a normal refresh time
every company has a complete row set for yesterday. **But at the moment of the refresh, "yesterday"
for a CompanySKey=2 branch already reflects that branch's own next business day.** This is exactly
how Cognos behaves too — do not try to normalise it.

For the local tie-out (§7) the comparison had to be run at `CalendarDate = 2026-08-04`, the latest
date on which the mirror carries all seven branches; the export's `INVENTORY_DATE` is 2026-08-05.
**The Inventory sheet's local comparison is therefore one business day stale by construction** and
its ~5% lot churn should be read in that light.

### 2.4 The LB and KG conversion factors — **the Cognos DW uses a constant of `2.2045992`, and EDW does not**

This is the finding with the widest blast radius, and it is measured on every row of both sheets.

**What the export actually contains.** Across all 2,065 Inventory rows and all 17,259 Shipments
rows, `Quantity on Hand LBs / Quantity on Hand KGs` is a **single constant, `2.2045992`** —
2,054/2,065 and 17,179/17,259 rows respectively; the handful of exceptions are UOMs that carry
their own JDE LB *and* KG conversions (e.g. `TM` → 2204.6 LB / 1000 KG = 2.2046). The reciprocal is
`0.453597189`. Worked from the export: `567 KG → 1250.0077464 LB`, `8276.5 → 18246.3652788`,
`336 LB → 152.408655504 KG`.

`2.2045992` is **not** the physical constant (`2.20462262`) and **not** JDE's standard conversion.
It is a 7-implied-decimal JDE factor (`22045992`). Corroborated in ODS: `PRODDTA.F41002` contains
`UMCONV = 22045992` on 23 `KG→LB` rows — and `22046200` on **265,323**. So the DW is not reading
the dominant per-item factor; it applies one stored constant.

**Where EDW disagrees:**

| Source | KG→LB | LB→KG |
|---|---|---|
| Cognos DW (the export) | **2.2045992** | **0.453597189** |
| `PRODDTA.F41003` (JDE standard) | 2.20462 | — |
| `BIQL.DimItemUOMConversionLBKG.LB` | 2.204620000 | — |
| `dbo.FactSalesDetail.ConversionFactorLB` / `…KG` | 2.2046200 | 0.4535971 |

Note that EDW's `ConversionFactorKG` (`0.4535971`) *is* the Cognos reciprocal truncated to its
`decimal(19,7)` scale, while its `ConversionFactorLB` (`2.2046200`) is the JDE standard — the two
columns are computed down different paths. `BIQL.DimItemUOMConversionLBKG` is worse still: its
`ConversionFactorSecToPrim` is `decimal(19,4)`, so a 7-decimal JDE factor is rounded before it ever
reaches the `LB`/`KG` columns. **Neither EDW source reproduces the export.**

**Therefore, use this rule on BOTH sheets** (measured results in §7 log #4 and #7):

```
IF   primary UOM = 'KG'  ->  KGs = qty                 ;  LBs = qty * 2.2045992
ELIF primary UOM = 'LB'  ->  LBs = qty                 ;  KGs = qty / 2.2045992
ELSE                     ->  KGs = qty * <EDW KG factor> ;  LBs = KGs * 2.2045992
```

- **Inventory sheet:** 1,847 of 1,959 comparable rows reproduce **exactly**, +22 within 1e-6, +3
  within 1e-3. The remaining 48 are rows whose `Quantity on Hand` itself moved between 08-04 and
  08-05 — i.e. every conversion that *could* be checked, checked out.
- **Shipments sheet:** the rule lifts exact matches from 7,974 → **16,564 of 17,253 on KGs**
  (96.0%) and 8,665 → **16,552 on LBs**. Using EDW's raw `ConversionFactorLB` instead leaves 7,912
  rows wrong in the 6th decimal — invisible at `#,0` but a guaranteed `EXACT()` failure in the
  report-out workbook.
- The 676 residual failures are **all `UOMPrimary = 'EA'`** items (mostly `B1`→`EA`), where EDW's
  `ConversionFactorKG` is typically exactly **2×** the Cognos one. That is a genuine EDW-vs-DW
  divergence on EA-primary weight conversions, not a formula error — see D-21e.

`2.2045992` must appear **once**, as a named constant, in each generated query. Do not inline it in
six places and do not round it.

### 2.5 `ORDERED_QTY` is net of cancellation, and it is measured in the PRIMARY UOM

Two separate corrections to the obvious mapping, both measured:

1. **`ORDERED_QTY * SALES_FACTOR` = `dbo.FactSalesDetail.QuantityOrderedPrimaryUOM`.** EDW's
   `SalesFactor` column is a sign/credit factor (±1), **not** Cognos's `SALES_FACTOR` (the
   line-UOM → primary-UOM conversion, `F41002.UMCONV / 10^7` — root `CLAUDE.md` §7). Multiplying
   `QuantityOrdered * SalesFactor` gives the quantity in the *transaction* UOM and is wrong by the
   pack size: order 26001236 line 1 comes out **1.0** (one drum) against the export's **200**.
   `QuantityOrderedPrimaryUOM` reproduces the export exactly on **17,253 of 17,259** rows.
2. **A fully-cancelled line has `ORDERED_QTY = 0` in Cognos and is dropped by the `> 0` filter.**
   EDW keeps the gross quantity and books the cancellation separately. Adding
   `AND (f.QuantityOrdered - f.QuantityCanceledScrapped) > 0` removes **1,427 of 1,432** spurious
   rows and only **6 of 17,261** genuine ones. Without it the sheet is 8.3% over-populated.
   The 6 genuine rows it costs are lines Cognos itself renders as `1e-10` — float residue on
   partially-cancelled lines — so they round to 0 on both sides anyway.

`QuantityCanceledScrapped` is in the transaction UOM, same as `QuantityOrdered`, so the two are
directly comparable; do not mix `QuantityOrderedPrimaryUOM` into that predicate.

---

## 3. Column mappings (measured EDW types)

Display order = the Cognos `<listColumns>` order. Headers render the **data-item label**, which is
usually the data-item name — with one exception called out below.

### 3.1 Sheet 1 — `Inventory` → page **Inventory** (17 columns, 2,065 export rows)

Base: `BIQL.FactInventorySnapshot_History_Filtered snap`
`JOIN BIQL.TbItemBranch ib ON ib.ItemBranchSKey = snap.ItemBranchSKey`
`LEFT JOIN BIQL.DimLot l ON l.LotSKey = snap.LotSKey`

| # | Header (verbatim) | Cognos source | EDW expression | Type | Format |
|---|---|---|---|---|---|
| 1 | Branch Plant | `INVENTORY_ON_HAND.BRANCH_PLANT` | `LTRIM(RTRIM(snap.BusinessUnit))` | `nchar(12)` | text |
| 2 | Global Bulk Item | `ITEM.GLOBAL_BULK_ITEM` | `ib.[Item Global Bulk]` | `nvarchar(25)` | text |
| 3 | Bulk Item | `ITEM.BULK_ITEM` | `ib.[Item Bulk]` | `nvarchar(25)` | text |
| 4 | 2nd Item Number | `MEASURE.ITEM_NUMBER_2ND` | `ib.[Item Num 2nd]` | `nvarchar(25)` | text |
| 5 | GL Class Code | `INVENTORY_ON_HAND.GL_CLASS_CODE` | `snap.CategoryGLF41021` | `nchar(4)` | text |
| 6 | Location | `INVENTORY_ON_HAND.LOCATION` | `snap.Location` raw; `-` in a **DAX display column** (§4.5) | `nvarchar(20)` | text |
| 7 | Lot Number | `INVENTORY_ON_HAND.LOT_NUMBER` | `snap.LotNum` raw; `-` in a **DAX display column** | `nchar(30)` | text |
| 8 | Lot Status | `MEASURE.LOT_STATUS` | `snap.LotStatusCode` raw; `-` in a **DAX display column** | `nchar(1)` | text |
| 9 | Master Planning Family | `INVENTORY_ON_HAND.MASTER_PLANNING_FAMILY` | `ib.[Master Planning Family]` | `nchar(3)` | text |
| 10 | Quantity on Hand | `SUM(MEASURE.QUANTITY_ON_HAND)` | `SUM(snap.QuantityOnHandPrimaryUOM)` | `decimal(19,4)` | `#,0` |
| 11 | **Primary Unit of Measure** | `MEASURE.UNIT_OF_MEASURE` | `snap.UOMPrimary` | `nchar(2)` | text |
| 12 | Quantity on Hand KGs | `SUM(QOH × CONVERSION_FACTOR_KG)` | §2.4 rule | — | `#,0` |
| 13 | Quantity on Hand LBs | `SUM(QOH × CONVERSION_FACTOR_LB)` | §2.4 rule | — | `#,0` |
| 14 | Stock Type Code | `ITEM.STOCK_TYPE_CODE` | `ib.[Stocking Type]` | `nchar(1)` | text |
| 15 | On Hand Date | `ITEM_LOT_NUMBER.ON_HAND_DATE` | `l.OnHandDate` | `date` | `d MMM, yyyy` (DMY) |
| 16 | Lot Expiry Date | `ITEM_LOT_NUMBER.LOT_EXPIRY_DATE` | `l.LotExpirationDate` | `date` | `d MMM, yyyy` (DMY) |
| 17 | DATE | `to_date({sysdate})` | `CAST(GETDATE() AS date)` | — | `d MMM, yyyy` (DMY) |

⚠ **Header trap — column 11.** The XML data item is named `UOM`, but it carries **no `label=`
override**, so Cognos falls back to the *model* item label and the export header reads
**`Primary Unit of Measure`**. Port that string, not `UOM`, via PBIR `displayName` (root
`CLAUDE.md` §7 — `label=` renders as the column header).

Also note `Inventory Date` is **selected but never displayed** (filter-only), and column 17 `DATE`
is the *run stamp* (`sysdate`, **not** `sysdate-1`) — it reads 2026-08-06 in the export while the
data is 2026-08-05. It moves with every refresh.

### 3.2 Sheet 2 — `Shipments` → page **Shipments** (19 columns, 17,259 export rows)

Base: `dbo.FactSalesDetail f`
`JOIN BIQL.TbItemBranch ib ON ib.ItemBranchSKey = f.ItemBranchSKey`
`JOIN dbo.DimCustomer c ON c.CustomerSKey = f.ShipToCustomerSKey`
`JOIN dbo.DimAddress a ON a.AddressSKey = c.AddressSKey`

| # | Header | Cognos source | EDW expression | Type | Format |
|---|---|---|---|---|---|
| 1 | Order Company | `substr(ORDER_LINE_ID,1,5)` | `f.OrderCompany` | `nchar(5)` | text |
| 2 | Branch Plant | `MEASURE.ORGANIZATION_ID` | `LTRIM(RTRIM(f.BusinessUnit))` | `nchar(12)` | text |
| 3 | Global Bulk Item | `ITEM.GLOBAL_BULK_ITEM` | `ib.[Item Global Bulk]` | `nvarchar(25)` | text |
| 4 | Bulk Item | `ITEM.BULK_ITEM` | `ib.[Item Bulk]` | `nvarchar(25)` | text |
| 5 | 2nd Item Number | `MEASURE.ITEM_NUMBER_2ND` | `f.ItemNum2nd` | `nvarchar(25)` | text |
| 6 | Order Number | `ORDER_ACTIVITY.ORDER_NUMBER` | `CAST(f.OrderNum AS varchar)` | `int` | text |
| 7 | Line Number | `substr(ORDER_LINE_ID, 1+instr(…,',',-1), 5)` | §3.4 — **string surgery required** | `decimal(9,3)` | text |
| 8 | Last Status | `MEASURE.LAST_STATUS` | `f.StatusCodeLast` | `nchar(3)` | text |
| 9 | Next Status | `MEASURE.NEXT_STATUS` | `f.StatusCodeNext` | `nchar(3)` | text |
| 10 | Open Indicator | `ORDER_ACTIVITY.OPEN_INDICATOR` | **D-21d — unresolved**, see §3.5 | — | text |
| 11 | Promised Ship Date | `ORDER_ACTIVITY.DUE_DATE` | `f.PromisedShipmentDate` | `date` | `d MMM, yyyy` (DMY) |
| 12 | Ordered Quantity | `SUM(ORDERED_QTY × SALES_FACTOR)` | `SUM(f.QuantityOrderedPrimaryUOM)` — §2.5 | `decimal(19,4)` | `#,0` |
| 13 | Ordering Unit of Measure | `ORDER_ACTIVITY.ORDERING_UNIT_OF_MEASURE` | `f.UOMTransaction` | `nchar(2)` | text |
| 14 | Ordered Quantity LBs | `SUM(qty × CONVERSION_FACTOR_LB × SALES_FACTOR)` | §2.4 rule on `QuantityOrderedPrimaryUOM` | — | `#,0` |
| 15 | Ordered Quantity KGs | `SUM(qty × CONVERSION_FACTOR_KG × SALES_FACTOR)` | §2.4 rule | — | `#,0` |
| 16 | Line Type | `MEASURE.LINE_TYPE` | `f.LineType` | `nchar(2)` | text |
| 17 | Customer Code | `CUSTOMER_SHIP_TO.CUSTOMER_CODE` | `CAST(f.AddressNumShipTo AS varchar)` | `int` | text |
| 18 | Customer Name | `CUSTOMER_SHIP_TO.CUSTOMER_NAME` | `a.AddressDesc` | `nvarchar` | text |
| 19 | Order Type Code | `ORDER_TYPE.ORDER_TYPE_CODE` | `f.OrderType` | `nchar(2)` | text |

`GL Class Code` is selected but not displayed on this sheet. Ordering UOM order is **LBs then KGs**
here (the Inventory sheet is KGs then LBs) — keep each sheet's own order.

**Ship-to join measured clean:** 25,993 of 25,993 in-window lines resolve through
`ShipToCustomerSKey → DimCustomer → DimAddress`. Zero drops, zero fan-out. `Customer Code` =
`AddressNumShipTo` and `Customer Name` = `DimAddress.AddressDesc` reproduce the export on
17,251/17,259 rows; the 8 misses are one customer whose name differs only in **letter case**
(`HOANG HA LABEL CO., LTD-Vietnam` vs `Hoang Ha Label Co., Ltd-Vietnam`) — a DW-vs-EDW casing
difference, not a join problem. Note `BIQL.TbCustomerShipTo` does **not** exist in the mirror; this
`DimCustomer → DimAddress` path is the reachable equivalent and it is sufficient.

### 3.3 Sheet 3 — `Items` → page **Items - Active** (5 columns, 5,286 export rows)

Base: `BIQL.TbItemBranch ib`, single table, `SELECT DISTINCT`.

| # | Header | EDW expression | Type |
|---|---|---|---|
| 1 | Branch Plant | `LTRIM(RTRIM(ib.[Business Unit]))` | `nchar(12)` |
| 2 | Global Bulk Item | `ib.[Item Global Bulk]` | `nvarchar(25)` |
| 3 | Bulk Item | `ib.[Item Bulk]` | `nvarchar(25)` |
| 4 | 2nd Item Number | `ib.[Item Num 2nd]` | `nvarchar(25)` |
| 5 | Stock Type Code | `ib.[Stocking Type]` | `nchar(1)` |

The **page** is named `Items - Active` while the XML query is named `Items`; the "Active" is the
page label and `STOCK_TYPE_CODE not in ('O')` is what it means (`O` = obsolete). Use the page name.

### 3.4 `OrderLineID` decomposition — and a Cognos defect it exposes

EDW's `OrderLineID` is `company,order,type,line` with the line **always** rendered to 3 decimals:
`00020,26001384,CO,2.000`. The Cognos DW's is **not** — it renders `4` for line 4.000 and `4.001`
for 4.001. So a literal `substr` port against EDW's string will not reproduce the export. Derive
from the typed column instead:

```sql
CASE WHEN f.LineNum = FLOOR(f.LineNum)
     THEN CAST(CAST(f.LineNum AS int) AS varchar(12))
     ELSE CAST(CAST(f.LineNum AS decimal(9,3)) AS varchar(12)) END
```

Order Company needs no surgery at all — `f.OrderCompany` already equals `LEFT(OrderLineID,5)`.

⚠ **Cognos's `substr(…, 5)` truncates the line number to five characters, and Cognos then GROUPs
BY the truncated string.** Line `10.001` renders as `10.00` — identical to line `10.000` — so the
two lines **merge into one row with summed quantities**. Measured: exactly **8 export rows** are
merges of this kind (e.g. order `25001999` merges lines 10.000/10.001/10.002/10.003 into a single
`10.00` row). Emulating the truncation lifted the local match from 17,251 to **17,259 of 17,259**
— it is the sole cause of every previously-unmatched export row.

This is a genuine defect in the Cognos report: it silently loses line-level detail for any line
number ≥ 10 that has sub-lines. **Do not silently reproduce it and do not silently fix it** — see
D-21a. The build should ship the *correct* (unmerged) form and the validation workbook should call
out the 8 rows, unless the requester says otherwise.

> ⚠ **SUPERSEDED 2026-08-06 — the requester did say otherwise.** Zack chose **parity**, so the
> shipped build **reproduces the truncation**, loudly documented rather than silently. The paragraph
> above stands as the rationale for the alternative; the decision and its measurements are in §7
> **#13**, and reversing it is a two-line edit described in `Shipments.commented.m`.

### 3.5 `Open Indicator` — the one column not settled locally (D-21d)

The Cognos column is `ORDER_ACTIVITY.OPEN_INDICATOR`, values `Y`/`N`, **displayed and not
filtered** on this report. `dbo.FactSalesDetail` has no column of that name. The best local
candidates, all measured:

| Candidate | Behaviour on in-window `LineType='S'` rows |
|---|---|
| `SalesTableSource` | `1` = 3,603 rows with mixed next-status (open, F4211-lineage); `2` = 424,423 all next-status `999`; `4` = 440,759 all `999` |
| `StatusCodeNext = '999'` | separates closed from open, but is not literally a `Y`/`N` flag |
| `QuantityOpen > 0` | **zero** rows in the window — every in-scope line has `QuantityOpen = 0` |

`SalesTableSource = 1` is the closest structural analog (JDE `F4211` = open, `F42119` = history),
and the export does contain both `Y` and `N`. **This could not be settled against the export
locally because the comparison key never needed it** — it is a display-only column and every other
column already ties. Resolve it with a single jumpbox probe (§8 P4): pull `Open Indicator` from a
fresh Cognos run alongside `SalesTableSource` and `StatusCodeNext` for the same order lines and
read the cross-tab. Do not guess.

> ✅ **RESOLVED 2026-08-06 by probe P1 — and this section's leading candidate was WRONG.**
> The answer is `StatusCodeNext`: **`Open Indicator = IF(TRIM(StatusCodeNext) = "999", "N", "Y")`**,
> a perfect partition over all 17,259 export rows (16,363 `N` / 896 `Y`, zero exceptions).
> **`SalesTableSource` is positively disproved, not merely second-best** — the probe found **252
> lines** with `SalesTableSource = 1` *and* `StatusCodeNext = 999`, which it would misclassify.
> Those 252 sit outside the export-matched set, which is why a local cross-tab on the matched rows
> made `SalesTableSource` look perfect. The column has been **removed from the shipped query** so it
> cannot be reinstated by accident. Full figures: §7 **#18**.

⚠ **Do not copy report 19's `Open Indicator <> 'Y'` carve-out into this report.** Report 19 filters
on it; report 21 only displays it. Two reports over the same fact, deliberately different scope.

---

## 4. The complete ported filter set

### 4.1 Query 1 — Inventory

```sql
snap.CalendarDate = DATEADD(DAY, -1, CAST(GETDATE() AS date))   -- to_date(sysdate)-1  (§2.3, timezone note)
                                                         -- NOT `CAST(...) - 1`: the T-SQL `date` type
                                                         -- has no arithmetic operators. §7 #19.
AND snap.QuantityOnHandPrimaryUOM > 0                    -- QUANTITY_ON_HAND > 0
AND LTRIM(RTRIM(snap.CategoryGLF41021)) = 'IN32'         -- FACT-level GL class (§0.1)
AND LTRIM(RTRIM(snap.BusinessUnit)) IN
    ('CINC','CIN2','CIN4','AUBA','AUB2','SING','SNG4')   -- seven plants, incl. CIN4
```

### 4.2 Query 2 — Shipments

```sql
f.QuantityOrderedPrimaryUOM > 0                          -- ORDERED_QTY*SALES_FACTOR > 0  (§2.5)
AND (f.QuantityOrdered - f.QuantityCanceledScrapped) > 0 -- net-of-cancel  (§2.5, REQUIRED)
AND f.PromisedShipmentDate >= DATEADD(DAY, -365, CAST(GETDATE() AS date))   -- NOT `CAST(...) - 365`; §7 #19
AND LTRIM(RTRIM(f.LineType)) = 'S'
AND LTRIM(RTRIM(f.OrderType)) NOT IN ('ST')
AND LTRIM(RTRIM(f.BusinessUnit)) IN
    ('CINC','CIN2','AUBA','AUB2','SING','SNG4')          -- SIX plants — no CIN4 (§4.4)
AND LTRIM(RTRIM(ib.[Category GL F4101])) = 'IN32'        -- ITEM-level GL class (§0.1)
-- India-tax exclusion (§4.5 case 3). NOT a literal port: EDW never stores '-',
-- so `= '-'` would be dead code and the fallback unreachable. Treat NULL,
-- empty and literal '-' alike so the predicate is correct against either warehouse.
AND COALESCE( NULLIF( NULLIF( LTRIM(RTRIM(ISNULL(ib.[Item Global Bulk],''))), '' ), '-' ),
              LTRIM(RTRIM(f.ItemNum2nd)) )
    NOT IN ('IGST','CGST','SGST','CVD','ADD')
```

Measured: this removes **0 rows** and the fallback fires on **0 rows** — the tax items exist in EDW
only at branches `MUM2`/`MUM3`/`HARY`, which the branch filter already excludes (§4.5 case 3, §7
log #9). Keep it regardless.

### 4.3 Query 3 — Items

```sql
LTRIM(RTRIM(ib.[Category GL F4101])) = 'IN32'
AND LTRIM(RTRIM(ib.[Stocking Type])) NOT IN ('O')
AND LTRIM(RTRIM(ib.[Business Unit])) IN
    ('CINC','CIN2','CIN4','AUBA','AUB2','SING','SNG4')
```

### 4.4 The `CIN4` inconsistency — **quantified, and currently inert**

Queries 1 and 3 list seven branch plants; query 2 lists `CINC` **twice** and omits `CIN4`. The
duplicate is harmless inside an `IN` list. The omission is a real inconsistency — but measured
against the mirror, **`CIN4` contributes exactly zero rows to all three queries**:

| Query | CIN4 rows |
|---|---|
| 1 Inventory (`CategoryGLF41021='IN32'`, QOH>0, 2026-08-04) | **0** |
| 2 Shipments (full filter set, 365-day window) | **0** |
| 3 Items (`Category GL F4101='IN32'`, stock type ≠ O) | **0** |

`CIN4` holds no `IN32` item-branches at all. So today the omission changes nothing, on any sheet.
Port the branch lists **exactly as written** (seven / six / seven) and raise it with the requester
as a latent inconsistency rather than a live bug — D-21b.

### 4.5 The `'-'` sentinel — Cognos's missing-value render, NOT stored data

**`-` is not a value. It is how Cognos renders a missing dimension attribute.** (Found by the
report 20 intake agent, independently confirmed by the team lead against the mirror, and confirmed
again here — see §7 log #11. Report 14 §9.1 hit the same thing from the other direction: its xlsx
renders blank `Location` as `-`, and ~530 rows false-mismatched until it was normalized before
joining.) An earlier draft of this spec, and `COLLECTION_NOTES.md`, called `-` "a real value" — it
is not, and the two places that mattered are corrected below.

⚠ **EDW is not uniform about how it stores "missing", and a predicate that tests only one form will
silently miss the other.** Measured on the mirror:

| Column | NULL | empty/whitespace | literal `-` |
|---|---|---|---|
| `TbItemBranch.[Item Bulk]` (`nvarchar`) — whole table | **385** | 0 | 0 |
| `TbItemBranch.[Item Global Bulk]` (`nvarchar`) — whole table | **17** | 0 | 0 |
| `FactInventorySnapshot*.Location` (`nvarchar`) — in scope | 0 | **306** | 0 |
| `FactInventorySnapshot*.LotNum` (`nchar`) — in scope | 0 | **3** | 0 |
| `FactInventorySnapshot*.LotStatusCode` (`nchar`) — in scope | 0 | **1,611** | 0 |
| `DimLot.LotStatusCode` (`nchar`) — in scope | 0 | **1,616** | 0 |

The `nvarchar` item-branch columns use **NULL**; the snapshot fact's columns use **blank/spaces**.
Nothing anywhere stores a literal `-`. So every missing-test in this build must treat
**NULL, empty and whitespace as the same thing**, via
`NULLIF(LTRIM(RTRIM(ISNULL(x,''))),'')`.

Three places in this export show `-`, and they need three different responses.

**1. `Location`, `Lot Number`, `Lot Status` (Inventory sheet) — store NULL, render `-`, in DAX.**
Keep the raw column as-is in the native query (missing stays missing) and add a **DAX display
column** alongside it:

```dax
Location (Display) = COALESCE( TRIM( 'Inventory'[Location] ), "-" )
```

Do **not** bake `-` into the native query, and do **not** do it with a format string. A display
column keeps the real distinction between missing / blank / a literal dash readable in the model,
survives the NULL-vs-empty-string fidelity the mirror preserves (root `CLAUDE.md` §9), and matches
the "no business logic in Power Query" rule. Report 20's spec §5.2 uses the same pattern — follow
it so the two reports stay consistent.

Parity evidence: the export's `Lot Status` distinct set is `-,A,B,E,H,L,P,Q,R,T`; EDW's is
`<blank>,A,B,E,H,L,P,Q,R,T` — an exact 10-for-10 match once missing ↔ `-` is applied.
⚠ Report 18 §14.2 over-counted **3.3×** by writing `LotStatusCode NOT IN ('-')` and thereby
matching nothing. This report does not filter on lot status, so that specific trap does not fire
here — but the same reflex would break the join key in the validation workbook.

**2. `Global Bulk Item` / `Bulk Item` (Items sheet) — NOT the sentinel issue. A real derivation
difference.** It is tempting to fold this into the correction above. **It does not fold**, and the
measurement is unambiguous: in the in-scope Items-Active population (5,282 rows) `[Item Bulk]` and
`[Item Global Bulk]` are **NULL on zero rows, blank on zero rows, dash on zero rows** — every one is
populated with a real item number. The 385 / 17 table-wide NULLs all sit in branches this report
never selects (`DALL`, `SANF`, `CIN3`, `CIN4`, …). So the 382 disagreements are EDW returning a
*genuine value* where Cognos returns *missing*, not a rendering mismatch.

Detail: **382 of 5,286** export rows carry `-` in both columns while EDW carries the derived item
number (export `('CINC','-','-','191245PX','1')` vs EDW `('CINC','191245PX','191245PX','191245PX','1')`).
382 dashes, 382 disagreements — perfect 1:1. **Every one is branch `CINC`**, and every affected
item appears *non-dashed* at another branch. So the Cognos DW's bulk-item attribute is
**branch-specific and genuinely absent for a subset of CINC item-branches**, while EDW's is
item-master-derived and always populated. `[Item Num Global Bulk]`, `[Item Num Bulk]`,
`[GlobalBulkFilter]`, `IGB_XFlag`, `ExperimentalFlag` and `DimItem.ItemGlobalBulk` were all checked
— every one returns the item number. **This cannot be reproduced from EDW.** 7.2% of sheet 3 will
differ; sheets 1 and 2 are unaffected (zero dashes in either). Disclose as D-21c.

**3. The India-tax exclusion — business logic, and the literal port is DEAD CODE.**
`decode(GLOBAL_BULK_ITEM,'-',ITEM_NUMBER_2ND,GLOBAL_BULK_ITEM) not in (…)` falls back to the 2nd
item number *when the global bulk item is missing*. A literal port tests `= '-'`, which **never
matches in EDW**, so the fallback would be unreachable and the exclusion would under-fire on
exactly the rows it was written for. Use the robust form in §4.2, which treats NULL, empty and
literal `-` alike.

> **Inference, flagged as such:** the presence of that `decode` is strong evidence that
> **DW_LEGACY stores `-` literally** — otherwise it would be dead code in Cognos too. So the two
> warehouses appear to differ in how they represent missing: DW_LEGACY stores `-`, EDW stores NULL
> or blank. This is an inference from the SQL, not something measured against DW_LEGACY, which we
> cannot reach. The robust predicate is correct under either reading, which is why it is the one to
> ship.

**Measured impact of the exclusion: it removes ZERO rows** — under the literal port *and* under the
robust predicate, and the fallback fires on 0 rows because `[Item Global Bulk]` is never missing in
the in-scope population. That is a finding, not a pass: the reason is that `IGST`, `CGST`, `SGST`,
`CVD` and `ADD` **do exist in EDW** (one `BIQL.DimItem` row each, and 15,316 sales lines) but only
at the India branches **`MUM2`, `MUM3`, `HARY`** — none of which is in this report's six-branch
list. The branch filter already excludes every row the tax filter was written to catch. Ship the
robust predicate anyway: it costs nothing, it is in the source, and it will fire correctly if an
India branch is ever added to the report. Recorded in §7 log #9.

### 4.6 Order type `S5`

The export contains `S4, S5, SA, SL, SZ`. Report 19 excludes `S5`; **report 21 excludes only `ST`**.
Same fact, deliberately different scope. Do not reuse a query between the two reports.

---

## 5. Power Query structure — and where each rule lands

Per root `CLAUDE.md` §1 and the memory note *"No business logic in Power Query"*: **SQL keeps
projection, mechanical joins and casts; business rules go in DAX calculated columns** so they can
be traced and explained.

### 5.1 What stays in SQL

| Stays in SQL | Why it is mechanical, not business logic |
|---|---|
| The three source `SELECT`s, their joins and `GROUP BY`/`DISTINCT` | Shape of the extract |
| `LTRIM(RTRIM(...))` on every `nchar` key | Storage artifact of `nchar` padding |
| `snap.CalendarDate = DATEADD(DAY, -1, CAST(GETDATE() AS date))`, the 365-day window | Extract-scoping predicate; pushing these to DAX would import the whole 13.3M-row fact |
| Branch-plant `IN` lists, `LineType='S'`, `OrderType NOT IN ('ST')`, `Stocking Type NOT IN ('O')`, `QOH > 0` | Row-scoping predicates on the source; same reason |
| The GL-class predicates (§0.1) | Row-scoping |
| `CAST` of `OrderNum`, `AddressNumShipTo` to text | Type mechanics |
| The `LineNum` → text rendering (§3.4) | Formatting mechanics |

### 5.2 What goes to DAX calculated columns

| Rule | Lands as | Why |
|---|---|---|
| **KG/LB conversion (§2.4)** | `Quantity on Hand KGs`, `Quantity on Hand LBs`, `Ordered Quantity KGs`, `Ordered Quantity LBs` calc columns | This is the report's one real derivation and it encodes a contested constant. It must be visible, traceable and changeable in one place when D-21e resolves. Expose `2.2045992` as a **measure-free constant in a single DAX variable** per column. |
| **Missing → `-` render (§4.5 case 1)** | `Location (Display)`, `Lot Number (Display)`, `Lot Status (Display)` calc columns wrapping the raw column; the raw column stays in the model, hidden | `-` is Cognos's *render* of missing, not stored data. Keeping the raw NULL/blank means the distinction survives (root `CLAUDE.md` §9 — NULL vs empty string is preserved end-to-end and must not be collapsed). Never bake it into the native query or a format string. Bind the Display column in the visual. |
| **Net-of-cancel `> 0` (§2.5)** | ⚠ **exception — stays in SQL** | It is a row-*scoping* predicate: applied in DAX it would import 8.3% more rows and every visual would need a filter. Documented here and in the `.commented.m` so it is still traceable. |
| **India-tax exclusion (§4.2)** | ⚠ **exception — stays in SQL**, and it is **business logic**, not a mechanical filter | Row-scoping, same reason. But unlike the other predicates it encodes a rule (*"identify the item by its global bulk, falling back to the 2nd item number when the global bulk is missing"*) — so it must use the robust missing-test in §4.2, not a literal `= '-'`, and the `.commented.m` must say why. |

The three exceptions are deliberate and belong in the `.commented.m` header, not left for a
reviewer to discover.

> ⚠ **Amended 2026-08-06.** The table above says to expose `2.2045992` as "a measure-free constant
> in a single DAX variable **per column**". Zack asked for **one** named constant in **one** place,
> so the shipped model puts it — and the LB→KG constant §7 #14 shows is also required — in the
> hidden **`Conversion Constants`** calculated table, which the four KG/LB columns read via `MAXX`.
> Nothing else in the model hard-codes a factor. Change the two numbers there and nowhere else.

### 5.3 `.m` shape (one per table, three tables)

```
let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(Source, "
        SET NOCOUNT ON;
        <the single SELECT for this sheet, WITH (NOLOCK) on every source object>
    ", null, [EnableFolding = false])
in
    Data
```

No `#temp` tables are needed — unlike reports 14 and 18, there is no per-item factor table to
materialise, because §2.4 replaces it with a constant. No `OUTER APPLY`, no `ROW_NUMBER` derived
tables (root `CLAUDE.md` §7 — both get inlined and re-evaluated per row; they hung report 14
twice). Sorting lives in the visual, not in `ORDER BY`.

Production `.m` files carry **no comments**; `Inventory.commented.m`, `Shipments.commented.m` and
`Items - Active.commented.m` carry the §2 rationale and the open-question markers, maintained in
parallel (root `CLAUDE.md` §1).

### 5.4 Fan-out and join drops — measured, all clean

| Join | Result |
|---|---|
| `snap.ItemBranchSKey → BIQL.TbItemBranch` | 1:1. 2,072 fact rows → 2,072 grouped rows; no inflation. Paired on **`ItemBranchSKey`**, not `ItemSKey`+`BusinessUnit` — `ItemBranchSKey` is the fact's own surrogate to the branch grain, so it cannot mis-pair, and the Cognos `ITEM` star is item-*branch* grain (it carries `BRANCH_PLANT` and a per-branch `STOCK_TYPE_CODE`). |
| `snap.LotSKey → BIQL.DimLot` | 1:1, **zero NULLs** on 2,072 rows. `LEFT JOIN` anyway, defensively. |
| `f.ItemBranchSKey → BIQL.TbItemBranch` | 1:1 across 25,993 in-window sales lines. |
| `f.ShipToCustomerSKey → dbo.DimCustomer → dbo.DimAddress` | 1:1, **25,993 of 25,993 resolve**. Zero drops. |

Technique per `edw_schema\probe9_mpf_itembranch.sql`: count the base rows, count after each join,
compare. No join in this report inflates or drops.

---

## 6. Design decision — **1:1 port now, modelled rebuild as a follow-on. RECOMMENDED: the 1:1 port.**

Both options are specced. The recommendation is the 1:1 port, and the reason is not conservatism.

### 6.1 Option A — the 1:1 port (RECOMMENDED)

Three independent import tables, three pages, three flat `tableEx` visuals. No relationships. Each
page reproduces its Cognos sheet column-for-column, headers verbatim, sorted
**Global Bulk Item ▸ Bulk Item ▸ 2nd Item Number ▸ Branch Plant** (all ascending, set in the
visual). Plus the house `Last Refreshed` card per page.

- **It is validatable today.** §7 already ties all three sheets against a same-week Cognos export.
  A report-out workbook per the STANDARD layout (`08 - SK Forecast.xlsx` template) can be built
  the moment the first refresh lands.
- **It preserves the user's existing Excel workflow** — they pull three sheets and do the join
  themselves. Nothing they do today breaks.
- Cost: it does not answer the actual business question. It hands over the same three lists.

### 6.2 Option B — the modelled rebuild

One model: `Items - Active` as the dimension (item-branch spine), `Inventory` and `Shipments` as
facts, both related on a synthetic `ItemBranchKey = Branch Plant | 2nd Item Number`. Slow-moving
logic as DAX measures — `Last Shipment Date`, `Days Since Last Shipment`, `Shipped Qty (365d)`,
`Months of Supply = On Hand / (Shipped 365d / 12)`, `Is Slow Moving`.

- **It is what the requester is actually doing by hand**, and it would let them slice by
  branch/family/expiry instead of re-pivoting three sheets every time.
- The lot-expiry column (§2.2) becomes genuinely useful here — expiry-risk-weighted slow movers is
  a question the flat export cannot answer at all.
- **But it is blocked on a definition we do not have.** Nobody has told us what "slow moving" means
  numerically — the threshold, the window, whether it is qty-based or value-based, and whether it
  is evaluated per branch or globally. Building measures against a guessed threshold produces a
  report that looks authoritative and is wrong. That is worse than the flat lists.
- Secondary risk: the relationship key depends on `Global Bulk Item`/`Bulk Item`, which is exactly
  the column where EDW and Cognos disagree on 382 rows (§4.5 case 2). A join on
  `Branch Plant | 2nd Item Number` sidesteps that — **use the 2nd item number, not the bulk item,
  as the relationship key** if Option B is built.

### 6.3 The recommendation

**Ship Option A, and put Option B to the requester with D-21f attached.** The 1:1 port is
validatable now, protects the existing workflow, and is a strict prerequisite for B anyway — the
modelled version needs the same three queries underneath. Once the requester answers "what makes an
item slow-moving", B is an additive second page on the *same* three tables, not a rebuild. Doing A
first costs nothing and de-risks B entirely.

---

## 7. Validation log (numbered, append-only)

Method per root `CLAUDE.md` §9 (local SQL mirror) and §7 (tight capture). **Mirror refreshed
2026-08-05; Cognos export pulled 2026-08-06.** The mirror proves SQL correctness only — never
freshness, never performance.

**#1 — 2026-08-06 — GL class, Items sheet: `[Category GL F4101]` CONFIRMED, `[Category GL F4102]`
REJECTED.** Compared the distinct `(Branch Plant, 2nd Item Number, Stock Type)` triples.
`Category GL F4101` → 5,282 tuples, **5,282 matched, 0 extras, 4 export rows missing**.
`Category GL F4102` → 5,316 tuples, 5,280 matched, **36 extras, 6 missing**. The 36 extras are all
water/utility items (`DIH2O`, `DIH2OF`, `DIH2OH`, `DIH2ORT`, `SH2O`, `SH2OD`, `SH2OF`, `SH2ORT`,
`JUG`, `QUART`, `DMEA45`). The 4 missing under F4101 are item-branches created between the mirror
refresh and the export (`AUBA/MFP1857.E-PL`, `CINC/ME02125-T3\``, `CINC/MP4990R.E`,
`SING/261206PX.S`). **Verdict: F4101. Delta −0.08%, fully explained by one day of staleness.**

**#2 — 2026-08-06 — GL class, Inventory sheet: `snap.CategoryGLF41021` CONFIRMED.** At
`CalendarDate = 2026-08-04`, grouped to the Cognos display grain:

| GL source | Grouped rows | Σ Quantity on Hand |
|---|---|---|
| **`snap.CategoryGLF41021`** | **2,072** | **304,085,037,158.91** |
| `ib.[Category GL F4102]` | 2,071 | 304,085,037,147.91 |
| `ib.[Category GL F4101]` | 2,031 | 7,533,956.12 |
| *export target* | *2,065* | *304,084,957,165.56* |

The fact-level column is decisive: the export's largest single row is `CINC / SH2OF` at
**99,979,021,880.0025**, which EDW reproduces at 99,979,027,909.0025 (one day of movement). F4101
excludes that row entirely and the sheet total collapses by four orders of magnitude. Per branch
(export / F41021): AUB2 27/27, AUBA 452/445, CIN2 865/856, CINC 278/295, SING 183/182, SNG4
260/267, **CIN4 0/0**. **Row delta +7 (+0.34%), QOH delta +79,993 (+0.000026%).**

**#3 — 2026-08-06 — lot dates SOURCEABLE.** `BIQL.DimLot.OnHandDate` and
`BIQL.DimLot.LotExpirationDate` exist, join on `snap.LotSKey`, and are **non-NULL on all 2,072**
in-scope positions. The flagged "biggest column-availability risk" is closed. Fidelity in #5.

**#4 — 2026-08-06 — conversion factors: the DW constant is `2.2045992`, EDW's is `2.20462`.**
Ratio `LBs/KGs` across the export is a single constant on 2,054/2,065 Inventory rows and
17,179/17,259 Shipments rows. Not the physical `2.20462262`, not `PRODDTA.F41003`'s `2.20462`, not
`BIQL.DimItemUOMConversionLBKG.LB`'s `2.204620000`, not `FactSalesDetail.ConversionFactorLB`'s
`2.2046200`. Corroborated in `PRODDTA.F41002`: `UMCONV = 22045992` exists (23 `KG→LB` rows) against
`22046200` on 265,323 — the DW applies the minority value as a global constant. Applying the §2.4
rule to the Inventory sheet: **1,847 of 1,959 comparable rows EXACT**, +22 within 1e-6, +3 within
1e-3, 48 off — and those 48 are precisely the rows whose `Quantity on Hand` also moved. Also
recorded: `BIQL.DimItemUOMConversionLBKG.ConversionFactorSecToPrim` is `decimal(19,4)` and
therefore **structurally incapable** of carrying a 7-decimal JDE factor. Do not use that dim here.

**#5 — 2026-08-06 — Inventory sheet, tight-capture row and value comparison.** EDW at
`CalendarDate = 2026-08-04` (latest date carrying all seven branches — §2.3) vs the export's
`INVENTORY_DATE = 2026-08-05`. Keyed on `(Branch Plant, 2nd Item Number, Location, Lot Number,
Primary UOM)`:

| | count |
|---|---|
| EDW rows | 2,072 |
| Export rows | 2,065 |
| **Matched on key** | **1,959 (94.9%)** |
| EDW-only | 113 |
| Export-only | 106 |

Column parity on the 1,959 matched rows:

| Column | Result |
|---|---|
| Global Bulk Item, Bulk Item, GL Class Code, Master Planning Family, Stock Type Code | **1,959 / 1,959 (100%)** |
| Quantity on Hand | 1,903 exact (97.1%), 4 within 1e-6, 3 within 1e-3, 49 moved |
| Quantity on Hand KGs | 1,847 exact, 22 within 1e-6, 3 within 1e-3, 48 moved |
| Quantity on Hand LBs | 1,865 exact, 4 within 1e-6, 3 within 1e-3, 48 moved |
| Lot Status | 1,948 (99.4%) |
| On Hand Date | 1,818 (92.8%) |
| Lot Expiry Date | 1,710 (87.3%) |

**Explanation of every delta.** The 113/106 key differences and the 49 quantity moves are one
business day of lot churn (positions consumed, received, or re-located between 08-04 and 08-05) —
unavoidable given §2.3's timezone stagger, and expected at lot × location grain. The date columns
are the only structural gap: **137 rows where Cognos shows the JDE zero-date `1900-01-01` and EDW
has a real date**, concentrated in lots created 2026-05 → 2026-08 (73 in July alone); plus 109
expiry values where both are real and differ, 30 of them by exactly ±1 day. Direction is
consistent — EDW is *more* populated and *more* current. This is a Cognos-side lot-dimension gap.

**#6 — 2026-08-06 — Shipments: the four corrections, measured in sequence.** Starting from the
naive port and adding one fix at a time, against 17,259 export rows keyed on
`(Order Company, Order Number, Line Number)`:

| Step | Matched | EDW-only | Export-only |
|---|---|---|---|
| Naive (`QuantityOrdered × SalesFactor`, literal line number) | 17,251 | 1,442 | 8 |
| \+ emulate Cognos's 5-char line truncation (§3.4) | **17,259** | 1,432 | **0** |
| \+ `QuantityOrderedPrimaryUOM` (§2.5.1) | 17,259 | 1,432 | 0 |
| \+ net-of-cancel `> 0` (§2.5.2) | **17,253** | **5** | **6** |

**Final: 17,258 EDW rows vs 17,259 export rows — a delta of 1 row (0.006%).** The 5 EDW-only and 6
export-only rows are one day of order activity. The 1,432 rows the net-of-cancel filter removed
were characterised first: 1,427 of them have `QuantityCanceledScrapped > 0` with
`QuantityOrdered − QuantityCanceledScrapped ≤ 0`, `QuantityShipped = 0`, `ShipmentNum = 0`, no
invoice and no actual ship date — fully-cancelled lines.

**#7 — 2026-08-06 — Shipments column parity, 17,253 matched rows.**

| Column | Result |
|---|---|
| Branch Plant, Global Bulk Item, Bulk Item, 2nd Item Number, Last Status, Next Status, Promised Ship Date, Ordering UOM, Customer Code, Order Type Code | **17,259 / 17,259 (100%)** |
| Customer Name | 17,251 (99.95%) — the 8 misses are letter-casing on one Vietnamese customer |
| Ordered Quantity | **17,253 exact (99.96%)**; the 6 misses are lines Cognos renders as `1e-10` |
| Ordered Quantity KGs (§2.4 rule) | **16,564 exact (96.0%)** + 13 within 1e-6 |
| Ordered Quantity LBs (§2.4 rule) | **16,552 exact** + 25 within 1e-6 |
| *…same two columns using EDW's raw `ConversionFactor*`* | *7,974 / 8,665 exact — 7,912 rows wrong in the 6th decimal* |

The 676 residual conversion failures are **100% `UOMPrimary = 'EA'`** rows — 542 `B1→EA`, 105
`EA→EA`, 16 `KG→EA`, 7 `BX→EA`, 6 `QT→EA`. In 508 of them EDW's factor is exactly **2×** Cognos's.
Recorded as D-21e.

**#8 — 2026-08-06 — the `'-'` sentinel, counted on both sides.** Inventory: 306 blank `Location`,
3 blank `LotNum`, 1,611 blank `LotStatusCode` in EDW ↔ the export's `'-'` values; `Lot Status`
distinct sets match 10-for-10 once missing ↔ `'-'`. Items: **382 of 5,286** export rows carry `'-'`
in `Global Bulk Item` **and** `Bulk Item`; EDW disagrees on **exactly** those 382 rows and no
others; **all 382 are branch `CINC`**, and every affected item appears non-dashed at another
branch. Shipments and Inventory contain **zero** dashes in those two columns. Six alternative EDW
columns checked and rejected (§4.5 case 2). *Superseded in part by #11 — see there for the
NULL-vs-blank breakdown and the corrected reading.*

**#9 — 2026-08-06 — `CIN4` and the India-tax exclusion are both inert, for different reasons.**
`CIN4` returns 0 rows on all three queries (§4.4). The India-tax exclusion removes **0 rows** under
the literal port **and** under the robust predicate, and its fallback fires on **0 rows**. Reason:
`IGST`/`CGST`/`SGST`/`CVD`/`ADD` **do exist in EDW** — one `BIQL.DimItem` row each and 15,316 sales
lines — but only at branches `MUM2` (435 lines), `MUM3` (14,167) and `HARY` (306 lines across the
five items), none of which is in this report's six-branch list. The branch filter already excludes
everything the tax filter targets. *(This corrects an earlier entry which said the items "do not
exist in EDW"; they do, just not in any in-scope branch. The conclusion — inert — is unchanged.)*
Both predicates are ported regardless.

**#10 — 2026-08-06 — fan-out and join drops: all four joins clean.** See §5.4. No join in this
report inflates or drops a row.

**#11 — 2026-08-06 — CORRECTION: `-` is Cognos's missing-value render, not stored data; and EDW is
not uniform about how it stores "missing".** Raised by the team lead off the report 20 intake
agent's finding; re-measured here. Confirmed: nothing in EDW stores a literal `-` anywhere in the
columns this report touches.

| Column | NULL | empty/whitespace | literal `-` | scope |
|---|---|---|---|---|
| `TbItemBranch.[Item Bulk]` | **385** | 0 | 0 | whole table (116,002 rows) |
| `TbItemBranch.[Item Global Bulk]` | **17** | 0 | 0 | whole table |
| `TbItemBranch.[Item Bulk]` / `[Item Global Bulk]` | **0** | **0** | **0** | **in-scope Items-Active population (5,282 rows)** |
| `FactInventorySnapshot*.Location` | 0 | **306** | 0 | in scope (2,072) |
| `FactInventorySnapshot*.LotNum` | 0 | **3** | 0 | in scope |
| `FactInventorySnapshot*.LotStatusCode` | 0 | **1,611** | 0 | in scope |
| `DimLot.LotStatusCode` | 0 | **1,616** | 0 | in scope |

Three consequences, all now reflected in §3.1, §4.2, §4.5 and §5.2:

1. **The `nvarchar` item-branch columns use NULL; the snapshot fact's columns use blank/spaces.**
   Every missing-test must handle NULL, empty *and* whitespace, or it silently misses one form.
2. **The rendering moves to DAX display columns** (`COALESCE(TRIM(col), "-")`), never into the
   native query or a format string, so the raw distinction survives in the model.
3. **The 382-row Items-sheet finding in #8 is NOT this issue and is unchanged.** The in-scope
   population has **zero** NULLs and **zero** blanks in both bulk columns — every row carries a real
   item number. The 385/17 table-wide NULLs all sit in out-of-scope branches (`DALL`, `SANF`,
   `CIN3`, `CIN4`, `LABO`, …). So EDW returning a genuine value where Cognos returns missing is a
   **derivation difference**, not a rendering mismatch, and D-21c stands as written.

Also inferred (not measured — DW_LEGACY is unreachable): the `decode(…,'-',…)` in the Cognos SQL
would be dead code unless DW_LEGACY stores `-` literally, so the two warehouses appear to represent
missing differently. The §4.2 predicate is correct under either reading.

> **TIGHT-CAPTURE house rule.** All three sheets are `sysdate`-relative and move daily: sheet 1 is
> a single-day snapshot, sheet 2 a 365-day rolling window whose lower bound advances every day.
> A PBI refresh on any day ≠ the Cognos run date will legitimately differ. To validate for turn-in,
> **re-run Cognos and refresh PBI on the same day** and compare same-day, with half-up rounding on
> both sides.

---

### Build entries (appended by the BUILD agent, 2026-08-06)

Method unchanged: local SQL mirror (root `CLAUDE.md` §9) against the same
`Intake\Cognos export - tight capture 2026-08-06.xlsx`. Every §7 figure below was **re-measured
from scratch by the build**, not copied from the intake — where a number differs from #1–#11 it is
called out. No refresh has run; nothing here is a claim about live data.

**#12 — 2026-08-06 — BUILT. Option A, the 1:1 port.** Delivered in the report folder:
`Inventory.m`, `Shipments.m`, `Items - Active.m` (production, comment-free) with
`*.commented.m` masters alongside each, and
`PBIP\1 - Inventory - Slow Moving Global Packaged Items.{Report,SemanticModel}` — five tables
(`Inventory` 21 cols, `Shipments` 22, `Items - Active` 5, hidden `Conversion Constants` 2,
`Last Refreshed` 2 + 1 measure), three pages (**Inventory**, **Shipments**, **Items - Active**),
one flat `tableEx` per page plus the house Last Refreshed card, no relationships. Sorted
Global Bulk Item ▸ Bulk Item ▸ 2nd Item Number ▸ Branch Plant ascending in the visual. Column
order, headers and the KGs/LBs ordering follow §3.1/§3.2/§3.3 exactly — including the
`Primary Unit of Measure` header trap on Inventory column 11. Option B was **not** built (§6.3).

**#13 — 2026-08-06 — THE LINE-NUMBER TRUNCATION IS REPRODUCED ON PURPOSE (D-21a decided).**
Zack's instruction of 2026-08-06 is **build for parity**, which resolves §3.4 against the spec's own
recommendation. `[Line Number]` is `LEFT(<rendered line>, 5)` and the query **GROUPs BY the
truncated string**, exactly as Cognos does. Re-measured, full filter set, keyed on
(Order Company, Order Number, Line Number):

| Line-number form | EDW rows | matched | EDW-only | export-only |
|---|---|---|---|---|
| Untruncated (correct, unmerged) | 17,260 | 17,245 | 15 | **14** |
| **Truncated to 5 chars (shipped)** | **17,258** | **17,253** | **5** | **6** |

The 8 export rows that go unmatched without truncation are precisely `10.00` ×4, `11.00`, `12.00`,
`17.00` and one more `10.00` — every one a `substr` collision, confirming §3.4. The 5/6 residual is
one day of order activity, unrelated. Of the shipped 17,258 rows exactly **1** still aggregates more
than one surviving source line (the net-of-cancel filter removes most collision partners before they
can merge); **10** source lines in the current window render a line number longer than 5 characters
and are therefore displayed truncated. Documented as a deliberately-reproduced Cognos defect in
`Shipments.commented.m` (its own top-of-file section) and in the `Shipments[Line Number]` TMDL
column description. **Reversing it is a two-line edit** — drop the `LEFT(..., 5)` wrapper from the
SELECT and the GROUP BY; the commented master carries the exact replacement text.

**#14 — 2026-08-06 — CORRECTION TO §2.4: the LB→KG branch must MULTIPLY by the DW's stored
`0.453597189`, not divide by `2.2045992`.** §2.4's rule reads `KGs = qty / 2.2045992` while §2.4's
own worked example (`336 LB → 152.408655504 KG`) is `336 × 0.453597189`. The distinction is
measurable, because the DW stores a 9-decimal truncation of the reciprocal rather than dividing:

| Sheet | `qty / 2.2045992` | `qty × 0.453597189` |
|---|---|---|
| Inventory (1,897 comparable rows) | 1,108 exact, 749 within 1e-6, 24 fail | **1,860 exact**, 15 within 1e-6, 22 fail |
| Shipments (17,253 matched rows) | 8,657 exact, 7,895 within 1e-6, 676 fail | **16,470 exact**, 82 within 1e-6, 676 fail |

Dividing is off in roughly the 6th decimal — invisible at `#,0` and a guaranteed `EXACT()` failure
in the report-out workbook, the same trap §2.4 flags for EDW's raw `ConversionFactorLB`. Both
constants are therefore stored, **once**, as the two columns of the hidden `Conversion Constants`
calculated table; the four KG/LB calculated columns read them and nothing else hard-codes a factor.
The residual 676 Shipments failures are 100% `UOMPrimary = 'EA'`, reproducing §7 #7 — D-21e stands.

**#15 — 2026-08-06 — the §2.4 ELSE branch on the INVENTORY sheet needed a factor source, and the
spec does not name one.** §2.4's third branch is `KGs = qty * <EDW KG factor>`. On Shipments that is
`FactSalesDetail.ConversionFactorKG`; the inventory snapshot fact carries **no conversion column at
all**, so the build had to choose. Measured first: 42 of the 2,072 in-scope rows have a primary UOM
that is neither KG nor LB (all `EA`), so the branch is live, not theoretical — and the 39 of them in
the matched set are exactly the rows unaccounted for in #5's tally (1,847+22+3+48 = 1,920 of 1,959).
Shipped: `BIQL.DimItemUOMConversionLBKG.KG` for the row where `UOM = UOMPrimary`, i.e. kilograms per
one primary unit. That grain is **unique** — verified, no fan-out, the join leaves the row count at
2,072 exactly and needs no `ROW_NUMBER` or temp table. Coverage on the 38 comparable EA rows:
**10 reproduce the export exactly, 22 disagree, 6 have no dim row at all.** The alternative
derivation `dim.LB × 0.453597189` scores 11/38 — no better, so the literal reading of §2.4 was kept.
This is the same EA-primary divergence as D-21e and is folded into it for probe P2. Note §2.4 says
"do not use that dim here" about the KG→LB **constant**; using its per-item `KG` column as an EA
weight is a different use and there is no other EDW source. Rows with no dim row (e.g. `CIN2 / JUG`,
which Cognos renders as 0) are left **BLANK** rather than forced to 0 — an honest missing value marks
them for the probe, a fabricated 0 would look like an answer. Disclosed, not fixed.

**#16 — 2026-08-06 — D-21d (`Open Indicator`) SETTLED LOCALLY. `SalesTableSource = 1` ⇔ `'Y'`, a
perfect partition.** §3.5 said this could not be settled against the export locally "because the
comparison key never needed it". It could: the export carries `Open Indicator` and the mirror
carries `SalesTableSource` on the same 17,253 matched keys. Cross-tab:

| | `SalesTableSource = 1` | `= 2` |
|---|---|---|
| Open Indicator `Y` | **896** | 0 |
| Open Indicator `N` | 0 | **16,357** |

Zero rows off-diagonal. `StatusCodeNext = '999'` ⇔ `'N'` partitions the identical set. This is also
the structural analog §3.5 favoured (JDE `F4211` = open, `F42119` = history), so evidence and
structure agree. Shipped as a **DAX calculated column** so probe **P1 is now a confirmation rather
than a gate**, and contradicting it is a one-line change. Report 19's `Open Indicator <> 'Y'`
carve-out is **not** copied — report 21 only displays the column (§3.5).

**#17 — 2026-08-06 — build-side verification.** (a) **MCP `ConnectFolder` lint: clean** — the TMDL
folder loads, 5 tables / 1 measure / 0 relationships, column counts as built. (b) **Microsoft's PBIR
validator: `0 error(s), 0 warning(s); result=succeeded`** on the `.Report` folder (for scale, the
Exec Dashboard scores 19/93 and OTIF 70/329). (c) Every visual projection and sort field resolves to
a real model column, no duplicate `nativeQueryRef`, page/visual folder names match their `name`
fields. (d) All files UTF-8 **without BOM**, CRLF, TMDL **tab**-indented; no `///` above a
relationship (there are none). (e) The **exact SQL text extracted from each shipped `.m`** was
executed against the mirror — all three parse and return rows, so the queries are syntactically
sound as shipped, not merely as drafted. (f) All three sheets re-tied independently of the intake:
Items **5,282 matched / 0 extras / 4 export-only** with the 382 bulk-column disagreements all
dashes and all `CINC` (= #1, #8); Inventory **1,959 matched**, Quantity on Hand 1,903 exact, Lot
Status 1,948, On Hand Date 1,818, Lot Expiry 1,710 (= #5 exactly); Shipments **17,253 matched**,
every column 100% except Customer Name 17,251 (the 8 casing misses) (= #6, #7).
⚠ (g) **§4.5's sample DAX `COALESCE(TRIM(col), "-")` does not work** and was not shipped as written.
The columns it targets are stored **blank/whitespace with zero NULLs** (§7 #11's own table), so
`COALESCE` never fires and the dash would never render on any of the 306/3/1,611 rows. The shipped
display columns test **trimmed LENGTH** — `IF(LEN(TRIM(col))=0, "-", TRIM(col))` — which is what
§4.5's prose requires ("treat NULL, empty and whitespace as the same thing"). Same pattern in all
three display columns; if report 20 shipped the literal sample, it has the same latent bug.
⚠ **#16 is SUPERSEDED by #18 — `SalesTableSource` is the wrong answer. Do not read it as current.**

⚠ (h) **Path length: the longest file in this PBIP is 291 characters.** Reports 14 (283) and 18
(273) exceed the 256 limit in root `CLAUDE.md` and open fine, and this PBIP has no `CustomVisuals/`
(the case that trap is really about) — but if Desktop ever opens it as **"Untitled"** with no error,
that is the cause, and `subst X: "…\Michelman"` is the escape hatch.
> ❌ **(h) IS WRONG AND SUPERSEDED BY #21.** 13 files were over the limit and the PBIP would have
> opened as "Untitled". The 14/18 precedent does not transfer — their report folders are 16–20
> characters shorter than this one's. Measuring a silent-failure condition and then arguing it away
> on precedent is the mistake; the fix is in #21 and the file is now at **246 / 0 over**.

**#18 — 2026-08-06 — `Open Indicator` REMAPPED to `StatusCodeNext` by probe P1. #16 is superseded
and its candidate is DISPROVED.** The jumpbox probe answered D-21d and the answer is not the one
§3.5 favoured. Over **all 17,259** export rows:

| Open Indicator | Next Status | Rows |
|---|---|---|
| `N` | `999`, every row | **16,363** |
| `Y` | 540 (516), 530 (129), 560 (109), 535 (48), 580 (39), 525 (25), 550 (21), 570 (9) | **896** |

Zero exceptions in either direction ⇒ `Open Indicator = IF(TRIM(StatusCodeNext) = "999", "N", "Y")`.
**`SalesTableSource` is positively disproved:** the probe's own cross-tab shows **252 lines with
`SalesTableSource = 1` AND `StatusCodeNext = 999`** — rows the status rule calls `N` and the source
rule calls `Y`. All 252 would be misclassified.

*Why #16 got it wrong, recorded so the method improves and not just the answer:* that entry
cross-tabbed the two candidates **only over the 17,253 rows that matched the tight capture**, where
both rules happen to partition perfectly. The 252 counterexamples lie outside the export-matched
set, so the local comparison was structurally incapable of seeing them — a same-key cross-tab can
only falsify a rule on keys it actually has. §3.5's "do not guess" instruction was right and #16
over-read a clean local result as a settled answer. Shipped: a DAX calculated column off the
already-projected `[Next Status]` (business logic belongs in DAX, not Power Query), with the TRIM
that `nchar` requires. **`SalesTableSource` has been removed from the Shipments query entirely** so
it cannot be quietly reinstated, and both the `.commented.m` and the TMDL column description carry
the disproof. §3.5 and D-21d are marked resolved.

**#19 — 2026-08-06 — SPEC DEFECT: `CAST(... AS date) - <int>` is invalid T-SQL. Corrected in four
places.** §4.1 and §4.2 specified the two date predicates as `CAST(GETDATE() AS date) - 1` and
`CAST(GETDATE() AS date) - 365`. The T-SQL `date` type does not support the arithmetic operators —
only `datetime`/`datetime2` do. Reproduced locally against the mirror:

```
SELECT TOP 1 1 FROM BIQL.FactInventorySnapshot_History_Filtered WITH (NOLOCK)
WHERE CalendarDate = CAST(GETDATE() AS date) - 1;
Msg 206, Level 16, State 2 — Operand type clash: date is incompatible with int
```

The same statement with `DATEADD(DAY, -1, CAST(GETDATE() AS date))` returns a row. This would have
failed at the **first refresh**, on two of the three queries. It survived intake because every probe
used a literal date (`'2026-08-04'`) rather than the relative expression, so the shipped form was
never executed. Corrected to the `DATEADD(DAY, -n, CAST(GETDATE() AS date))` style report 19 uses,
in the shipped `.m`, the `.commented.m` masters, and the four spec locations that taught the wrong
pattern (§2.3 prose, §4.1, §4.2, §5.1's SQL-vs-DAX table).

⚠ **Method note, and the real lesson:** the build's original form was
`CAST(DATEADD(DAY, -1, GETDATE()) AS date)` — valid, and it had been smoke-tested — so this defect
never reached the deliverable. That was luck of phrasing, not diligence: the spec's form was copied
into prose and would have been copied into a query by the next person. **Every native query is now
executed against the local mirror before it ships** (root `CLAUDE.md` §9). Row counts differ from
production and that is fine — the check is that it parses and runs, and a type or syntax error
fails identically on the jumpbox. Re-verified after this change: all three queries exit 0 and return
rows (Inventory 914, Shipments 17,258, Items 5,282; the low Inventory count is the mirror's
timezone stagger at `CalendarDate = yesterday`, §2.3, not a logic change).

**#20 — 2026-08-06 — PROBE P5 CLOSED on live EDW. The lot-date disclosure holds and EDW is the more
complete side.** Live, yesterday's snapshot, in-scope population (IN32, seven branches, QOH > 0):

| | |
|---|---|
| In-scope positions | 2,070 |
| Rows with no `DimLot` row | **0** |
| NULL `OnHandDate` / NULL `LotExpirationDate` | **0 / 0** |
| JDE zero-date (`1900-01-01`) on hand / expiry | **3 / 3** |
| `OnHandDate` range | 1900-01-01 → 2026-08-05 |

Three things settled: (1) `LEFT JOIN BIQL.DimLot ON l.LotSKey = snap.LotSKey` **never drops and
never blanks** on live data, so §2.2's column mapping is sound beyond the mirror; (2) the direction
of the gap is confirmed — EDW carries **3** zero-dates against the **137** rows where Cognos shows
`1900-01-01` and EDW has a real date, so this is Cognos-side staleness in the legacy DW's lot
dimension, exactly as §2.2 argued; (3) the 3 genuine zero-dates are real JDE data and pass through
as-is. **No build change.** ⚠ The parity directive does **not** extend to this: do not coerce EDW's
real dates back to `1900-01-01`. Parity covers values and columns, not propagating a known upstream
staleness defect. D-21g remains a disclosure to the requester. Raw output is in `PROBE\`.
Remaining open probe: **P2b** (the ODSPROD half of the EA conversion-factor question, D-21e) —
EA rows only, not blocking.

**#21 — 2026-08-06 — BLOCKER FIXED: 13 files were over the 256-char path limit (worst 291). The
PBIP would have opened as "Untitled".** Root `CLAUDE.md` §7 trap 1: past ~256 characters Desktop
opens **"Untitled" with no error whatsoever**. #17(h) *measured* 291 and reasoned it away on the
precedent that reports 14 (283) and 18 (273) open fine — wrong call. Those two live in folders 16–20
characters shorter than report 21's, so their margin was never evidence about this one, and a
silent-failure mode is exactly the class of defect that precedent must not be used to excuse. Every
local check passes regardless, which is why nothing caught it: the PBIR validator, the MCP load and
the field-resolution sweep are all path-length-blind.

**The budget.** The prefix through `…\PBIP` is **155** characters and is fixed by the repo's
report-folder naming. The two longest tails after the artifact name:

| Tail | Length |
|---|---|
| `.Report\StaticResources\SharedResources\BaseThemes\CY24SU10.json` | **64** |
| `.Report\definition\pages\<page id>\visuals\<visual id>\visual.json` — 20-char ids | 86 |
| …the same with 4-char ids | 54 |

Two changes, both needed:

1. **Page and visual ids shortened from 20 characters to 4** — `21a1010000000000e001` → `21p1`,
   `21b1010000000000f0c1` → `21c1`, etc. They only have to be unique and referenced consistently.
   This frees 32 characters on the pages path.
2. **Artifact renamed** `1 - Inventory - Slow Moving Global Packaged Items` (49) →
   **`Slow Moving Packaged Items`** (26). The full Cognos report name does not fit under **any** id
   scheme — even with 4-char ids it lands at 259. The `.pbip`, both artifact folders,
   `definition.pbir`'s `byPath` and both `.platform` `displayName`s were updated together; the
   **page names on the three tabs are unchanged**, so nothing the requester sees moves.

⚠ **Once the ids were shortened the binding constraint moved to the THEME file, not the pages
path** — at a 30-character name the worst path was still 250 (6 chars of headroom) and it was
`BaseThemes\CY24SU10.json`, not a `visual.json`. Anyone re-deriving this budget from the pages path
alone will get the wrong answer. The governing inequality is
**155 + 1 + len(name) + 64 ≤ 256 ⇒ name ≤ 36**, and **≤ 26 to keep 10 characters of headroom.**
The arithmetic is recorded in the generator beside the `NAME` constant so it travels with the code.

**Verified:**

```
Len FullName
--- --------
246 …\21 - 1 - Inventory - Slow Moving Global Packaged Items\PBIP\Slow Moving Packaged
    Items.Report\StaticResources\SharedResources\BaseThemes\CY24SU10.json
240 …\PBIP\Slow Moving Packaged Items.SemanticModel\definition\tables\Conversion Constants.tmdl
236 …\PBIP\Slow Moving Packaged Items.Report\definition\pages\21p1\visuals\21t1\visual.json

over256 = 0
maxLen  = 246          (10 characters of headroom)
```

Re-verified after the rename, all clean: PBIR validator **0 errors / 0 warnings**; MCP
`ConnectFolder` loads 5 tables / 1 measure / 0 relationships; `.pbip` → `.Report` →
`.SemanticModel` cross-references and both `.platform` displayNames consistent; every page/visual
folder name equals its own `name` field and every `pages.json` entry resolves; all visual
projections and sort fields resolve, no duplicate `nativeQueryRef`; no BOM, TMDL tab-indented, all
JSON parses; **zero stale references** to the old artifact name or the old ids anywhere in the PBIP.
The M embedded in each TMDL partition was diffed against the shipped `.m` — all three **match
exactly** — and all three queries re-smoke-tested against the mirror (Inventory 914, Shipments
17,258, Items 5,282; exit 0, no SQL errors).

⚠ **If this PBIP is ever renamed, or moved into a deeper folder, re-run the check in the verified
block above before shipping.** It is the one defect class in this build that fails silently.

---

**#22 — 2026-08-07 — POST-REFRESH VALIDATION ON THE LIVE MODEL. THREE FINDINGS; ONE IS A DEFECT
THIS BUILD SHIPPED WITH: the `Ordered Quantity LBs/KGs` fallback branch is 32.79% accurate, and
report 19 has already proven the fix. ⬜ NEEDS A SECOND REFRESH.**

First validation of this build that is **not** a mirror simulation. Zack refreshed on the jumpbox
and saved 2026-08-07 00:21; `<...>\21\PBIP\Slow Moving Packaged Items.SemanticModel\.pbi\cache.abf`
was mounted per root `CLAUDE.md` §9 and all three tables exported in full and compared column by
column against `Intake\Cognos export - tight capture 2026-08-06.xlsx`.

Loads: **Inventory 2,062 · Shipments 17,268 · Items - Active 5,284** against the export's
2,065 / 17,259 / 5,286 — all within a day of churn, as #12–#21 predicted.

Because the export is a day older, every figure below is measured on **stable rows only** — rows
whose own inputs (quantity, UOM, dates, statuses) are byte-identical on both sides. That separates
staleness from logic, and it is the only way to read a weight column honestly across a date gap.

---

**(a) DEFECT — the `Ordered Quantity LBs/KGs` ELSE branch. 654 of 16,889 stable lines (3.87%) wrong.**

The §2.4 rule is a three-way `SWITCH` on primary UOM. Attributing every error to its branch:

| `SWITCH` branch | lines | wrong | accuracy |
|---|---|---|---|
| `UOM = "LB"` → quantity as-is | 8,408 | **0** | **100.00%** |
| `UOM = "KG"` → quantity × `[KG to LB]` | 7,508 | **0** | **100.00%** |
| **ELSE → quantity × `[KG Factor]` × `[KG to LB]`** (primary UOM `EA`) | 973 | **654** | **32.79%** |

Every error is in one branch, and the two direct branches are perfect across 15,916 lines. The
error distribution names the cause outright — **504 rows at a ratio of exactly 2.0**, plus 60×,
1/22, 1.6787 and 0.9072 clusters:

```
DP680-B1     B1   cognos    88.0000   ours    176.0000
DP680-B1     B1   cognos 1,056.0000   ours  2,112.0000
DP680.S-B1   B1   cognos   440.9198   ours    881.8397
```

**This is report 19's defect, in the same item family, and it was diagnosed and fixed there hours
before this refresh ran.** Report 19 V38/V40: `dbo.FactSalesDetail.ConversionFactorLB/KG` is
exactly 2× the correct value for the `B1` family (`DP680-B1` was V38's worked example, order
2585134), and EDW ships the correction as `Unit_Weight_Adj` / `UOM_Weight_Adj` — columns that exist
**only on the `BIQL.FactSalesDetail` view**, which is why the mirror cannot see them and why §7's
17,258/17,259 tie-out could not catch this. `[KG Factor]` here is `MIN(f.ConversionFactorKG)` off
`dbo`, so this build inherited the bad column wholesale.

**The fix — scoped to the ELSE branch only; do not touch the LB and KG branches, which are exact.**

```sql
-- Shipments.m:  FROM dbo.FactSalesDetail f   ->   FROM BIQL.FactSalesDetail f
--               + two aggregates alongside [KG Factor] (SUM: the GROUP BY collapses
--                 source rows to line grain, and Unit_Weight_Adj is a LINE TOTAL):
    SUM(f.Unit_Weight_Adj)                  AS [Line Weight Adj],
    LTRIM(RTRIM(MIN(f.UOM_Weight_Adj)))     AS [Line Weight Adj UOM],
```

```dax
-- Shipments.tmdl, ELSE branch only:
--   was:  Qty * 'Shipments'[KG Factor] * KGtoLB
--   now:  IF ( 'Shipments'[Line Weight Adj UOM] = "LB",
--              'Shipments'[Line Weight Adj],
--              'Shipments'[Line Weight Adj] * KGtoLB )
-- and the KGs mirror, dividing rather than multiplying.
```

⚠ **`Unit_Weight_Adj` is a LINE TOTAL, not a per-unit weight — there is no multiplication by
quantity.** Report 19 V40 established this empirically over 5,675 export groups; do not re-derive it.
Note the branch already reaches `[KG Factor]`, so the two new columns **replace** it rather than
joining it — leave `[KG Factor]` in the query, it still feeds the Inventory sheet's own ELSE branch.

Expected outcome, extrapolating report 19's measured result (V42: 2,350 rows fixed, 23 sub-rounding
regressions, 34 residual): the ELSE branch should go from 32.79% to roughly 90–95% and the sheet
from 96.13% to ~99.4%. **Not a prediction this build can verify** — `BIQL.FactSalesDetail` is not
in the mirror, so like report 19's `Shipments.m` this change is only measurable after a refresh.

**Inventory has a milder form of the same thing:** on 1,977 stable rows `Quantity on Hand LBs` is
98.63% exact, and **all 22 misses are primary-UOM `EA`** — the same ELSE branch, the same cause.
Ratios 44.09, 26.46, 0.11, 0.0507. Fixing Shipments without Inventory would leave the two sheets
inconsistent with each other; the Inventory query needs the same treatment, and its ELSE branch is
already isolated the same way (#15).

---

**(b) DISCLOSE — `Items - Active` Bulk Item: 382 rows (7.2%) where the legacy DW is NULL and EDW is
populated. All 382 are branch `CINC`. Ours is the better data.**

Cognos renders `-` for both `Global Bulk Item` and `Bulk Item`; we render the real value, and on
**381 of 382** that value is exactly the `2nd Item Number` with its packaging suffix stripped —
which is the definition of a bulk item, so the values are self-evidently right. 100% concentrated in
one branch is the signature of a legacy-DW load gap, not a logic difference on our side.

Note **the other two sheets are 100.00% on both columns.** Only the item master diverges — i.e.
these 382 are items with no inventory position and no shipment in the window, which is precisely the
dormant population this report exists to surface. That makes the gap worth raising with the
requester rather than filing as cosmetic: **it changes which items group together on a report about
slow movers.** Folds into **D-21g**, same direction as the lot-date finding.

---

**(c) DISCLOSE — `Lot Expiry Date`: 117 rows (5.8%) where both sides hold a real, different date.**

`On Hand Date` is clean: 92.35% match, and of the 154 differences **151 are the known
Cognos-zero-date-vs-EDW-real direction** (#20 / P5) with only **3** genuine disagreements.
`Lot Expiry Date` carries the same 151 — plus **117 where both sides have a real date and they
differ**, mostly by months and mostly with EDW **later**:

```
ML160PF-KD    lot 4564694   cognos 2026-07-09   ours 2026-12-29
MC55V2        lot 4559102   cognos 2026-04-23   ours 2026-10-01
ML723HSP.E    lot 4573472   cognos 2026-07-06   ours 2026-10-22
```

Later-in-EDW is consistent with **lots being re-tested and re-dated**, EDW tracking the current
expiry while DW_LEGACY keeps the original. A minority run the other way, so this is a hypothesis,
not a finding. It matters because expiry is plausibly load-bearing for a slow-moving decision —
**ask the requester which date they mean** before treating either as authoritative. Extends D-21g,
which as written covers only the zero-date direction.

`Lot Status` differs on **5 of 2,013** rows (hold/test flags moving between capture and refresh) —
noise, no action.

---

**PBIP integrity after the jumpbox round trip:** 0 BOM, 0 space-indented TMDL lines,
`definition.pbir` **4.0**, and the jumpbox bumped no schema (`visualContainer 2.1.0`, `page 2.0.0`,
`report 2.1.0`, `pagesMetadata 1.0.0`). Path lengths unchanged from #21. ✅

**Status: (a) is a code change awaiting the open/closed interlock (root `CLAUDE.md` §1) and then a
second refresh. (b) and (c) are disclosures for the requester, no code change.** ⬜ OPEN

---

**#23 — 2026-08-10 — SECOND REFRESH VALIDATED. Data-only: the #22(a) fix is NOT in this build**
(the shipped `Shipments.tmdl` still reads `dbo.FactSalesDetail` — verified before mounting).
Cache saved 2026-08-10 15:31, copied into the repo directly (OneDrive transfer abandoned as slower),
mounted locally and compared against the 2026-08-06 tight capture — a 4-day-apart **intersection
test on shared keys**, not a row-count tie.

Rows: Inventory **2,088** (export 2,065) · Shipments **17,262** (17,259) · Items **5,285** (5,286).

- **Items — clean.** 5,284/5,286 keys matched, **0** stock-type mismatches, **0** bulk-column
  mismatches beyond the D-21c dash rows, which count **exactly 382** again. Of #1's four
  staleness-missing item-branches, two now exist; `CINC/ME02125-T3\`` and `CINC/MP4990R.E` are
  still absent from live EDW four days on — no longer explainable as mirror staleness, worth an
  eye at the next capture. One new model-only row (`AUBA/DPV9050.E`), consistent with item churn.
- **Shipments — every stable non-EA line is exact.** 17,091 shared order-line keys; of 168
  export-only rows **157** are the 365-day window moving past their `Promised Ship Date`; 171
  model-only are new orders. Control column `Ordered Quantity` exact on **17,037/17,091 (99.68%)**;
  the 54 misses are genuine quantity edits over the four days, and they account **1:1** for the
  31 + 23 = **54** LB/KG-primary weight misses — i.e. the LB and KG branches are **100.00% correct
  on every line whose quantity did not move**. `Open Indicator` differs on 141 (lines closing to
  `999` since capture — drift, not logic).
- **EA-primary — the #22(a) defect, unchanged as expected.** 668–669 of 999 EA lines wrong on the
  weight columns; same 2× / per-item-factor signature. Inventory's milder form likewise: of 1,775
  stable-QOH positions, conversion exact on 1,751, and 19 of the 24 misses are EA-primary.
- **Inventory churn:** 1,880/2,065 keys matched, 105 stable-key QOH moves — in line with the ~5%/day
  lot churn #5 measured.

**Verdict: refresh #2 is healthy; the only wrong numbers in the model are the ones #22(a) already
names, and the fix remains the single code change pending.** Comparison script:
scratchpad `r21_compare.py` (session-local, not filed — rerunnable against any future capture).

---

## 8. Probe plan (run once on the jumpbox before first refresh)

Most of the usual probe surface is already closed by §7 — these are the residuals that genuinely
need live data or a fresh Cognos run. Package as a probe PBIP (report 12/17 template).

1. **P1 — `Open Indicator` (GATE for column 10).** Pull a fresh Cognos Shipments extract and, for
   the same `(Order Company, Order Number, Line Number)` keys, dump `SalesTableSource`,
   `StatusCodeNext`, `QuantityOpen`, `QuantityShipped` from EDW. Cross-tab against the export's
   `Y`/`N`. This is the one column with no local answer (§3.5).
2. **P2 — EA-primary conversion factors (D-21e).** For the 676 `UOMPrimary='EA'` rows, dump
   `ConversionFactorLB`, `ConversionFactorKG`, `UOMTransaction`, `QuantityOrdered`,
   `QuantityOrderedPrimaryUOM` alongside `PRODDTA.F41002.UMCONV/1e7` for the same item/branch/UOM
   pairs, and compare all three against the export. Determine whether F41002 reproduces Cognos
   where EDW's fact column does not.
3. **P3 — the `2.2045992` constant on live data.** Confirm the constant still holds on a
   same-day Cognos run (it is a DW-load constant, so it should — but it is now load-bearing in
   four columns and deserves one live check).
4. **P4 — freshness/count parity.** Reproduce all three sheets on the refresh day and compare to a
   same-day Cognos export. Expect the §7 deltas to shrink to near zero; anything that does not
   is a logic issue, not staleness.
5. **P5 — lot-date gap (D-21g).** Quantify how many in-scope lots Cognos still shows as
   `1900-01-01` on live data, and confirm the direction (EDW more populated) holds.
6. **P6 — format spot-checks.** Dates render `d MMM, yyyy` day-first; the three quantity columns
   render `#,0`; `Primary Unit of Measure` is the header on column 11 of sheet 1; blank
   `Location`/`Lot Number`/`Lot Status` render `'-'`.

---

## 9. Open questions for the requester

- **D-21a — the merged line numbers (needs a decision before turn-in).** Cognos truncates the line
  number to 5 characters and merges lines that collide — measured, **8 export rows** are merges of
  2–4 real order lines with summed quantities (§3.4). Our rebuild can show the real lines. *Ask:
  do you want the corrected (unmerged) detail, or byte-parity with the current report?*
  **Recommend: corrected**, with the 8 rows called out in the report-out workbook.
  ✅ **DECIDED 2026-08-06 (Zack): parity.** The truncation is reproduced. Still worth putting to the
  requester, since it is their data that is being merged — §7 #13.
- **D-21b — `CIN4` on the Shipments query.** Queries 1 and 3 include it, query 2 omits it (and
  lists `CINC` twice). Measured **inert today** — `CIN4` holds no `IN32` items at all (§4.4).
  *Ask: intentional, or a typo to fix before it starts mattering?* **Recommend: fix it**, since
  correcting it costs nothing today and prevents a silent gap the day `CIN4` gets `IN32` stock.
- **D-21c — the `'-'` bulk items on sheet 3 (cannot be reproduced from EDW).** 382 of 5,286 rows
  (7.2%), all `CINC`, where Cognos shows *missing* and EDW shows a real derived item number
  (§4.5 case 2). **Checked and ruled out:** this is *not* the `-`-renders-missing issue that
  affects the Inventory sheet — the in-scope item-branch population has **zero NULLs and zero
  blanks** in both bulk columns (§7 log #11), so EDW genuinely holds a value where Cognos holds
  none. Six alternative EDW columns were tried and all return the item number. *Ask: is the blank
  meaningful to you (i.e. "this CINC item-branch has no bulk parent"), or is the item number
  acceptable — arguably better — there?* This is the only column in the whole report we cannot
  match, and it is a source-derivation difference, not a bug on either side.
- **D-21d — `Open Indicator` mapping.** No EDW column of that name; three candidates measured, none
  conclusive without a fresh Cognos run (§3.5). Gated on probe P1. **Do not guess.**
  ✅ **CLOSED 2026-08-06 by probe P1 — the answer is `StatusCodeNext`, NOT `SalesTableSource`.**
  `IF(TRIM(StatusCodeNext) = "999", "N", "Y")` partitions all 17,259 export rows exactly
  (16,363 / 896, zero exceptions). `SalesTableSource` is **disproved** by 252 counterexample lines
  and has been removed from the query. Shipped as a DAX calculated column. §7 **#18**.
  ⚠ An earlier build entry (#16) claimed `SalesTableSource` was the answer — it is **superseded**;
  do not read #16 as current.
- **D-21e — EA-primary weight conversions.** 676 of 17,253 Shipments rows (3.9%) where EDW's
  `ConversionFactorKG` is typically exactly 2× the Cognos one, all `UOMPrimary = 'EA'` (§7 #7).
  Affects only the KGs/LBs columns, never `Ordered Quantity`. Gated on probe P2. *Also worth a
  question to Dave: which system is right about the weight of an `EA` for these items?*
- **D-21f — 1:1 port or modelled rebuild (§6).** *Ask both halves:* (a) do you want the three flat
  sheets, or one model with the slow-moving logic built in; and (b) **what defines "slow moving"
  numerically** — the threshold, the window, qty-vs-value, per-branch or global. (b) is the
  blocker: the modelled version cannot be built honestly without it.
- **D-21g — the lot-date gap.** 137 in-scope lots where Cognos shows the JDE zero-date and EDW has
  a real date, concentrated in recently-created lots (§2.2, §7 #5). Our numbers are more complete.
  *Ask: are `On Hand Date` and `Lot Expiry Date` load-bearing for your slow-moving decision?* If
  yes, the improvement is worth flagging to them explicitly rather than letting it look like a
  discrepancy.
- **D-21h — SSAS routing.** The `Supply and Demand` perspective reading is off the **stale**
  `BIQLTabular` dump and must be re-checked against `BIQLTabular_v2` on the jumpbox before anyone
  cites it (§1). Independently, a live connection would forbid §2.4 and §2.5, so **EDW is the
  route** regardless of how that check comes out.
- **D-21i — tracker row.** Report ID / owner / prior owner still TBD from the migration workbook.
