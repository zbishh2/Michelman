# Report 19 — 1 - Inventory - Safety Stock and Order Size — BUILD SPEC

**Cognos path:** Public Folders > Michelman Reporting > Production and Shipping > **Cogan Excel AD HOC Reports**
**Portal folder ID:** `i52030381F2354AC6818EE9527C4297C8`
**Report name (XML `reportName`):** `1 - Inventory - Safety Stock and Order Size`
**Cognos package:** `/content/package[@name='Data Warehouse']/model[@name='model']` — the **DW_LEGACY** Oracle star (`RS_modelModificationTime = 2018-07-31`), same legacy warehouse as reports 13 / 14 / 18 / 20 / 21.
**Assigned:** Zack, 2026-08-06. Intake collected 2026-08-06.

**Stage:** ✅ **INTAKE COMPLETE AND TIED OUT.** Both sheets reproduce **exactly** against the tight capture, locally, before a single line of PBIP has been written:

| Sheet | Cognos rows | EDW rows | Matched on the full display key |
|---|---|---|---|
| Safety Stock | **177** | **177** | 177 / 177 |
| Shipments | **5,675** | **5,675** | 5,674 (1 residual, §4.7) |

A **two-sheet Excel data dump**. Two independent queries, one flat `<list>` each, no grouping, no summaries, no prompts, no parameters (`run.prompt=true` is inert — every filter is hardcoded or `sysdate`-relative). Structurally the simplest report in the program; the risk was entirely in the **column semantics**, and §0 lists the five places the obvious port was wrong.

Author the PBIP in **PBIR** format (like reports 02/03/14/17/18). Production `.m` files are comment-free; a `<name>.commented.m` master sits alongside each (repo rule: prod deliverables carry no comments).

**Do NOT build the PBIP from this file if you are the intake agent** — a separate build agent consumes this spec. Everything below is explicit enough that the build agent needs no further research.

---

## 0. Intake integrity + the five findings that shape the build (READ FIRST)

| Artifact | Status | Notes |
|---|---|---|
| **Native (Oracle) SQL** | **COMPLETE — the authoritative form** | `Intake\Native SQL (filed 2026-08-06).txt`. Cite this in preference to the IBM Cognos SQL wherever they overlap. |
| IBM Cognos SQL + report XML | COMPLETE, untruncated | `Intake\Query + XML (filed 2026-08-06).txt`. Still the source for layout, formats and data-item names. |
| **Rendered export (xlsx)** | **PRESENT — TIGHT CAPTURE** | `Intake\Cognos export - tight capture 2026-08-06.xlsx`. `DATE` column = **2026-08-06**; mirror loaded **2026-08-05**. Two sheets, 177 + 5,675 data rows. |
| Screenshots | Not collected | Not needed — the xlsx is complete render evidence. |

**One material difference between the two SQL forms.** The native `GROUP BY` has **15 keys**; the IBM form's `XSUM ... for` list has 16 because it carries `to_date({sysdate})`. Oracle drops it as a constant. **Group by 15 keys, not 16** — §4.2.

### 0.1 Finding A — `Ordered Quantity` is `QuantityOrderedPrimaryUOM`, not `QuantityOrdered * SalesFactor`

Cognos: `sum(ORDERED_QTY * SALES_FACTOR)`. `dbo.FactSalesDetail` has a column literally called `SalesFactor`, and the obvious port is wrong: measured, **`SalesFactor` is `1.0000` on 977,203 rows and `0.0000` on 2,140** — every row. It is not a UOM conversion. The conversion lives in **`QuantityOrderedPrimaryUOM`**, whose ratio to `QuantityOrdered` reproduces F41002 `UMCONV` exactly (TO→LB 2500, TO→KG 1000, DR→KG 200, B1→LB 44, KG→LB 2.204619), and **10,308 of 15,704 in-window lines (65.7%) differ between the two**.

**Proven against the capture: `SUM(QuantityOrderedPrimaryUOM)` matches Cognos's `Ordered Quantity` on 5,674 of 5,674 rows — 100.00%, exact, and the column totals agree to the cent (39,590,712.21 both sides).** Corroborated by SSAS, which ships `QuantityOrderedPrimaryUOM` and `Qty Ordered Primary UOM LB/KG` on `Sales`.

### 0.2 Finding B — `CANCELLED_INDICATOR` is NOT `Cancelled_Flag` (worth 263 rows)

`FactSalesDetail.Cancelled_Flag` looks like the port and is not. It is set on only **366 rows model-wide** and catches **118 of the 486** cancelled lines in scope. Porting it alone leaves the report **+263 rows (+4.6%) too high**, spread proportionally across every branch, which is exactly the kind of miss that reads as "close enough".

The real discriminator is **`StatusCodeLast`**. In the final population, statuses **`980` and `984`** have, on 100% of their rows: `QuantityShipped = 0`, `QuantityCanceledScrapped <> 0`, `AmountExtendedPrice = 0`. Every other status (`620`, `900`, `912`, `902`) has `QuantityCanceledScrapped = 0` on 100% of rows. They are cancelled lines, and `Cancelled_Flag` flags only a quarter of them.

**Port as `StatusCodeLast NOT IN ('980','984')`.** Measured row counts against the 5,675 target:

| Cancel predicate | Output rows |
|---|---|
| *(none)* | 6,024 |
| `Cancelled_Flag <> 1` | 5,938 |
| `QuantityCanceledScrapped = 0` | 5,663 |
| **`StatusCodeLast NOT IN ('980','984')`** | **5,675** ✅ |

`QuantityCanceledScrapped = 0` gets within 12 rows and is the *semantic* equivalent, but it misses one line (status 980 with a zero cancelled quantity) and requires the TM fix below to land. The status predicate is the one that ties.

### 0.3 Finding C — `Global Parent Name` is `AddressNum5th`, not `ParentAddressSKey`

Cognos walks `CUSTOMER_SHIP_TO.GLOBAL_REPORTING → CUSTOMERID → CUSTOMER.CUSTOMER_NAME`. The intuitive EDW port is the fact's own `ParentCustomerSKey` / `ParentAddressSKey`. Measured over 5,661 matched rows, that reproduces Cognos on **20.4%**. The address book's *fifth* address number does it on **99.9%**:

| Candidate | Reproduces Cognos `Global Parent Name` |
|---|---|
| `f.ParentAddressSKey → AddressDesc` | 1,154 / 5,661 (20.4%) |
| `sa.AddressNum1st` | 1,160 (20.5%) |
| `sa.AddressNum2nd` | 892 (15.8%) |
| `sa.AddressNum3rd` | 1,083 (19.1%) |
| `sa.AddressNum4th` | 1,074 (19.0%) |
| **`sa.AddressNum5th → AddressDesc`** | **5,655 (99.9%)** |
| `sa.AddressNumParent` | 0 (0.0%) |

The tell that this is right rather than lucky: the **self-parent share matches exactly** — 1,076 rows where Global Parent = Customer Name on both sides. Under `ParentAddressSKey` EDW showed 2,406 self-parents against Cognos's 1,084. And the values read correctly: `Henkel - Global Parent`, `Grafix - Global Parent`, `Barentz - Global Parent` are real global-reporting entities that the AN8 parent chain never surfaces. The 6 exceptions are cosmetic (trailing tabs in Cognos, one case difference).

### 0.4 Finding D — the Territory Manager join must be LEFT, not INNER

Cognos's `SALES_REP_ID = VENDOR_DIM_ID` is a comma-join and therefore an inner join, so the natural port is an inner join — and that is what drops the last 13 rows. **`BIQL.TbTerritoryManager` is incomplete**: 22 distinct `TerritoryManagerSKey` values on the fact do not resolve in it, including the `-1` unknown member. Cognos's `VENDOR` dimension resolves all of them, rendering `'Not Available'` for the unknowns and real names (`Brendan Schloerb`, `Bryan Fuka`, `Dave Jeffers`) for the rest.

**Use `LEFT JOIN` + `ISNULL(tm.[Mailing Name],'Not Available')`.** 17 lines / 13 output rows depend on it. This is the one place the usual "EDW denormalises so the naive port over-includes" logic runs backwards: here EDW's dimension is *thinner* than Oracle's and an inner join under-includes.

### 0.5 Finding E — `dbo.FactSalesDetail`'s LB/KG factors are known-wrong, and EDW ships a fix we cannot see locally

With everything above correct, `Ordered Quantity` is exact on 100% of rows but the two weight columns are not:

| Column | Exact | As displayed (`#,##0`) | Structurally wrong | Total vs Cognos |
|---|---|---|---|---|
| Ordered Quantity | 5,674 / 5,674 (100.00%) | 100.00% | 0 | **+0.000%** |
| Ordered Quantity LBs | 3,295 (58.07%) | 5,354 (94.36%) | **285** | +0.376% |
| Ordered Quantity KGs | 5,385 (94.91%) | 5,417 (95.47%) | **264** | +0.376% |

Two separate causes, and only one is a defect:

1. **Precision (2,094 LB rows, 25 KG rows).** Ratio EDW/Cognos = 1.0000 to four decimals; the stored factor differs in the 6th–7th decimal. Same `0.4535971` vs `0.45359237` issue report 18 §5.1 documented. Concentrated in the metric branches (AUBA 1,539, SNG4 644). **Invisible after the `#,##0` display rounding** — not a defect, do not chase.
2. **Structural (285 LB rows, 264 KG rows, ~5% of the report).** Ratio is 2.0, 1/22, 60, 0.9072, 1.6787 — item-specific, not UOM-wide (`B1` splits 189 rows at 1.0, 161 at 2.0, 47 at ~0.0455). **EDW's factor is a constant multiple of the DW's for those items.** Worth **+0.376% on both weight totals** — the same figure on both, confirming one cause.

**The cause is documented by EDW itself.** `edw_schema\edw_columns_current.csv` shows a table `BIQL.FactSalesDetail_UOM_Fix` (18 columns: `Unit Weight_Adj`, `UOMWeight_Adj`, `Fix U/M`, `Fix Qty`, `Fix Actual Qty`, keyed on `FSDSKey`), and the **view** `BIQL.FactSalesDetail` exposes `Unit_Weight_Adj`, `UOM_Weight_Adj`, `Fix U/M`, `Fix Qty`, `Fix Actual Qty` — **none of which exist on `dbo.FactSalesDetail`** (186 columns) or in the local mirror. `BIQL.TbSales_Detail_v2` likewise carries four factor columns (`ConversionFactorLB/KG` **and** `ConversionFactorWeightLB/KG` **and** `ConversionFactorPrimaryLB/KG`) where `dbo.FactSalesDetail` carries two.

**Recommendation: source query 2 from `BIQL.FactSalesDetail`, not `dbo.FactSalesDetail`** (§1.2), and settle the weight columns with jumpbox probe **J1** (§9.3). Everything else in this spec is column-for-column identical between the two, so this is a one-word change to the `FROM` clause, not a redesign. Until J1 lands, ship the `dbo` expressions and **disclose the +0.376%**; it is a defensible, quantified variance, not an unknown.

> ⛔ **SUPERSEDED 2026-08-06 — J1 ran, and this section's *premise* is wrong. See V38 + V40.**
> The view does **not** carry corrected conversion factors: the probe listing every line where
> `BIQL.FactSalesDetail` and `dbo.FactSalesDetail` disagree returned **zero rows**, and `[Fix U/M]` is
> populated on **0 of 15,823** in-scope lines, so `BIQL.FactSalesDetail_UOM_Fix` is a red herring here.
> The real fix is a different column — **`Unit_Weight_Adj`**, which is a **line total** weight in the
> unit named by `UOM_Weight_Adj`, applied in DAX with no multiplication by quantity. That closes the
> variance: **+0.376% → −0.0021%**, LBs exact 57.89% → **98.96%**. The build does now read the view,
> but only for those two columns. And it stays locally verifiable: `dbo.FactSalesDetail.UnitWeight` /
> `UOMWeight` are byte-identical to the `_Adj` pair on all 7,663 probe lines.

---

## 1. Source route — **EDW SQL Server** (SSAS blocked, ODS unnecessary)

Evaluated SSAS → EDW → ODS per the standing mandate (CLAUDE.md §1). This is a *new* report, so the mandate genuinely applies.

### 1.1 SSAS live connection — **BLOCKED** on one column

A live connection means no local tables, so every column must sit inside one perspective. Measured against `ssasprod.bim`:

- **`Sales Order`** carries `Sales` + `Item Branch` + `Customer Ship To` + `Customer Parent` + `Territory Manager`, but its `Item Branch` (87 columns) exposes **neither safety-stock column**. Query 1 is impossible there.
- **`Supply and Demand`** is the only perspective that could carry the whole report: `Item Branch` at 131 columns with **both** safety-stock columns, plus `Sales` (144 columns incl. `Open Order Flag`, `Cancelled_Flag`, `QuantityOrderedPrimaryUOM`, `Qty Ordered Primary UOM LB/KG`, `Promised Shipment Date`, `Scheduled Pick Date`, `Order Type`, `Line Type`), `Customer Ship To`, `Customer Parent`, `Territory Manager`, `Branch`.
- **The blocker: `Lead Time MFG_BP` is exposed in ZERO of the 34 perspectives.** The string occurs exactly **twice** in the whole `.bim` (the base-table column definition and one annotation) against 9 for `SafetyStock` and 26 for `Master Planning Family`. `Item Branch` exposes only `Lead time Level` and `Fixedor Variable Lead time`, and those are **not substitutes**: `[Lead Time MFG_BP]` = `F4102.IBLTMF`, `[Lead time Level]` = `IBLTLV`, and they disagree on real rows (item 844318: 12 vs 0). The export confirms Cognos renders the `IBLTMF` value (69, 6 — plain integers).

**⚠ Provisional:** `ssasprod.bim` is a dump of **`BIQLTabular`**, the *stale* model (verified — its `model.name` is literally `BIQLTabular`). §1.1 is *where to look first*, not a final answer. Stated as checkable item **J2** in §9.3.

### 1.2 EDW SQL Server — **CHOSEN**

| Need | EDW object | In local mirror? |
|---|---|---|
| Query 1, all ten columns | `BIQL.TbItemBranch` (116,002 rows) | ✅ |
| Query 2 fact | **`BIQL.FactSalesDetail`** (view; `dbo.FactSalesDetail` = 979,343 rows, 186 cols) | ⚠️ only the `dbo` table — §0.5 |
| Item attrs for query 2 | `BIQL.TbItemBranch` via `ItemBranchSKey` | ✅ |
| Ship-to category codes (AC01/AC06) | `BIQL.DimCustomer` (22,227) | ✅ |
| Ship-to name, country, **global parent** | `BIQL.DimAddress` (37,339) | ✅ |
| Territory manager | `BIQL.TbTerritoryManager` (19,321) | ✅ |

Connection: `Sql.Database("EDWPROD", "EDW")`, two-part `BIQL.<obj>` names, native T-SQL via `Value.NativeQuery(..., null, [EnableFolding=false])`. **Every source query carries `WITH (NOLOCK)`** (CLAUDE.md §9).

> **`BIQL.TbCustomerShipTo` is not needed.** COLLECTION_NOTES routed four attributes through it; it is absent from the mirror and all four turned out to be reachable and verified without it (§4.4). Nothing about report 19 is blocked on it, and the `c16` → **"Customer Segmentation Description"** mapping the export confirmed is satisfied by `BIQL.DimCustomer.CustomerSegmentationDesc` with **0 mismatches on 5,674 rows** — so that column is *not* jumpbox-only after all.

### 1.3 ODS — not needed

`PRODDTA.F4102` / `F4101` / `F0101` / `F4211`+`F42119` could reproduce both queries, but EDW already carries the decoded columns and the SKey joins. ODS was used here only as **corroboration** (safety-stock scaling, lead-time field identity, name lineage) — the right use of it, not a fallback route. It stays relevant for exactly one thing: the `Planner Name` fix in §3.4 trap 3.

---

## 2. Table / model design — **two import tables PLUS a real relationship** (recommended, argued)

Cognos ships two sheets that never touch each other; the analyst joins them in Excel. The stated business intent is to put each item's *standing* safety stock next to the *actual order sizes* it has had to absorb. Rebuilding that as two disconnected islands preserves the defect.

**Recommendation: build the two tables exactly 1:1 with the Cognos queries (parity is the deliverable), and additionally wire a many-to-one relationship `Shipments[ItemBranchSKey] → Safety Stock[ItemBranchSKey]`, then add a third "Safety Stock vs Order Size" page.** The two Cognos pages stay untouched and tie out on their own; the third page is the improvement.

Why the relationship is worth it — measured:

- The 177 query-1 item-branches account for **2,974 of the 7,633 shipment lines (39.0%)** on `ItemBranchSKey` (44.0% matched on Bulk + 2nd item across branches).
- The other 61% are items with **no safety stock to right-size** — not lost, simply outside the analysis the report exists to support.
- `ItemBranchSKey` is unique in `TbItemBranch` (116,002 = 116,002 distinct), so the relationship is a clean many-to-one with **no fan-out**. `ItemSKey + Business Unit` is *not* unique (115,989 distinct — 13 collisions), so **use `ItemBranchSKey`**, which is also what §4 joins on.

Cost: one extra non-displayed column per table and one relationship. If the client says the two-sheet split is deliberate (Q3, §11), drop the third page and leave the relationship inactive.

**Do not** merge the two into one table — different grains, different row sets, different refresh scopes.

---

## 3. Query 1 — "Safety Stock" — **TIES AT 177/177**

### 3.1 Native source (authoritative)

```sql
select distinct "ITEM"."BRANCH_PLANT", "ITEM"."BULK_ITEM", "ITEM"."ITEM_NUMBER_2ND", "ITEM"."STOCK_TYPE_CODE",
       "ITEM"."MASTER_PLANNING_FAMILY__IMPR", "ITEM"."LEADTIME_MFG", "ITEM"."PLANNER_NUMBER",
       "VENDOR_ALIAS_PLANNER"."VENDOR_NAME", "ITEM"."SAFETY_STOCK", "ITEM"."UNIT_OF_MEASURE__PRIMARY"
 from "DW_LEGACY"."ITEM" "ITEM", "DW_LEGACY"."VENDOR" "VENDOR_ALIAS_PLANNER"
 where "ITEM"."BRANCH_PLANT" in (N'CINC',N'CIN2',N'AUBA',N'AUB2',N'SING',N'SNG4')
   and "ITEM"."SAFETY_STOCK">1 and "ITEM"."STOCK_TYPE_CODE" not in (N'O')
   and "ITEM"."MASTER_PLANNING_FAMILY__IMPR" like N'%F%'
   and "ITEM"."PLANNER_NUMBER"="VENDOR_ALIAS_PLANNER"."VENDOR_DIM_ID"
 order by "Bulk_Item" asc nulls last, "C_2nd_Item_Number" asc nulls last, "Branch_Plant" asc nulls last
```

### 3.2 Column mapping — 8 of 10 columns are exact against the export

| # | Header (verbatim) | EDW `BIQL.TbItemBranch` | Type | Verified vs export |
|---|---|---|---|---|
| 1 | Branch Plant | `LTRIM(RTRIM([Business Unit]))` | `nchar(12)` | **0 mismatches / 177** |
| 2 | Bulk Item | `[Item Bulk]` | `nvarchar(25)` | **0 / 177** — `[Item Bulk]` and `[Item Num Bulk]` are identical on all 116,002 rows, so the COLLECTION_NOTES "which one" is moot |
| 3 | 2nd Item Number | `[Item Num 2nd]` | `nvarchar(25)` | **0 / 177** |
| 4 | Stock Type Code | `LTRIM(RTRIM([Stocking Type]))` | `nchar(1)` | **0 / 177** |
| 5 | Master Planning Family | `LTRIM(RTRIM([Master Planning Family]))` | `nchar(3)` | **0 / 177** |
| 6 | Lead Time Order to Ship | `[Lead Time MFG_BP]` | `int` | **0 / 177** — = `F4102.IBLTMF` |
| 7 | Planner Number | `[Planner Num]` | `int` | **1 / 177** — data drift, §3.4 trap 4 |
| 8 | Planner Name | `[Planner Name]` | `nvarchar(40)` | **177 / 177 differ — §3.4 trap 3** |
| 9 | Safety Stock | `SafetyStock` | `decimal(19,4)` | **1 / 177** — same drifted row |
| 10 | Unit of Measure Primary | `LTRIM(RTRIM([UOM Primary]))` | `nchar(2)` | **0 / 177** |

Plus, not displayed: **`ItemBranchSKey`** (`int`) for the §2 relationship.

The Cognos `VENDOR` join **disappears** — EDW denormalises `Planner Name` onto the row. One table, no joins.

**Safety Stock is in the item's primary UOM and is not converted** (export shows `840` beside `KG`, `9500` beside `LB`). Apply no LB/KG conversion to it.

### 3.3 Filters, ported

```sql
WHERE LTRIM(RTRIM([Business Unit])) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND SafetyStock > 1
  AND LTRIM(RTRIM([Stocking Type])) NOT IN ('O')
  AND [Master Planning Family] LIKE '%F%'
```

`SELECT DISTINCT` is **not** needed — the 10-column projection yields 177 distinct tuples from 177 rows. Keep it out; a stray `DISTINCT` masks future fan-out.

| Step | Rows |
|---|---|
| A — all `TbItemBranch` | 116,002 |
| B — + 6 branch plants | 44,330 |
| C — + `SafetyStock > 1` | 509 |
| D — + `Stocking Type <> 'O'` | 502 |
| E — + `MPF LIKE '%F%'` | **177** |
| F — + planner resolves to a name | **177** (zero drop) |
| **Cognos export** | **177** ✅ |

Branch split: CIN2 129, AUBA 24, SNG4 11, AUB2 9, CINC 4, **SING 0**.

### 3.4 Traps

1. **The two safety-stock columns are identical — the choice is free.** Over all 116,002 rows: `SafetyStock` and `[Safety Stock SAFE]` are 115,309 NULL each, 693 non-null each, **693 equal, 0 differ**; `> 1` gives 647 on each; under the full query-1 filter set both give **177**, and the export says 177. COLLECTION_NOTES flagged this as a row-set risk; it is not one. Use `SafetyStock`. Lineage: `SafetyStock = F4102.IBSAFE / 10000` (JDE 4 implied decimals), 1 mismatch in 116,000. EDW writes `NULL` where `IBSAFE = 0`; `> 1` excludes NULL in T-SQL exactly as Oracle does — **do not add `ISNULL`**. Threshold sensitivity: `> 1` → 177, `> 0` → 178.
2. **The planner inner join drops nothing — verified against the export.** All 177 rows have a non-zero `Planner Num` and a non-blank `Planner Name`, and Cognos returns exactly 177. The predicted "EDW over-includes by the number of unresolvable planners" gap is **zero**. **Do not add a defensive `WHERE [Planner Name] <> ''`** — it changes nothing today and would diverge from Cognos if a planner were ever unnamed.
3. **`Planner Name` — Cognos renders `Last, First`; EDW renders `First Last`. CONFIRMED, affects all 177 rows.**

   | Cognos | EDW |
   |---|---|
   | `Murphy, Lance` (72) | `Lance Murphy` (72) |
   | `Howe, Dave` (55) | `Dave Howe` (55) |
   | `Desjardin, Laurent` (24) | `Laurent Desjardin` (24) |
   | `Lee, Wen Wei` (11) | `Wen Wei Lee` (11) |
   | `Bertrand, Joel` (9) | `Joël Bertrand` (8) |
   | `Hanlon, Tammy` (6) | `Tammy Hanlon` (6) |
   | — | `Lise Jacquet` (1) |

   EDW's `[Planner Name]` matches `F0101.ABALPH` on only **117 of 93,054** rows — it is a normalised re-ordering. **Note also that Cognos drops the diaeresis: `Bertrand, Joel`, not `Bertrand, Joël`.** `ABALPH` in ODS stores the ASCII form.

   **Fix: take the name from `ODS.PRODDTA.F0101.ABALPH` keyed on `ABAN8 = [Planner Num]`, which reproduces both the ordering and the ASCII spelling in one step.** That is the only place this build needs ODS. Alternative if a cross-database query is unwanted: a 7-row `CASE` in the SQL — but it will rot the first time a planner changes. Recommend the ODS join; it is one `LEFT JOIN` on a 177-row table.
4. **One row of genuine drift, fully explained.** Exactly one item-branch differs: Cognos `Planner Number 291244` / `Safety Stock 9000`, EDW `340941` / `8550`. The planner tallies confirm it — Cognos has 9 `Bertrand, Joel` and no `Jacquet`; EDW has 8 `Joël Bertrand` and 1 `Lise Jacquet`. One item-branch had its planner and safety stock edited between the mirror load (2026-08-05) and the Cognos run (2026-08-06). **This is snapshot staleness, not a logic error** — expect it to disappear on a live refresh.
5. **`MPF LIKE '%F%'` is a substring match and admits exactly four codes.**

   | Verdict | Codes |
   |---|---|
   | **ADMIT** | `FBW` Finished Good made in Bluewave (2) · `FCB` Finished Good Cold Blend (97) · `FEC` Finished Good made in EC (33) · `FRC` Finished Good made in Reactor (45) |
   | reject | *(blank)* · `ATP` · `CTR` · `ETP` · `H2O` · `INT` · `MAP` · `MNT` · `NPK` · `PKG` · `RAW` · `RBW` · `RCB` · `REC` · `RRC` · `RWW` · `SPC` · `TOL` · `WAG` |

   Sum of admitted = 177 ✓. **The rule means "finished goods".** No current code carries an embedded `F`, so `'%F%'` ≡ `'F%'` today — but keep `'%F%'` verbatim for parity, and know a future code such as `TFL` would silently join the report (Q6, §11).
6. **`Joël Bertrand` carries a non-ASCII character in EDW.** The source columns are `nvarchar` and any intermediate written by PowerShell must be **UTF-8 without BOM** (memory: `powershell-utf8-bom-breaks-pbir`). Moot if trap 3's ODS fix is taken, since Cognos itself renders ASCII.

---

## 4. Query 2 — "Shipments" — **TIES AT 5,675/5,675**

### 4.1 What it is

`ORDER_ACTIVITY` + `ORDER_ACTIVITY_MEASURES` + 9 dimension aliases, aggregated over a **15-key** group-by (native form). Net grain = **order × item**, line detail summed away. Three measures.

### 4.2 Column mapping — all 19 columns verified against the export

Display order = the Cognos `<listColumns>` order. Headers render the data-item **name** verbatim; there are no `label=` overrides, so **no PBIR `displayName` renames** — with one exception: the data item named `Customer Segmentation Description` is aliased `c16` in the SQL. **The export header confirms it renders as `Customer Segmentation Description`.** Do not ship `c16`.

| # | Header | Cognos | EDW source | Verified vs export (5,674 matched rows) |
|---|---|---|---|---|
| 1 | Order Company | `substr(ORDER_LINE_ID,1,5)` | `f.OrderCompany` | ✅ = `LEFT(OrderLineID,5)`, **0 mismatches / 869,741** |
| 2 | Branch Plant | `MEASURE.ORGANIZATION_ID` | `LTRIM(RTRIM(f.BusinessUnit))` | ✅ 0 |
| 3 | Order Number | `ORDER_NUMBER` | `f.OrderNum` | ✅ 0 |
| 4 | Bulk Item | `ITEM.BULK_ITEM` | `ib.[Item Bulk]` | ✅ 0 (1 residual, §4.7) |
| 5 | 2nd Item Number | `MEASURE.ITEM_NUMBER_2ND` | `f.ItemNum2nd` | ✅ 0 — **fact-side**, not `ib.[Item Num 2nd]` |
| 6 | Ordered Date | `MEASURE.ORDERED_DATE` | `f.OrderDate` | ✅ 0 |
| 7 | Ordered Quantity | `sum(ORDERED_QTY * SALES_FACTOR)` | `SUM(f.QuantityOrderedPrimaryUOM)` | ✅ **5,674 / 5,674 exact** — §0.1 |
| 8 | Ordering Unit of Measure | `ORDERING_UNIT_OF_MEASURE` | `LTRIM(RTRIM(f.UOMTransaction))` | ✅ 0 |
| 9 | Ordered Quantity LBs | `sum(ORDERED_QTY * CONVERSION_FACTOR_LB * SALES_FACTOR)` | `SUM(f.QuantityOrderedPrimaryUOM * f.ConversionFactorLB)` | ⚠️ 285 structural — §0.5 |
| 10 | Ordered Quantity KGs | `sum(… * CONVERSION_FACTOR_KG * …)` | `SUM(f.QuantityOrderedPrimaryUOM * f.ConversionFactorKG)` | ⚠️ 264 structural — §0.5 |
| 11 | Promised Ship Date | `ORDER_ACTIVITY.DUE_DATE` | `f.PromisedShipmentDate` | ✅ 0 |
| 12 | Scheduled Pick Date | `SCHEDULED_PICK_DATE` | `f.ScheduledPickDate` | ✅ 0 |
| 13 | Customer Code | `CUSTOMER_SHIP_TO.CUSTOMER_CODE` | `f.AddressNumShipTo` | ✅ 0 — JDE `AN8` |
| 14 | Customer Name | `CUSTOMER_SHIP_TO.CUSTOMER_NAME` | `LTRIM(RTRIM(sa.AddressDesc))` | ✅ 4 residual — **needs the trim**, §4.6 |
| 15 | Global Parent Name | `CUSTOMER__ALIAS_SHIP_TO_GP.CUSTOMER_NAME` | `p5.AddressDesc` via `sa.AddressNum5th` | ✅ 4 residual — **§0.3** |
| 16 | Customer Segmentation Description | `AC06 CUSTOMER_TYPE_DESCRIPTION` | `sc.CustomerSegmentationDesc` | ✅ **0** |
| 17 | TM Name | `VENDOR_ALIAS_TM.MAILING_NAME` | `ISNULL(tm.[Mailing Name],'Not Available')` | ✅ 8 residual — **§0.4** |
| 18 | Country Name | `T6.DESCRIPTION` (UDC `00,CN`) | `sa.MailAddressCountryDesc` | ✅ **0** |
| 19 | DATE | `to_date(sysdate)` | `CAST(GETDATE() AS date)` | ✅ constant `2026-08-06` in the export |

Plus, not displayed: **`ItemBranchSKey`** for the §2 relationship.

**Join skeleton — four INNER, one LEFT:**

```sql
FROM BIQL.FactSalesDetail f WITH (NOLOCK)            -- see §0.5 / §1.2 re: dbo vs BIQL
JOIN      BIQL.TbItemBranch       ib WITH (NOLOCK) ON ib.ItemBranchSKey = f.ItemBranchSKey
JOIN      BIQL.DimCustomer        sc WITH (NOLOCK) ON sc.CustomerSKey   = f.ShipToCustomerSKey
JOIN      BIQL.DimAddress         sa WITH (NOLOCK) ON sa.AddressSKey    = f.ShipToAddressSKey
LEFT JOIN BIQL.DimAddress         p5 WITH (NOLOCK) ON p5.AddressNum     = sa.AddressNum5th AND p5.DWIsCurrent = 1
LEFT JOIN BIQL.TbTerritoryManager tm WITH (NOLOCK) ON tm.TerritoryManagerSKey = f.TerritoryManagerSKey
```

Measured join drops on the pre-filter base: item-branch **0**, ship-to customer **0**, ship-to address **0**, parent **0**, territory manager **387** raw / **17 lines in the final set**. All four dims are **unique on their SKey** (`DimCustomer` 22,227 = 22,227; `DimAddress` 37,339 = 37,339; `TbItemBranch` 116,002 = 116,002; `TbTerritoryManager` 19,321 = 19,321) — **no fan-out anywhere**. `DimCustomer` / `DimAddress` carry SCD2 columns but are already collapsed to one row per SKey, so **no effective-date predicate on the SKey joins** — adding one would be a bug. The `AddressNum5th` join is by *address number*, not SKey, so it **does** need `DWIsCurrent = 1`.

### 4.3 `OPEN_INDICATOR <> 'Y'` → `SalesTableSource <> 1`

The native SQL confirms `OPEN_INDICATOR` is a **plain physical column on `DW_LEGACY.ORDER_ACTIVITY`** — a stored Y/N flag, not a derived expression. So look for a stored discriminator on the EDW side, which is what `SalesTableSource` is.

Candidate elimination, measured: `Source` is constant `1` on all 979,343 rows. `QuantityOpen <> 0` on **zero** rows — unpopulated. `Cancelled_Flag` is the `CANCELLED_INDICATOR` port, and a bad one (§0.2). That leaves:

| `SalesTableSource` | `RecordType` | rows | OrderDate range | distinct `StatusCodeNext` | reading |
|---|---|---|---|---|---|
| 1 | Sales Detail | 3,603 | 2012-05-21 → 2026-08-05 | **13** | **F4211 — open orders** |
| 2 | Sales Detail | 424,423 | 2009-10-22 → 2026-08-05 | 1 (`999`) | F42119 — sales history |
| 3 | Sales Detail | 956 | → 2015-03-13 | 1 | F4211_ARCH |
| 4 | Sales Detail | 440,759 | → 2015-06-30 | 1 | F42119_ARCH |
| 5 | **GL Detail** | 109,602 | 1900-01-01 only | 1 | budget / GL — **must be excluded**, §4.5 trap 3 |

Only value 1 carries in-flight statuses. `OrderLineID` is unique across all Sales Detail rows (**0 duplicates**) and no `SalesTableSource = 1` line reappears in 2/3/4, so the union does not double-count.

Corroborating structure: EDW's own `Open Order Flag` is a `varchar(1) NOT NULL` column at ordinal 88 on **both** `BIQL.TbSales_Detail_v2` and `BIQL.TbSales_History_v2`, and SSAS partitions `Sales` as `Sales_Detail_P1` ← `TbSales_Detail` / `Sales_History_P1..P6` ← `TbSales_History` — the same seam.

**And it ties: `SalesTableSource <> 1` is part of the filter set that reproduces 5,675 exactly.** The status-based alternative (`StatusCodeNext = '999'`) would add 38 lines / 36 rows and break the tie. **Settled — do not relitigate.**

> ⛔ **SUPERSEDED 2026-08-06 — the build ships `LTRIM(RTRIM(StatusCodeNext)) = '999'`. See V39.**
> This section's conclusion ties, but for the wrong reason. Report 21's jumpbox probe cross-tabbed the
> real `OPEN_INDICATOR` against its Cognos export over 17,259 rows: `'N'` ⟺ `StatusCodeNext = '999'`,
> zero exceptions — and it *disproves* `SalesTableSource` there, where 252 lines are
> `SalesTableSource = 1` **and** `StatusCodeNext = '999'`. In report 19's window the two are exactly
> equivalent (0 disagreements either way over 8,077 lines), so **the row count is unchanged at 5,675**
> and the "+38 lines / 36 rows" above was measured against the *first-pass* filter set, before the
> V22–V24 corrections; against the final set the delta is zero. The predicate changed because the
> equivalence is a property of this window, not of the data model. ⚠ `StatusCodeNext` is `nchar(3)` —
> the trim is load-bearing.

### 4.4 The four "ship-to" attributes, without `BIQL.TbCustomerShipTo`

| Cognos | Route | Verified |
|---|---|---|
| `CUSTOMER_CODE` | `f.AddressNumShipTo` (JDE `AN8`) | ✅ 0 mismatches / 5,674 |
| `CUSTOMER_NAME` | `LTRIM(RTRIM(sa.AddressDesc))` via `f.ShipToAddressSKey` | ✅ `AddressDesc = F0101.ABALPH` on 37,337 / 37,337; 4 residual vs export |
| Global parent `CUSTOMER_NAME` | `sa.AddressNum5th → DimAddress.AddressDesc` | ✅ 5,655 / 5,661 (§0.3) |
| `T6.DESCRIPTION` (UDC `00,CN`) | `sa.MailAddressCountryDesc` | ✅ **0 mismatches** — EDW pre-decodes the UDC, so the whole `CATEGORY_CODES_UDC` join disappears |
| AC01 `CUSTOMER_TYPE_CODE` (the `<> 'INT'` filter) | `sc.SalesBusinessUnit` | ✅ **0 mismatches** vs `dbo.DimCustomer.AddressCode01` over all 22,227 rows |
| AC06 `CUSTOMER_TYPE_DESCRIPTION` | `sc.CustomerSegmentationDesc` | ✅ **0 mismatches** vs `AddressCode06`, and **0 vs the export** |

`BIQL.DimCustomer` names its first six address category codes rather than numbering them — `SalesBusinessUnit`(01), `ShippingDocuments`(02), `PalletRequirements`(03), `LabelFormat`(04), `InternationalCustomer`(05), `CustomerSegmentation`(06) — which is why AC01 does **not** map to the plausible-looking `InternationalCustomer`. Closed by the 0-mismatch check; do not re-derive it from the name.

### 4.5 Filters, ported — **this exact set reproduces 5,675**

```sql
WHERE f.RecordType = 'Sales Detail'                                            -- trap 3
  AND f.SalesTableSource <> 1                                                  -- OPEN_INDICATOR <> 'Y'   (§4.3)
  AND LTRIM(RTRIM(f.BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND f.PromisedShipmentDate >= <window lower bound>                           -- trap 1
  AND LTRIM(RTRIM(f.OrderType)) NOT IN ('S5','ST')
  AND f.LineType NOT LIKE '%F%'                                                -- trap 2
  AND f.StatusCodeLast NOT IN ('980','984')                                    -- CANCELLED_INDICATOR <> 'Y'  (§0.2)
  AND f.QuantityOrderedPrimaryUOM > 0                                          -- trap 4
  AND LTRIM(RTRIM(ISNULL(sc.SalesBusinessUnit,''))) <> 'INT'
  AND ib.[Master Planning Family] LIKE '%F%'
  -- India-tax exclusion is NOT here: it is a business rule and lives in DAX (§5.2 / trap 5).
  -- SQL only projects its two inputs, [Item Global Bulk] and ItemNum2nd.
```

Deliberately **not** ported: `BUDGET_FACTOR <> 1` (trap 3) and `Cancelled_Flag <> 1` (§0.2).

Stepwise counts against the **2026-02-05** boundary (the capture's own):

| Step | Lines |
|---|---|
| A0 — Sales Detail | 869,741 |
| A1 — + 6 branch plants | 725,224 |
| A2 — + `PromisedShipmentDate >= 2026-02-05` | 15,704 |
| A3 — + closed (`SalesTableSource <> 1`) | 14,471 |
| A4 — + order type not `S5`/`ST` | 10,332 |
| A5 — + line type not `%F%` | 8,723 |
| A6 — + `StatusCodeLast NOT IN ('980','984')` | ~8,204 |
| A7 — + `QuantityOrderedPrimaryUOM > 0` | 8,133 |
| B1 — + ship-to AC01 `<> 'INT'` | 7,909 |
| B2 — + `MPF LIKE '%F%'` | 7,209 |
| B3 — + India-tax exclusion *(applied in DAX)* | 7,209 *(**0 removed** — trap 5, and the reason is measured)* |
| **Output rows after the 15-key group-by** | **5,675** ✅ |

Branch split — **exact match on every branch**:

| Branch | Cognos | EDW |
|---|---|---|
| CIN2 | 3,229 | 3,229 |
| AUBA | 1,567 | 1,567 |
| SNG4 | 653 | 653 |
| CINC | 209 | 209 |
| SING | 17 | 17 |
| AUB2 | 0 | 0 |

**Traps:**

1. **The window boundary genuinely moves by a day with the run's time of day — and the capture proves it.** The native SQL is:

   ```sql
   "ORDER_ACTIVITY"."DUE_DATE" >= to_date(sysdate - (182.5*1.0e0))
   ```

   The subtraction happens **inside** `to_date()`. `sysdate` carries a time component, so `sysdate - 182.5` lands 182 days and 12 hours back and *then* truncates:
   - run **before 12:00** → lands on day D−183 in the evening → truncates to **D−183**
   - run **at or after 12:00** → lands on day D−182 in the small hours → truncates to **D−182**

   Contrast report 21, whose native SQL is `to_date(sysdate) - 365` — truncate first, then subtract, which is deterministic. **Report 19 is the ambiguous construction.**

   **Measured from the capture:** `DATE = 2026-08-06` and the minimum `Promised Ship Date` is **2026-02-05** = D−182 ⇒ **this export was run in the afternoon.**

   **Exposure, measured against the mirror:** the boundary day (`2026-02-04`) holds **51 output rows across 41 distinct orders — 0.90% of the report** (5,726 rows at `-183` vs 5,675 at `-182`).

   **Decision: ship `DATEADD(DAY, -183, CAST(GETDATE() AS date))`.** It is the more inclusive of the two, so the report can never silently *drop* orders Cognos would have shown — and for a six-month order-size analysis one extra day of history is harmless, while a missing day is a defect the reader cannot see. A Power BI refresh runs on a schedule we control, so the result is deterministic on our side even though Cognos's is not.
   **Consequence for the tie-out:** against an *afternoon* Cognos capture, `-183` will read **+51 rows / +0.90%**. That is a known, explained variance, not a miss (CLAUDE.md §7). To reproduce the capture exactly, use `-182`; §12 V19 records that the 5,675 tie was measured at `-182`. **Always record the Cognos run's time of day with the capture.**

2. **`LINE_TYPE not like '%F%'` is the freight carve-out and admits an embedded `F`.** Excluded set, measured: `FS` (130,333) · `FT` (3,550) · `FI` (3,193) · **`CF`** (2,209, "Credit on Freight" — F in position 2) · `FA` (509) · `FO` (456) · `FN` (193, "Insurance") · `FD` (157) · `FF` (1) · `F ` (1). Keep `'%F%'` verbatim; a `LIKE 'F%'` "simplification" would wrongly keep `CF`.
3. **`BUDGET_FACTOR <> 1` is a no-op on EDW and does NOT exclude budget rows.** `FactSalesDetail.BudgetFactor` is **`0.0000` on all 979,343 rows** — Sales Detail and GL Detail alike. Porting it is harmless but useless; porting it *instead of* an explicit exclusion would let **109,602 GL/budget rows** in. The real carve-out is **`RecordType = 'Sales Detail'`** (equivalently `SalesTableSource <> 5`). Cognos's two `DESCRIPTION_1` account carve-outs (`51210`, `61121`, both gated on `SALES_OR_GL = 'Budget Detail'`) are subsumed by that and are also inert on EDW. **Port `RecordType = 'Sales Detail'` and drop the three budget predicates**, documenting why in the `.commented.m`. Three dead predicates that look protective are worse than one live one.
4. **`(ORDERED_QTY * SALES_FACTOR) > 0` becomes `QuantityOrderedPrimaryUOM > 0`**, not `QuantityOrdered * SalesFactor > 0` — same §0.1 substitution. The naive form keeps the 2,140 `SalesFactor = 0` rows out for the wrong reason.
5. **`'-'` is Cognos rendering a NULL, not a stored value — and that changes the India-tax exclusion from a no-op into dead code if ported literally.**

   Corrected 2026-08-06 in line with reports 14 / 20 / 21: `-` is Cognos's default missing-value character. Measured across all 116,002 item-branches, `[Item Global Bulk]` is `'-'` on **0** rows, empty on **0**, and NULL on **17**; `[Item Bulk]` is `'-'` on 0, empty on 0, NULL on 385.

   **Inference (stated as such):** the `decode` exists in the Cognos report at all, so DW_LEGACY presumably *does* store `-` literally — otherwise it would be dead code there too. The two warehouses appear to differ: **DW_LEGACY stores `-`, EDW stores NULL.** We have no way to confirm the Oracle side from here.

   **Consequence: a literal `= '-'` port never matches on EDW, so the fallback to 2nd item number becomes dead code and the exclusion under-fires on exactly the rows it was written for.** Write it robust to all three forms of "missing":

   ```dax
   -- "missing" = NULL, empty, whitespace, or a literal dash
   Tax Item Key =
       VAR gbi = TRIM ( COALESCE ( Shipments[Item Global Bulk], "" ) )
       RETURN IF ( gbi IN { "", "-" }, TRIM ( Shipments[2nd Item Number] ), gbi )

   Is India Tax Item = Shipments[Tax Item Key] IN { "IGST","CGST","SGST","CVD","ADD" }
   ```

   **This is not hypothetical — the rows it targets exist, and they carry NULL.** Measured: `FactSalesDetail.ItemNum2nd` is one of the five tax codes on **15,316 lines**, and every one of them lives in an **Indian branch plant** — `MUM3` (14,167), `MUM2` (843), `HARY` (306) — with a **blank `Master Planning Family`** and an **`[Item Global Bulk]` of NULL**. That is precisely the `decode`'s fallback case, and precisely the case a literal `= '-'` test would miss. So the robust predicate is the correct port, demonstrably.

   **It removes 0 rows from report 19, for two independent reasons — this is a finding, not a pass.** All 15,316 tax lines are in Indian plants: **0 fall in the six branch plants**, and **0 have an item-branch whose MPF matches `'%F%'`** (their MPF is blank). Either filter alone already excludes them. Row counts are identical — 5,675 — under the literal, NULL-only and robust variants. **Ship the robust form anyway:** it costs nothing, it is the only variant that would actually fire if an Indian plant ever joins the six, and the two-column fallback is genuinely not a plain `COALESCE`.

   **Display consequence, separate from the filter:** where EDW stores NULL, Cognos renders `-`. Handle that in **DAX, not SQL and not a format string** (§5.2, §7). It also matters for tie-outs — comparing an EDW NULL against the export's `-` false-mismatches every such row unless one side is normalized first. *(It did not bite this capture: `[Item Bulk]` is NULL on 0 of the 7,209 in-scope lines and on 0 of the 177 Safety Stock rows, so no normalization was needed — but do not assume that holds next time.)*
6. **`ConversionFactorLB/KG` are NULL on 2,031 of the 15,704 in-window lines (12.9%) — but on 0 of the final lines.** The nulls are all outside the finished-goods MPF set. `NULL × qty` is NULL and `SUM` skips it, so a null would silently under-report rather than error. Not required today; becomes required immediately if the MPF filter is relaxed.
7. **Do not `SELECT DISTINCT`.** The Cognos query is a `GROUP BY` + `SUM`, not a dedup. §6 reproduces it by importing at line grain and letting the visual group; collapsing with `DISTINCT` would drop genuine repeat lines and understate the quantities.

### 4.6 `Customer Name` needs an explicit trim

12 of 5,674 rows mismatched before trimming; 4 after. EDW's `DimAddress.AddressDesc` carries a **leading space** on some rows (`' 3 Print Adriatik (X) Celje SI'`) which Cognos does not render. Apply `LTRIM(RTRIM(...))` to `Customer Name` and `Global Parent Name`. The 4 that survive are genuine source differences (case: `HOANG HA LABEL CO., LTD-Vietnam` vs `Hoang Ha Label Co., Ltd-Vietnam`, and trailing tabs inside the Cognos value) — a **0.07%** cosmetic residual, disclose and leave.

### 4.7 The single residual row

One EDW row and one Cognos row fail to pair, and they are **the same order line**: order `336252` / `DP050-P2` / CINC, where Cognos's `ITEM.BULK_ITEM` renders `-` (NULL in DW_LEGACY) and EDW's `[Item Bulk]` is `DP050`. Every other column agrees. So the row set is 5,675 = 5,675 with **one item-master value difference**, not a missing or extra row. Not worth engineering around; note it in the report-out workbook.

---

## 5. Where the logic lives

Per CLAUDE.md §1 and the memory note *no-business-logic-in-power-query*: **SQL keeps projection, mechanical joins and casts; business rules go in DAX so they can be traced and explained.**

### 5.1 The three measures

**SQL projects three raw inputs, per line:**

```sql
f.QuantityOrderedPrimaryUOM  AS [Ordered Quantity Primary UOM],
f.ConversionFactorLB         AS [Conversion Factor LB],
f.ConversionFactorKG         AS [Conversion Factor KG],
```

**DAX computes the two derived quantities as calculated columns on `Shipments`:**

```dax
Ordered Quantity LBs = Shipments[Ordered Quantity Primary UOM] * Shipments[Conversion Factor LB]
Ordered Quantity KGs = Shipments[Ordered Quantity Primary UOM] * Shipments[Conversion Factor KG]
```

and three measures for the visual:

```dax
[Ordered Quantity]     = SUM ( Shipments[Ordered Quantity Primary UOM] )
[Ordered Quantity LBs] = SUM ( Shipments[Ordered Quantity LBs] )
[Ordered Quantity KGs] = SUM ( Shipments[Ordered Quantity KGs] )
```

Why this split rather than multiplying in SQL: §0.5 is the one place this report is still measurably off, and it is a *business* rule (weight basis for order-size analysis), not a mechanical cast. Keeping the factors as visible columns means anyone auditing a number sees `qty × factor` on the row instead of reverse-engineering a native query — and when **J1** lands, swapping in the `_UOM_Fix` factor is a one-line DAX change, not a query rewrite. Cost: three extra columns on a 7,200-row table.

### 5.2 The India-tax exclusion and the `-` render — both in DAX

Two rules that are *not* scope predicates and must not sit in the native query.

**The exclusion.** SQL projects `[Item Global Bulk]` and `[2nd Item Number]` and nothing else; the rule is the two calculated columns in §4.5 trap 5, applied as a **report-level filter** `Is India Tax Item = FALSE` on the Shipments page.

Why DAX rather than a `WHERE` clause: this is a genuine business rule with a non-obvious two-column fallback and a warehouse-specific NULL/`-` mismatch behind it — exactly the thing that has to be readable to be trusted. Buried in a `Value.NativeQuery` string it is invisible to anyone auditing a number; as a named boolean column it can be put on a page and counted. It also costs nothing here: the rule removes 0 rows (§4.5 trap 5), so the import is byte-identical either way.

⚠ **The cost, stated plainly:** a report-level filter is easier to lose in a visual edit than a `WHERE` clause is. Put it at **report** level, not visual level, name the column exactly as above so its purpose is self-evident, and list it in the report-out workbook's Notes sheet. If it ever starts removing rows, add a validation-log entry with the count.

**The `-` render.** Where EDW stores NULL, Cognos prints `-`. Add display columns rather than coalescing in SQL, so the model keeps the missing/blank/literal-dash distinction that §4.5 trap 5 depends on:

```dax
Bulk Item (Display) = COALESCE ( Shipments[Bulk Item], "-" )
```

Bind the display column in the table visual; keep the raw column in the model for the relationship and for the tax rule. Do **not** do this with a format string — a format string cannot distinguish NULL from an empty string, and that distinction is the whole point.

### 5.3 What stays in SQL

The **scope filters stay in SQL.** They define the extract, they must fold to keep the pull small, and there is no derivation to trace in `IN ('CINC',…)`. The one scope filter with real semantic content — `MPF LIKE '%F%'` = "finished goods" — is documented in §3.4 trap 5 and its input column is projected into the model so the rule is inspectable. It stays in SQL because it removes 700+ lines and moving it would bloat the import for no gain in readability; the India-tax rule moves because it removes none and *is* the readability problem.

---

## 6. `.m` structure and grain

Two tables. Shape = report 14/18's single `Value.NativeQuery` with `[EnableFolding = false]`.

```
let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(Source, "
        SET NOCOUNT ON;
        SELECT <§3.2 or §4.2 projection>
        FROM   <§4.2 join skeleton>
        WHERE  <§3.3 or §4.5 filters>
    ", null, [EnableFolding = false])
in
    Data
```

**Grain decision: import `Shipments` at LINE grain (7,209 rows), not pre-aggregated.**

The Cognos `GROUP BY <15 keys> + SUM` is reproduced by the **table visual**, which groups by its displayed columns and sums the three measures — yielding exactly the 5,675 Cognos rows. Rationale:

- No aggregation in Power Query, consistent with the §5 split.
- The model stays drillable — a user can expand an order row to its lines, which the Cognos sheet cannot do.
- The §2 relationship works at line grain.
- Cost: 7,209 rows instead of 5,675. Irrelevant.
- **Discipline this requires:** every identifier/text/date column must be `summarizeBy: none` (a `summarizeBy: sum` on an identifier corrupts the grouping — CLAUDE.md §7), and the three quantities must be surfaced **as measures**, not raw columns, or the visual shows line grain.

`Safety Stock` imports at its natural 177-row grain, no aggregation anywhere.

No `ORDER BY` in either query — sorts live in the visual (§7). Both `.m` files ship comment-free with a `.commented.m` master carrying the §4.5 trap rationale inline.

---

## 7. Pages, layout, formats — **all confirmed from the export**

Two pages (three with the §2 analysis page), each **one flat `tableEx`** — no matrix, no grouping, no totals row. Plus the house `Last Refreshed` card per page (copy report 14/18's `Last Refreshed.tmdl` verbatim).

**Sorts** (Cognos `<sortList>`, all ascending, `nulls last`, set in the visual):

| Page | Sort |
|---|---|
| Safety Stock | Bulk Item ▸ 2nd Item Number ▸ Branch Plant |
| Shipments | Bulk Item ▸ 2nd Item Number ▸ Order Number |

**Formats — read off the export's cell `number_format`, not guessed:**

| Column | Export format | PBI `formatString` |
|---|---|---|
| Ordered Date, Promised Ship Date, Scheduled Pick Date, DATE | `d\ mmm\,\ yyyy` | `d MMM, yyyy` — **day-first**, all four |
| **Safety Stock** | **`#0`** | **`0`** — ⚠ **no thousands separator**. An earlier draft of this spec said `#,0`; the export disproves it. |
| Lead Time Order to Ship | `#0` | `0` |
| Ordered Quantity / … LBs / … KGs | **`#,##0`** | `#,##0` — **with** separator, 0 decimals |
| Order Company, Order Number, Customer Code, Planner Number | `General`, stored as **text** | see below |

**Identifier columns are text in the export.** `Order Company` is `'00010'` — **leading zeros, so it must be text**; a numeric type would render `10`. `Order Number`, `Customer Code` and `Planner Number` are also exported as strings but contain no leading zeros, so `Int64` + `formatString 0` renders identically (report-07 precedent) and keeps them sortable. **Recommendation: `Order Company` as text; the other three as `Int64` with `formatString 0`.**

**Alignment:** Cognos left-aligns the numeric-ID and date columns (`text-align:left` on their `listColumnBody`); Power BI right-aligns `int64`/`dateTime` by default. Report 07 §6.1 documents the fix — per-column `objects.values[]` with `selector.metadata` = the column queryRef and `properties.alignment = Literal "'Left'"`. Applies to: Order Number, Customer Code, Planner Number, Lead Time Order to Ship, and all four date columns. LOW priority, cosmetic, visible side-by-side.

**Blank rendering:** where EDW stores NULL, Cognos renders `-` (§4.5 trap 5). Use the **DAX display column** in §5.2 — not SQL, and not a format string, which cannot tell NULL from an empty string. Bind `Bulk Item (Display)` in the visual and keep the raw `Bulk Item` in the model. Affects `Bulk Item` on the Shipments page (1 row in this capture — and that one is a genuine value difference, §4.7, not a NULL).

**House style:** column headers **bold red on a 1pt black border**, body cells 1pt black border. Reproduce via the table style — cosmetic, **not** data-driven CF, so the PBIR `dataViewWildcard` selector trap does not arise.

**Model hygiene:** Auto date/time OFF (`__PBI_TimeIntelligenceEnabled = 0`, no `LocalDateTable`). Theme: copy `CY24SU10.json` from report 14/17/18. `noDataHandler` "No Data Available" — standard non-reproduced LOW.

**The `DATE` column** is `to_date(sysdate)` — a refresh stamp, constant across every row, `2026-08-06` in the export. Compute as `CAST(GETDATE() AS date)` (**not** `-1` like report 18, which used `sysdate-1`).

---

## 8. Deliverables

| Artifact | Path |
|---|---|
| PBIP | `PBIP\19 - Safety Stock and Order Size.*` (PBIR format) — **name deliberately short; see V41 before renaming it** |
| Power Query masters | `Safety Stock.m` + `.commented.m`; `Shipments.m` + `.commented.m` |
| Verify SQL | `00_verify_tables.sql` (the §12 probes, re-runnable; sources in `C:\Users\Zack\pbilab\r19\`) |
| Probe PBIP | `PROBE\` — **only the §9.3 jumpbox items** |
| Report-out workbook | `Excel Validation\_report_out\19 - Safety Stock and Order Size.xlsx`, STANDARD layout (template `08 - SK Forecast.xlsx`): Notes ▸ `[Cognos \| Compare \| PBI]` blocks ▸ RS tab. Compare block is per-column live `EXACT()` — never hardcoded TRUE/FALSE. |
| Query exports | `Query Exports for Rohit\` — comment-free `.txt` of both native queries |

---

## 9. Probe status

### 9.1 The six mandated categories (CLAUDE.md §1) — all closed locally

| Category | Status |
|---|---|
| Column existence | ✅ every column in §3.2 and §4.2 confirmed with measured type and length |
| Join drops | ✅ all six quantified; two corrections found (§0.3, §0.4) |
| Fan-out | ✅ all four dims unique on their SKey; `ItemBranchSKey` chosen on measured evidence |
| Code decodes | ✅ MPF domain, LineType `%F%` set, Stocking Type domain, AC01/AC06 identity, `'-'`-is-NULL |
| Count parity | ✅ **exact on both sheets** against the tight capture |
| Format spot-checks | ✅ every column's `number_format` read from the export; 10 rows compared column-by-column with **zero** differences |

### 9.2 No probe PBIP is needed for the build

Every probe ran against the **local SQL mirror** (CLAUDE.md §9), which is why this spec carries measured numbers. The mirror proves the SQL correct; it proves nothing about freshness or performance.

### 9.3 The two jumpbox items

| # | Item | Query | Why |
|---|---|---|---|
| **J1** | **The UOM-fix weight factors** (§0.5) — worth +0.376% on both weight totals and ~285 rows | `SELECT TOP 50 f.FSDSKey, f.ConversionFactorLB, f.ConversionFactorKG, f.[Unit_Weight_Adj], f.[UOM_Weight_Adj], f.[Fix U/M], f.[Fix Qty], f.[Fix Actual Qty] FROM BIQL.FactSalesDetail f WITH (NOLOCK) WHERE f.OrderNum IN (2585134) AND f.ItemNum2nd = 'DP680-B1';` then reconcile against the export's `176` LBs / `79.833105264` KGs for that row | `BIQL.FactSalesDetail` and `BIQL.FactSalesDetail_UOM_Fix` are not in the mirror. If the fix reproduces Cognos, switch the `FROM` to `BIQL.FactSalesDetail` and use the adjusted factor — the report then ties on all 19 columns. |
| **J2** | SSAS `BIQLTabular_v2` re-check | `SELECT * FROM $SYSTEM.TMSCHEMA_PERSPECTIVE_COLUMNS` on `SSASPROD` / `BIQLTabular_v2`, filtered to `Item Branch` — does any perspective expose **`Lead Time MFG_BP`**? | `ssasprod.bim` is the stale `BIQLTabular`. If v2 exposes it in `Supply and Demand`, SSAS live becomes the mandated route and the report collapses to two tables with zero Power Query. |

Neither blocks the build. J1 should be answered before publish; J2 is a route re-decision that would be a rewrite, not a patch.

> ✅ **J1 IS CLOSED (2026-08-06) — answered, and its stated hypothesis rejected. See V38 + V40.**
> Probes filed as `PROBE\probe_J1_uom_fix.sql`, `PROBE\probe_J1b_unit_weight_adj.sql` with results in
> `PROBE\J1 results` / `j1b results (jumpbox 2026-08-06).xlsx`. Outcome: the conversion factors are
> **identical** on the view and the table, so the `FROM`-clause swap this row proposed fixes nothing;
> the fix is `Unit_Weight_Adj`, a **line total** weight, applied in DAX. Shipped — the two weight
> columns now land **−0.0021%** against the capture instead of +0.376%.
> **J2 remains OPEN** and is still a route re-decision, not a patch.

---

## 10. Validation targets

**Locked, from `Intake\Cognos export - tight capture 2026-08-06.xlsx`** (`DATE` = 2026-08-06, afternoon run ⇒ boundary `2026-02-05`):

| Sheet | Rows | Cols | Σ Ordered Quantity | Σ LBs | Σ KGs | Distinct orders |
|---|---|---|---|---|---|---|
| `Safety Stock_1` | **177** | 10 | — | — | — | — |
| `Shipments_2` | **5,675** | 19 | **39,590,713.21** | 48,307,620.74 | 21,912,200.98 | 4,155 |

Shipments branch split: CIN2 3,229 · AUBA 1,567 · SNG4 653 · CINC 209 · SING 17. Promised Ship Date spans **2026-02-05 → 2026-08-07** (no upper bound — future-dated rows are in scope).

**Because both queries are refresh-time-relative, any re-capture must be tight** (CLAUDE.md §7) — pull the Cognos export and the PBI numbers minutes apart, and **record the Cognos run's time of day** (§4.5 trap 1). Round half-up on both sides before comparing; the export's display formats are `#0` / `#,##0`.

Diagnostic ladder if a future run misses — each entry has a known magnitude:

| Miss | Cause |
|---|---|
| PBI **+263 rows** | `Cancelled_Flag <> 1` used instead of `StatusCodeLast NOT IN ('980','984')` — §0.2 |
| PBI **+51 rows / +0.90%** | `-183` window vs an afternoon Cognos capture — §4.5 trap 1, **expected and defensible** |
| PBI **−13 rows** | Territory Manager joined INNER instead of LEFT — §0.4 |
| ~~PBI **+36 rows**~~ | ~~`StatusCodeNext = '999'` used as the open filter instead of `SalesTableSource <> 1` — §4.3~~ — **retired, V39.** The build now ships `StatusCodeNext = '999'`; the two are equivalent here (0 disagreements / 8,077 lines) and the +36 was a first-pass measurement |
| PBI **+319 rows** | AC01 `<> 'INT'` not applied |
| PBI **hugely** high | `RecordType = 'Sales Detail'` missing → 109,602 GL rows — §4.5 trap 3 |
| PBI **0 rows** on Shipments | the trim dropped from `LTRIM(RTRIM(StatusCodeNext)) = '999'` — `nchar(3)`, so the untrimmed test matches nothing — V39 |
| `Global Parent Name` wrong on ~80% of rows | `ParentAddressSKey` used instead of `AddressNum5th` — §0.3 |
| Quantities wrong on ~2/3 of rows | the `SalesFactor` trap — §0.1 |
| ~~LBs/KGs high by **0.376%**~~ | ~~the known `dbo.FactSalesDetail` UOM defect — §0.5, **expected until J1**~~ — **closed, V40.** Weights now come from `Unit_Weight_Adj`; totals are −0.0021%. If you see **+0.376%** again, the weight columns have been reverted to `qty × ConversionFactorLB/KG` |
| LBs/KGs wildly wrong on ~40% of rows | `Unit_Weight_Adj` multiplied by quantity — it is already a **line total**, not per-unit — V40 |

---

## 11. Open questions for the requester

1. **Who owns this report and who receives the Excel?** (Cogan? Ivan? the planning team?) Determines whether §2's third page is wanted.
2. **Is `Lead Time Order to Ship` actually used downstream, or vestigial?** It is the single column that blocks the SSAS live route (§1.1). If it can be dropped, re-run J2.
3. **Is the two-sheet split deliberate, or would one model with a real item↔order relationship be better?** §2 recommends adding the relationship; measured, it covers 39% of shipment lines and every stocked item-branch.
4. **The 6-month window and the six branch plants are hardcoded — should they become slicers?** Neither is a parameter in Cognos, so this is a scope change, not a port. Note `AUB2` returns 0 shipment rows and `SING` only 17 — is the six-plant list still right?
5. **`Ordered Quantity` is expressed in the item's PRIMARY UOM but printed next to the ORDERING UOM code.** The export confirms it: `6,000` beside `DR`, where 6,000 is KG; `108` beside `PL`, where 108 is KG. This is Cognos's behaviour and we reproduce it faithfully, but it is misleading. Add the primary UOM as a column, or relabel the header?
6. **`Master Planning Family LIKE '%F%'` means "finished goods"** and today admits exactly `FBW`/`FCB`/`FEC`/`FRC` (§3.4 trap 5). Pin it to that explicit list so a future code containing `F` cannot silently join the report?
7. **`Planner Name`: Cognos renders `Murphy, Lance`; EDW renders `Lance Murphy`** (§3.4 trap 3). We will reproduce Cognos via `F0101.ABALPH`. Confirm the recipient wants `Last, First` — it is a one-line change either way.
8. **Territory manager gaps.** 22 `TerritoryManagerSKey` values on the fact do not resolve in `BIQL.TbTerritoryManager`, and Cognos shows `Not Available` for some and real names for others (§0.4). Should the EDW dimension be fixed upstream? We render `Not Available`, which loses 8 real names out of 5,674 rows.

---

## 12. Validation log (numbered, APPEND-ONLY)

> Add entries; never edit or renumber an existing one. Entries 1–14 are the intake probes (run **2026-08-06** against the local SQL mirror — `localhost` / `EDW` + `ODS`, snapshot loaded 2026-08-05). Entries 15–25 are the tight-capture reconciliation. Scripts in `C:\Users\Zack\pbilab\r19\p*.sql`; fold into `00_verify_tables.sql` at build time.

**1 — Mirror inventory.** `EDW` holds 34 objects, `ODS` 46. Present: `dbo.FactSalesDetail` (979,343 rows / 186 columns), `BIQL.TbItemBranch` (116,002), `BIQL.DimCustomer` (22,227), `BIQL.DimAddress` (37,339), `BIQL.TbTerritoryManager` (19,321), `ODS.PRODDTA.F4102` (116,000), `ODS.PRODDTA.F0101`. **Absent: `BIQL.TbCustomerShipTo`** (not needed — V21) **and `BIQL.FactSalesDetail` / `BIQL.FactSalesDetail_UOM_Fix`** (needed — J1). ✅

**2 — Safety-stock column disambiguation (GATE, CLOSED).** Over all 116,002 rows: `SafetyStock` and `[Safety Stock SAFE]` are identical — 115,309 NULL each, 693 non-null each, **693 equal, 0 differ**; `> 1` gives **647** on each. Cross-checked to ODS: `F4102.IBSAFE` has 693 non-zero rows and `SafetyStock = IBSAFE / 10000`, **1 mismatch in 116,000** (snapshot timing). Under the full query-1 filter set **both give 177, and the export is 177** (V15). **Decision: use `SafetyStock`.** ✅

**3 — `OPEN_INDICATOR` candidate elimination.** `Source` constant `1` on all 979,343 rows — eliminated. `QuantityOpen <> 0` on **zero** rows — unpopulated, eliminated. `SalesTableSource` splits `{1: 3,603 (13 distinct next-statuses); 2: 424,423; 3: 956; 4: 440,759; 5: 109,602 GL Detail}` — only value 1 carries in-flight statuses. `OrderLineID` unique across all Sales Detail rows (0 duplicates); no `SalesTableSource = 1` line reappears in 2/3/4. ✅ Confirmed by tie-out (V19).

**4 — Query 1 stepwise counts + join drop + DISTINCT.** 116,002 → branch6 44,330 → `SafetyStock > 1` 509 → `Stocking Type <> 'O'` 502 → `MPF LIKE '%F%'` **177**. **Planner join drop = 0.** `SELECT DISTINCT` over the 10 output columns = **177**, a no-op. Branch split CIN2 129 · AUBA 24 · SNG4 11 · AUB2 9 · CINC 4 · SING 0. Threshold: `> 1` → 177, `> 0` → 178. ✅

**5 — Query 2 join drops (LEFT JOIN, unresolved counts) on the 8,596-row base.** `ItemBranchSKey` 0 · ShipTo customer 0 · ShipTo address 0 · Parent customer 0 · Parent address 0 · **Territory Manager 387**. Attribute blanks: AC01 blank 6, AC01 = `'INT'` 319, AC06 desc 0, country code 0, country desc 0, TM mailing name 0. ✅ Superseded in part by V22 (TM must be LEFT-joined).

**6 — Master Planning Family domain.** 23 distinct MPF values across the 6 branches; `LIKE '%F%'` admits exactly **`FBW` / `FCB` / `FEC` / `FRC`**, contributing 2 / 97 / 33 / 45 to the 177 (sum = 177 ✓). No code carries an embedded `F`, so `'%F%'` ≡ `'F%'` today. Stocking Type domain: `O` Obsolete 37,155 (the carve-out), `P` 1,917, `S` 1,787, `D` 1,628, `M` 1,044, `2` 326, `1` 152, `U` 110, `T` 94, `Q` 64, `A` 53. ✅

**7 — Query 2 stepwise counts + the open-indicator delta.** At boundary `2026-02-04`: 869,741 Sales Detail → branch6 725,224 → in-window 15,704 → closed **14,471** (`SalesTableSource <> 1`) vs **14,634** (`StatusCodeNext = '999'`) → order type 10,332 → line type 8,723 → not cancelled (old `Cancelled_Flag` form) 8,572 → qty > 0 8,501. The 163-line gap between open-candidates narrows to **95 lines** after the full chain (`StatusCodeLast = 980` on every one). ✅

**8 — Fan-out / key choice.** All four dims unique on their SKey: `DimCustomer` 22,227 = 22,227 · `DimAddress` 37,339 = 37,339 · `TbItemBranch` 116,002 = 116,002 · `TbTerritoryManager` 19,321 = 19,321. **`ItemSKey + [Business Unit]` yields only 115,989 distinct pairs for 116,002 rows (13 collisions)** ⇒ `ItemBranchSKey` is the correct pairing key. No join fans out. ✅

**9 — Decode and lineage identities.** `BIQL.DimCustomer.SalesBusinessUnit` = `dbo.DimCustomer.AddressCode01` (**0 mismatches / 22,227**) and `CustomerSegmentation` = `AddressCode06` (**0 mismatches**). `BIQL.DimAddress.AddressDesc` = `F0101.ABALPH` (**37,337 / 37,337**). `TbTerritoryManager.[Territory Manager]` = `ABALPH` (**19,321 / 19,321**); `[Mailing Name]` matches neither `ABALPH` nor `ABALP1` ⇒ it is the true `VENDOR.MAILING_NAME` analog. **`TbItemBranch.[Planner Name]` = `ABALPH` on only 117 / 93,054.** `OrderCompany` = `LEFT(OrderLineID,5)`, **0 mismatches / 869,741** — which also confirms the comma-delimited `ORDER_LINE_ID` structure report 21 documented (order company = first 5). ✅

**10 — Item-column and line-type domains.** `[Item Bulk]` = `[Item Num Bulk]` on **all 116,002 rows** (385 blank on each) ⇒ the COLLECTION_NOTES ambiguity is moot. `LineType LIKE '%F%'` set: `FS` 130,333 · `FT` 3,550 · `FI` 3,193 · `CF` 2,209 · `FA` 509 · `FO` 456 · `FN` 193 · `FD` 157 · `FF` 1 · `F ` 1. `[Item Global Bulk] = '-'` on **0** rows (17 NULL); no item-branch has `[Item Global Bulk]` or `[Item Num 2nd]` in the tax list ⇒ **India-tax exclusion removes 0 rows.** `BudgetFactor` = `0.0000` on **all 979,343 rows** ⇒ `BUDGET_FACTOR <> 1` is a no-op. ✅

**11 — Measure mapping (GATE, CLOSED).** `SalesFactor` is `1.0000` on 977,203 rows and `0.0000` on 2,140 — not a UOM conversion. `QuantityOrderedPrimaryUOM / QuantityOrdered` reproduces F41002 `UMCONV` exactly (TO→LB 2500, TO→KG 1000, DR→KG 200, B1→LB 44, KG→LB 2.204619); **10,308 of 15,704 in-window lines (65.7%) differ**. `ConversionFactorLB/KG` are per-primary-UOM (LB→LB 1 / LB→KG 0.4535971; KG→LB 2.2046200 / KG→KG 1). Factor NULLs: 2,031 of 15,704 in-window, **0** of the final lines. ✅ Proven exact by V20.

**12 — SSAS perspective check (provisional).** `ssasprod.bim` is the **stale** model (`model.name = "BIQLTabular"`). Occurrences: `Lead Time MFG_BP` **2** vs `SafetyStock` 9, `Safety Stock SAFE` 4, `Lead time Level` 9, `Master Planning Family` 26. Across all 34 perspectives, `Lead Time MFG_BP` appears on `Item Branch` in **zero**. `Sales Order`'s `Item Branch` (87 cols) exposes neither safety-stock column; `Supply and Demand`'s (131 cols) exposes both, and its `Sales` (144 cols) exposes `Open Order Flag`, `Cancelled_Flag`, `QuantityOrderedPrimaryUOM`, `Qty Ordered Primary UOM LB/KG`. SSAS `Sales` is partitioned `Sales_Detail_P1` ← `BIQL.TbSales_Detail` / `Sales_History_P1..P6` ← `BIQL.TbSales_History`; `Open Order Flag` is a **source column**, `varchar(1) NOT NULL` at ordinal 88 on both `TbSales_Detail_v2` and `TbSales_History_v2`, and **not** on `dbo.FactSalesDetail`. ⚠️ Provisional — re-check as J2. ✅

**13 — Lead-time field identity.** `[Lead Time MFG_BP]` = `F4102.IBLTMF`, `[Lead time Level]` = `IBLTLV`, confirmed on rows where they disagree (item 844318: 12 vs 0; item 844297: 12 vs 6). In the 177-row set: 0 NULL lead times, 0 zeros, 0 blank `UOM Primary`. The export renders plain integers (69, 6), consistent with `int`. ✅

**14 — §2 overlap.** The 177 query-1 item-branches account for **2,974 of the 7,633 query-2 lines (39.0%)** on `ItemBranchSKey`, or 3,360 (44.0%) matched on Bulk + 2nd item across branches ⇒ the item↔order relationship is materially useful. ✅

---

**15 — TIGHT CAPTURE PROFILED (2026-08-06).** `Intake\Cognos export - tight capture 2026-08-06.xlsx`, two sheets. `Safety Stock_1` = **177 data rows × 10 cols**; `Shipments_2` = **5,675 × 19**. `DATE` column constant `2026-08-06`. Cell formats read directly: Safety Stock **`#0`** (no thousands separator — an earlier draft of this spec was wrong), Lead Time `#0`, the three quantities **`#,##0`**, all four dates `d\ mmm\,\ yyyy`. `Order Company` stored as **text with leading zeros** (`'00010'`); `Order Number`, `Customer Code`, `Planner Number` stored as text but with no leading zeros. Shipments Σ Qty **39,590,713.21**, Σ LBs 48,307,620.74, Σ KGs 21,912,200.98, 4,155 distinct orders, 0 blank LBs/KGs, 1 row with `Bulk Item = '-'`. ✅

**16 — NATIVE SQL FILED.** `Intake\Native SQL (filed 2026-08-06).txt`. Confirms: `OPEN_INDICATOR` is a **plain physical column** on `DW_LEGACY.ORDER_ACTIVITY` (a stored Y/N flag, not derived) ⇒ look for a stored discriminator, which `SalesTableSource` is; all five join-drop risks are **comma-join equality predicates = inner joins**; and the native `GROUP BY` has **15 keys, not 16** — Oracle drops the constant `to_date(sysdate)`. ✅

**17 — DATE WINDOW MECHANISM SETTLED.** Native text: `"ORDER_ACTIVITY"."DUE_DATE" >= to_date(sysdate - (182.5*1.0e0))`. The subtraction is **inside** `to_date()`, so a morning run truncates to D−183 and an afternoon run to D−182. (Contrast report 21's deterministic `to_date(sysdate) - 365`.) **The capture proves an afternoon run:** `DATE = 2026-08-06`, minimum Promised Ship Date = **2026-02-05** = D−182. **Exposure measured:** the boundary day 2026-02-04 holds **51 output rows across 41 distinct orders = 0.90%** (5,726 rows at `-183` vs 5,675 at `-182`). **Decision: ship `-183`** (more inclusive — can never silently drop orders Cognos would show); expect and disclose a +0.90% variance against an afternoon capture. **Known, explained variance per CLAUDE.md §7 — not a defect.** ✅

**18 — QUERY 1 TIES: 177 / 177, eight of ten columns exact.** Row-for-row comparison in the Cognos sort order. Per-column mismatches over the 177 aligned rows: Branch Plant **0**, Bulk Item **0**, 2nd Item Number **0**, Stock Type Code **0**, Master Planning Family **0**, Lead Time **0**, Unit of Measure Primary **0**; Planner Number **1**, Safety Stock **1**, **Planner Name 177**. The two single-row misses are the *same* row and are **snapshot drift**: Cognos `Planner Number 291244` / `Safety Stock 9000` vs EDW `340941` / `8550`, corroborated by the planner tallies (Cognos 9 × `Bertrand, Joel` / 0 × Jacquet; EDW 8 × `Joël Bertrand` / 1 × `Lise Jacquet`). One item-branch was edited between the 2026-08-05 mirror load and the 2026-08-06 Cognos run. **The predicted planner-join over-inclusion is exactly zero.** ✅

**19 — QUERY 2 TIES: 5,675 / 5,675 (boundary `2026-02-05`).** Reached by three corrections to the first-pass filter set (V22–V24). Progression of output-row counts against the 5,675 target: no cancel filter **6,024** → `Cancelled_Flag <> 1` **5,938** → `QuantityCanceledScrapped = 0` **5,663** → `StatusCodeLast NOT IN ('980','984')` + TM LEFT JOIN **5,675** ✅. Branch split matches on **every** branch: CIN2 3,229 / AUBA 1,567 / SNG4 653 / CINC 209 / SING 17. Key-level pairing: **5,674 matched, 1 EDW-only, 1 Cognos-only** — and those two are the *same* order line (V25). ✅

**20 — `Ordered Quantity` EXACT: 5,674 / 5,674 (100.00%).** `SUM(QuantityOrderedPrimaryUOM)` reproduces Cognos's `sum(ORDERED_QTY * SALES_FACTOR)` to the cent; column totals **39,590,712.21 on both sides, +0.000%**. This closes V11's gate empirically. ✅

**21 — Text columns over the 5,674 matched rows.** `Customer Segmentation Description` **0 mismatches** (which also confirms the `c16` → AC06 mapping *without* `BIQL.TbCustomerShipTo`, so that column is **not** jumpbox-only). `Country Name` **0**. `Customer Name` 12 exact-mismatches → **4** after `LTRIM`/`RTRIM` (EDW carries a leading space on some `AddressDesc` values). `Global Parent Name` 6 → **4** after trim. `TM Name` **8** (V22). The 4 residuals on each name column are genuine source differences (case: `HOANG HA LABEL CO., LTD-Vietnam` vs `Hoang Ha Label Co., Ltd-Vietnam`; trailing tabs inside the Cognos value) = **0.07%**. ✅

**22 — CORRECTION: Territory Manager must be LEFT-joined.** An INNER join (the faithful reading of Cognos's comma-join) dropped exactly **13 output rows / 17 lines**. **`BIQL.TbTerritoryManager` is incomplete** — 22 distinct `TerritoryManagerSKey` values on the fact do not resolve in it, including the `-1` unknown member. Cognos resolves all of them, rendering `Not Available` for unknowns and real names (`Brendan Schloerb`, `Bryan Fuka`, `Dave Jeffers`) otherwise. Fix: `LEFT JOIN` + `ISNULL(tm.[Mailing Name],'Not Available')`, which restores the 13 rows at the cost of **8 wrong TM names**. This is the one place EDW's dimension is *thinner* than Oracle's, so the usual over-inclusion logic runs backwards. ✅

**23 — CORRECTION: `CANCELLED_INDICATOR` is `StatusCodeLast`, not `Cancelled_Flag`.** `Cancelled_Flag = 1` on only **366 rows model-wide** and catches **118 of the 486** cancelled lines in scope; using it alone leaves the report **+263 rows (+4.6%)**, spread proportionally across every branch. In the final population, statuses **`980` (311 lines) and `984` (57)** have `QuantityShipped = 0`, `QuantityCanceledScrapped <> 0` and `AmountExtendedPrice = 0` on **100%** of rows, while `620` / `900` / `912` / `902` have `QuantityCanceledScrapped = 0` on 100%. `StatusCodeLast NOT IN ('980','984')` ties at 5,675; `QuantityCanceledScrapped = 0` gets to 5,663. ✅

**24 — CORRECTION: `Global Parent Name` is `AddressNum5th`, not `ParentAddressSKey`.** Tested all seven candidate address fields over 5,661 matched rows: `AddressNum5th → AddressDesc` **5,655 (99.9%)**; `AddressNum1st` 1,160 (20.5%); `ParentAddressSKey` 1,154 (20.4%); `AddressNum3rd` 1,083; `AddressNum4th` 1,074; `AddressNum2nd` 892; `AddressNumParent` **0**. Confirming tell: the **self-parent share matches exactly** — 1,076 rows on both sides, where `ParentAddressSKey` gave EDW 2,406 against Cognos's 1,084. Values read correctly (`Henkel - Global Parent`, `Grafix - Global Parent`, `Barentz - Global Parent`). The join is by address *number*, so it needs `DWIsCurrent = 1`. ✅

**25 — OPEN (disclose, do not block): the `dbo.FactSalesDetail` weight factors are wrong on ~5% of rows, and EDW ships a fix we cannot reach locally.** With everything else correct: `Ordered Quantity` **100.00%** exact; `Ordered Quantity LBs` 3,295/5,674 exact (58.07%), **5,354 (94.36%) after `#,##0` display rounding**; `KGs` 5,385 (94.91%) / **5,417 (95.47%)**. Two causes — **precision** (2,094 LB / 25 KG rows at ratio 1.0000 to 4 dp; the `0.4535971` vs `0.45359237` issue from report 18 §5.1; concentrated in AUBA 1,539 / SNG4 644; invisible after display rounding, not a defect) and **structural** (285 LB / 264 KG rows, item-specific ratios of 2.0, 1/22, 60, 0.9072, 1.6787 — `B1` alone splits 189 rows at 1.0, 161 at 2.0, 47 at ~0.0455). Column totals **+0.376% on both LBs and KGs** — identical, confirming one cause. **Root cause identified in EDW's own schema:** `BIQL.FactSalesDetail_UOM_Fix` (18 columns, keyed `FSDSKey`: `Unit Weight_Adj`, `UOMWeight_Adj`, `Fix U/M`, `Fix Qty`, `Fix Actual Qty`) and the view `BIQL.FactSalesDetail`, which exposes those adjustment columns — **none present on `dbo.FactSalesDetail` (186 cols) or in the mirror**. `BIQL.TbSales_Detail_v2` likewise carries `ConversionFactorWeightLB/KG` and `ConversionFactorPrimaryLB/KG` where `dbo` has only `ConversionFactorLB/KG`. **Action: jumpbox probe J1** (§9.3); worked example row for the reconciliation is order `2585134` / `DP680-B1` (`UOMTransaction B1`, `UOMPrimary EA`, `UnitWeight 176`, `ConversionFactorLB 88`, Cognos LBs **176** ⇒ Cognos's factor is exactly half EDW's). ⬜ OPEN

**26 — Ten-row column-by-column sample, Shipments: ZERO differences.** Rows 1–10 in the Cognos sort order compared across all 18 data columns (Order Company, Branch Plant, Order Number, Bulk Item, 2nd Item Number, Ordered Date, Ordered Quantity, UOM, LBs, KGs, Promised Ship Date, Scheduled Pick Date, Customer Code, Customer Name, Global Parent Name, Segmentation, TM Name, Country Name) — **`NONE` on every row**. ✅

**27 — `'-'` is Cognos rendering a NULL, not a stored sentinel** (aligned with the 2026-08-06 corrections on reports 14 / 20 / 21). In report 19's query-2 population: `[Item Bulk]` NULL **0**, empty **0**, `'-'` **0**; `[Item Global Bulk]` NULL 0, empty 0, all-whitespace 0, `'-'` 0. Model-wide, `TbItemBranch` has 385 / 17 NULLs and **zero** `'-'` and **zero** empty strings. So the Oracle `decode(GLOBAL_BULK_ITEM,'-',…)` ports to a **missing test** on EDW, not a string comparison. **No tie-out normalization was needed** — `[Item Bulk]` is NULL on 0 of the 7,209 in-scope lines and 0 of the 177 Safety Stock rows, so no row false-mismatched against the export's `-`. Do not assume that holds on the next capture. ✅

**28 — INDIA-TAX EXCLUSION: removes 0 rows, and the reason is measured (not a pass).** Output rows under every predicate variant against the 5,675 target: no exclusion **5,675**; literal `= '-'` port **5,675**; NULL-only **5,675**; robust (NULL **or** blank **or** whitespace **or** `-`) **5,675**. Zero removed under all four.

**Why zero, with two independent causes.** The tax pseudo-items *do* exist in EDW — `FactSalesDetail.ItemNum2nd` is one of `IGST`/`CGST`/`SGST`/`CVD`/`ADD` on **15,316 lines**, and `dbo.DimItem` holds 5 such items — but every one of those lines is in an **Indian branch plant**: `MUM3` 14,167 (IGST 9,139 / SGST 2,514 / CGST 2,514), `MUM2` 843, `HARY` 306. Against report 19's scope: **0 of them fall in the six branch plants**, and **0 have an item-branch whose `Master Planning Family` matches `'%F%'`** (their MPF is blank). Either filter alone already removes them.

**This also proves the robust predicate is the right one.** Those 15,316 lines carry `[Item Global Bulk] = NULL` — exactly the `decode`'s fallback case, and exactly what a literal `= '-'` test would miss on EDW. The exclusion is therefore **not** structurally dead against EDW; it is dead only against *this report's* branch/MPF scope, and it would fire correctly the moment an Indian plant joined the six — but only in the robust form. Ported literally it would be dead code, silently under-firing on the rows it was written for. ✅

**29 — Rule placement (per CLAUDE.md §1 / *no-business-logic-in-power-query*).** The India-tax exclusion moved **out of the native query into DAX** (§5.2): SQL projects `[Item Global Bulk]` and `[2nd Item Number]`; the rule is a `Tax Item Key` calculated column plus an `Is India Tax Item` boolean, applied as a **report-level** filter. Free to move because it removes 0 rows, so the import is byte-identical. The `-` render is likewise a DAX display column, `COALESCE(col,"-")`, **not** a format string — a format string cannot distinguish NULL from an empty string, and that distinction is what V28 turns on. Scope filters (branch, window, order type, line type, cancel, AC01, MPF) stay in SQL: they remove 700+ lines each, must fold, and carry no derivation to trace. ⚠ Residual risk: a report-level filter is easier to lose in a visual edit than a `WHERE` clause — recorded in §5.2 with the mitigation. ✅

**30 — [OPEN] J2 — `BIQLTabular_v2` perspective re-check.** See §9.3. Could reopen the SSAS route. ⬜ OPEN

---

> Entries 31–37 are the **BUILD** (2026-08-06). Every SQL figure below was re-measured against the
> local SQL mirror (`localhost` / `EDW` + `ODS`, snapshot loaded 2026-08-05) from the *shipped* `.m`
> text, not from the intake scripts — so they verify the deliverable, not the spec.

**31 — SHIPPED SQL RE-VERIFIED FROM THE `.m` FILES: both queries still tie.** Ran the exact projection,
join skeleton and filter set now in `Safety Stock.m` and `Shipments.m`.

| Check | Shipped `.m` | Capture / §10 target |
|---|---|---|
| Q1 rows | **177** | 177 ✅ |
| Q1 branch split | CIN2 129 · AUBA 24 · SNG4 11 · AUB2 9 · CINC 4 · SING 0 | identical ✅ |
| Q2 lines @ boundary `2026-02-05` | **7,209** | §4.5 B2 = 7,209 ✅ |
| Q2 rows after the 15-key group-by | **5,675** | 5,675 ✅ |
| Q2 Σ Ordered Quantity | **39,590,713.21** | 39,590,713.21 — **+0.000%** ✅ |
| Q2 Σ LBs | 48,489,410.07 | 48,307,620.74 — **+0.376%** ⚠ expected, V25 |
| Q2 Σ KGs | 21,994,591.37 | 21,912,200.98 — **+0.376%** ⚠ expected, V25 |
| Q2 distinct orders | **4,155** | 4,155 ✅ |
| Q2 branch split | CIN2 3,229 · AUBA 1,567 · SNG4 653 · CINC 209 · SING 17 · AUB2 0 | exact on every branch ✅ |
| Promised Ship Date span | 2026-02-05 → 2026-08-07 | identical ✅ |
| India-tax rule | removes **0** lines | V28 ✅ |
| `[Item Bulk]` / `[Item Global Bulk]` NULLs in scope | 0 / 0 | V27 ✅ |

The two weight variances are **identical to three decimal places on both columns**, which is the V25
signature of one shared cause — not two independent errors. **The shipped `-183` boundary was measured
separately and behaves exactly as V17 predicted: 7,279 lines → 5,726 rows = +51 rows / +0.90%.** ✅

**32 — CORRECTION TO §3.4 TRAP 3: the planner-name fix cannot be a join, because EDW and ODS are
different servers.** The spec prescribes "one `LEFT JOIN` on a 177-row table" against
`ODS.PRODDTA.F0101` inside query 1. That reads as a cross-database join and is not available:
`Sql.Database("EDWPROD","EDW")` and `Sql.Database("ODSPROD","ODS")` are **separate servers**
(CLAUDE.md §2), so a three-part name would need a linked server that cannot be verified from here and
that **no `.m` in this repo relies on** — surveyed: 66 files use `ODSPROD`, 16 use `EDWPROD`, **0 use
both**.

**Resolution — the join moves into the model, keeping the spec's intent intact.** A third table
`Planner Names` (its own comment-free `.m` + commented master, per the house one-`.m`-per-table
convention) projects `F0101.ABAN8` / `ABALPH`, scoped ODS-side through `F4102.IBANPL` for the six
branch plants; a many-to-one relationship `Safety Stock[Planner Number] → Planner Names[Planner
Number]` carries it; and the displayed value is a DAX calculated column, which is where §5 wants a
rendering rule anyway:

```dax
Planner Name = COALESCE ( RELATED ( 'Planner Names'[Planner Name (JDE)] ), 'Safety Stock'[Planner Name (EDW)] )
```

Measured: `F0101.ABAN8` is **unique on all 37,337 rows** (no fan-out); the scoped lookup returns **57
rows**; **all 177 query-1 planner numbers resolve inside it**, so the `COALESCE` fallback is dead
weight today and exists only so a future unresolvable planner degrades to the EDW spelling instead of
blanking. And it reproduces Cognos exactly — `Bertrand, Joel` · `Desjardin, Laurent` · `Hanlon, Tammy`
· `Howe, Dave` · `Jacquet, Lise` · `Lee, Wen Wei` · `Murphy, Lance`: **both the `Last, First` ordering
and the dropped diaeresis, in one step.** The spec's stated alternative (a 7-row `CASE`) was rejected
for the reason the spec itself gives — it rots at the first planner change. A Power Query cross-source
**merge** was also rejected: it would drag in `Formula.Firewall` for no benefit. ✅

**33 — CORRECTION TO §5.1: a calculated column may not share a name with the measure that sums it.**
§5.1 specifies `Ordered Quantity LBs` as *both* a calculated column and a measure. That is invalid —
in Tabular, a measure name must be unique across the whole model and must not collide with any column
name, or `[Name]` is ambiguous. **Resolution: the calculated columns are suffixed
`Ordered Quantity LBs (Line)` / `KGs (Line)`; the three measures keep the exact Cognos header names,
since the measures are what the table visual binds.** Parity is unaffected — the displayed column
headers are `Ordered Quantity`, `Ordered Quantity LBs`, `Ordered Quantity KGs` as specified. ✅

**34 — MODEL BUILT AND LINTED — `powerbi-modeling` MCP `ConnectFolder`: CLEAN.** Loaded
**4 tables / 4 measures / 2 relationships**, no parse errors. Verified through `GetSchema`:

- **Grain discipline (§6) holds** — *every* column on both tables is `summarizeBy: none`, including
  the three raw quantity/factor columns, so no identifier can corrupt the visual's grouping. The three
  quantities are surfaced only as **measures**.
- Types as specified: `Order Company` **string** (leading zeros survive); `Order Number` /
  `Customer Code` / `Planner Number` / `Lead Time Order to Ship` `int64` + `formatString 0`;
  `Safety Stock` `double` + **`0`** (no thousands separator, per V15 — not `#,0`); the three
  quantities `#,##0`; all four dates `d MMM, yyyy` day-first.
- Both relationships resolved **many-to-one, single-direction, active**, as §2 argues.
- The five DAX calculated columns compile: `Tax Item Key`, `Is India Tax Item`, `Bulk Item (Display)`,
  the two `(Line)` weights, plus `Safety Stock[Planner Name]`.
- Relationship keys re-measured: `Safety Stock[ItemBranchSKey]` is **177 rows / 177 distinct / 0
  NULLs**. No `///` description sits above a relationship (the §7 PBIP-open breaker); TMDL is
  **tab-indented throughout** — checked mechanically, 0 lines begin with a space, matching delivered
  report 18 exactly. No file carries a UTF-8 BOM. ✅

**35 — PBIR VALIDATED — Microsoft's `powerbi-report-author validate`: 0 errors / 0 warnings.** Worth
recording because the rule is normally noisy: the Executive Dashboard scores 19/93 and OTIF 70/329
while both publish fine (CLAUDE.md §7). A clean run here means every visual passed **real remote
schema validation** — which is only true because the report artifacts were kept on the report-18
generation (`visualContainer 2.1.0` / `page 2.0.0` / `report 2.1.0` / `pagesMetadata 1.0.0`,
`definition.pbir` 4.0). The jumpbox generation's `visualContainer 2.10.0` **404s on its schema URL**,
so choosing it would have silently skipped validation on every visual. Desktop upgrades these on its
own save, so nothing is lost. Cross-checked independently: **all 52 field references in the visuals
resolve against the TMDL**, and no visual has a duplicate `nativeQueryRef`/`displayName` (the §7 hard
render error). Column counts per §7: Safety Stock **10**, Shipments **19**. ✅

**36 — CORRECTION TO §7 / report 07 §6.1: the left-alignment property is `columnFormatting`, not
`values`.** §7 cites report 07 §6.1's recipe — per-column `objects.values[]` with
`selector.metadata`. Built that way, the validator rejects it: `PBIR_FORMATTING_PROP_UNKNOWN`,
*"Unknown property `alignment` in formatting object `values` for tableEx"*, **6 errors**. Note report
07's recipe appears to have never actually been implemented — `"alignment"` occurs in **zero**
`visual.json` files across `Cognos Reports/`, so this was a documented-but-untested recommendation.
The CLI settles it: `formatting search tableEx align` returns `alignment` on **`columnHeaders`** and
**`columnFormatting`** (enum `Auto` / `Left` / `Center` / `Right`), and not on `values`. Rebuilt with
`objects.columnFormatting[]`, selector unchanged → **0 errors**. Applied per §7 to `Order Number`,
`Customer Code`, `Planner Number`, `Lead Time Order to Ship` and all four date columns. ✅

**37 — DELIVERABLES (§8) — built, and the one that is not.**

| Artifact | Status |
|---|---|
| PBIP, PBIR format, 3 pages | ✅ `PBIP\19 - Inventory - Safety Stock and Order Size.*` — flat under `PBIP\`, matching delivered reports 14/18 rather than §8's nested form (saves 45 chars of path; longest file is **280** chars, inside the 283/285 already proven by delivered reports 14 and 12) |
| Power Query masters | ✅ `Safety Stock`, `Shipments`, **`Planner Names`** — each comment-free `.m` + `.commented.m`, maintained in parallel |
| `00_verify_tables.sql` | ✅ the §12 probes folded into one re-runnable script; **executes end-to-end against the mirror with zero errors**. One `@Boundary` to change; blocks 10 (ODS) and 11 (J1/J2) are commented out for their own servers |
| PROBE PBIP | ✅ `PROBE\R19 Probe.*` — **only** J1 and J2, each carrying its decision rule as a TMDL description. Validates 0/0, MCP loads 2 tables |
| Query exports for Rohit | ✅ `Query Exports for Rohit\19 - …\` — 3 comment-free `.txt` + `_README.txt` + the verbatim Oracle reference SQL |
| **Report-out workbook** | ⬜ **NOT BUILT — blocked.** §8 requires the STANDARD layout with a **live `EXACT()`** Compare block computed against a real Cognos block and a real PBI block. The PBI block must come from the refreshed report; EDW is unreachable from this machine, and filling it with mirror numbers would present a **2026-08-05 snapshot as refreshed PBI output**. Build it after the jumpbox refresh, in the same tight capture as the tie-out |

**Third page built as §2 recommends** — *Safety Stock vs Order Size*, grouped on the Safety Stock side
so only the 177 stocked item-branches appear, with the three Shipments measures beside standing safety
stock, lead time and primary UOM. If Q3 (§11) comes back saying the two-sheet split is deliberate,
delete the page and set the relationship `isActive: false`; the two Cognos pages are untouched by it
either way. The India-tax exclusion is wired at **report** level per §5.2 — `Is India Tax Item` is a
visible boolean column so it can be put on a page and counted, and it is listed here so a visual edit
that loses it is detectable. ⚠ Two things stay open and neither is mine to close: **J1** (the +0.376%
weight variance) and **J2** (the SSAS route). Both are in `PROBE\`. ✅

**38 — J1 ANSWERED (jumpbox, 2026-08-06): §0.5's recommended fix is DISPROVED, and the real fix is a
different column. The +0.376% closes.** `PROBE\probe_J1_uom_fix.sql` + `probe_J1b_unit_weight_adj.sql`
were run on the jumpbox and their results filed as `J1 results` / `j1b results (jumpbox 2026-08-06).xlsx`.
Analysed locally against the tight capture; the numbers below are measured, not argued.

**What is disproved.** §0.5 / §1.2 / §9.3 all recommend sourcing query 2 from `BIQL.FactSalesDetail`
instead of `dbo.FactSalesDetail`. **That changes nothing.** The two carry *identical* conversion
factors — probe section 4, which lists every line where they differ, returned **zero rows**, and the
target row reads `ConversionFactorLB = 88` on both. `[Fix U/M]` is populated on **0 of 15,823**
in-scope lines, so `BIQL.FactSalesDetail_UOM_Fix` is a red herring for this report. **The build's
`FROM dbo.FactSalesDetail` was the right call and is now positively confirmed, not merely a fallback.**

**What is proved.** The view carries `Unit_Weight_Adj` (populated on **all 15,823** in-scope lines,
1,315 distinct items) and `UOM_Weight_Adj`. `Unit_Weight_Adj` is a **LINE TOTAL** expressed in
`UOM_Weight_Adj` units — not a per-unit weight. Settled on the distribution, not one row:
`Unit_Weight_Adj / QuantityOrderedPrimaryUOM` = **1.000000** across every UOM pair whose weight UOM
equals its primary UOM (DR→LB, TO→KG, KG→KG, TO→LB, PL, PA, LB — 11,000+ lines), and where they differ
the ratio is EDW's own KG/LB constant. Tested all three readings by aggregating the 7,663-line probe
export to order × item and comparing against **5,640 matched keys** of the capture:

| Weight formula | LBs exact | LBs after `#,##0` | Σ LBs | KGs exact | KGs after `#,##0` | Σ KGs |
|---|---|---|---|---|---|---|
| **A** — shipped: `qty × ConversionFactorLB/KG` | 57.87% | 94.33% | **+0.3763%** | 37.62% | 95.44% | **+0.3760%** |
| **B** — `Unit_Weight_Adj` as a line total | 61.06% | **98.30%** | **−0.0018%** | 40.96% | **99.43%** | **−0.0021%** |
| **C** — `Unit_Weight_Adj` as per-unit | 0.20% | 0.66% | +1,962,672% | 0.44% | 0.82% | +1,962,669% |

Control: `Ordered Quantity` is **100.00% exact on all 5,640**, confirming the join and grain. **B closes
the variance** — 0.376% becomes 0.002%, and the residual inexact rows are the §0.5 precision noise that
the report's `#,##0` format already hides. C is decisively rejected. Target row `2585134 / DP680-B1`
under B: **LB 176.0** and **KG 79.833105** against Cognos's **176** and **79.833105264** — exact.

**The cross-conversion needs no hardcoded constant, and that also settles the parity question.** Where
the weight UOM is LB but KGs are wanted (and vice versa), use the row's own
`ConversionFactorKG / ConversionFactorLB`. Verified: `176 × (39.916553/88)` = **79.83310544** ≈ Cognos's
79.833105264, whereas the physically-correct `176 × 0.45359237` = **79.8322571**, which Cognos is not.
So **Cognos itself uses EDW's stored `0.4535971x`**, and deriving the ratio from the row reproduces it
exactly while keeping the constant in exactly one place — which is what the "parity over physical
correctness" instruction asks for, without anyone having to pin a literal.

**NOT APPLIED TO THE SHIPPED BUILD — this is a scope call, deliberately left open.** Three reasons to
decide it rather than assume it: (a) it *does* require moving to `BIQL.FactSalesDetail` after all — for
`Unit_Weight_Adj`, not for the factors — and that view is **absent from the local mirror**, so the
shipped query stops being locally verifiable, which is the whole reason §0.5 said ship `dbo`;
(b) six columns the query needs were not exercised by the probe and must be confirmed present on the
view first — `RecordType`, `ShipToCustomerSKey`, `ShipToAddressSKey`, `TerritoryManagerSKey`,
`AddressNumShipTo`, `ScheduledPickDate`; (c) the comparison matched 5,640 of 5,675 keys, strong but not
total. **The build as shipped ties on 18 of 19 columns with a quantified, disclosed +0.376% on the other
two.** The change, ready to apply:

```sql
-- Shipments.m:  FROM dbo.FactSalesDetail f   ->   FROM BIQL.FactSalesDetail f
--               + project, alongside the two existing factors:
    f.Unit_Weight_Adj                     AS [Line Weight Adj],
    LTRIM(RTRIM(f.UOM_Weight_Adj))        AS [Line Weight Adj UOM],
```

```dax
Ordered Quantity LBs (Line) =
    IF ( Shipments[Line Weight Adj UOM] = "LB",
         Shipments[Line Weight Adj],
         Shipments[Line Weight Adj] * DIVIDE ( Shipments[Conversion Factor LB], Shipments[Conversion Factor KG] ) )

Ordered Quantity KGs (Line) =
    IF ( Shipments[Line Weight Adj UOM] = "KG",
         Shipments[Line Weight Adj],
         Shipments[Line Weight Adj] * DIVIDE ( Shipments[Conversion Factor KG], Shipments[Conversion Factor LB] ) )
```

Nothing else moves — the measures, the visual bindings and all 17 other columns are unchanged, and
§5.1's reason for keeping the weight arithmetic in DAX is exactly what makes this a two-line edit.
**J1 is closed as a question; applying it is a decision.** J2 remains open. ⬜ DECISION PENDING

---

> Entries 39–40 are the **post-build corrections** directed by the team lead (2026-08-06), both
> applied to the shipped PBIP and re-verified against the mirror.

**39 — CORRECTION TO §4.3: `OPEN_INDICATOR <> 'Y'` is `StatusCodeNext = '999'`, not
`SalesTableSource <> 1`. The row count does not move; the reason it is right does.** §4.3's port ties
at 5,675 — **and it ties for the wrong reason.** Report 21's jumpbox probe cross-tabbed the real
`OPEN_INDICATOR` against its own Cognos export over all 17,259 rows and it partitions perfectly on
`StatusCodeNext`, with zero exceptions either way:

| Cognos `Open Indicator` | `StatusCodeNext` | rows |
|---|---|---|
| `N` | `999` | 16,363 |
| `Y` | 540 / 530 / 560 / 535 / 580 / 525 / 550 / 570 | 896 |

`SalesTableSource` is **positively disproved** there: report 21's population holds **252 lines with
`SalesTableSource = 1` AND `StatusCodeNext = '999'`**, which the two rules classify oppositely.

**In report 19's window the two are exactly equivalent** — measured on the mirror under the shipped
full filter set, and now a permanent guard block in `00_verify_tables.sql`:

```
lines with SalesTableSource =  1 AND StatusCodeNext =  '999'  ->  0
lines with SalesTableSource <> 1 AND StatusCodeNext <> '999'  ->  0
lines in window                                               ->  8,077
```

Cross-tabbed the same way: `StatusCodeNext = '999'` ⟺ `SalesTableSource = 2` on **7,209 lines**, and
every one of the nine open statuses present (540 · 530 · 560 · 535 · 580 · 525 · 550 · 570 · 515,
798 lines) carries `SalesTableSource = 1`. Zero rows disagree. Re-ran the full tie-out after the swap:
**7,209 lines → 5,675 rows**, Σ Ordered Quantity **39,590,713.21**, branch split exact on every branch,
4,155 orders — every §10 target untouched.

**Changed anyway, because the equivalence is a property of THIS WINDOW, not of the data model.** Report
21 proves the two diverge in a wider one, so the old predicate sat one scope change away from being
silently wrong — and would have *stayed* silently wrong, since it currently produces a perfect tie.
⚠ `StatusCodeNext` is `nchar(3)`: **the `LTRIM(RTRIM(...))` is load-bearing.** Without it the
comparison matches nothing and the table loads empty.

*Reconciling this with V7, which is not wrong:* V7 measured the two predicates **early in the filter
chain** (869,741 → branch6 → in-window only) and found 14,471 vs 14,634, a 163-line gap. That gap is
entirely closed by the later predicates — order type, line type, the `StatusCodeLast` cancel
correction (V23) and MPF. §4.3's "would add 38 lines / 36 rows and break the tie" was measured against
the *first-pass* filter set, before V22–V24. Against the final set the delta is zero. ✅

**40 — THE WEIGHT COLUMNS REBUILT ON `Unit_Weight_Adj`. The +0.376% is closed.** V38 established the
finding; this entry records the applied change and the re-measurement the team lead asked for, using
the **full §4.5 filter set** rather than V38's approximation.

Shipped rule — `Unit_Weight_Adj` is a **LINE TOTAL** in the unit named by `UOM_Weight_Adj`, so there is
**no multiplication by quantity**, only a unit conversion:

```dax
Ordered Quantity LBs (Line) = IF ( Shipments[Line Weight Adj UOM] = "LB", Shipments[Line Weight Adj], Shipments[Line Weight Adj] * [K KG to LB] )
Ordered Quantity KGs (Line) = IF ( Shipments[Line Weight Adj UOM] = "KG", Shipments[Line Weight Adj], Shipments[Line Weight Adj] / [K KG to LB] )
```

`[K KG to LB] = 2.2045992` is a **hidden measure — the constant's single home**, so the basis can be
flipped in one line. It is pinned to the Cognos DW's value deliberately, not the physically-correct
`2.20462262`: measured, `176 / 2.2045992` = **79.833105** reproduces Cognos's **79.833105264**, where
the physical constant gives 79.8322571. Parity wins, and the measurement says which value that is.

**Re-measured with the full §4.5 filter set, 5,675 of 5,675 export groups matched (100%):**

| Column | old: `qty × factor` | **new: `Unit_Weight_Adj`** |
|---|---|---|
| Ordered Quantity *(control)* | 5,675 / 5,675 exact (100.00%), **+0.0000%** | — |
| Ordered Quantity **LBs** | 3,285 exact (57.89%) · 94.36% after `#,##0` · **+0.3763%** | **5,616 exact (98.96%)** · **99.40%** after `#,##0` · **−0.0021%** |
| Ordered Quantity **KGs** | 5,411 exact (95.35%) · 95.47% after `#,##0` · **+0.3760%** | **5,618 exact (99.00%)** · **99.44%** after `#,##0` · **−0.0021%** |

Confirmed end-to-end in `00_verify_tables.sql`: Σ LBs **48,306,618.96** and Σ KGs **21,911,746.57**
against the capture's 48,307,620.74 / 21,912,200.98 — **−0.0021% on both**, from **+0.376%**.

⚠ **The team lead's first figures (98.96% / 99.03%) needed one correction to reproduce, and it was a
harness bug, not a formula bug.** `(OrderNum, LineNum, ItemNum2nd)` is **not unique** in the probe
export — 26 pairs share it and differ only in `UOMTx`/quantity — so a naive merge attaches the wrong
adjusted weight and manufactures ~26 false mismatches, which is what dragged an interim reading down to
98.50%. Adding `UOMTx` and rounded quantity to the merge key fixed it and landed on 98.96% / 99.00%.

**Residual: 59 LB / 57 KG groups of 5,675 (~1%), and it is genuine source disagreement, not formula
error.** Both items the team lead flagged are real: `DF201-JG` — Cognos 8.34 LB, EDW 7.0, old basis
14.0, so *neither* basis reproduces the DW; `251067CX.S-PD` — `Unit_Weight_Adj` of **0.005 KG** against
a correct 440.92 LB, simply wrong in EDW. A third family (`MI102-ML` / `MI001-ML`, EA items) has Cognos
printing LBs **equal to the quantity**, which no weight column reproduces. None are worth engineering
around; note them in the report-out workbook.

**LOCAL VERIFIABILITY PRESERVED — this is the part worth not losing.** `Unit_Weight_Adj` /
`UOM_Weight_Adj` exist only on `BIQL.FactSalesDetail` (194 columns vs the table's 186), which is absent
from the mirror, so shipping them would normally end local verification. It does not, because
`dbo.FactSalesDetail` carries **`UnitWeight` / `UOMWeight`**, and those are **byte-identical to the
`_Adj` pair on all 7,663 probe lines** — the substitution reproduces the shipped weights *exactly*, to
the same 98.96% / 99.00% and the same −0.0021%. `00_verify_tables.sql` block 8 uses it and says so.
The shipped query still reads the `_Adj` columns, because that is where a future item-weight correction
will land. All eight otherwise-unexercised columns were confirmed present on the view from
`edw_schema\edw_columns_current.csv` before the switch: `RecordType`, `ShipToCustomerSKey`,
`ShipToAddressSKey`, `TerritoryManagerSKey`, `AddressNumShipTo`, `ScheduledPickDate`, `StatusCodeNext`,
`OrderCompany`.

`Conversion Factor LB` / `KG` stay **projected but demoted to diagnostics** — labelled as such in TMDL
— so anyone auditing a number can reproduce the superseded value and see the discrepancy. A new guard
block asserts `[Line Weight Adj UOM]` is exactly `{LB, KG}` with no nulls or blanks (measured: LB 4,352
/ KG 2,857, 0 nulls, 0 zeros), because the DAX `IF()` has no third branch. **§0.5 / §1.2 / §9.3's
stated reason for moving to the view — corrected conversion factors — remains disproved (V38); the view
is used only for `Unit_Weight_Adj`.** ✅

**41 — PATH LENGTH FIXED: 280 → 246, headroom 10. The PBIP was over the 256-char limit.** Caught on
review. This matters because it is **silent**: past ~256 chars Power BI Desktop opens **"Untitled"
with no error at all** (CLAUDE.md §7 trap 1), and every local check still passes — MCP lint, the PBIR
validator, JSON parsing and field resolution were all green at 280. Nothing in the toolchain catches it.

**The arithmetic, so the next person does not rediscover it:**

```
prefix through ...\PBIP\                                              150   (repo convention, fixed)
+ artifact name
+ deepest tail
<= 256
```

| Deepest tail | chars |
|---|---|
| `.Report\definition\pages\<20-char id>\visuals\<20-char id>\visual.json` | 86 |
| `.Report\definition\pages\<8-char id>\visuals\<8-char id>\visual.json` | 62 |
| **`.Report\StaticResources\SharedResources\BaseThemes\CY24SU10.json`** | **64** ← binding once ids are short |
| `.SemanticModel\definition\tables\Last Refreshed.tmdl` | 52 |

**Both fixes applied, because either alone was not enough.** Shortening the page/visual ids from 20 to
8 chars frees 24 — but that only moves the ceiling to the **theme path**, which is 64 and cannot be
shortened. So the name had to come down too:

| Artifact name | chars | worst path | headroom |
|---|---|---|---|
| `19 - Inventory - Safety Stock and Order Size` *(as built)* | 44 | **280** | **−24** ❌ |
| `1 - Inventory - Safety Stock and Order Size` *(report-18 convention)* | 43 | 279 | −23 ❌ |
| **`19 - Safety Stock and Order Size`** *(shipped)* | **32** | **246** | **+10** ✅ |

Ids went `19a1010000000000e001` → `19a10001` (pages), `19b1…` → `19b10001` (tables),
`19b1…f0c1` → `19c10001` (cards — the old scheme collided at 8 chars). Renamed the three artifacts and
updated all four cross-references: `.pbip` → `.Report`, `definition.pbir` → `.SemanticModel`, and both
`.platform` `displayName`s. **Measured after: 0 files over 256**, worst 246 (theme), visuals 244.

Re-verified everything downstream of the rename — PBIR validator **0 errors / 0 warnings** (report and
probe), MCP `ConnectFolder` **4 tables / 5 measures / 2 relationships**, all **52 field references
resolve**, no duplicate `nativeQueryRef`, `preview-pages` lists all three pages with the right names
and active page, JSON all valid, no BOMs, and **zero surviving references to the old name**.

⚠ **The rule to keep, not just the number.** With the name at 32, the budget for any future tail is
**74 chars** — so a new page/visual folder pair must stay at or under **14 characters each**. Desktop
generates **20-char** ids for visuals added through the UI, which would put the path at 268 and
silently break the PBIP. If a visual is ever added on the jumpbox, **rename its folder to ≤14 chars
before committing**, and re-run the check:

```powershell
$p = "…\19 - 1 - Inventory - Safety Stock and Order Size"
(Get-ChildItem $p -Recurse -File | Where-Object {$_.FullName.Length -gt 256}).Count   # must be 0
```

*Context worth recording rather than losing:* the original 280 was not arbitrary — **delivered reports
14 (283) and 12 (285) exceed 256 in this same tree and open on the jumpbox**, which is why the build
sized to it. That makes 256 an inconsistently-enforced boundary here, not a cliff — but the failure
mode is silent and the fix is free, so the margin is not worth defending. Reports 20 (247) and 21 are
being brought under the same bar. ✅

---

**42 — POST-REFRESH VALIDATION AGAINST THE LIVE MODEL. V40's `Unit_Weight_Adj` rule holds on real
refreshed data; the residual is 34 rows (0.60%), 28 of them Cognos falling back to a factor of 1.**

First validation of this build that is **not** a mirror simulation. Zack refreshed on the jumpbox
and saved 2026-08-07 00:25; `<...>\19\PBIP\19 - Safety Stock and Order Size.SemanticModel\.pbi\cache.abf`
(0.33 MB) was mounted locally per root `CLAUDE.md` §9 and queried through
`export-dax-csv.ps1`. This is the first time `Shipments.m` has been **executed anywhere** — §9.3
recorded that it could not be smoke-tested locally because `BIQL.FactSalesDetail` is absent from the
mirror, which is exactly the gap that produced the report-21 `date - <int>` defect (V39/#19). It ran.

Table loads: **Safety Stock 177 · Shipments 7,317 lines · Planner Names 57 · Last Refreshed 1.**
Safety Stock is the export's 177 exactly. Shipments is line grain (7,279 on the mirror the previous
day; +38 is one day of the 183-day rolling window).

Collapsed to the export's 15-key report grain under the shipped report-level filter
`Is India Tax Item = FALSE`: **5,762 groups vs the export's 5,675.** The window moved a day, so this
is an intersection test, not a row-count tie: **5,666 keys in both**, 9 export-only, 96 model-only.

| Column | exact | within 1e-6 | after `#,##0` | Σ delta |
|---|---|---|---|---|
| Ordered Quantity *(control)* | **5,666 / 5,666 — 100.00%** | 100.00% | 100.00% | **+0.0000%** |
| Ordered Quantity **LBs** | 5,570 (98.31%) | **5,609 (98.99%)** | **5,632 (99.40%)** | **−0.0021%** |
| Ordered Quantity **KGs** | 2,222 (39.22%) | **5,609 (98.99%)** | **5,634 (99.44%)** | **−0.0021%** |

Within a rounding hair of V40's mirror-based prediction (98.96 / 99.40 / −0.0021 and 99.00 / 99.44 /
−0.0021). The KGs "exact" figure of 39.22% is **not a regression** — it is float representation of
the `/ 2.2045992` division; at 1e-6 it is identical to LBs, and the Σ delta is the same to four
decimals, which is the tell. The control column tying at 100.00% with a **+0.0000%** sum is what
licenses reading the other two as weight-logic differences rather than population differences.

**Old rule vs new, measured head-to-head on the same 5,666 keys** (`SUMX(qty × ConversionFactorLB)`
recomputed inside the same query, so both rules see identical rows):

| | rows wrong |
|---|---|
| old `qty × factor` wrong, **new fixes** | **2,350** |
| new wrong, old was right | 23 — all ratio 1.0000 to 4 dp, the `0.4535971` precision class, invisible after display rounding |
| **neither matches Cognos** | **34** |

So the change corrects 2,350 rows and costs 23 sub-rounding ones. Net.

**The 34, fully characterised — 28 are Cognos, not us:**

| rows | items | what Cognos shows | what EDW shows |
|---|---|---|---|
| **28** | `MI001-ML`, `MI102-ML`, `MI102.S-ML` | LBs **exactly equal to Ordered Quantity** — i.e. no conversion, factor 1 | 0.0507 lb/EA ≈ 23 g, physically right for a sample vial |
| **5** | `DF201-JG`, `DF702-JG` | 8.34 lb per EA — the density of **water** per US gallon; `JG` = jug | 7.00 / 28.00 |
| **1** | `251067CX.S-PD` | 440.92 (agrees with the old rule to 1e-5) | `Unit_Weight_Adj` = **0.011 lb for 200 drums** — a corrupt source value |

The 28 are a legacy-DW fallback: Cognos has no conversion for these sample items and passes the
quantity straight through as pounds. Ours is the better number and cannot be matched without
reintroducing the fallback deliberately. **Disclose, do not chase** — 0.49% of rows, and the
direction is in our favour. The single `251067CX.S-PD` row is a genuine `Unit_Weight_Adj` data
defect in EDW and is worth naming to the EDW owner.

**The Safety Stock sheet ties 1:1 and completely — 177 rows, 10 of 10 columns at 100.00%,
zero rows on either side without a match.** Keyed on (Branch Plant, 2nd Item Number). That includes
`Planner Name`, which is the one column in this build sourced from a **different server** — the
ODSPROD `PRODDTA.F0101` lookup merged onto the EDW row in Power Query — so the cross-server merge is
confirmed correct on live data, not just the 57-row local smoke test. It also includes
`Lead Time Order to Ship`, whose SSAS alternative (`Lead Time MFG_BP`, probe J2) remains unrun: at
100.00% against the export the EDW column needs no second opinion, which retires J2 as a
prerequisite and leaves it a nice-to-have.

**PBIP integrity after the jumpbox round trip:** 0 files with a BOM, 0 space-indented TMDL lines,
0 `///` above a relationship, `definition.pbir` **4.0**, and the jumpbox did **not** bump any
schema (`visualContainer 2.1.0`, `page 2.0.0`, `report 2.1.0`, `pagesMetadata 1.0.0` — all below the
2.146 ceiling, so root `CLAUDE.md` §7's forward-skew trap has no purchase here). No bookmarks
exist in this report, which removes that failure mode entirely. ✅

**43 — SAME-DAY TIGHT CAPTURE TIES CLEAN: the sign-off validation. Every residual is a known,
counted class.** Cognos export pulled and jumpbox refresh saved the **same minute** (2026-08-11
10:20) — the tightest capture this report has had, and a **morning run**: min Promised Ship Date
2026-02-09 = D−183, so the shipped `-183` window aligns exactly and V17's +0.90% boundary variance
does not appear. Cache mounted locally, both tables exported uncapped, compared in full.

**Safety Stock: 177 / 177, all 10 columns 0 mismatches, 0 unmatched keys on either side.** The V18
snapshot-drift row is gone — same-day capture, no drift.

**Shipments: 5,749 Cognos rows vs 5,775 model groups (7,332 lines collapsed to the 15-key report
grain, India filter applied); 5,729 keys shared (99.65%).** On the shared keys:

| Column | exact (1e-6) | after `#,##0` | Σ delta |
|---|---|---|---|
| Ordered Quantity *(control)* | **5,729 / 5,729 — 100.00%** | 100.00% | **+0.0000%** |
| Ordered Quantity LBs | 5,670 (98.97%) | 5,694 (99.39%) | **−0.0021%** |
| Ordered Quantity KGs | 5,670 (98.97%) | 5,696 (99.42%) | **−0.0021%** |

Identical to V42's profile to the second decimal — the V40 weight rule holds on a third
independent capture.

**All 66 unmatched keys characterised, none new:** the 20 Cognos-only keys each pair to a
model-only near-match differing in exactly **one attribute** — **8 TM rows** (`Brendan Schloerb` /
`Bryan Fuka` vs `Not Available` — V22's thin-dimension gap, the *exact* predicted count), **11
Global Parent rows** (all one customer: Cognos `Aegilops (X) Val de Reuil FR` vs EDW
`Aegilops - Global parent` — source-side parent-name drift), **1 Bulk Item** (Cognos `-` vs EDW
`DP050` — item master populated in EDW, NULL in legacy DW), **1 Segmentation**. The **26 unpaired
model-only keys** all carry Promised Ship Dates of 2026-08-07/10/11 — current-week in-flight lines
whose status moved in live Oracle after EDW's nightly load (the INSERT-current / UPDATE-stale drift,
CLAUDE.md §7). Weight residuals after rounding (35 LB / 33 KG rows) are V42's characterised classes
(sample-item factor-1 fallback + water-jug density + the one corrupt `Unit_Weight_Adj` row).

**Verdict: VALIDATED FOR SIGN-OFF.** Report-out workbook is the remaining deliverable. ✅

---

## 13. Rejected v2 live prototype — `19 - Safety Stock and Order Size (SSAS Live)\`

This folder is a validation prototype against `BIQLTabular_v2`; it is **not the production
deliverable**. `BIQLTabular` is the production model on `SSASPROD`, while v2 is a
modeling/development-like model. The live prototype also cannot expose the report's normal
rolling Promised Ship Date filter as required by the team. It remains only as evidence that the
three-page report layout and full-model field coverage validate. Do not publish it as Report 19.

A second PBIP, live-connected to `SSASPROD` / `BIQLTabular_v2` (full Model, not a perspective),
built on the report-12 `(SSAS Live)` pattern: thin PBIR report + proxy SemanticModel
(`modelReference.json`, `analysisServicesDatabaseLive`), report-level measures in
`definition\reportExtensions.json`, WHERE-clause logic as measure-internal `KEEPFILTERS` plus
hidden Include measures applied as visual-level `= 1` filters. Same three pages, same visuals,
same sorts and formatting as the import PBIP. Microsoft's PBIR validator passes it with
0 errors / 0 warnings.

**NOT blocked — the §1.1 blocker dissolves on the live connection.** `Item Branch`
[`Lead Time MFG_BP`] (= `F4102.IBLTMF`, Cognos's *Lead Time Order to Ship*) sits in `v2.xmla`'s
**base `Item Branch` table** (132 columns; the `Supply and Demand` perspective exposes 131 — the
one it hides is exactly this column). §1.1's "zero perspectives" finding is true but only
constrains perspective connections; this variant connects to the **full Model**
(`Cube=Model` in `modelReference.json`), where every base-table column is visible. Every field
the report binds, including this one, is proven present in `v2.xmla`. Belt-and-braces: probe J2
(`$SYSTEM.TMSCHEMA_COLUMNS` on the live server) confirms before first open.

### 13.1 Field mapping (import → live)

| Header | Import (EDW SQL) | Live (BIQLTabular_v2) |
|---|---|---|
| Branch Plant (SS pages) | `ib.[Business Unit]` | `Item Branch`[Business Unit] |
| Bulk Item | `ib.[Item Bulk]` | `Item Branch`[Item Bulk] |
| 2nd Item Number (SS) | `ib.[Item Num 2nd]` | `Item Branch`[Item Num 2nd] |
| Stock Type Code | `ib.[Stocking Type]` | `Item Branch`[Stocking Type] |
| Master Planning Family | `ib.[Master Planning Family]` | `Item Branch`[Master Planning Family] |
| Lead Time Order to Ship | `ib.[Lead Time MFG_BP]` | `Item Branch`[Lead Time MFG_BP] — base model only, no perspective; fine on full-Model live |
| Planner Number | `ib.[Planner Num]` | `Item Branch`[Planner Num] |
| Planner Name | ODS `F0101` merge (§3.4 trap 3) | `Item Branch`[Planner Name] — **EDW's stale name, see 13.3** |
| Safety Stock | `ib.SafetyStock` | `Item Branch`[SafetyStock] |
| Unit of Measure Primary | `ib.[UOM Primary]` | `Item Branch`[UOM Primary] |
| Order Company / Order Number | `f.OrderCompany` / `f.OrderNum` | `Sales`[Order Company] / [Order Num] |
| Branch Plant (Shipments) | `f.BusinessUnit` | `Sales`[BusinessUnit] |
| Bulk Item (Shipments) | `[Bulk Item (Display)]` calc col | measure `[Bulk Item (Display)]` = COALESCE(SELECTEDVALUE(`Item Branch`[Item Bulk]), "-") |
| 2nd Item Number (Shipments) | `f.ItemNum2nd` | `Sales`[Item Num 2nd] |
| Ordered Date | `f.OrderDate` | `Sales`[Order Date] |
| Ordered Quantity / LBs / KGs | measures over SQL-filtered rows | measures over `Sales`[QuantityOrderedPrimaryUOM] / [QuantityOrderedLB] / [QuantityOrderedKG] — see 13.3 |
| Ordering Unit of Measure | `f.UOMTransaction` | `Sales`[UOM] |
| Promised / Sched Pick dates | `f.PromisedShipmentDate` / `f.ScheduledPickDate` | `Sales`[Promised Shipment Date] / [Scheduled Pick Date] |
| Customer Code / Name | `f.AddressNumShipTo` / `sa.AddressDesc` | `Customer Ship To`[Customer Ship To] / [Customer Ship To Name] |
| Global Parent Name | `p5.AddressDesc` via `sa.AddressNum5th` | `Customer Parent`[Customer Parent Name] via `Sales`[ParentCustomerSKey] — verify equivalence on first refresh |
| Customer Segmentation Description | `sc.CustomerSegmentationDesc` | `Customer Ship To`[Customer Segmentation Desc] |
| TM Name | `ISNULL(tm.[Mailing Name],'Not Available')` | `Territory Manager`[Mailing Name] — broken keys render BLANK, not 'Not Available' (§0.4) |
| Country Name | `sa.MailAddressCountryDesc` | `Customer Ship To`[Country Desc] |
| DATE | `CAST(GETDATE() AS date)` | measure `[DATE]` = TODAY() |
| Last Refreshed card | `#table` refresh stamp | measure on `Audit`: "Last refreshed: " & FORMAT([Last Updated], …) & " ET" |

### 13.2 Where the WHERE clauses went

- **Safety Stock predicates** (six plants, `SafetyStock > 1`, stocking type ≠ 'O', MPF contains F)
  → hidden measure `Item Branch`[R19 SS Include], visual-level `= 1` filter on both Safety Stock
  grids. All four inputs are SELECTEDVALUE-safe: each grid displays every filtered column, or sits
  at `ItemBranchSKey` grain.
- **Shipments predicates** (Sales Detail / status 999 / six plants / promised ≥ TODAY()−183 /
  order-type & status-code exclusions / qty > 0 / ship-to AC01 ≠ INT / MPF contains F)
  → `KEEPFILTERS` args inside all three quantity measures, so page 3's per-item aggregates filter
  at LINE level exactly like the SQL WHERE. The Shipments grid's row set is gated by a visual
  filter `[Ordered Quantity] > 0` (blank = no qualifying line in the window).
- String predicates compare through `TRIM()` so they hold whether or not the cube's JDE codes
  carry padding.
- The **India-tax report filter** is not ported: per the import TMDL note it removes 0 rows and
  every such line sits in an Indian branch plant, outside the six-plant predicate that IS ported
  (measure-internal and Include-measure both).

### 13.3 Disclosed differences vs the import PBIP

1. **Planner Name** reverts to EDW's `Item Branch`[Planner Name] — the §3.4 ODS `F0101` fix
   cannot ride a live connection. Ask #2 for Rohit's team: correct the planner name upstream
   (EDW/`BIQLTabular_v2`), or accept EDW's rendering on this variant.
2. **LB/KG quantities** bind the model's `QuantityOrderedLB/KG`, not the import's
   `[Line Weight Adj]`-based columns (§0.5). Whether the cube's conversion carries the UOM fix is
   a first-refresh validation item; expect the +0.376%-class drift if it does not.
3. **TM Name** renders BLANK where the import renders 'Not Available' (the §0.4 orphaned-SKey
   rows). Same upstream dimension gap, different cosmetic.
4. **Global Parent Name** rides `ParentCustomerSKey` → `Customer Parent` instead of the ship-to's
   5th address book; tie out on first refresh.
5. Column format strings come from the cube; the import's `#0` / `d MMM, yyyy` etc. are only
   reproduced where a report measure carries its own formatString.

### 13.4 First-open checklist (jumpbox)

1. Confirm `Lead Time MFG_BP` exists on `Item Branch` (`$SYSTEM.TMSCHEMA_COLUMNS`, probe J2 —
   expected present in the base model per `v2.xmla`), then open the PBIP — Desktop should connect
   straight to `SSASPROD` / `BIQLTabular_v2` with no dialog.
2. Safety Stock grid vs import: 177 rows, 10 columns tie (§10). If row count is 0, check code
   padding — the TRIM comparisons should make that impossible, but that is the first suspect.
3. Shipments grid vs import at the same capture: row count and the three quantity totals
   (LB/KG per 13.3.2), TM blanks vs 'Not Available' (13.3.3), Global Parent (13.3.4),
   Planner Name deltas (13.3.1).
4. Page 3 aggregates: spot-check one item's Ordered Quantity against the import page 3 — proves
   the measure-internal line-level filtering.

---

## 14. Production build — `19 - Safety Stock and Order Size (SSAS Import)\`

The production rebuild is a three-page PBIP backed by one external source:
`SSASPROD` / **`BIQLTabular`**, imported through the on-premises gateway. It follows the agreed
source ladder: SSAS Live was evaluated first; SSAS Import is selected because the Shipments page
requires a normal date-filtered snapshot. The semantic model has no EDW or ODS datasource.
`Last Refreshed` is an internal Power Query-generated one-row table and is not an external source.

### 14.1 Source evaluation

- **Shipments** defines the eligible Sales rows once in the SSAS native DAX query and imports
  them at Sales-line grain. The query retrieves related attributes from `Item Branch`,
  `Customer Ship To`, `Customer` (sold-to), and `Territory Manager`. The three local model
  measures sum the imported primary-UOM, LB, and KG quantity columns; no temporary SSAS measures
  or `SUMMARIZECOLUMNS` step is required. The displayed customer fields are Ship-To Customer
  Code, Ship-To Customer Name, and Customer Sold-To Name; no parent-name field is displayed.
  All Cognos predicates, including `Promised Shipment Date >= TODAY()-183`, execute once when
  defining the eligible Sales-line table.
- **Safety Stock** imports from the full model's `Item Branch` base table. The required
  `Lead Time MFG_BP` column exists in production `BIQLTabular`; a perspective connection is not
  used because the relevant perspective does not expose the column.
- **Safety Stock vs Order Size** is derived from those two imported tables and needs no third
  source.
- **Planner Name** comes directly from production `Item Branch`. Its `First Last` presentation
  differs from Cognos's `Last, First` presentation. The rebuild discloses that source-owned
  display difference instead of adding an ODS dependency.

### 14.2 Published validation — 2026-08-12

The private PPU semantic model refreshed successfully through the production gateway at
2026-08-12 14:40 ET. The published report is
`https://app.powerbi.com/groups/50b98bb9-9fcb-47db-a0df-f2c167b351fb/reports/a33863c6-6309-49fc-9151-c140739c2ee7`.
Microsoft's PBIR validator returns 0 errors and 0 warnings.

Against the fresh 2026-08-12 Cognos export:

- Safety Stock: **177 / 177 keys match**. All fields tie except Planner Name formatting on all
  177 rows.
- Shipments: **5,639 / 5,640 Cognos business keys match**; Cognos-only 1, Power BI-only 119.
  Power BI uses the deterministic D-183 boundary and also includes same-day source movement after
  the Cognos capture.
- Ordered Quantity: **5,639 / 5,639 exact**, shared-key total delta **0.0000%**.
- Ordered Quantity LBs: 5,561 / 5,639 agree at display precision; shared-key total delta
  **-0.000681%**.
- Ordered Quantity KGs: 5,457 / 5,639 agree at display precision; shared-key total delta
  **-0.001396%**.
- Customer Name differs on 135 shared keys because the production SSAS ship-to dimension does
  not reproduce every legacy warehouse label. Customer Sold-To Name is the approved replacement
  for the legacy Global Parent Name column. Segmentation, TM Name, and Country Name tie.

The report-out workbook is
`Cognos Reports\Excel Validation\_report_out\19 - Safety Stock and Order Size.xlsx`.

---

## 15. DAX-model build — `19 - Safety Stock and Order Size (DAX Model)\`

This PBIP is the maintainable star-schema implementation of the production SSAS Import report.
Its only external source is `SSASPROD` / `BIQLTabular`; it has no EDW or ODS dependency.

### 15.1 Model structure

- `Shipments` preserves Sales line grain and carries the source relationship keys and quantity
  inputs.
- `Safety Stock`, `Customer Ship To`, `Customer`, and `Territory Manager` are separate imported
  dimensions.
- The local model recreates the four relationships defined by the production XMLA model:
  `ItemBranchSKey`, `ShipToCustomerSKey`, `SoldToCustomerSKey`, and
  `TerritoryManagerSKey` from `Shipments` to their corresponding dimension keys.
- Customer Sold-To Name comes from `Sales[SoldToCustomerSKey]` →
  `Customer[CustomerSKey]`; no parent-name field is used.
- Related display fields on `Shipments` are DAX calculated columns. Ordered Quantity, LBs, and
  KGs are local DAX measures.

### 15.2 Extraction boundary vs report logic

Production `BIQLTabular` marks the three required quantity columns, their raw input measures,
and all four relationship keys as hidden. `Cube.AddAndExpandDimensionColumn` and
`Cube.AddMeasureColumn` cannot address hidden objects; the connector returns `The key didn't
match any rows in the table.` The partitions therefore use minimal native DAX projections to
expose source rows and source keys. This is an SSAS connector constraint, not report logic.

The `Shipments` partition limits extraction to a 200-day candidate window, the six report plants,
and stable row predicates. The local measures repeat those predicates and own the exact rolling
`TODAY()-183` report boundary. Consequently, model behavior remains explicit in DAX while the
import avoids scanning irrelevant Sales history.

The Safety Stock inclusion rule is a DAX Boolean column applied as a page filter. The Shipments
business rules are `KEEPFILTERS` expressions inside all three quantity measures. The report-level
India tax-item exclusion remains a model-calculated Boolean filter.

### 15.3 Validation

The private PPU model refreshes through the production BIQLTabular gateway connection in about
23 seconds. It imports 7,896 Sales source rows and groups them to the same 5,758 displayed
Shipments rows as the validated flattened model. Safety Stock returns the same 177 rows.

An `executeQueries` comparison across all displayed shipment attributes and the three measures
returns 5,758 rows from each model, with zero rows unique to either model. Totals match:

| Measure | DAX model total |
|---|---:|
| Ordered Quantity | 40,189,350.2172 |
| Ordered Quantity LBs | 49,011,758.3570 |
| Ordered Quantity KGs | 22,231,437.1689 |

The validation report and semantic model are published in `Zack (Validation)` as
`19 - Safety Stock and Order Size (DAX Model)`.
