# Report 13 - "1 - Ivan LIVE Global Inventory Excel" - Build Spec

Cognos path: `Public Folders > Michelman Reporting > Production and Shipping > Cogan Excel AD HOC Reports > 1 - Ivan LIVE Global Inventory Excel`
Tracker outline: `1.27.27.1`. Cognos model: **"JDE Live Data"** (live Oracle JDE).

This is an Ivan-style Excel ad-hoc export, same family as delivered reports 07-10. Six pages,
each a single flat list (Cognos `tableEx`), one backing query per page. No prompts, no parameters,
no conditional formatting on cell values (only header font colours). It is a **LIVE** report: every
filter is relative to `sysdate` (no hard-coded date ceiling), so it never decays to zero rows the way
the forecast twins 08/10 do.

---

## 1. Source route: ODS (ODSPROD / "ODS" / PRODDTA), native T-SQL import

**Chosen: ODS**, exactly like siblings 07/09/10/01. Rationale, evaluated in the mandated order:

- **SSAS (`BIQLTabular_v2`, Live Connection) - REJECTED.** Pages 1 ("Inventory OH") and 6
  ("OH and Expiry") are at F41021 **Item Location File** lot/location grain, and the prior cube
  survey found **F41021 is in NO perspective of `BIQLTabular_v2`**. The report also needs the
  F30026 cost-component pivot (A1/B1/C1/C2) and F4108 lot-master expiry, which the cube does not
  model at this grain either. Live Connection allows no local tables, so SSAS must cover **all six**
  query objects to qualify; it fails at the first. Reject.
- **EDW (SQL Server) - REJECTED.** EDW does carry inventory objects (`dbo.DimItemLocationFile`,
  `FactInventoryDetail`, `FactInventorySnapshot`, `FactInventoryAsOf*`), but these are ETL'd
  snapshot / as-of facts at a modelled grain that does **not** reproduce the Cognos lot + location +
  status + cost-component + lot-expiry rows 1:1. Matching the captured xlsx would mean re-deriving
  the exact JDE joins on top of the EDW facts anyway. The PO/Sales/WO/WO-Parts pages need
  open-transaction grain from F4311/F4211/F4801/F3111, the same sources the delivered Ivan siblings
  all took from ODS. Given the parity-now mandate and the proven pattern, EDW adds risk without
  removing work. Reject.
- **ODS (PRODDTA on ODSPROD) - CHOSEN.** The Cognos generated SQL is a clean 1:1 port target over
  JDE base tables; report 07's `Inventory.m` already runs the identical F4102/F4101/F554101/F41021
  join on `Sql.Database("ODSPROD","ODS")` and validated clean. All 13 source tables confirmed present
  (see `00_verify_tables.sql`). Import mode, native query, `[EnableFolding = true]`.

Connection string in every `.m`: `Sql.Database("ODSPROD", "ODS")`.

---

## 2. Query objects and files

Ten Cognos query objects; five are intermediate (Inventory, Purchase Orders, Item, Quality, Sales)
and are inlined as derived tables inside the five rendered summary queries. The **Inv Summary** query
is rendered TWICE (different column projections), giving six generated-SQL files / six page tables:

| Page (tab) | Cognos list | Backing query | Generated SQL | `.m` file | xlsx rows |
|---|---|---|---|---|---|
| Inventory OH | List1 | Inv Summary (full) | `Inv Summary.0.sql` | `Inv_Summary.m` | **7,257** |
| PO | List3 | PO Summary | `PO Summary.1.sql` | `PO_Summary.m` | **7,098** |
| Sales | List2 | Sales Summary | `Sales Summary.2.sql` | `Sales_Summary.m` | **1,034** |
| Work Order | List4 | Work Orders | `Work Orders.3.sql` | `Work_Orders.m` | **460** |
| WO Parts List | List5 | WO Parts List | `WO Parts List.4.sql` | `WO_Parts_List.m` | **1,676** |
| OH and Expiry | List6 | Inv Summary (subset) | `Inv Summary.5.sql` | `Inv_Summary_OH_Expiry.m` | **6,868** |

Each production `.m` is comment-free; a `*.commented.m` master alongside carries the full porting
rationale. Row counts are the captured-xlsx targets; live counts drift because the date floors roll.

**Why "OH and Expiry" is its own table, not a subset visual of "Inventory OH":** List1 aggregates to
the lot+location+status+UOM grain (7,257), List6 is `SELECT DISTINCT` on only 10 identity columns
(6,868 - multiple locations/statuses of a lot collapse). The counts differ, so page 6 needs its own
DISTINCT projection. Keep the two tables separate.

---

## 3. PBIR authoring requirements (MUST)

Author the PBIP in **PBIR format** (like reports 02/03), not the legacy single-`report.json`.

- **Header labels = displayName renames.** Cognos renders each column header as the raw data-item
  name. Reproduce every header **verbatim**, including the join-duplicate suffixes: page 1 has
  `Lot Number` AND `Lot Number1`; page 2 has `Branch Plant1` and `2nd Item Number1`; page 6 has
  `Lot Number` AND `Lot Number1`. Do **not** clean these up - the trailing "1" is the parity target.
  In PBIR set the visual column `displayName`; a `nativeQueryRef` alone does not rename.
- **`summarizeBy: none`** on every numeric IDENTIFIER column so a table/matrix never sums them:
  `Purchase Order Number`, `Vendor Code`, `Primary Supplier` (PO); `Order Number`, `Customer Code`
  (Sales); `WO Number` (Work Order, WO Parts). The real measures (`Quantity On Hand`, costs, all the
  quantities) keep default `sum`.
- **No duplicate `nativeQueryRef` inside one visual.** The join-dup columns are distinct fields
  (`[Lot Number]` vs `[Lot Number1]`), so they carry distinct refs - fine. Just do not point two
  visual columns at the same field.
- **No value-level conditional formatting exists** in this report, so the dataViewWildcard
  values-CF-selector trap does not apply. Header font colours only (see 5).
- Add the standard **"last refreshed" card** to every page (house convention on the Ivan reports).

---

## 4. Per-page column spec

Columns are listed in **exact rendered (left-to-right) order**. "Fmt" is the Power BI VBA-style
`formatString`; blank = default/general. Dates: every date column is Cognos `dateStyle="medium"
displayOrder="DMY"` -> **`d MMM, yyyy`** (day-first, abbreviated month, literal comma), matching the
sibling 07-10 decision. Align: text left, numeric right.

### Page 1 - "Inventory OH"  (table = `Inv_Summary`, sort + 7,257 rows)

Order: Branch Plant | Global Bulk Item | Bulk Item | 2nd Item Number | Commodity Class | Sub Class |
Master Planning Family | Safety Stock | Shelf Life | Stock Type | GL Category | Leadtime Level |
Leadtime MFG | Location | Lot Number | Status | Quantity On Hand | Primary UOM | Hard Commit |
A1 Cost | B1 Cost | C1 Cost | C2 Cost | Lot Number1 | Supplier Lot Number | On Hand Date |
Expiration Date Month | TIME

- Fmt `#,0`: Quantity On Hand, Hard Commit.  Fmt `$#,0`: A1 Cost, B1 Cost, C1 Cost, C2 Cost.
- Safety Stock / Shelf Life / Leadtime Level / Leadtime MFG: default number, right-aligned (values
  carry decimals, e.g. 31.8 - do not force 0 decimals).
- Dates `d MMM, yyyy`: On Hand Date, Expiration Date Month. TIME: leave general (it is `sysdate`).
- **Sort** (visual): Global Bulk Item, Bulk Item, 2nd Item Number, Branch Plant (all ascending).

### Page 2 - "PO"  (table = `PO_Summary`, NO Cognos sort, 7,098 rows)

Order: Company | Branch Plant | 2nd Item Number | Purchase Order Number | Reference 2 |
Reporting Code 3 | Open Quantity | Primary Quantity | Primary UOM | Secondary Quantity |
Secondary UOM | Last Status | Next Status | Requested Date | Promised Date | Vendor Code |
Vendor Name | Freeze Code Flag | Branch Plant1 | Global Bulk Item | Bulk Item | 2nd Item Number1 |
Commodity Class | Sub Class | Master Planning Family | GL Category | Primary Supplier | Safety Stock |
Leadtime Level

- Fmt `#,0`: Open Quantity, Primary Quantity, Secondary Quantity.
- Dates `d MMM, yyyy`: Requested Date, Promised Date.
- Identifiers `summarizeBy:none`: Purchase Order Number, Vendor Code, Primary Supplier.
- Freeze Code Flag: text; blank/null renders as `-` (the query already coalesces).
- **Sort**: the Cognos "PO" list has **no `<sortList>`** - leave unsorted (or a neutral key); do not invent one.

### Page 3 - "Sales"  (table = `Sales_Summary`, sort + 1,034 rows)

Order: Order Company | Branch Plant | Global Bulk Item | Bulk Item | 2nd Item Number | Order Number |
Order Line | Customer PO | Lot Number | Hold Orders Code | Last Status | Next Status |
Primary Quantity Ordered | Primary UOM | Secondary Quantity Ordered | Secondary UOM | Order Date |
Promised Ship Date | Scheduled Pick Date | Customer Code | Customer Name | Order Type

- Fmt `#,0`: Primary Quantity Ordered, Secondary Quantity Ordered.
- Dates `d MMM, yyyy`: Order Date, Promised Ship Date, Scheduled Pick Date. (Promised Ship Date and
  Scheduled Pick Date are intentionally the SAME value - Cognos sources both from SDPDDJ.)
- Identifiers `summarizeBy:none`: Order Number, Customer Code. Order Line is a decimal (SDLNID/1000).
- **Sort** (visual): Global Bulk Item, Bulk Item, 2nd Item Number, Promised Ship Date (ascending).
  (Cognos sorts on the hidden `2nd Item Number1`, which equals the visible `2nd Item Number` because
  the join forces them equal - sort on the visible one.)

### Page 4 - "Work Order"  (table = `Work_Orders`, sort + 460 rows)

Order: Branch Plant | Global Bulk Item | Bulk Item | 2nd Item Number | WO Number | WO Status |
Order Date | Start Date | Completed Date | Quantity Requested | Quantity Completed | Unit of Measure

- Fmt `#,0`: Quantity Requested, Quantity Completed.
- Dates `d MMM, yyyy`: Order Date, Start Date, Completed Date.
- `summarizeBy:none`: WO Number.
- **Sort** (visual): Global Bulk Item, Bulk Item, 2nd Item Number, Start Date (ascending).

### Page 5 - "WO Parts List"  (table = `WO_Parts_List`, sort + 1,676 rows)

Order: Branch Plant | Global Bulk Item | Bulk Item | 2nd Item Number | WO Number | WO Status |
Order Date | Start Date | Completed Date | Quantity Requested | Quantity Completed | Unit of Measure |
Component Branch | Component 2nd Item Number | Ordered Quantity | Issued Quantity | Component UOM |
Requested Date

- Fmt `#,0`: Quantity Requested, Quantity Completed, Ordered Quantity, Issued Quantity.
- Dates `d MMM, yyyy`: Order Date, Start Date, Completed Date, Requested Date.
- `summarizeBy:none`: WO Number.
- Quantity Requested / Completed are WO-header averages spread across the parts rows (see the
  `.commented.m`); they repeat per component row - that is correct/faithful.
- **Sort** (visual): Global Bulk Item, Bulk Item, 2nd Item Number, Start Date (ascending).

### Page 6 - "OH and Expiry"  (table = `Inv_Summary_OH_Expiry`, sort + 6,868 rows)

Order: Branch Plant | Global Bulk Item | Bulk Item | 2nd Item Number | Lot Number | Lot Number1 |
Supplier Lot Number | On Hand Date | Expiration Date Month | TIME

- Dates `d MMM, yyyy`: On Hand Date, Expiration Date Month. TIME: general.
- **Sort** (visual): Global Bulk Item, Bulk Item, 2nd Item Number, Branch Plant, Lot Number (asc).

---

## 5. Cosmetics (low priority, cell-value parity is what matters)

- Every list cell has a `1pt solid black` border (Cognos grid look). Optional in PBI - a thin
  gridline style is close enough; do not spend time chasing exact borders.
- **Header font colours** (Cognos `listColumnTitle` CSS), cosmetic: on each page the primary/left
  columns are bold **red**, the joined item / lot-master columns bold **blue**, and `TIME` bold
  **green** (pages 1 and 6). Reproduce only if cheap in the theme; skip otherwise.
- Column titles are bold. Numeric columns are right-aligned, text left-aligned.

---

## 6. Porting flags (all handled in the `.m`; called out for the reviewer)

- **No expired date ceiling.** Every filter is `sysdate`-relative (PO Promised >= today-365; WO Start
  >= today-30; TIME = today). Nothing to unblock - contrast the 08/10 `DATE '2026-06-30'` defect.
- **No F42119 union needed.** The Sales query is OPEN orders only (`Next Status NOT IN ('620','999')`,
  qty > 0). F42119 holds the purged closed/999 lines this query deliberately excludes.
- **No `F0005` UDC decodes, no `PRODCTL` 3-part names** - none of the six queries touch F0005.
- **Scaling (JDE implied decimals), reproduced:** quantities and costs `/10000.0`
  (LIPQOH, LIHCOM, IECSL, PDUOPN/PDPQOR/PDSQOR, SDPQOR/SDSQOR, WAUORG/WASOQS, WMUORG/WMTRQT),
  Safety Stock `IBSAFE/10000.0`, Order Line `SDLNID/1000.0`. Validate magnitudes against the xlsx.
- **Julian dates (CYYDDD):** ported as
  `CASE WHEN j>0 THEN DATEADD(DAY,(j%1000)-1,DATEFROMPARTS(1900+(j/1000),1,1)) ELSE NULL END`.
- **Fan-out / DISTINCT:** the generated SQL already carries every GROUP BY / DISTINCT (Inv Summary
  lot-master join fan-out is re-collapsed by the final GROUP BY; page 6 is SELECT DISTINCT). The
  ports reproduce these exactly.
- **CTEs -> derived tables:** Power BI wraps the native query as `SELECT * FROM (...)`, where `WITH`
  is illegal, so every Cognos CTE is inlined as a nested derived table.
- **`sysdate` in SELECT with GROUP BY:** `CAST(GETDATE() AS date)` is a runtime constant; kept in the
  SELECT list and DROPPED from every GROUP BY (proven safe in report 07).
- **Simplified redundant windows (Work Orders / WO Parts):** Cognos's outer `first_value(...) OVER`
  wraps a per-partition-single-row group; dropped because it returns that same value and T-SQL
  `FIRST_VALUE` would need an `ORDER BY` Cognos omits. Rows are identical. The WO-Parts inner
  `SUM/COUNT` -> outer `SUM() OVER / NULLIF(SUM() OVER,0)` weighted-average IS preserved.

---

## 7. Clone potential: report 14 ("Ivan Global Inventory Excel - Select Date")

Report 14 is the near-clone date-prompt variant. Expect the same six queries with a **user-selected
as-of date** replacing (a) the `TIME`/`sysdate` value and/or (b) the relative date floors (PO -365,
WO -30) with a prompted date. Plan: clone all six `.m`, hoist the date to a Power Query parameter
(e.g. `AsOfDate`), and swap `CAST(GETDATE() AS date)` / `DATEADD(DAY,-N,CAST(GETDATE() AS date))`
for parameter arithmetic. Do not start 14 until its own XML/SQL confirms exactly which dates the
prompt drives - stay scoped to 13 for now.

---

## 7b. Validation round 2 - 14 Jul 2026 (tight capture, ~5 min apart)

Round 1 compared a Cognos capture and a PBI refresh **13.5 hours apart**, so 25% of rows "missed"
purely on live movement and nothing could be concluded. Round 2 used a Cognos export at 17:00:07
against a PBI export off the same refresh (~5 min later), which reduces drift to near-zero and makes
every residual a candidate defect. Evidence workbook:
`Excel Validation/_report_out/13 - Ivan LIVE Global Inventory.xlsx` (live formulas).

**Row counts tie exactly on 5 of 6 pages** (7,134 / 1,018 / 452 / 1,624 / 6,754); PO is +2 in PBI.

**DEFECT FOUND AND FIXED - literal `'NULL'` in Supplier Lot Number.** ODS stores the 4-character
text `'NULL'` in `PRODDTA.F4108.IORLOT` where live JDE holds an empty value (Oracle `'' IS NULL`;
the SQL Server replica materialised it as a string). Cognos renders those lots blank, the PBI model
was printing the word NULL. 552 rows on Inventory OH, 532 on OH and Expiry. Proof: PBI's 3,941
blanks + 532 `'NULL'` = 4,473 = Cognos's 4,473 blanks, exactly. Every other text column in all six
tables is clean. Fixed with `NULLIF(LTRIM(RTRIM(lm.IORLOT)), 'NULL')` in `Inv_Summary` and
`Inv_Summary_OH_Expiry` (.m masters + PBIP + live model).

**✅ REFRESHED AND VERIFIED 14 Jul 2026 17:48** - literal `'NULL'` count is now **0** on both tables
(was 552 / 532); those rows render blank, matching Cognos. Cleanest read on the fix: **OH and Expiry
went from 92.12% → 99.99%** (all 6,753 PBI rows found in Cognos; the single Cognos row missing is a
lot that was consumed). That page has no transactional columns, so it cannot drift on status or
allocation - the improvement is entirely the fix.

On the tight capture pair, **Inventory OH, Work Order, WO Parts List and OH and Expiry tie 1:1
exactly.** Note the defect was **invisible to count-based validation** - row counts tied perfectly
with the bug present. Only a value-level compare finds it.

**Residuals that are NOT rebuild defects:**

1. **2 extra PO rows in PBI** - purchase orders `178865` and `178866`, consecutive doc numbers,
   status 220 -> 230, keyed into JDE between the Cognos capture and the PBI refresh. All 7,123
   Cognos rows are present in PBI; nothing is missing. Correct-direction drift.
2. **Text-case differences in 38 rows** - Vendor Name (33), Reference 2 (4), Customer PO (1).
   e.g. Cognos `KAOLIN INTERNATIONAL NV` vs PBI `Kaolin International NV`. Both sides read the SAME
   JDE columns (`F0101.ABALPH`, `F4311.PDVR02`) with the same trim, so the port is faithful - the
   two **sources** disagree. Case only, zero numeric impact. Note the direction: ODS has newer
   INSERTs (the 2 new POs) but staler UPDATEs (these edits), which suggests a change-capture gap on
   updates in the ODS replica rather than a simple lag. **Raise with the ODS owner** - it would
   affect every ODS-sourced report, not just this one.

**Comparison gotcha for whoever repeats this:** PBI's "export data with current layout" writes the
*displayed* string, so `#,0` / `$#,0` columns come out rounded to whole units while Cognos exports
full precision. Round both sides to the displayed precision before matching, and use half-away-from-
zero (Excel `ROUND`, PBI's display rule) - Python's default banker's rounding manufactures phantom
"PBI is exactly +1" diffs on `.5` values.

---

## 8. Open questions for the human

1. **`TIME` column format/grain.** Cognos `{sysdate}` is a full timestamp with no explicit format;
   the port uses `CAST(GETDATE() AS date)` (house convention, per report 07's `NOW`). If Ivan wants
   the time-of-day shown, switch to `GETDATE()` (datetime) and a datetime format. Default assumption:
   date only. Confirm.
2. **Header font colours (red/blue/green).** Reproduce for exact visual parity, or skip as cosmetic?
   Recommend skip unless the theme makes it trivial.
3. **Refresh cadence.** Being "LIVE", the date floors freeze at refresh time. Confirm a Service
   refresh schedule so the rolling windows stay current (same open item as report 06/12).
