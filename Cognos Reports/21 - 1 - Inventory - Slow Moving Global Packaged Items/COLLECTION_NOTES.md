# Cognos source collection — Report 21

- **Report name:** 1 - Inventory - Slow Moving Global Packaged Items
- **Cognos path:** `Michelman Reporting / Production and Shipping / Cogan Excel AD HOC Reports`
- **Portal folder ID:** `i52030381F2354AC6818EE9527C4297C8`
- **Cognos package:** `/content/package[@name='Data Warehouse']/model[@name='model']` — DW_LEGACY.
  Two stars: **Inventory On Hand** and **Order Activity**.
- **Run output format:** `spreadsheetML` (Excel), `run.prompt=true` but no prompt pages or
  parameters in the XML — inert, same as reports 19 and 20.
- **Assigned to Zack 2026-08-06.** Best-documented intake of the three.

Same Cognos folder as report 19; `1 - ` prefix puts it in the Cogan Excel AD HOC family with
reports 13 / 14 / 18 / 19.

## Collected so far

| File | What it is |
|---|---|
| `Intake\Query + XML - NATIVE SQL (filed 2026-08-06).txt` | **Native (Oracle) SQL** for all three queries + full report XML |
| `Intake\Cognos export - tight capture 2026-08-06.xlsx` | Three-sheet output export, `DATE` column = **2026-08-06** |

**This is the only one of the three new reports with a tight capture** (§7 validation method): the
export was pulled today, so a PBI refresh run now is directly comparable. Do not let it go stale —
if the build slips more than a few days, pull a fresh pair.

⚠ Note the SQL here is **native**, unlike reports 19 and 20 which arrived as IBM Cognos SQL. Native
gives real Oracle syntax and resolved `sysdate` arithmetic; treat this file as the more trustworthy
of the two forms.

---

## Report anatomy

Three pages, three independent queries, three flat lists. No grouping, no summaries, no prompts.
Headers bold red on 1pt black borders; dates `dateStyle="medium" displayOrder="DMY"` (day-first).
All three sort `Global Bulk Item, Bulk Item, 2nd Item Number, Branch Plant`.

| Sheet | Query | Rows in export | Cols | Grain |
|---|---|---|---|---|
| `Inventory_1` | Inventory | **2,065** | 17 | lot × location × item × branch, yesterday's snapshot |
| `Shipments_2` | Shipments | **17,259** | 19 | order line, last 365 days |
| `Items - Active_3` | Items | **5,286** | 5 | item-branch master, distinct |

**Business intent:** a classic slow-mover analysis. Sheet 3 is the spine (every active packaged
item-branch), sheet 1 is what is sitting in stock right now, sheet 2 is what has actually moved in
the last year. Items present in 1 with little or nothing in 2 are the slow movers. **Nothing in
Cognos joins the three** — the analysis happens in Excel by hand.

That makes this the strongest candidate of the batch for a **real rebuild rather than a port**: one
model, three tables, proper relationships on item-branch, and the slow-moving logic expressed as
DAX measures (days-of-supply, last-shipment-date, on-hand with no movement in N days). Recommend
speccing both the 1:1 port and the modelled version, and putting the choice to the requester.

---

## The common thread: `GL_CLASS_CODE = 'IN32'`

Every one of the three queries filters on it. This is what "Global Packaged Items" means in this
report — it is the whole scope definition, not a detail.

In EDW: the snapshot fact carries `CategoryGLF41021` (+ `CategoryGLDescF41021`) and
`BIQL.TbItemBranch` carries both `Category GL F4101` and `Category GL F4102`. **Three candidate
columns for one Cognos column** — and note query 1 takes GL class from the *inventory fact* while
queries 2 and 3 take it from the *item*. Getting this wrong silently changes the population of all
three sheets. Settle it with counts before anything else.

---

## Query-by-query

### 1. Inventory — yesterday's on-hand, lot grain

```
INVENTORY_DATE = to_date(sysdate) - 1
QUANTITY_ON_HAND > 0
GL_CLASS_CODE = 'IN32'
BRANCH_PLANT in ('CINC','CIN2','CIN4','AUBA','AUB2','SING','SNG4')
```

Joins `INVENTORY_ON_HAND` + `INVENTORY_ON_HAND_MEASURES` + `ITEM` + `ITEM_LOT_NUMBERS` (for
`ON_HAND_DATE` and `LOT_EXPIRY_DATE`). Measures: `SUM(QUANTITY_ON_HAND)`, and the same × KG and
× LB conversion factors.

- **`to_date(sysdate) - 1` truncates first, then subtracts** — a clean "yesterday", no half-day
  ambiguity. Confirmed by the export: `DATE` = 2026-08-06, so the snapshot is 2026-08-05.
- **Seven branch plants, including `CIN4`** — one more than report 19's six.
- Lot-level detail (`Location`, `Lot Number`, `Lot Status`, expiry) means this maps to the same
  lineage as reports 14 and 18. `BIQL.FactInventorySnapshot_History_Filtered` holds `Location`,
  `LotNum`, `LotStatusCode`, `QuantityOnHandPrimaryUOM` and `CalendarDate`; whether
  `BIQL.FactInventorySnapshot` (current-only, 120k rows) is the better fit for a "yesterday" query
  is a real choice to make, not a coin flip.
- `ITEM_LOT_NUMBERS` supplies **two dates that may have no EDW home** — `ON_HAND_DATE` and
  `LOT_EXPIRY_DATE`. The snapshot fact has `LastReceiptDate` but nothing obviously expiry-shaped.
  Report 18 dealt with lot status and shelf life; check what it used. **This is the biggest
  column-availability risk in the report.**

### 2. Shipments — last 365 days, order-line grain

```
ORDERED_QTY * SALES_FACTOR > 0
DUE_DATE >= to_date(sysdate) - 365
LINE_TYPE = 'S'
ORDER_TYPE_CODE not in ('ST')
ORGANIZATION_ID in ('CINC','CIN2','CINC','AUBA','AUB2','SING','SNG4')
ITEM.GL_CLASS_CODE = 'IN32'
decode(GLOBAL_BULK_ITEM,'-',ITEM_NUMBER_2ND,GLOBAL_BULK_ITEM) not in ('IGST','CGST','SGST','CVD','ADD')
```

- **`Open Indicator` is DISPLAYED, not filtered** — unlike report 19, which filters `<> 'Y'`. This
  report shows open *and* closed lines. Do not copy report 19's carve-out across.
- The branch-plant list has **`CINC` twice and omits `CIN4`** — a harmless duplicate in the `IN`
  list, but the CIN4 omission is a real inconsistency with queries 1 and 3. Flag it to the
  requester rather than silently normalising: it may be deliberate, it may be a bug in their report.
- `LINE_TYPE = 'S'` (stock line) — narrower and cleaner than report 19's `not like '%F%'`.
- **`ORDER_LINE_ID` structure is now confirmed**, which also settles it for report 19:
  order company = `substr(ORDER_LINE_ID, 1, 5)`; line number = `substr(ORDER_LINE_ID,
  1+instr(ORDER_LINE_ID, ',', -1), 5)` — i.e. comma-delimited, line number after the **last** comma.
  Export shows line numbers as `4` and `4.001`, matching EDW's `decimal LineNum`.
- Same India-tax `decode` exclusion as report 19, with the same `'-'` sentinel fallback.
- Only **four** joined tables and no parent/country/TM/segmentation chain, so this query has
  **far less join-drop exposure** than report 19's. Still verify the ship-to join.

### 3. Items - Active — the spine

```
SELECT DISTINCT branch plant, global bulk item, bulk item, 2nd item number, stock type code
GL_CLASS_CODE = 'IN32'
STOCK_TYPE_CODE not in ('O')
BRANCH_PLANT in (7 plants)
```

Single table, single `DISTINCT`. Trivially portable from `BIQL.TbItemBranch`. Note the sheet is
named **"Items - Active"** while the XML query is named "Items" — the *layout page* carries the
"Active" label, and `STOCK_TYPE_CODE not in ('O')` is what "active" means here (`O` = obsolete).

---

## Confirmed from the export

- **⚠ CORRECTED 2026-08-06 — `'-'` is Cognos rendering a NULL, not a stored value.** The export
  shows `'-'` in `Global Bulk Item`, `Bulk Item` (`Items - Active_3` row 2) and `Lot Status`
  (`Inventory_1`), and this note originally read that as a literal sentinel. Measured against the
  mirror, the opposite is true: `BIQL.TbItemBranch` has **0** rows with `'-'` in either bulk column,
  **0** empty strings, and **385** / **17** NULLs respectively. `-` is Cognos's default
  missing-value character. Report 14 hit the same thing from the other side (its §9.1: the xlsx
  renders blank `Location` as `-`; normalize before joining or ~530 rows false-mismatch).
  **Build rule: store NULL, render `-`, in DAX not SQL.**
  ⚠ Consequence for the India-tax exclusion: a literal port of
  `decode(GLOBAL_BULK_ITEM,'-',ITEM_NUMBER_2ND,GLOBAL_BULK_ITEM)` tests `= '-'`, which never matches
  in EDW, making the fallback dead code and the exclusion under-fire. The presence of that `decode`
  is strong evidence DW_LEGACY *does* store `-` literally — so the two warehouses differ. Write the
  predicate to treat NULL, `''` and `'-'` alike, and measure how many rows it actually removes.
- **KG vs LB is a straight factor**, not independent data: where UOM is `KG`, `Quantity on Hand KGs`
  equals `Quantity on Hand` exactly, and LB ≈ KG × 2.20462 (`567 → 1250.0077464`,
  `8276.5 → 18246.3652788`). Whatever supplies `CONVERSION_FACTOR_LB` must reproduce that
  precision — the export carries 7+ decimals, so rounding early will fail an `EXACT()` compare.
- **Order Type `S5` appears in the export.** Report 19 excludes `S5`; this one only excludes `ST`.
  Two reports over the same fact with different order-type scope — correct as written, but a
  standing trap if anyone reuses a query between them.
- Stock type codes seen: `1`, `2`, `Q`. Lot statuses seen: `A`, `-`.

---

## Source routing — SSAS → EDW → ODS

Per §1: new report ⇒ prefer SSAS live where one perspective covers it, else EDW, else ODS.

This report needs **inventory-on-hand + order activity + item master in one model**. Under a live
connection that means one perspective covering all three, which is a much taller order than reports
19 or 20. `Supply and Demand` is the only realistic candidate (it carries `Inventory Snapshot`,
`Sales`, `Item Branch`, `Lot` and `Customer Ship To`). ⚠ Read off the local `ssasprod.bim`, which
dumps the **stale** `BIQLTabular`, not `BIQLTabular_v2` — provisional until re-checked.

EDW covers it: `BIQL.FactInventorySnapshot_History_Filtered` (or `FactInventorySnapshot`),
`dbo.FactSalesDetail`, `BIQL.TbItemBranch`. All three are in the local `EDW-ODS Snapshot`, so the
probes run on this machine (§9). Open EDW risks: the GL-class column choice, and whether
`ON_HAND_DATE` / `LOT_EXPIRY_DATE` exist anywhere.

ODS: `PRODDTA.F41021` is current-only — adequate for "yesterday" in principle, but EDW already
carries decoded columns and the order side. Not the route.

**Recommendation: EDW**, with the lot-date availability question closed first, since it is the one
that could force a scope conversation with the requester.

---

## Open questions for the requester

1. Is the **CIN4 omission** on the Shipments query deliberate, or a bug? Queries 1 and 3 include it.
2. Are `On Hand Date` and `Lot Expiry Date` load-bearing for the slow-moving decision, or nice to
   have? They are the columns most at risk of not existing in EDW.
3. Do they want the 1:1 three-sheet port, or one model with the slow-moving logic built in?
4. What defines "slow moving" numerically — is there a threshold they apply in Excel today?
