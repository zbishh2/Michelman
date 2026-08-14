# Report 20 — Inventory for tier 2 report — BUILD SPEC

Cognos path: `Production Moves / Tim Bath / Operations Metrics Reports`
Portal folder ID `i593C0D3C30104FC68E5C9E1798BDF446` · package `Data Warehouse` (Oracle `DW_LEGACY`),
star **Inventory On Hand** — the same legacy warehouse behind reports 13/14/18/19/21.

Intake provenance:
- `Intake\Native SQL (filed 2026-08-06).txt` — **the authority.** Cite this over the IBM Cognos SQL
  wherever they overlap; the two are semantically identical (no extra predicates in either).
- `Intake\Query + XML (filed 2026-08-06).txt` — Cognos-generated SQL + full report XML.
- Two Cognos Viewer screenshots (list pages 1 and 2) supplied in chat 2026-08-06, **not yet filed
  into `Intake\`** — see §11.0.
- `COLLECTION_NOTES.md` — the orchestrator's intake analysis. This spec starts from it and corrects
  it in two places (§6.1, §4).

⚠ **First report taken out of the `Production Moves` tree.** Every prior report came from
`Michelman Reporting`. The requirements contact is presumed to be **Tim Bath** and that presumption is
**unconfirmed** — confirm ownership before taking §12 to anyone.

Report anatomy: one page, one query, one flat `<list>`, **seven columns**, no grouping, no summaries,
no prompt page, no parameters, no conditional formatting, default `lt`/`lc`/`lm` styles only. The
simplest report in the program.

---

## 0. What this report is, and the one thing to get right

**The date range is user-driven.** Cognos had no prompt page — users were editing the `BETWEEN` filter
**at run time**, by hand, in the report definition. The `2020-01-01` / `2020-12-31` literals in the
captured SQL are simply whatever happened to be in the definition on capture day. They are **not** a
requirement, not a baseline, and not a default to port. A user-selectable date range **is** the
requirement, and a slicer is therefore the **faithful port** — not an improvement on the original.

Everything else here is straightforward. The one design question that can ship wrong and stay hidden is
**§5.3: on-hand quantity must never sum across snapshot dates.** It is a stock, not a flow. Read that
section before writing a measure.

Two technical findings, both measured, both new:

1. **The Cognos LB conversion factor is a single pinned constant, `K = 2.2045992`** (§4), and EDW's own
   conversion table disagrees with it in the 6th significant digit. This is the root cause of an
   unexplained residual report 14 logged and never chased ("~30 rows LB off by ~0.5 … KG→LB factor
   precision, cosmetic", its §9.5).
2. **Master Planning Family is *not* the hazard it looked like** (§6). Report 14 §9.6/§9.7 already ran
   this experiment against a tight Cognos capture: sourcing MPF from `BIQL.TbItemBranch` takes the
   mismatch count to **zero**. Use item-**branch** grain, never item grain.

---

## 1. Source routing — SSAS Live → SSAS Import → EDW Import → ODS Import

**Primary decision: SSAS Live against `SSASPROD / BIQLTabular_ISH`.** This is Michelman's production
Inventory Snapshot History model and it exposes every required Cognos field. Inventory quantities
exist once per cost method. Report 20 uses standard cost method `07` and the model's native
`Inventory Snapshot[Qty On Hand LB]` measure. The report retains the live connection and avoids
Power Query, a duplicated fact, or guessed relationships.

The local project is
`Inventory for Tier 2 Report (SSAS Live)\Inventory for Tier 2 Report (SSAS Live).pbip`. Its report
connects to the shared Power BI semantic model **Inventory Snapshot History Dataset** in workspace
**Michelman - Inventory Snapshot History**. That shared semantic model is already bound to the
production `BIQLTabular_ISH` Analysis Services gateway datasource. Development metadata points to the
same `BIQLTabular_ISH` model.

The validation deployment is report `20 - Inventory for Tier 2 Report (SSAS Live)` in workspace
**Michelman - Validation (Inventory)**. It is a thin report bound to dataset
`15dcf8b0-e008-4662-ae33-4c7f432f7173` in the central Inventory Snapshot History workspace; it does
not own a duplicate semantic model or refresh schedule.

### 1.1 SSAS production models — measured coverage

`SSASPROD / BIQLTabular` is the general production model, but its `Inventory Snapshot` table is
current-only. The production probe returns exactly two snapshot dates: 599,381 rows for 2026-08-12
and 163,643 rows for 2026-08-13. It cannot satisfy Report 20's user-selected historical range.

`SSASPROD / BIQLTabular_ISH` is the purpose-built production inventory-history model. Its current
coverage is:

| Property | Measured value |
|---|---:|
| Minimum snapshot date | 2021-06-30 |
| Maximum snapshot date | 2026-08-12 |
| Distinct snapshot dates | 133 |
| Inventory Snapshot rows | 3,482,249 |

The dates are the model's approved snapshot spine: older history is predominantly month-end and the
recent period is denser. The report date slicer therefore selects only dates that actually exist in
the production history model.

### 1.2 SSAS Import — valid but unnecessary

An SSAS Import variant could project the same seven fields from `BIQLTabular_ISH`, but it would copy
the history fact into a report-owned model without adding coverage. The native quantity measure and
standard-cost filter satisfy the requirement in Live mode. Use Import only if a future requirement
needs local modeling that the shared semantic model cannot provide.

### 1.3 EDW Import — retained full-daily-depth fallback

| | `BIQL.FactInventorySnapshot_History_Filtered` | `dbo.FactInventorySnapshot_History` |
|---|---|---|
| Shape | date-exploded (`CalendarDate` materialized) | SCD2 intervals (`StartDate` / `StopDate`) |
| Rows | 13,349,051 | 2,029,747 |
| Company-2 +1-day shift | already baked in | must be applied by hand |
| Dates available | **only** what `BIQL.DimCalendarInventorySnapshot` holds | **any** date 2021-06-02 → 2026-08-05 |

The view is the `dbo` table joined to the pruned calendar spine — measured (**V4**): exactly **1
distinct date per month** for 60 consecutive months (2021-06 → 2026-05), then daily from 2026-06.
Report 18 found and repointed away from this same spine.

The two are **equivalent where both have the date**, proven (**V5**), CINC+CIN2 row counts:

| Date | view | `dbo` + company-2 **+1 day** | `dbo`, no shift |
|---|---|---|---|
| 2026-08-04 (daily) | 34,351 | **34,351** ✔ | 34,177 ✘ |
| 2026-04-30 (month-end) | 34,593 | **34,593** ✔ | 34,383 ✘ |

Build on `dbo` + an explicit spine (§5.1). It reproduces the view exactly, and it keeps the spine a
**spec decision** rather than a source limitation — which matters the moment anyone asks for daily
history older than two months.

⚠ **Both CINC and CIN2 are `CompanySKey = 2`** (**V6**: 444,410 + 617,597 interval rows, no other
company key). Reports 14 and 18 treat the +1-day shift as a regional edge case; **here it governs 100%
of the report's rows.** Omitting it returns the *previous day's* position under the current day's
label. It will not look wrong.

The existing `Inventory for Tier 2 Report\Inventory for Tier 2 Report.pbip` remains the documented
EDW fallback. It reconstructs about 1,890 daily snapshot dates from SCD2 intervals, compared with the
133 approved dates exposed by `BIQLTabular_ISH`. Do not mix the EDW fact and SSAS history in one model;
choose EDW only when the business explicitly requires daily dates absent from the production SSAS
history model.

### 1.4 ODS `PRODDTA.F41021` — rejected

Current-only: 120,086 rows, no history dimension, only julian stamp columns (`LIUPMJ`, `LIURDT`)
(**V1**). Cannot serve a date range. Already settled on report 14; nothing has changed.

### 1.5 Paginated Report Builder implementation

`Inventory for Tier 2 Report (Paginated)\Inventory for Tier 2 Report.rdl` is the export-oriented
implementation. It connects directly to `SSASPROD / BIQLTabular_ISH` with the `OLEDB-MD` provider,
so it has no report-owned semantic model, refresh schedule, EDW query, or ODS dependency.

The report uses three DAX datasets:

- `InventoryTier2` returns the seven Cognos columns for `CINC` and `CIN2` and the selected inventory
  date. It filters `Inventory Snapshot[CostMethod]` to standard cost `07` and evaluates the model's
  native `[Qty On Hand LB]` measure.
- `InventoryDates` supplies the date parameter list from dates where `[Qty On Hand LB]` is nonblank
  for the in-scope branches under standard cost method `07`.
- `LatestInventoryDate` supplies the default as the newest date from the same fact-backed set. Future
  calendar rows without inventory facts therefore cannot become the default.

The main query uses a scalar `@InventoryDate` dataset parameter and compares the model date with
`DATEVALUE(@InventoryDate) + TIMEVALUE(@InventoryDate)`. `RSCustomDaxFilter` is not available in this
direct `OLEDB-MD` execution path and is not used. The landscape tablix repeats its header on every
page, has no stock total, and formats the inventory date as `M/d/yyyy` for Cognos parity. Report
Builder renders the current default snapshot as 38 pages of inventory rows.

---

## 2. Column mapping — all seven, with measured types

Cognos reads from three DW objects: `ITEM` (item **×** branch grain — it carries `BRANCH_PLANT`),
`INVENTORY_ON_HAND` (fact header), `INVENTORY_ON_HAND_MEASURES` (fact detail). The native SQL confirms
`CONVERSION_FACTOR_LB` sits on **`INVENTORY_ON_HAND_MEASURES`** — a measures-table column, not an item
attribute.

The SSAS Live implementation uses the model's native objects:

| # | Report column | `BIQLTabular_ISH` field |
|---|---|---|
| 1 | Branch Plant | `Branch[Branch Plant]` |
| 2 | 2nd Item Number | `Item Branch[Item Num 2nd]` |
| 3 | Bulk Item | `Item Branch[Item Num Bulk]` |
| 4 | Global Bulk Item | `Item Branch[Item Num Global Bulk]` |
| 5 | Master Planning Family | `Item Branch[Master Planning Family]` |
| 6 | Quantity on Hand LBs | native `[Qty On Hand LB]` filtered to `Inventory Snapshot[CostMethod] = "07"` |
| 7 | Inventory Date | `Calendar Inventory Snapshot[Calendar Date]` |

The table total is disabled because on-hand quantity is a stock and must not sum across snapshot
dates. The page filter locks Branch Plant to `CINC` and `CIN2`; the visible controls are a Between
date slicer, Branch Plant slicer, and Master Planning Family slicer.

| # | Cognos column | Cognos source | EDW source | Type (measured) | Confidence |
|---|---|---|---|---|---|
| 1 | Branch Plant | `ITEM.BRANCH_PLANT` | `LTRIM(RTRIM(snap.BusinessUnit))` | `nchar(12)` | **High** — trim required |
| 2 | 2nd Item Number | `INVENTORY_ON_HAND_MEASURE.ITEM_NUMBER_2ND` | `ib.[Item Num 2nd]` | `nvarchar(25)` | **High** — branch-invariant (**V11**) |
| 3 | Bulk Item | `ITEM.BULK_ITEM` | `ib.[Item Bulk]` | `nvarchar(25)`, **nullable** | **High** — see §6.1 on `'-'` |
| 4 | Global Bulk Item | `ITEM.GLOBAL_BULK_ITEM` | `ib.[Item Global Bulk]` | `nvarchar(25)`, **nullable** | **High** |
| 5 | Master Planning Family | `INVENTORY_ON_HAND.MASTER_PLANNING_FAMILY` | `ib.[Master Planning Family]` | `nchar(3)` | **High at branch grain** — §6, and R14 §9.7 measured 0 mismatches |
| 6 | Quantity on Hand LBs | `SUM(QUANTITY_ON_HAND * CONVERSION_FACTOR_LB)` | derived — **§4** | — | **High** — calibrated exactly, **V21** |
| 7 | Inventory Date | `INVENTORY_ON_HAND.INVENTORY_DATE` | the spine date `c.CalendarDate` (**not** `StartDate`) | `date` | **High** |

The snapshot fact carries **no item-descriptive columns whatsoever** — no `MasterPlanningFamily`, no
`ItemNum2nd`, no `ItemBulk`, no `ItemGlobalBulk` (**V2**). Every one of columns 2–5 comes from
`BIQL.TbItemBranch`: 116,002 rows, one per `ItemBranchSKey`, **zero duplicate SKeys** so the join
cannot fan out (**V7**). Its column names contain **spaces** — bracket them everywhere.

---

## 3. The date picker (the faithful port)

### 3.1 A slicer, not a Power Query parameter

Report 14 is the prior art and it settled this by reversal: it shipped a PQ `AsOfDate` parameter, then
converted to a slicer (its §13, Zack's call — *"a PQ parameter defeats a report literally named Select
Date"*; Service users cannot change a parameter without a refresh). Report 20 takes the destination
directly.

**Where report 20 differs from report 14, and why the architecture is simpler here.** Report 14 needed
*one* as-of date pickable out of a 13-month window, so it loaded **interval-grain** rows and re-derived
the interval match inside measures at the selected date. Report 20's Cognos filter is a `BETWEEN` and
its output carries `Inventory Date` as a **column** — the report shows **many dates at once**. Doing
that from interval grain would mean expanding intervals per date inside DAX (`SUMX` over the selected
dates against ~1M intervals) — expensive and easy to get subtly wrong.

So: **materialize per-date rows in SQL** and let the slicer filter an ordinary date column. Sized
(**V22**): the full spine over CINC/CIN2 with the §5.4 filter is **320,657 rows**. That is the whole of
EDW's retained inventory history for these two branches, in one small import table, with no DAX
gymnastics at all.

### 3.2 The spine — `BIQL.DimCalendarInventorySnapshot`, and how it solves the data floor

Measured (**V23**): **127 rows**, two columns (`DateSKey int`, `CalendarDate date`), range
**2021-06-30 → 2026-08-06** — 60 month-ends (≤ 2026-05-31) plus 67 daily dates. It is EDW's own
definition of "a snapshot date", and it is exactly the set the `_Filtered` view exposes (126 of the 127
have facts; 2026-08-06 is seeded ahead of the load).

**This is the answer to the data-floor problem, and it is better than a note or a bounded range: the
slicer can only ever offer dates that exist.** Bind the slicer to a `Snapshot Date` dimension sourced
from this table and a user *cannot* drag the range before 2021-06-30, because there is nothing there to
drag to. No empty report, no unexplained blank, no floor note needed on the page. (The floor is
recorded once in **V1** and nowhere else — that is the entire remaining trace of the 2020 literals.)

Trade-off, stated: month-ends only before 2026-06. Cognos's users were picking daily ranges, so if
daily history older than two months is wanted, swap the spine for a generated date list (report 18's
`#dates` pattern — same query, one clause changed) at roughly 3× the rows (~944 K for a trailing 13
months daily). **Recommendation: ship the calendar table.** It covers the full retained range, it
self-bounds the slicer, and it is 320 K rows. Revisit only if Tim asks for daily depth.

### 3.3 Range, not single date

Cognos's filter is a `BETWEEN` and the output is one row per date, so a **Between (range) slicer** is
the faithful shape. Report 14 used a single-select dropdown because *its* report was an as-of; that
difference is deliberate and is the one place this spec departs from report 14's pattern.

**Default state: the latest snapshot date only** (range collapsed to one date). The report is a stock
position — "today" is the natural landing state, and it means the page opens showing ~1,250 rows rather
than 320,657. Do **not** default to the 2020 literals; they are disposable (§0).

### 3.4 Model shape

| Table | Source | Rows | Notes |
|---|---|---|---|
| `Snapshot` | native query, §5.1 | ~320,657 | the fact, per-date grain |
| `Snapshot Date` | `BIQL.DimCalendarInventorySnapshot` | 127 | **mark as date table**; 1:* to `Snapshot[Inventory Date]`, single direction |

Slicer binds to `'Snapshot Date'[Date]`, never to the fact column directly — a slicer on the fact hides
dates that happen to have no rows in the current filter context, and the two would drift.

---

## 4. The LB conversion — calibrated exactly

Cognos multiplies a per-row `CONVERSION_FACTOR_LB` carried on `INVENTORY_ON_HAND_MEASURES`. **The EDW
snapshot fact has no conversion column** (**V2**), so it must be reconstructed from
`BIQL.DimItemUOMConversionLBKG` (316,592 rows: `BusinessUnit`, `ItemNumShort`, `UOM nchar(2)`,
`UOMPrimary nchar(2)`, `ConversionFactorSecToPrim decimal(19,4)`, `LB decimal(26,9)`,
`KG numeric(26,10)`, `TM`), which is what reports 14 and 18 used for KG.

### 4.1 What `CONVERSION_FACTOR_LB` actually is (report 21's export, **V21**)

Report 21 is the same `INVENTORY_ON_HAND` star and arrived with a tight Cognos capture. Reading all
2,065 data rows of `Cognos export - tight capture 2026-08-06.xlsx`, grouped by primary UOM:

| Primary UOM | Cognos LB factor | Cognos KG factor | Rows |
|---|---|---|---|
| **KG** | **2.2045992** (one value, no exceptions) | 1.0 | 896 |
| **LB** | **1.0** (one value, no exceptions) | 0.453597189 (= 1 / 2.2045992) | 1,130 |
| EA | per-item: 44.091984, 44.0, 1.0, 0.0533513, 0.0507058, 0.0238097 … | per-item: 20.0, 19.958276, 0.0242, 0.023, 0.0108 … | 39 |

So `CONVERSION_FACTOR_LB` **= (kg per primary unit) × K**, where kg-per-primary is real per-item JDE
data and **K = 2.2045992** is DW_LEGACY's single KG→LB constant. It resolves to a constant for KG- and
LB-primary items and to genuine per-item data only for `EA`. The two calibration pairs pin K to all
seven digits — arithmetic confirmed in SQL (**V21**):

```
567    × 2.2045992 = 1250.0077464    (Cognos: 1250.0077464)   exact
8276.5 × 2.2045992 = 18246.3652788   (Cognos: 18246.3652788)  exact
44.091984 / 2.2045992 = 20.0         (the 20-kg drum)         exact
```

### 4.2 EDW uses a different constant — and this explains an old open residual

EDW's table encodes the same structure with **K = 2.20462** (**V24**: `LB / KG` = 2.20462 on the
dominant KG-primary rows). The physical value is 2.20462262. All three agree to five significant
figures and differ at the sixth:

| Source | K | 567 kg → | vs Cognos |
|---|---|---|---|
| **DW_LEGACY (Cognos)** | **2.2045992** | 1250.0077464 | — |
| EDW `DimItemUOMConversionLBKG` | 2.20462 | 1250.0195400 | +0.00094% |
| Physical | 2.20462262 | 1250.0210255 | +0.00106% |

0.00094% has no business meaning and **total** meaning for validation: the report-out workbook compares
per column with `EXACT()` (CLAUDE.md §6), and 1250.01954 ≠ 1250.0077464 on every KG-primary row.

This is almost certainly the root cause of a residual report 14 logged and never chased — its §9.5:
*"~30 rows LB off by ~0.5 in 48,501 (1e-5 — KG→LB factor precision, cosmetic)"*. 1e-5 relative is the
signature. Worth telling that report's owner.

Note EDW is also internally inconsistent: `LB / KG` takes the values 2.2046 (169,541 rows), 2.20462
(98,990), 2.2046244202 (47,242) and a long tail (**V24**). Pinning K removes that inconsistency as a
side effect.

### 4.3 The rule to build

Derive **kg per primary unit** from EDW (real per-item data) and apply K once, as a **named constant in
one place**:

```
K_KG_TO_LB = 2.2045992          -- DW_LEGACY's constant, pinned from report 21's tight capture (V21)

LB per primary unit =
  1)  UOMPrimary = 'LB'                    ->  1.0                     -- Cognos: exactly 1.0, 1,130/1,130 rows
  2)  kg-per-primary available             ->  KGperPrim × K_KG_TO_LB
  3)  otherwise                            ->  BLANK                   -- §4.4
```

Coverage on the rows that matter — CINC+CIN2 @ 2026-08-04, `QOH ≠ 0`, 2,360 rows (**V25**):
**2,222 (94.2%) take rule 1**, 91 take rule 2, 47 take rule 3.

**Rule 1 is mandatory, not a shortcut.** Round-tripping LB-primary rows through kg would introduce an
8e-6 error on 94% of the report (EDW's kg-per-primary for LB-primary items is 0.453592, whose product
with K is 0.9999918, not 1.0). Cognos uses exactly 1.0 for all 1,130 of its LB-primary rows.

**Derive kg-per-primary with an identity guard.** Take the conversion row where `UOM = UOMPrimary`
first, and on that row force the divisor to 1 rather than dividing by `ConversionFactorSecToPrim`:
**161 rows carry `UOM = UOMPrimary = 'KG'` with a bogus `ConversionFactorSecToPrim = 2.2046`**, which
would yield 1.000009 lbs per kg instead of 2.2046 — a 2.2× error. **39 of those 161 are at CINC/CIN2**
(13 CINC, 26 CIN2), so this is in scope, though only **1** fact row @ 2026-08-04 actually lands on one
(**V26**). Report 18's formula divides unconditionally and would ship the bug. The `ROW_NUMBER`
tie-break itself is safe: **0 ambiguous (item, branch) groups** (**V26**).

Effect of the constant choice on the day's grand total: **2.75 lbs out of 204,273,859,707** — because
94% of rows are identity. It is a per-row validation issue, not a materiality issue.

### 4.4 The 47 unconvertible rows

47 rows/day with non-zero quantity have no conversion row at all — all `UOMPrimary = 'EA'`, 41,000,944
EA (**V8**). An "each" has no intrinsic weight and EDW carries no factor. Cognos always shows *a*
number because DW stores one inline, **including its `-1` "no conversion" sentinel**, which report 14
§9.1 proved renders as physically absurd values (a 20,000 g lot shown as 880,000 lbs). **EDW's
conversion table has no negative values at all** — 0 rows with `LB < 0`, 0 with `KG < 0`, 0 with
`ConversionFactorSecToPrim = 0` (**V9**) — so the sentinel is not reproducible and must not be
simulated.

Decision: leave the value **BLANK** and surface the reason in an `[LB Factor Source]` column (§5.2). Do
not coerce to 0 — that reports "zero pounds" where the truth is "unknown pounds". Disclose per the
report-11 *we're-more-correct, disclosed* precedent.

(Related oddity to be aware of, not to act on: 8 `GM`-primary rows carry an EDW `LB`-per-primary of
exactly 1.0, which is physically wrong for grams. Rule 2 routes them through kg and avoids inheriting
it.)

---

## 5. Build

### 5.1 One query — `Snapshot`

Per CLAUDE.md §1 and the standing rule *no business logic in Power Query*: **SQL does projection,
mechanical joins, casts and the WHERE clause; every derived business value is a DAX calculated
column.** Reports 14 and 18 computed the weight conversion inside the `.m`; this spec deliberately does
not, and §4.2 is why — a constant buried in a `CASE` inside a native query is exactly how a 1e-5 drift
survives three validation rounds unexplained.

Comment-free production `.m`, with a maintained `Snapshot.commented.m` alongside (CLAUDE.md §1).
`Sql.Database("EDWPROD", "EDW")` → `Value.NativeQuery(..., null, [EnableFolding = false])`.
Native-query wrapper rules (report 14 §6): **no CTEs, no `ORDER BY`** — Power BI wraps the statement in
`SELECT * FROM ( … )`. Temp tables and `SET NOCOUNT ON;` are fine.

```sql
SET NOCOUNT ON;

-- kg per primary unit, one row per (item, branch), identity-guarded (§4.3)
SELECT z.ItemNumShort, z.BU, z.KGperPrim
INTO #kgf
FROM (SELECT k.ItemNumShort,
             ISNULL(LTRIM(RTRIM(k.BusinessUnit)), '') AS BU,
             k.KG / CASE WHEN LTRIM(RTRIM(k.UOM)) = LTRIM(RTRIM(k.UOMPrimary)) THEN 1.0
                         ELSE NULLIF(k.ConversionFactorSecToPrim, 0) END AS KGperPrim,
             ROW_NUMBER() OVER (PARTITION BY k.ItemNumShort, ISNULL(LTRIM(RTRIM(k.BusinessUnit)), '')
                                ORDER BY CASE WHEN LTRIM(RTRIM(k.UOM)) = LTRIM(RTRIM(k.UOMPrimary))
                                              THEN 0 ELSE 1 END, k.UOM) AS rn
      FROM BIQL.DimItemUOMConversionLBKG k WITH (NOLOCK)) z
WHERE z.rn = 1;
CREATE UNIQUE CLUSTERED INDEX ix_kgf ON #kgf (ItemNumShort, BU);

SELECT
    CAST(c.CalendarDate AS date)                AS [Inventory Date],
    LTRIM(RTRIM(snap.BusinessUnit))             AS [Branch Plant],
    ib.[Item Num 2nd]                           AS [2nd Item Number],
    ib.[Item Bulk]                              AS [Bulk Item],
    ib.[Item Global Bulk]                       AS [Global Bulk Item],
    LTRIM(RTRIM(ib.[Master Planning Family]))   AS [Master Planning Family],
    snap.QuantityOnHandPrimaryUOM               AS [Quantity on Hand],
    LTRIM(RTRIM(snap.UOMPrimary))               AS [Primary UOM],
    COALESCE(kx.KGperPrim, kb.KGperPrim)        AS [KG per Primary Unit],
    LTRIM(RTRIM(snap.Location))                 AS [Location],
    LTRIM(RTRIM(snap.LotNum))                   AS [Lot Number],
    snap.LotStatusCode                          AS [Lot Status],
    snap.ItemBranchSKey                         AS [ItemBranchSKey]
FROM BIQL.DimCalendarInventorySnapshot c WITH (NOLOCK)
    INNER JOIN dbo.FactInventorySnapshot_History snap WITH (NOLOCK)
            ON (CASE WHEN snap.CompanySKey = 2 THEN DATEADD(DAY, 1, c.CalendarDate)
                     ELSE c.CalendarDate END)
               BETWEEN snap.StartDate AND ISNULL(snap.StopDate, '9999-12-31')
    INNER JOIN BIQL.TbItemBranch ib WITH (NOLOCK)
            ON ib.ItemBranchSKey = snap.ItemBranchSKey
    LEFT  JOIN #kgf kx ON kx.ItemNumShort = snap.ItemNumShort
                      AND kx.BU = LTRIM(RTRIM(snap.BusinessUnit))
    LEFT  JOIN #kgf kb ON kb.ItemNumShort = snap.ItemNumShort
                      AND kb.BU = ''
WHERE LTRIM(RTRIM(snap.BusinessUnit)) IN ('CINC', 'CIN2')
  AND snap.QuantityOnHandPrimaryUOM <> 0
```

- **`WITH (NOLOCK)` on every source object** (CLAUDE.md §9) — a scan this size escalates to a
  table-level shared lock and blocks the replication writers that keep the warehouse current, in
  exactly the overnight window they run in.
- The `CompanySKey = 2` `CASE` is written generally even though every in-scope row is company 2
  (§1.2), so it stays correct if a branch is added.
- `LTRIM(RTRIM(...))` on every fixed-width `nchar` column.
- **The output date is `c.CalendarDate`, never `snap.StartDate`** — the shifted date is used only to
  *match* the interval.
- No decode, no business `CASE`, no aggregation. The projection carries ingredients.
- ⚠ Do not reformat casually after the first refresh: Power BI invalidates a partition when its M
  changes **as text** (CLAUDE.md §7), and reloading 320 K rows is not free.

### 5.2 DAX calculated columns on `Snapshot` — where the rules live

```dax
K_KG_TO_LB = 2.2045992      -- §4.2. Set to 2.20462 to use EDW's own constant. One place, one number.

LB Factor Source =
SWITCH(TRUE(),
    'Snapshot'[Primary UOM] = "LB",                "LB primary (identity)",
    NOT ISBLANK('Snapshot'[KG per Primary Unit]),  "Item KG factor x K",
                                                   "NO FACTOR — not convertible")

Quantity on Hand LBs (Row) =
SWITCH(TRUE(),
    'Snapshot'[Primary UOM] = "LB",                'Snapshot'[Quantity on Hand],
    NOT ISBLANK('Snapshot'[KG per Primary Unit]),  'Snapshot'[Quantity on Hand]
                                                     * 'Snapshot'[KG per Primary Unit]
                                                     * [K_KG_TO_LB],
                                                   BLANK())

Bulk Item (Display)        = COALESCE('Snapshot'[Bulk Item], "-")
Global Bulk Item (Display) = COALESCE('Snapshot'[Global Bulk Item], "-")
Master Planning Family (Display) =
    IF(LEN(TRIM('Snapshot'[Master Planning Family])) = 0, "-",
       TRIM('Snapshot'[Master Planning Family]))
```

Every branch is visible and every row self-identifies which branch it took. That is the whole point of
`[LB Factor Source]`: it costs one column and it is what would have surfaced §4.2 on day one.

### 5.3 ⚠ The measure must not sum across snapshot dates

On-hand is a **stock**, not a flow. 1,250 lbs on Monday and 1,250 lbs on Tuesday is 1,250 lbs of
inventory observed twice — never 2,500. Cognos never hits this because `Inventory Date` is one of its
`GROUP BY` keys, so every row it emits is a single date and it prints no total row at all. Power BI
*will* hit it, on the table's own total row, the moment a range spanning several dates is selected.

**Faithful semantic (ship this):** the value is defined only when exactly one snapshot date is in
filter context.

```dax
[Quantity on Hand LBs] =
VAR DatesInContext = DISTINCTCOUNT('Snapshot Date'[Date])
RETURN IF(DatesInContext > 1, BLANK(), SUM('Snapshot'[Quantity on Hand LBs (Row)]))
```

Behaviour: with `Inventory Date` on the axis every data row shows a value (one date each); the table's
total row goes **blank**, which is correct and matches Cognos printing no total. Remove `Inventory
Date` from the axis with a multi-date range selected and you get blank rather than a plausible wrong
number — discoverable, not silent. This is the trap being closed, and blank is the point.

**Alternative to offer Tim, not to default to** — closing position over the range:

```dax
[Quantity on Hand LBs (Latest in Range)] =
VAR LastDate = MAX('Snapshot Date'[Date])
RETURN CALCULATE(SUM('Snapshot'[Quantity on Hand LBs (Row)]),
                 'Snapshot Date'[Date] = LastDate)
```

This one *does* total meaningfully across a range, because it evaluates a single date. Ship it hidden
or in a separate visual; do not make it the default, because it is not what Cognos does.

The same rule applies to `[Quantity on Hand]` (primary UOM) if it is ever surfaced. Do **not** put a
bare `SUM` of either quantity in the field well.

### 5.4 The zero-quantity filter — a deliberate, measured departure

Cognos applies no quantity filter. Measured (**V15**) @ 2026-08-04, CINC+CIN2: `QOH > 0` **2,357** ·
`QOH = 0` **31,991** · `QOH < 0` **3**. **93% of EDW snapshot rows are zero-quantity positions**, and
a literal port emits ~31,284 rows *per date*, ~30,000 of them showing 0.00 lbs.

**Decision: `QuantityOnHandPrimaryUOM <> 0` at source.** Rationale: (a) it changes no reported number —
a zero-quantity position contributes exactly 0 lbs to every group it belongs to; (b) it is almost
certainly *closer* to Cognos, since a snapshot warehouse conventionally stores only non-zero positions
and the Oracle fact very likely never held these rows; (c) without it the model is 25× larger for no
information. Note `<> 0`, **not** `> 0` — reports 14 and 18 used `> 0` but had no negative rows to
lose; here 3 exist and Cognos would show them.

Validate (b) against the first Cognos export (**P4**). If Oracle does emit zero rows, this becomes a
disclosed difference rather than a neutral optimisation.

Bonus: 21 rows/day carry `ItemBranchSKey = -1` (dimension unknown member — `Business Unit
'????????????'`, `Item Num 2nd '??????'`). All 21 have `QOH = 0` and the filter removes them
(**V14**). **Assert this** rather than assume it; an unknown-member row with real quantity would render
as a `????` row in the client's report.

### 5.5 Reproducing the Cognos `GROUP BY` in the visual

Bind the six key columns + `[Quantity on Hand LBs]` to a flat `tableEx`; Power BI merges identical key
tuples and sums the measure — exactly Cognos's `GROUP BY` + `SUM`, and the r17 / report-14 §13 pattern.

The grouping is real work, not a formality: measured (**V13**) @ 2026-08-04, 34,351 fact rows collapse
to **31,284** output rows, **1,285** groups draw on more than one source row, and the largest merges
**26**. A `SELECT DISTINCT` would under-merge (report 14 §6, the r17 RULE B lesson).

Set `summarizeBy: none` on all six identifier columns (a stray `summarizeBy: sum` on an identifier
corrupts the grid, CLAUDE.md §7).

---

## 6. Attribute grain, sentinels, lot status, boundaries

### 6.1 `'-'` is a Cognos *rendering* of NULL — correction to COLLECTION_NOTES

The collection notes read the screenshot row `CINC | H1 | - | H1 | REC` as evidence of a literal `'-'`
sentinel in `BULK_ITEM`. **Measured (V16): the opposite.** In `BIQL.TbItemBranch` there are **0 rows**
with `[Item Bulk] = '-'`, **0** with `[Item Global Bulk] = '-'`, **0** empty strings in either — and
**385** / **17** NULLs respectively. Cognos's default missing-value character is `-`. Report 14 hit the
same thing from the other side (its §9.1: *"the xlsx renders blank `Location` as `-`; normalize before
joining or ~530 rows false-mismatch"*), and report 21's export shows `-` in its Lot Status column too.

The pattern reproduces exactly. A Path-A sample row (**V17**) reads `CIN2 | 1C | - | 1C | H2O` — 2nd
Item Number `1C`, **Bulk Item NULL**, Global Bulk `1C` — structurally identical to the screenshot.

**Build rule: store NULL, render `-`**, via the DAX display columns in §5.2 — not in SQL, not in a
format string. It is a presentation rule about a real distinction (missing vs blank vs `-`) and belongs
where it can be read. Counts in the output @ 2026-08-04: Bulk Item NULL **169**, Global Bulk NULL
**21**, MPF blank **240**, 2nd Item Number NULL/blank **0** (**V17**).

### 6.2 Master Planning Family — use item-**branch** grain; the risk is smaller than it looks

In Cognos MPF comes off `INVENTORY_ON_HAND`, the fact. EDW's fact has no MPF column, so it must come
from a dimension — and **which** dimension is the whole question.

**Report 14 already ran this experiment against a tight Cognos capture and the answer is unambiguous
(its §9.6 / §9.7):** sourcing MPF from item-grain `BIQL.DimItem` produced **2,209 mismatches on 4,129
shared keys — 53%**. Repointing to item-**branch** `BIQL.TbItemBranch` took it to **0**, and recovered
42 rows the item-grain filter had been silently dropping. Stock Type (981 → 0) and both Commodity
descriptions (121 → 0, 164 → 0) moved the same way. So Oracle's `INVENTORY_ON_HAND.MASTER_PLANNING_FAMILY`
resolves at **branch** grain, and `TbItemBranch` reproduces it exactly.

That is measured proof against real Cognos output, and it is stronger than anything this spec could
derive. My own probes corroborate the mechanism: MPF is genuinely branch-varying — **4,124 of 36,939
items (11.2%)** carry more than one distinct family across their branches (**V11**) — and `DimItem` vs
`TbItemBranch` disagree on **10,654 of 116,002 item-branch rows (9.2%)** (**V12**). By contrast Bulk
Item, Global Bulk Item and 2nd Item Number are effectively branch-invariant (**0** and **1** items
respectively with more than one value), so those three were never at risk.

**Use `BIQL.TbItemBranch`. Do not use `BIQL.DimItem` — report 18 does, and that is a bug it got away
with.**

**Residual, worth one line of disclosure:** the dimension is SCD1/current-state, so a family
reclassified *since* a snapshot date shows its current value against a historical position. There is
nowhere to get the historical value: neither fact carries MPF, and `dbo.DimItemBranch` — which has the
SCD2 machinery (`EffectiveFromDate`, `EffectiveThruDate`, `IsCurrent`) — is **empty of history**:
116,002 rows, one per SKey, all `IsCurrent = 1`, every `EffectiveThruDate` NULL, `EffectiveFromDate`
only back to 2026-06-16, and **no MPF column at all** (**V10**). This matters least at recent dates
(where current ≡ snapshot) and most at 2021 month-ends. It is a disclosure, not a redesign.

### 6.3 Lot status — no filter, deliberately

The native SQL has **no lot-status predicate**, so held / quarantined / rejected / on-test lots are all
in the quantity. Full population @ 2026-08-04, CINC+CIN2 (**V18**):

| `LotStatusCode` | Rows | Σ QOH (primary UOM) |
|---|---|---|
| `' '` (blank = approved/none) | 33,607 | 204,313,717,545.80 |
| `A` | 54 | 139,098.50 |
| `B` | 36 | 273,027.00 |
| `E` | 59 | 105,974.28 |
| `H` (hold) | 24 | 106,959.00 |
| `L` | 89 | 234,865.83 |
| `P` | 63 | 54,534.23 |
| `Q` (quarantine) | 39 | 9,007.00 |
| `T` (test) | 379 | 2,160.00 |
| `Z` | 1 | 1,068.71 |

Ten distinct values, 744 non-blank rows. **All included, matching Cognos.** `Lot Status` is carried
into the model as a non-displayed column so the choice is auditable and a carve-out is one filter away
(**Q2**).

### 6.4 The timestamp boundary is moot

The native SQL's `TIMESTAMP '2020-12-31 00:00:00.000000000'` would half-exclude the last day if the
date column carried a time. It does not: `CalendarDate`, `StartDate`, `StopDate` are all `date`, and
the fact's separate `TimeofDay datetime2` is **100% NULL** — 0 distinct non-null values across all
106,449 rows of 2026-08-04 (**V19**). A date-range predicate needs no boundary special-casing.

### 6.5 Water dominates the LB total — check this against any Cognos export

Measured (**V20**) @ 2026-08-04, CINC+CIN2: Σ LB over all families = **204,273,816,213.74**, of which
MPF `H2O` alone is **204,263,210,615** — **99.995%**. Excluding H2O: **10,605,598 lbs**, which is the
order of magnitude a plant inventory report should show. The H2O rows are bulk-water pseudo-lots
(`SH2OF`, `DIH2O`, `1ADIH2O` …) with blank Location; the two largest are single rows of 99.98 bn and
99.52 bn lbs.

The screenshots' visible MPF domain is `FCB FEC RRC FRC TOL RCB FBW RBW REC` — **no `H2O`, no `PKG`** —
though 40 rows across two pages is not proof of absence. Report 18's queries explicitly excluded
`MasterPlanningFamily NOT IN ('H2O','PKG')`; **report 20's native SQL has no such exclusion**, so the
default is to include them. If the Cognos output omits H2O, the port is off by five orders of magnitude
on every total. **Highest-value single check against any export** (**P5**), and **Q3** for Tim.

---

## 7. Pages / layout

One page, one flat `tableEx`, seven columns **in this order** (headers = Cognos `label`, all defaults):

1. Branch Plant
2. 2nd Item Number
3. Bulk Item *(display column, §5.2)*
4. Global Bulk Item *(display column)*
5. Master Planning Family *(display column)*
6. Quantity on Hand LBs *(measure, `#,0.00`)*
7. Inventory Date *(`d MMM, yyyy` — ⚠ confirm against the screenshots' `1/1/2020`, **Q4**)*

Slicers: **`Snapshot Date` range slicer** (§3.3, default = latest date), Branch Plant, Master Planning
Family.

No sort is specified in the report XML (no `sortList`) — Cognos returned database order. Choose
Branch Plant ▸ 2nd Item Number ▸ Inventory Date ascending and note it as a deliberate improvement.
No grouping, no summary row, no conditional formatting: the XML has none, so **no PBIR values-CF
selectors are involved** and the `dataViewWildcard` trap (CLAUDE.md §7) does not arise. Renames via
`displayName`; never a duplicate `nativeQueryRef`. Standard `Last Refreshed` card.

Import mode. Two tables, one relationship (`Snapshot Date` 1:* `Snapshot`, single direction),
`Snapshot Date` marked as the date table.

---

## 8. Probe plan (run once on the jumpbox before the first refresh)

Six categories per CLAUDE.md §1. **P1–P3 and P6 are answered locally** (§9); carry them to the jumpbox
only to confirm the mirror is not stale — it proves SQL correctness, never freshness (CLAUDE.md §9).
**P4 and P5 need Cognos and cannot be answered here.**

| # | Category | Probe | Status |
|---|---|---|---|
| P1 | Column existence | all 7 columns resolve, with types | **Answered — V2, V3** |
| P2 | Join drops / fan-out | `snap → TbItemBranch` on `ItemBranchSKey`; assert no `ItemBranchSKey = -1` row survives the filter | **Answered — V14**; the assertion is new |
| P3 | Count parity | rows before/after `GROUP BY`; multi-row group count | **Answered — V13** |
| P4 | Code decodes | `'-'` = NULL rendering; **do zero-quantity rows appear in Cognos?** (§5.4) | **Half — V16/V17 prove the EDW side; Cognos side needs an export** |
| P5 | Fan-out / scope | **does the Cognos output contain `H2O`?** (§6.5) | **Cognos-only. Highest value.** |
| P6 | Format spot-checks | date rendering, LB decimals to 7 places, thousands separators | Partly — needs the screenshots (§11.0) |
| P7 | **LB constant** | re-run the §4.1 calibration against report 20's own export once one exists — confirm `K = 2.2045992` holds for CINC/CIN2 | **Pinned from report 21 (V21); confirm on this report's data** |

Validation method (CLAUDE.md §7): **tight capture** — Cognos export and PBI numbers pulled minutes
apart. ⚠ Report 14 §9.2 found `DW_LEGACY` had already purged a 10-day-old snapshot date, so pick a
recent date and confirm Cognos still returns rows before planning a tie-out.

---

## 9. Validation log (numbered, append-only)

All entries run against the local SQL mirror of `EDW-ODS Snapshot` on **2026-08-06** unless stated.
Per CLAUDE.md §9 this proves SQL correctness and column semantics only — never freshness, never
performance.

### V1 — Data floor
EDW inventory history begins **2021-06-30** (`BIQL.FactInventorySnapshot_History_Filtered`,
13,349,051 rows, `CalendarDate` 2021-06-30 → 2026-08-05) / **2021-06-02**
(`dbo.FactInventorySnapshot_History`, 2,029,747 rows, `StartDate` 2021-06-02 → 2026-08-05). Nothing
earlier exists; the §3.2 spine bounds the slicer so a user cannot select below it.
`ODS.PRODDTA.F41021` is current-only (120,086 rows, only julian stamp columns) and cannot serve a date
range at all.

### V2 — Column existence, snapshot fact
`_Filtered` view: 43 columns — `CalendarDate date`, `ItemSKey`, `ItemBranchSKey`, `BusinessUnit nchar(12)`,
`Location nvarchar(20)`, `LotNum nchar(30)`, `QuantityOnHandPrimaryUOM decimal(19,4)`,
`LotStatusCode nchar(1)`, `ItemNumShort`, `UOMPrimary nchar(2)`, `CompanySKey`, `StartDate`/`StopDate`,
`AmountUnitCost`, `AmountValueAtCost`, `TimeofDay datetime2`. `dbo` twin: 48 columns, adds
`ItemCostSKey`, `UOMSKey`, `LoadDate`, `Source`; its `Location` is `nchar(20)`.
**Neither carries `MasterPlanningFamily`, `ItemNum2nd`, `ItemBulk` or `ItemGlobalBulk`.**

### V3 — Column existence, `BIQL.TbItemBranch`
116,002 rows. `[Business Unit] nchar(12)`, `[Item Num 2nd] nvarchar(25)`,
`[Master Planning Family] nchar(3)`, `[Item Bulk] nvarchar(25)`, `[Item Global Bulk] nvarchar(25)`,
`ItemBranchSKey int`, `ItemSKey int`. **Column names contain spaces — bracket them.**

### V4 — `_Filtered` spine is month-end-only before 2026-06
Distinct `CalendarDate` per month: exactly **1** for every month 2021-06 → 2026-05 (60 consecutive),
then **30** in 2026-06, **31** in 2026-07, **5** in 2026-08. Confirms report 18's pruned-spine finding.
2026-08-05 is a **partial** load (17,496 rows vs ~106,000/day) — 2026-08-04 is the reference date
throughout this log.

### V5 — The company-2 +1-day shift reproduces the view exactly
CINC+CIN2. 2026-08-04 (daily): view **34,351**, `dbo` +1d **34,351** ✔, no shift 34,177 ✘.
2026-04-30 (month-end): view **34,593**, `dbo` +1d **34,593** ✔, no shift 34,383 ✘.
`dbo` + shift works at any date back to 2021-06-02 (spot checks: 2021-09-15 → 33,886; 2023-03-15 →
34,421; 2024-11-07 → 33,022; 2025-06-18 → 33,472).

### V6 — Both branches are `CompanySKey = 2`
CINC 444,410 and CIN2 617,597 interval rows, **all** `CompanySKey = 2`; no other key appears. The shift
governs the entire report.

### V7 — `TbItemBranch` cannot fan out
116,002 rows, 116,002 distinct `ItemBranchSKey`, **0** duplicate-SKey groups.

### V8 — Conversion coverage, CINC+CIN2 @ 2026-08-04 (34,351 fact rows)
Rows with no conversion row from either the exact-BU or blank-BU match: **2,773** (8.1%), of which 2,491
are LB-primary (identity) or zero-quantity. **LB-primary rows whose EDW factor ≠ 1.0: 0.**
KG-primary rows: **568**, of which **470** have a factor and **21 deviate >0.5% from the physical
2.20462262** → the per-item factor must win over any constant. **No factor, not LB-primary, `QOH ≠ 0`:
47 rows, all `UOMPrimary = 'EA'`, 41,000,944 EA.**

### V9 — EDW's conversion table carries no `-1` sentinel
`BIQL.DimItemUOMConversionLBKG` (316,592 rows): **0** with `LB < 0`, **0** with `KG < 0`, **0** with
`ConversionFactorSecToPrim = 0`. The DW_LEGACY `-1` sentinel behind report 14's ×20/×44 artifacts has
no EDW analogue and must not be simulated.

### V10 — No historical attribute grain anywhere in EDW
No MPF column on either snapshot fact. `dbo.DimItemBranch`: 116,002 rows, 116,002 distinct
`ItemBranchSKey`, `IsCurrent = 1` for **all**, `EffectiveThruDate` NULL for all, `EffectiveFromDate`
range **2026-06-16 → 2026-08-05**, and **no `MasterPlanningFamily` column** (0 columns matching
`%Planning%Family%`). The SCD2 machinery exists and is empty.

### V11 — MPF is branch-varying; Bulk / 2nd Item are not
Of 36,939 items in `TbItemBranch`, **4,124 (11.2%)** carry more than one distinct
`[Master Planning Family]` across branches. **0** items have more than one `[Item Bulk]`; **1** has more
than one `[Item Num 2nd]`.

### V12 — `DimItem` vs `TbItemBranch` MPF disagree on 9.2%
116,002 item-branch rows joined to `BIQL.DimItem` on `ItemSKey`: MPF differs on **10,654**.
Corroborates report 14 §9.6/§9.7, which measured the same defect against a real Cognos capture
(2,209 mismatches → 0 after repointing to `TbItemBranch`).

### V13 — The `GROUP BY` genuinely merges
CINC+CIN2 @ 2026-08-04: **34,351** fact rows → **31,284** output rows on the six Cognos keys.
**1,285** groups draw on >1 source row; largest merges **26**. Four-day window 2026-08-01…04 →
**125,132** output rows.

### V14 — Join drops: none
`snap.ItemBranchSKey → TbItemBranch` @ 2026-08-04: 34,351 → **34,351** (0 unmatched, 0 fan-out).
`ItemSKey → BIQL.DimItem`: 0 unmatched. **21 rows carry `ItemBranchSKey = -1`** (unknown member:
`Business Unit '????????????'`, `Item Num 2nd '??????'`, `Item Bulk` NULL, MPF `'   '`); all have
`QOH = 0` and are removed by the §5.4 filter.

### V15 — 93% of snapshot rows are zero-quantity
CINC+CIN2 @ 2026-08-04: `QOH > 0` **2,357** · `QOH = 0` **31,991** · `QOH < 0` **3**. Output rows after
`GROUP BY`: unfiltered **31,284**, restricted to `QOH > 0` **1,247**.

### V16 — `'-'` is a render of NULL, not a stored value (corrects COLLECTION_NOTES)
`BIQL.TbItemBranch`: `[Item Bulk] = '-'` → **0 rows**; `[Item Global Bulk] = '-'` → **0 rows**;
`[Item Bulk] IS NULL` → **385**; `[Item Global Bulk] IS NULL` → **17**; empty strings → **0**.

### V17 — Output sample; the screenshot pattern reproduces
CINC+CIN2 @ 2026-08-04, grouped on the six Cognos keys, `Σ QOH > 0`. Format
`Branch Plant | 2nd Item | Bulk | Global Bulk | MPF | LBs | Date`:

```
CIN2 | 100C          | 100C       | 100C     | H2O | <NULL>   | 2026-08-04
CIN2 | 100FGK        | 100FGK     | 100FGK   | REC | 22000.00 | 2026-08-04
CIN2 | 104DPM        | 104DPM     | 104DPM   | RCB |   823.90 | 2026-08-04
CIN2 | 15S40         | 15S40      | 15S40    | RCB |  2358.00 | 2026-08-04
CIN2 | 161190PX-T2   | 161190PX   | 161190PX | TOL | 40765.00 | 2026-08-04
CIN2 | 1C            | -          | 1C       | H2O | <NULL>   | 2026-08-04
CIN2 | 2%CAR934      | 2%CAR934   | 2%CAR934 | FCB |    18.00 | 2026-08-04
CIN2 | 211001PX.E-PD | 211001PX.E | 211001PX | FCB |  1388.91 | 2026-08-04
CIN2 | 227158X-T3    | 227158X    | 227158X  | FRC | 16200.00 | 2026-08-04
CIN2 | 231350PX.S    | 231350PX.S | 231350PX | FRC |   436.92 | 2026-08-04
```

`CIN2 | 1C | - | 1C | H2O` is structurally identical to the screenshot's `CINC | H1 | - | H1 | REC`.
Null counts in the same population: Bulk Item **169**, Global Bulk **21**, MPF blank **240**, 2nd Item
Number **0**. `<NULL>` LB values are the §4.4 unconvertible rows.

### V18 — Lot-status population
10 distinct `LotStatusCode` values, 744 non-blank rows @ 2026-08-04 — table in §6.3. Includes `H` (24),
`Q` (39), `T` (379). All included, matching Cognos.

### V19 — No time component
`TimeofDay` is **100% NULL** — 0 distinct non-null values across all 106,449 rows of 2026-08-04.
`CalendarDate` / `StartDate` / `StopDate` are `date`.

### V20 — Water is 99.995% of the LB total
CINC+CIN2 @ 2026-08-04: Σ LB all families **204,273,816,213.74**; excluding `H2O` **10,605,598.33**.
Family row counts / Σ QOH: H2O 119 / 204,304,210,483 · FCB 4,149 / 2,222,156 · FRC 3,006 / 2,214,339 ·
RRC 1,392 / 1,949,890 · RCB 1,765 / 1,204,895 · FEC 1,567 / 1,003,035 · REC 1,803 / 856,264 ·
RBW 184 / 562,636 · FBW 360 / 251,413 · TOL 265 / 83,077 · PKG 234 / 46,535 · RWW 42 / 38,604 ·
blank 240 / 251 · RAW 608 / 663 · ATP/CTR/ETP/INT/NPK/SPC/WAG all 0. Largest rows: item 707495 lot
`SH2OF` @ CINC = 99,979,027,909 lbs; item 704770 lot `SH2O` @ CINC = 99,515,698,496 lbs.

### V21 — **`CONVERSION_FACTOR_LB` calibrated: `K = 2.2045992`, exact to 7 digits**
All 2,065 data rows of `Cognos Reports\21 …\Intake\Cognos export - tight capture 2026-08-06.xlsx`
parsed and grouped by primary UOM (branches AUBA 452 / CIN2 865 / SING 183 / SNG4 260 / CINC 278 /
AUB2 27):

| Primary UOM | LB factor (LB col ÷ Qty) | KG factor | Rows |
|---|---|---|---|
| KG | **2.2045992** — one value, no exceptions | 1.0 | 896 |
| LB | **1.0** — one value, no exceptions | 0.453597189 (= 1/K) | 1,130 |
| EA | per-item: 44.091984 · 44.0 · 1.0 · 0.0533513 · 0.0507058 · 0.0238097 | 20.0 · 19.958276 · 0.0242 · 0.023 · 0.0108 | 39 |

Arithmetic verified in SQL: `567 × 2.2045992 = 1250.0077464` and
`8276.5 × 2.2045992 = 18246.3652788` — both **exact** against the export. `44.091984 / 2.2045992 = 20.0`
exactly (a 20-kg drum). ⇒ `CONVERSION_FACTOR_LB = (kg per primary unit) × K`; it is a **per-UOM
constant** for KG/LB items and genuine per-item data only for `EA`.

### V22 — Picker sizing
Materialising `dbo.FactInventorySnapshot_History` over all 127 `DimCalendarInventorySnapshot` dates,
CINC+CIN2, `QOH ≠ 0`, with the company-2 shift: **320,657 rows.** That is EDW's entire retained
inventory history for these branches in one import table.

### V23 — `BIQL.DimCalendarInventorySnapshot`
**127 rows**, columns `DateSKey int` / `CalendarDate date`, range **2021-06-30 → 2026-08-06** —
**60** month-ends (≤ 2026-05-31) + **67** daily (> 2026-05-31). The `_Filtered` view exposes 126 of
them (2026-08-06 is seeded ahead of the fact load).

### V24 — EDW uses a different KG→LB constant, and is internally inconsistent
`LB / KG` across `DimItemUOMConversionLBKG`: **2.2046** (169,541 rows), **2.20462** (98,990),
**2.2046244202** (47,242), 0.4535929094 (561), 2.204595 (106), 2.2045 (45). On the dominant KG-primary
rows (`UOM = UOMPrimary = 'KG'`, 30,548 rows) `LB = 2.204620000` against `KG = 1.0`.
So EDW's constant is **2.20462** vs DW_LEGACY's **2.2045992** vs physical **2.20462262**:

| K | 567 kg → lbs | vs Cognos (1250.0077464) |
|---|---|---|
| 2.2045992 (Cognos) | 1250.0077464 | — |
| 2.20462 (EDW) | 1250.0195400 | +0.00094% |
| 2.20462262 (physical) | 1250.0210255 | +0.00106% |

Effect on the day's grand total: **2.75 lbs out of 204,273,859,707** (94% of rows are identity).
Effect on a per-column `EXACT()` compare: total. **Likely root cause of report 14 §9.5's unexplained
"~30 rows LB off by ~0.5 … 1e-5 … cosmetic".**

### V25 — §4.3 rule coverage
CINC+CIN2 @ 2026-08-04, `QOH ≠ 0`, 2,360 rows: rule 1 (LB-primary identity) **2,222 (94.2%)** ·
rule 2 (`KGperPrim × K`) **91** · rule 3 (BLANK) **47**. Rows where EDW's LB-per-primary is exactly
1.0: LB 2,220 · EA 9 · GM 8 (the GM rows are physically wrong in EDW; rule 2 routes them via kg and
avoids inheriting it).

### V26 — The identity guard, and tie-break determinism
**161 rows** carry `UOM = UOMPrimary = 'KG'` with `ConversionFactorSecToPrim = 2.2046` instead of 1.0;
dividing by it yields **1.000009 lbs per kg** instead of 2.2046 — a 2.2× error. **39 are at CINC/CIN2**
(CINC 13, CIN2 26; others at CIN3, DALL, SANF, AUBA, AUB2, NAPC, CGAY, CVAL, COCA, COCB, ORTC, NORM,
CANC, LABO, LAMBERT, SING, SNG4). Only **1** fact row @ 2026-08-04 lands on one, but the guard costs
nothing. Report 18's formula divides unconditionally.
Tie-break safety: **0** (item, branch) groups have more than one `UOM = UOMPrimary` candidate, so the
`ROW_NUMBER` pick is deterministic. Note **242,999 of 278,651** (item, branch) groups have *no*
`UOM = UOMPrimary` row at all — the general `KG / ConversionFactorSecToPrim` branch is the common
path, not the exception.

---

## 9a. Validation log — build round (appended 2026-08-06, entries V27–V36)

Run by the build agent. **V27–V32 are the first entries in this report's log backed by real
Cognos output** — the export filed at `Intake\Cognos export - 2020 full year (filed 2026-08-06).xlsx`
arrived after §1–§8 were written. Everything else is the local mirror, which per CLAUDE.md §9 proves
SQL correctness and column semantics only — never freshness, never performance.

⚠ **The export is calibration evidence, never a parity count.** EDW's inventory history begins
2021-06-30 and **not one of its 313 dates exists in EDW**, so no row-count reconciliation against it
is possible or attempted. What it can settle — and does — is column semantics, the `'-'` rendering,
the MPF grain, and the LB constant.

### V27 — The Cognos export, profiled
**499,227 data rows**, one sheet, the seven spec'd columns in the §2 order. `Inventory Date` spans
**2020-01-01 → 2020-12-31 over 313 distinct dates**. Branches **CIN2 309,911 / CINC 189,316** — the
CINC/CIN2 pair and nothing else, confirming the §5.1 `WHERE`. 2,351 distinct 2nd Item Numbers across
3,062 (branch, item) pairs. 18 distinct Master Planning Family values.

⚠ Correction to the intake note that `Quantity on Hand LBs` "renders as integers": it does not.
Decimal-place histogram — 0 dp **416,255** (83.4%) · 1 dp 32,138 · 2 dp 33,043 · 3 dp 9,188 ·
4 dp 3,630 · 5 dp 314 · 6 dp 41 · 7 dp 160 · 8 dp 32 · 9 dp 635 · ≥10 dp 3,791. The deep-decimal tail
is the residue of multiplying by a 7-decimal constant, and it is what makes V29 possible. Round
half-up on both sides before comparing (CLAUDE.md §7) still applies.

### V28 — **`H2O` and `PKG` ARE in the Cognos output — R3 closed, no family exclusion**
The single highest-value question in the spec (§6.5, **P5**, **Q3**, risk **R3** "High"). Measured
directly:

| MPF | rows | | MPF | rows |
|---|---|---|---|---|
| FCB | 130,502 | | RWW | 1,793 |
| FRC | 96,427 | | *(blank `'   '`)* | 993 |
| FEC | 76,757 | | WAG | 798 |
| RCB | 59,689 | | ETP | 291 |
| RRC | 42,398 | | ATP | 159 |
| REC | 39,440 | | INT | 109 |
| **PKG** | **11,189** | | FBW | 10,283 |
| **H2O** | **7,390** | | RBW | 10,168 |
| TOL | 8,057 | | RAW | 2,784 |

The native SQL has no family predicate and **the rendered output confirms it** — report 18's
`NOT IN ('H2O','PKG')` exclusion must **not** be carried over. The §6.5 worry that the port could be
off by five orders of magnitude on every total is settled: including them is correct. The screenshots'
apparent absence of `H2O` was the 20-row pagination trap (CLAUDE.md §7), exactly as §6.5 allowed for.
**Q3 no longer needs asking of Tim.**

### V29 — **`K = 2.2045992` confirmed on report 20's own data — P7 closed**
§4 pinned K from report 21's export; **P7** asked for confirmation on this report. Isolating the
**4,973 rows carrying ≥5 decimal places** (the genuinely converted ones — rows at 0–2 dp are mostly
LB-primary identity quantities and carry no information about K), and testing whether `LB ÷ K` lands
on a clean quantity:

| K | `LB ÷ K` an exact integer | clean to 4 dp |
|---|---|---|
| **DW_LEGACY 2.2045992** | **1,106 / 4,973 (22.24%)** | **2,233 / 4,973 (44.90%)** |
| EDW `DimItemUOMConversionLBKG` 2.20462 | 0 (0.00%) | 0 (0.00%) |
| physical 2.20462262 | 0 (0.00%) | 0 (0.00%) |

Both alternatives score **exactly zero** on 4,973 independent rows. Worked examples straight out of
the export: `1322.75952 ÷ 2.2045992 = 600` exactly; `4848.7998896784 ÷ 2.2045992 = 2199.402` exactly;
`1319.9993618016 ÷ 2.2045992 = 598.748` exactly. The remaining 55% are the per-item `EA` factors
(§4.1) and float-representation noise, both expected. **Ship K = 2.2045992** — confirmed twice over,
on two different reports' captures.

### V30 — **Master Planning Family is branch-grain — confirmed against real Cognos output**
§6.2 rests on report 14's experiment. Report 20's export corroborates it independently and, unlike a
mismatch count, **decisively**: of **711 items present at both CIN2 and CINC, 41 carry a different
family at each branch.**

```
ML160PFP-T2  CIN2=ETP  CINC=FEC        ACACID56  CIN2=RCB  CINC=RRC
FORMALFC     CIN2=RCB  CINC=REC        MT242R    CIN2=FCB  CINC=FRC
AMP95        CIN2=RCB  CINC=RRC        NAOH50    CIN2=RCB  CINC=RRC
```

An item-grain dimension holds **one** MPF per item and therefore *cannot* reproduce a single one of
these rows. `BIQL.DimItem` is not merely less accurate here — it is structurally incapable.
**`BIQL.TbItemBranch` confirmed; R5 stays closed.**

The same pass re-confirms **V11** from the Cognos side: **0** items carry more than one Bulk Item and
**0** more than one Global Bulk Item across branches — those three columns were never at risk.

Residual for §6.2 / **R8**, now quantified from real data: **27 of 3,062 (branch, item) pairs (0.9%)**
changed MPF *during* calendar 2020. That is the size of the SCD1 current-state exposure over a year —
small, and worth exactly the one line of disclosure §6.2 called for.

### V31 — `'-'` is a NULL render (§6.1 confirmed) — **and a correction to §5.2**
In all 499,227 rows the literal `-` appears in **`Bulk Item` only, 3,402 times**, and in no other
column. There are **no empty/None cells anywhere**. §6.1's "store NULL, render `-`" is confirmed on
rendered output.

⚠ **But `Master Planning Family` blank renders as blank, not as `-`.** The export carries **993 rows
whose MPF is the three-space string `'   '`** and **zero** rows where MPF is `-`. The reason is in
EDW: `BIQL.TbItemBranch.[Master Planning Family]` is `nchar(3)` and is **never NULL** — measured
**0 NULLs against 5,929 blank-space rows**. Cognos's missing-value character only fires on NULL, so
MPF can never take it.

**§5.2's third display column is therefore a parity defect and has not been built.** Shipped instead:
`Bulk Item (Display)` and `Global Bulk Item (Display)` (both `COALESCE(…, "-")` — Bulk NULL 385 and
Global Bulk NULL 17 in the dimension, so both genuinely need it), and the table binds
**`Snapshot[Master Planning Family]` directly**. Mapping its blank to `-` would have put a character
in 993-rows-per-year worth of cells that Cognos leaves empty.

### V32 — Zero and negative rows in Cognos — **P4 answered; §5.4 becomes a disclosed difference**
§5.4 predicted the Oracle fact "very likely never held" zero-quantity rows and asked for this check.
Measured in the export: **987 rows (0.198%) render `0`**, and **159 rows are negative**.

Two consequences, both concrete:

1. **Cognos does emit a small number of zero rows.** 0.198% is nowhere near EDW's **93%** (V15), so
   `QuantityOnHandPrimaryUOM <> 0` stands — it still removes ~30,000 empty rows per date and changes
   no reported number. But §5.4's own condition is met, so this ships as a **disclosed difference**,
   not a neutral optimisation. Added to §11.2's list in substance.
2. **`<> 0` rather than `> 0` is vindicated.** §5.4 chose it over reports 14/18's `> 0` on the strength
   of 3 negative rows in EDW. Cognos shows **159** negatives in one year — `> 0` would have dropped
   every one of them.

### V33 — **Spine changed to a generated daily list — §3.2's recommendation overturned**
§3.2 recommended `BIQL.DimCalendarInventorySnapshot` (127 rows: month-ends before 2026-06, daily
after) and flagged the generated daily list as the alternative. **V27 overturns it: 313 distinct dates
inside a single calendar year proves users were picking arbitrary DAILY dates.** A month-end-only
picker would silently withdraw a capability they demonstrably used — and `dbo.FactInventorySnapshot_History`
is SCD2 over a continuous range, so any date in the window is reconstructable. The 127-row calendar
is a limitation of the pre-built spine, not of the data.

**The self-bounding property survives, which was the whole merit of the original recommendation.**
Bounds are read from the fact itself — no date literal appears in either query:

```sql
SELECT @lo = MIN(CASE WHEN CompanySKey = 2 THEN DATEADD(DAY,-1,StartDate) ELSE StartDate END),
       @hi = MAX(CASE WHEN CompanySKey = 2 THEN DATEADD(DAY,-1,StartDate) ELSE StartDate END)
FROM dbo.FactInventorySnapshot_History WITH (NOLOCK)
WHERE LTRIM(RTRIM(BusinessUnit)) IN ('CINC','CIN2');
```

The `-1` is the company-2 shift read backwards: to *display* date D the query must *match* D+1, so the
last servable date is `MAX(StartDate) - 1`. Written as a general `CASE` so it stays correct if a
non-company-2 branch is added.

**Sizing — materially larger than §3.2 estimated.** Measured: **1,890 spine dates,
2021-06-02 → 2026-08-04**, materialising to **5,106,257 fact rows**. That is **15.9× the spec's
320,657**, not the "roughly 3×" §3.2 anticipated — because §3.2 sized 3× against a trailing-13-month
daily window, whereas self-bounding to the fact means **daily across the full five-year retained
range**. Per-date rows: min **2,045** (2025-12-12) · avg **2,703** · max **3,661**. Narrow table,
mostly low-cardinality strings, so Vertipaq should compress it well — but **first-refresh duration is
unmeasured and is the one thing to watch on the jumpbox.** A trailing-window bound is a one-clause
change if it proves painful.

**One interior gap, disclosed not hidden: 2022-10-24 returns no rows.** EDW holds only **189** interval
rows for that date at CINC/CIN2 and every one is zero-quantity — an EDW load gap, not a modelling
choice. 1,889 of 1,890 dates return data. The date is **kept** in the spine so the column stays
contiguous (which "mark as date table" requires); dropping it would change no number, since a range
spanning it has no rows there either way.

### V34 — The shipped SQL, run end-to-end on the mirror
The exact `Snapshot.m` query text, executed against the local mirror:

| Check | Result |
|---|---|
| Total rows | **5,106,257** |
| Distinct dates | **1,889** (of 1,890 — V33's gap) |
| Rows @ 2026-08-04 | **2,360** — ties **V25** exactly |
| **`ItemBranchSKey = -1` surviving the filter** | **0** — the §5.4 / **P2** assertion holds |
| `Master Planning Family` NULL | **0** (blank 2,254) — underpins V31 |
| `Bulk Item` NULL (→ renders `-`) | 53,982 |

**P2 is now an assertion that has actually been run**, not an assumption: no unknown-member row
survives, so no `????` row can reach the client's report.

### V35 — Rule coverage, and the identity guard is bigger than §4.3 sized it
§4.3's three-branch rule over all 5,106,257 rows:

| Rule | Rows | % |
|---|---|---|
| 1 — LB primary (identity) | **4,833,003** | 94.65% |
| 2 — `KGperPrim × K` | **182,296** | 3.57% |
| 3 — BLANK (no factor) | **90,958** | 1.78% |

The 94/4/2 shape holds across five years, not just the sample date — rule 1 remains mandatory, not a
shortcut (§4.3). Restricted to 2026-08-04 the split is **2,222 / 91 / 47**, ties **V25** exactly.
Rule 3 resolves to **90,368 `EA`** rows (§4.4's "an each has no intrinsic weight") plus **590 `KG`**
rows that carry no conversion row at all — the latter are new here and also ship BLANK with
`[LB Factor Source] = "NO FACTOR - not convertible"`.

Grand total under `K = 2.2045992` @ 2026-08-04: **204,273,859,704.52 lbs**, reconciling with **V24**'s
204,273,859,707 to within decimal rounding.

⚠ **The identity guard's blast radius is 11,788 rows, not 1.** §4.3/V26 measured "only 1 fact row
@ 2026-08-04 actually lands on one" and concluded the guard "costs nothing". Over the full 1,890-day
spine, **11,788 rows** get a different `KGperPrim` with the guard than without it — widening the spine
widened the exposure by four orders of magnitude. Report 18's unconditional divide would have shipped
a **2.2× error** on every one. The guard is built as specified; this entry records that it was never
the cosmetic detail it looked like at a single date.

### V36 — Build artifacts and lint
Built under `PBIP\` as **`Inventory for Tier 2 Report`** (artifact name kept short deliberately:
worst-case path 247 chars against the 256 limit — CLAUDE.md §5. `20 - Inventory for Tier 2 Report`
would have been 252, with 4 characters of headroom).

- **`powerbi-modeling` MCP `ConnectFolder`: loads clean** — 3 tables, 4 measures, 1 relationship, no
  parse errors. Relationship reads back as `Snapshot[Inventory Date]` **Many → One**
  `'Snapshot Date'[Date]`, `OneDirection`, active — exactly §3.4. `Snapshot Date` carries
  `dataCategory: Time` + `isKey` (marked as date table).
- **Microsoft PBIR validator: `0 error(s), 1 warning(s)`.** The lone warning is
  `PBIR_SCHEMA_UNREACHABLE` for `visualContainer/2.10.0`, the known 404 documented in CLAUDE.md —
  not a defect in this report. (Exec Dashboard scores 19/93 and OTIF 70/329 for scale.)
- Independent cross-check of every visual field reference against the model: **11/11 resolve, 0
  duplicate `nativeQueryRef`**, all JSON parses.
- TMDL is **tab**-indented, CRLF, **no UTF-8 BOM** (verified by byte inspection on every file).
  No `///` comment above the relationship.
- `Snapshot.m` / `Snapshot Date.m` and the PBIP partitions are emitted **from one source text**, so
  the shipped `.m` and the model cannot drift. `*.commented.m` masters maintained alongside.

**Not verifiable here, carried to the jumpbox:**
1. **No refresh was run** — every row count above is the local mirror, never EDWPROD. Nothing in this
   log is a freshness or performance claim.
2. **First-refresh duration for 5.1M rows is unmeasured** (V33).
3. **`[K_KG_TO_LB]` is referenced from a calculated column** on a 5.1M-row table, as §4.3 specifies.
   That is a context transition per row at *refresh* time only, not query time, and a constant measure
   should optimise away — but it is untested at this scale. If refresh is slow, this is the first
   thing to check.
4. ⚠ **The slicer's landing state is a stored date literal (`2026-08-04`)** — the latest snapshot date
   in the mirror at build time. §3.3 asks the page to open on "the latest snapshot date only", and
   Power BI has no way to express a *default range selection that follows the data*; it must be a
   persisted filter. **It will be stale on the first jumpbox refresh.** It is one literal in one file
   (`…\visuals\20b1010000000000fd01\visual.json`), or Zack can simply drag the slicer. Flagged rather
   than hidden — it is the only stale value in the build.

---

## 10. Risk register

| # | Risk | Severity | Status |
|---|---|---|---|
| R1 | Company-2 +1-day shift omitted ⇒ every row is the previous day's position | **High** | **Measured V5/V6.** Specified §5.1; silent if wrong |
| R2 | On-hand summed across snapshot dates in a total row | **High** | **Closed by design** — §5.3 guard measure |
| R3 | `H2O` in or out changes totals by 5 orders of magnitude | **High** | **Measured V20.** Needs a Cognos export (P5) or Tim (Q3) |
| R4 | KG→LB constant mismatch fails `EXACT()` on every KG-primary row | Medium | **Root-caused V21/V24.** Pinned `K = 2.2045992`, single named constant |
| R5 | MPF sourced at item grain instead of item-branch | Medium | **Closed** — §6.2; R14 measured 53% → 0 |
| R6 | 47 EA rows have no LB conversion | Medium | **Measured V8.** BLANK + `[LB Factor Source]` label |
| R7 | Zero-quantity exclusion departs from the native SQL | Medium | **Measured V15.** No number changes; validate vs export (P4) |
| R8 | MPF/attributes are current-state against historical positions | Low at recent dates, higher at 2021 month-ends | **Measured V10.** Disclose |
| R9 | Month-end-only spine before 2026-06 | Low | **Measured V4/V23.** Documented upgrade path, §3.2 |
| R10 | SSAS rejection rests on report 14's live probe; local `.bim` is the stale `BIQLTabular` | Low | Rejection is live-server evidence; structural detail provisional |
| R11 | No Cognos row count, no export, screenshots unfiled | Medium | §11.0 — intake incomplete |
| R12 | Mirror proves SQL correctness only, never freshness or performance | Low | CLAUDE.md §9; carry P1–P3/P6 to the jumpbox |

---

## 11. Open questions

### 11.0 For Zack / the orchestrator (intake completeness)
- **The two Cognos Viewer screenshots supplied in chat 2026-08-06 are still not filed into `Intake\`.**
  They are the only evidence of rendered output — date format, decimals, header labels, the `-`
  rendering — and P6 cannot close without them.
- **No Cognos row count and no export for this report.** The viewer paginates at 20 rows
  (CLAUDE.md §7), so the screenshots are pages 1–2. An export is needed for P4, P5 and P7.
- **Confirm Tim Bath is the owner** before taking §11.1 to him.
- **Tell report 14's owner about V21/V24** — it explains their §9.5 residual.

### 11.1 For Tim Bath
1. **What does "tier 2" mean?** It appears nowhere in the native SQL — no tier column, no tier filter,
   no tier grouping. Either it means the CINC/CIN2 branch pair, or it is applied downstream in Excel by
   whoever receives this. **We will not invent a tier dimension.**
2. **Should held / quarantined / test lots be excluded from Quantity on Hand?** Cognos includes them
   (no status filter) and the port follows — 744 non-blank-status rows/day across 9 codes (§6.3). One
   filter away if not wanted.
3. **Should bulk water (`H2O`) be in scope?** It is 99.995% of the LB total (§6.5). The native SQL has
   no family exclusion, but report 18's queries excluded `H2O` and `PKG`, and the screenshots show
   neither.
4. **Date format:** the screenshots render `1/1/2020` (US m/d/yyyy); project convention is
   `d MMM, yyyy`. Per-report parity is the standing choice (CLAUDE.md §7).
5. **Date range depth:** month-ends back to 2021-06-30 plus daily for the last two months (what EDW's
   own snapshot calendar offers, §3.2), or daily throughout? The latter costs ~3× the rows and one
   changed clause.
6. **Is HTML-in-Viewer the delivered form, or does everyone export to Excel?** `run.outputFormat` is
   empty. If everyone exports, a table with slicers is a strict improvement; if the HTML is pasted
   downstream, layout parity matters more.

### 11.2 Disclosures for the report-out
- **KG→LB constant.** Cognos uses 2.2045992; EDW's own table implies 2.20462; the physical value is
  2.20462262. We ship Cognos's for parity. All three agree to five significant figures (§4.2).
- **Master Planning Family and the item attributes are current-state**, applied to historical
  positions. Materially identical at recent dates; drifts at older ones (§6.2).
- **47 rows/day of `EA`-primary inventory have no LB conversion** and show blank rather than a
  fabricated zero (§4.4). Cognos shows a number because DW stores an inline factor including a `-1`
  sentinel that report 14 proved produces physically absurd values.
- **Zero-quantity positions are excluded** (§5.4). No reported number changes; ~30,000 empty rows per
  date do not appear.
