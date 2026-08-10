# DAX Validation Layer — Report 14

**Purpose:** every piece of report logic that has been hard to tie (or hard to explain) is
rebuilt in DAX on raw base tables, so the whole report can be walked through in the model —
relationships + `RELATED()` instead of SQL joins — during validation with Rohit.
The production queries (`Inventory`, `Escor Inventory`, `Escor Lot Info`) are untouched;
this layer sits beside them and ties out against them. It can be deleted after sign-off
(remove the 7 tables + relationships + the DAX Validation page).

**Needs one jumpbox refresh before first use** (7 new tables). Same AsOfDate parameter
drives everything.

## The pieces

| Table | Source (raw, no joins in SQL) | Role |
|---|---|---|
| `Snapshot` | `dbo.FactInventorySnapshot_History`, intervals covering AsOf or AsOf+1, the 9 branch plants | the fact — one row per item/lot/location position |
| `Item` | `BIQL.DimItem` | item master |
| `Lot` | `BIQL.DimLot` | lot master |
| `Company` | `BIQL.DimCompany` | company → currency |
| `FX Rate` | `BIQL.DimCurrencyExchangeRatesUSDDaily` @ AsOf | one row per currency, direct →USD multiplier |
| `UOM Conversion` | `BIQL.DimItemUOMConversionLBKG` | KG/LB factor rows |
| `Missing Lots` | static list (the 80 Cognos-only lots) | probe |

**Relationships (Model view):** `Snapshot→Item`, `Snapshot→Lot`, `Snapshot→Company`,
`Company→FX Rate` (so `RELATED` chains Snapshot→Company→FX), and an *inactive*
`Lot→Item` (would be ambiguous with the Snapshot path; Lot's item columns use
`LOOKUPVALUE` instead).

## How each "hard" piece reads in DAX (all on `Snapshot`, in display folders)

1. **The joins** — folder *Joined via RELATED*. Every Cognos join is one line, e.g.
   `Bulk Item = RELATED('Item'[Bulk Item])`. The INNER-JOIN semantics are explicit
   booleans: `Has Item Match` / `Has Lot Match` / `Has Company Match`
   (`NOT ISBLANK(RELATED(...))`).
2. **The Select-Date logic + Aubange timezone shift** — folder *Scope (WHERE clause)*.
   `Interval Match Date` = AsOf, **+1 day when CompanySKey = 2**; `In Interval` checks it
   against the row's `Interval Start/Stop`. Filter a table visual to CompanySKey = 2 to
   show the shift doing real work.
3. **The whole WHERE clause** — `In Inner Query` (joins + interval + family list + the
   widened QOH-or-cost-carrier condition) and `In Report` (`In Inner Query && QOH > 0`).
   Cognos's row population is literally a TRUE/FALSE column you can filter on.
4. **Carrier-borrow (the USD/EUR fix)** — folder *Cost & FX*. `Unit Cost (Borrowed)` is
   the aggregate equivalent of the SQL window function: `MAXX(FILTER(Snapshot, same
   item + branch, ItemCostSKey <> -1, In Inner Query), Unit Cost (Lot))`.
   `Cost Source` labels each row: *Own lot cost / Borrowed from item-branch cost
   carrier / No cost available*. Slice by it to show exactly which rows borrow.
5. **FX** — `FX Local to USD` (1.0 for USD companies, else `RELATED` from the FX table)
   and EUR **triangulation**: `Extended Cost EUR` divides by `FX EUR to USD`
   (`LOOKUPVALUE` of the EUR row). The 418-row cost residual vs Cognos can be narrated
   row-by-row: our unit cost is EDW `AmountUnitCost`; Cognos used Oracle `UNIT_COST`.
6. **KG/LB factors + the ×20/×44 sentinel** — folder *Weights (KG-LB)*.
   `KG/LB per Primary Unit (Dim)` reproduces the `#lbf` pick (exact branch → blank-branch
   fallback → primary-UOM-preferred row) with `FILTER`/`TOPN`. `Weight Source` labels each
   row: *Constant (KG/LB primary) / Dim factor / DW sentinel −1: ×20 KG ×44 LB / No
   conversion row*. The 19 GM/EA rows Cognos inflates (ETHAL.S) show up under the
   sentinel label — filter to it and the −1.24M LBs story tells itself.
7. **The GROUP BY grain** — `Rows (DAX)` = `COUNTROWS(SUMMARIZE(...19 output columns))`,
   the DAX form of the Cognos GROUP BY; ties to `Rows (SQL)`.

## Tie-out measures (folder *Tie-Out …* on `Snapshot`)

`X (DAX)` = the rebuild; `X (SQL)` = the production import table, mapped into the same
slice via `TREATAS` (Region/Branch Plant/Location/Lot/2nd Item); `X Delta` = difference,
should be **0.00 at every slice** for QOH/KGs/LBs/USD/EUR/Rows, plus the Escor trio and
`Lot Info Rows (DAX/SQL/Cognos)`. The **DAX Validation** report page has all of this laid
out (tie-out matrix by Region/Branch Plant, the Missing-Lots probe grid, Escor/Lot-Info
counts).

## The Missing-Lots probe (replaces 00_verify_tables.sql §6)

`Missing Lots` holds the 80 (Branch Plant, Lot Number) pairs that are in the fresh Cognos
Escor Lot Details export but not in our Lot Info output. After refresh, its `Verdict`
column answers §6 directly per lot:

- *"Not in DimLot — retention gap"* → reroute Escor Lot Info to ODS `F4108`
- *"In DimLot but ItemSKey does not resolve"* → re-key the join
- *"In DimLot — Bulk Item changed to X"* → SCD1 drift; Cognos re-run would drop them too
- *"In DimLot and still ESC"* → defect in our query (not expected)

`Missing Lots Found in DimLot` (of `Missing Lots Total` = 80) is the headline number.

## Caveats

- `Snapshot` deliberately loads a superset (both AsOf and AsOf+1 interval windows, QOH=0
  cost carriers, all families). Row counts of the raw table mean nothing; only
  `In Report`-filtered numbers are the report.
- `X (SQL)` measures assume the production tables and the validation slice were refreshed
  from the same AsOfDate in the same refresh — refresh everything together.
- Expected non-zero deltas: none. The rebuild mirrors the production SQL exactly
  (including the sentinel guard and Escor's no-guard variant). Any non-zero delta is a
  real divergence between the DAX rebuild and the SQL — find it by drilling the slice.
