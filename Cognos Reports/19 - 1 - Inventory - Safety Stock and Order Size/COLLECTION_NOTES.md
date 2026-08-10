# Cognos source collection — Report 19

- **Report name:** 1 - Inventory - Safety Stock and Order Size
- **Cognos path:** `Michelman Reporting / Production and Shipping / Cogan Excel AD HOC Reports`
- **Portal folder ID:** `i52030381F2354AC6818EE9527C4297C8`
- **Cognos package:** `/content/package[@name='Data Warehouse']/model[@name='model']` — the
  **DW_LEGACY** star, i.e. the same legacy warehouse the earlier Ivan/Cogan reports came off.
- **Run output format:** `spreadsheetML` (Excel), `run.prompt=true` but the report XML contains
  **no prompt pages and no parameters** — the prompt flag is inert, every filter is hardcoded or
  `sysdate`-relative. Nothing to parameterise on our side.
- **Assigned to Zack 2026-08-06.** Folder scaffolded same day.

Same Cognos folder as report 21, and the `1 - ` prefix puts it in the Cogan Excel AD HOC family
alongside reports 13 / 14 / 18.

## Collected so far

| File | What it is |
|---|---|
| `Intake\Query + XML (filed 2026-08-06).txt` | Cognos-generated SQL for both queries + the full report XML spec |

Still to collect: an **output export** (both sheets) and a **tight capture** for the tie-out.
No screenshots yet.

---

## Report anatomy

Two pages, two independent queries, one flat `<list>` each, no grouping, no prompts, no summaries.
Excel out. This is a **two-sheet data dump** — structurally the simplest kind we've taken on.

| Page / query | Grain | Rows about |
|---|---|---|
| **Safety Stock** | item-branch (`DISTINCT`) | current planning master data — safety stock, lead time, planner |
| **Shipments** | order × item, summed from lines | ~6 months of *closed* order activity, qty in order UOM, LB and KG |

**Business intent** (inferred, confirm with the requester): put each item's *standing* safety stock
next to the *actual* order sizes it has had to absorb over the last six months, so planning can
right-size safety stock and order multiples. Nothing in the report joins the two sheets — the
analysis happens in Excel. That is a strong argument for rebuilding it as **one model with two
tables and a real relationship**, which is a genuine improvement over the Cognos original rather
than a 1:1 port.

Both lists sort `Bulk Item, 2nd Item Number, {Branch Plant | Order Number}`; every column header is
**bold red on a 1pt black border** (`lt` / `lc` / `lm` styles) — cosmetic, reproduce in PBIR if we
are going for visual parity. Dates render `dateStyle="medium" displayOrder="DMY"` (day-first) on
all four date columns, per the usual per-report parity rule (§7).

---

## Query 1 — "Safety Stock"

`DW_LEGACY.ITEM` inner-joined to `DW_LEGACY.VENDOR` on `PLANNER_NUMBER = VENDOR_DIM_ID`, `SELECT DISTINCT`.

Filters: `BRANCH_PLANT in ('CINC','CIN2','AUBA','AUB2','SING','SNG4')`, `SAFETY_STOCK > 1`,
`STOCK_TYPE_CODE not in ('O')`, `MASTER_PLANNING_FAMILY like '%F%'`.

**All ten columns exist on `EDW.BIQL.TbItemBranch`** — one table, no joins:

| Cognos column | EDW `BIQL.TbItemBranch` |
|---|---|
| `BRANCH_PLANT` | `Business Unit` (nchar — trim) |
| `BULK_ITEM` | `Item Bulk` / `Item Num Bulk` — **which one, confirm** |
| `ITEM_NUMBER_2ND` | `Item Num 2nd` |
| `STOCK_TYPE_CODE` | `Stocking Type` (+ `Stocking Type Desc`) |
| `MASTER_PLANNING_FAMILY__IMPR` | `Master Planning Family` (+ Desc) — JDE `F4102.IBPRP4`, UDC `41/P4`, per `edw_schema\probe9_mpf_itembranch.sql` |
| `LEADTIME_MFG` | `Lead Time MFG_BP` (int) |
| `PLANNER_NUMBER` | `Planner Num` (int) |
| `VENDOR.VENDOR_NAME` | `Planner Name` — **already denormalised, the join disappears** |
| `SAFETY_STOCK` | `SafetyStock` **or** `Safety Stock SAFE` — **two candidates, must disambiguate** |
| `UNIT_OF_MEASURE__PRIMARY` | `UOM Primary` |

### Traps in query 1

1. **The planner join is an INNER join.** An item-branch whose `PLANNER_NUMBER` has no `VENDOR`
   row is *dropped from the Cognos output entirely*. Because EDW denormalises `Planner Name` onto
   the row, the naive port **keeps** those rows and the sheet comes out longer than Cognos. Probe
   the count of item-branches with a planner number that resolves to no name.
2. **Two safety-stock columns.** `SafetyStock` and `Safety Stock SAFE` both live on
   `TbItemBranch`, both `decimal`. JDE's field is `F4102.IBSAFE`, so `Safety Stock SAFE` is the
   likelier literal match — but `> 1` is a *filter*, so picking wrong changes the row set, not
   just a value. Compare the two columns before choosing.
3. **`MPF like '%F%'` is a substring match, not equality.** Cognos's `contains ('F')` ports to
   `LIKE '%F%'`, so every MPF code containing the letter F qualifies. Pull the MPF domain
   (probe9 §6 gives the distribution over the sales fact) and *list the codes this actually
   admits* in BUILD.md — a future reader will assume it means one family and be wrong.
4. `SELECT DISTINCT` is doing real work only if `VENDOR` has >1 row per `VENDOR_DIM_ID`. Check;
   if it does, the EDW port needs the same dedup.

---

## Query 2 — "Shipments"

`ORDER_ACTIVITY` + `ORDER_ACTIVITY_MEASURES` + 9 dimension aliases, aggregated with `XSUM` over a
16-column group-by. Net grain = **order company × branch plant × order number × bulk item ×
2nd item × ordered date × UOM × dates × customer × parent × country × segmentation × TM**, i.e.
order-and-item, with the line detail summed away.

Three measures, all `qty × SALES_FACTOR`: order UOM, `× CONVERSION_FACTOR_LB`, `× CONVERSION_FACTOR_KG`.
`SALES_FACTOR` is the one we already ran down on report 17 — `F41002.UMCONV / 10^7`, converting the
line UOM to the item's primary UOM. **`dbo.FactSalesDetail` carries `SalesFactor`,
`ConversionFactorLB` and `ConversionFactorKG` as explicit columns**, so all three measures port directly.

| Cognos | EDW |
|---|---|
| `substr(ORDER_LINE_ID,1,5)` | `OrderCompany` (verify it equals the first 5 of `OrderLineID`) |
| `ORGANIZATION_ID` | `BusinessUnit` |
| `ORDER_NUMBER` | `OrderNum` |
| `ITEM.BULK_ITEM` | `TbItemBranch[Item Bulk]` via `ItemBranchSKey` |
| `ITEM_NUMBER_2ND` | `ItemNum2nd` |
| `ORDERED_DATE` | `OrderDate` |
| `ORDERING_UNIT_OF_MEASURE` | `UOMTransaction` (confirm vs `UOMPrimary` / `UOMPricing`) |
| `DUE_DATE` → "Promised Ship Date" | `PromisedShipmentDate` |
| `SCHEDULED_PICK_DATE` | `ScheduledPickDate` |
| ship-to code / name | `ShipToCustomerSKey` → `BIQL.TbCustomerShipTo` |
| `Global_Parent_Name` | `ParentCustomerSKey` → Customer Parent |
| AC06 `CUSTOMER_TYPE_DESCRIPTION` (aliased `c16`) | `TbCustomerShipTo[Customer Segmentation Desc]` |
| TM `MAILING_NAME` | `TerritoryManagerSKey` → `BIQL.TbTerritoryManager` |
| `T6.DESCRIPTION` (UDC `00,CN`) | `TbCustomerShipTo[Country Desc]` |
| `to_date({sysdate})` | refresh stamp — same pattern as report 18's `DATE` column |

Filters, in Cognos order: `OPEN_INDICATOR <> 'Y'`; order type not `S5`/`ST`; ship-to AC01 `<> 'INT'`
(intercompany); two budget carve-outs on `DESCRIPTION_1` (`51210`, `61121`) that only bite when
`SALES_OR_GL = 'Budget Detail'`; `BUDGET_FACTOR <> 1`; `LINE_TYPE not like '%F%'` (freight);
`CANCELLED_INDICATOR <> 'Y'`; `DUE_DATE >= to_date(sysdate - 365/2)`; the 6 branch plants;
`ORDERED_QTY * SALES_FACTOR > 0`; `MPF like '%F%'`; and an India-tax exclusion.

### Traps in query 2

1. **Five inner joins that silently drop rows.** Ship-to → AC01 category, ship-to → AC06 category,
   ship-to → `GLOBAL_REPORTING` → `CUSTOMERID` → parent customer, ship-to country → UDC `00,CN`,
   and sales rep → `VENDOR`. Any order line whose ship-to lacks a global-reporting parent, a
   country decode, a category code or a resolvable TM **is not in the Cognos output at all**. EDW
   denormalises all five, so the naive port *over-includes* — the mirror image of trap 1 above and
   the **single biggest parity risk in this report**. Quantify each drop before building.
2. **`sysdate - 365/2` is 182.5 days, and Oracle keeps the half.** `to_date()` then truncates, so
   the window boundary depends on the **time of day the report runs** — before noon it is 183 days
   back, after noon 182. Any fixed T-SQL/DAX equivalent will disagree with some Cognos runs by one
   day's worth of orders. Pick one (recommend `-183`), state it in BUILD.md, and expect a small
   boundary-day delta in the tie-out rather than chasing it.
3. **`OPEN_INDICATOR <> 'Y'` = closed/shipped lines only** — the report is history, not a live
   order book. `FactSalesDetail` has no `OpenIndicator`; the candidates are `Source` /
   `SalesTableSource` (the F4211-vs-F42119 discriminator), `StatusCodeNext`, or `QuantityOpen = 0`.
   **This is the one mapping I could not settle from the schema dump — probe it first.**
4. **The India-tax exclusion carries a `'-'` sentinel:**
   `decode(GLOBAL_BULK_ITEM, '-', ITEM_NUMBER_2ND, GLOBAL_BULK_ITEM) not in ('IGST','CGST','SGST','CVD','ADD')`
   — when the global bulk item is `'-'`, fall back to the 2nd item number. Same `'-'`-means-blank
   convention we hit on report 18's Lot Status. EDW's `Item Global Bulk` should carry it identically;
   confirm rather than assume, and note the two-column `COALESCE` is **not** the same as a plain one.
5. `BUDGET_FACTOR <> 1` plus the two `DESCRIPTION_1` carve-outs are the Cognos framework's
   "Exclude Budget Data" filter expanded. `FactSalesDetail.BudgetFactor` exists; the account-number
   carve-outs need `Description1`, which also exists. Port all three, not just the factor.
6. The `Master Planning Family` and `Customer Segmentation Description` data items are **declared in
   the query but not on the list layout** — MPF is filter-only, segmentation *is* displayed (as
   `c16`). Don't drop segmentation just because the generated SQL alias looks like scaffolding.

---

## Source routing — SSAS → EDW → ODS

Per CLAUDE.md §1 this is a **new** report, so the mandate applies: prefer an **SSAS live connection**
where a single perspective covers it, else EDW, else ODS.

**⚠ Caveat on everything below:** it was read off the local `ssasprod.bim` dump, whose database name
is **`BIQLTabular`** — the *stale* model. `BIQLTabular_v2` is the truth (§2). Treat this as
"where to look first", and re-confirm against v2 before committing.

### SSAS — plausible, with one hard gap

A live connection means no local tables, so **everything must sit inside one perspective**.

- **`Sales Order`** has `Sales` + `Item Branch` + `Customer Ship To` + `Customer Parent` +
  `Territory Manager` — but its `Item Branch` **does not expose Safety Stock at all**. Query 1 is
  impossible there.
- **`Supply and Demand`** is the one that could carry the whole report: `Sales` (with
  `Promised Shipment Date`, `Scheduled Pick Date`, `Order Date`, `Order Company`, `Order Type`,
  `Line Type`, `Cancelled_Flag`, `Open Order Flag`, `Conversion Factor LB/KG`, `QuantityOrderedLB/KG`),
  `Item Branch` **with both `SafetyStock` and `Safety Stock SAFE`**, plus `Customer Ship To`
  (`Customer Segmentation Desc`, `Country Desc`), `Customer Parent`, `Territory Manager`, `Branch`.
- **The gap: `Lead Time MFG_BP` is not exposed on `Item Branch` in *any* perspective** in this dump —
  only `Lead time Level` and `Fixedor Variable Lead time`. Cognos's `Lead Time Order to Ship` maps
  to `Lead Time MFG_BP` by name on the EDW view. If that column is genuinely required, **SSAS live
  is blocked** unless BIQL adds it to the perspective.
- Second unknown: no `Sales Factor` column is exposed on `Sales`. `QuantityOrderedLB/KG` may already
  fold it in — if so that is *better* than our port, but it has to be proven, not assumed.

### EDW — covers 100% of both queries, and is locally probeable

`BIQL.TbItemBranch` alone satisfies query 1 (all ten columns, table verified in
`edw_schema\edw_columns_current.csv`). `dbo.FactSalesDetail` + `BIQL.TbItemBranch` +
`BIQL.TbCustomerShipTo` + `BIQL.TbTerritoryManager` + parent customer satisfy query 2, and
`SalesFactor` / `ConversionFactorLB` / `ConversionFactorKG` are explicit columns.

**Every one of those tables is already in the local `EDW-ODS Snapshot`.** Per §9 that means the
whole build — column existence, join drops, fan-out, the `OPEN_INDICATOR` mapping, the `'-'`
sentinel, the two safety-stock columns — is answerable **on this machine**, in DAX against the
mounted cache or T-SQL against the SQL mirror. No jumpbox trip until the tie-out.

### ODS — not needed

`PRODDTA.F4102` / `F4101` / `F0101` / `F4211`+`F42119` could reproduce it, but EDW already carries
the decoded columns and the SKey joins. Only fall back here if the two safety-stock columns can't
be told apart from EDW (`F4102.IBSAFE` settles it) — and `F4101`/`F4102` are in the snapshot too,
so even that is a local question.

### Recommendation

**Build on EDW**, and treat the SSAS live connection as a question to close first rather than a
default: check `BIQLTabular_v2`'s `Supply and Demand` perspective for `Lead Time MFG_BP` and for
whether `QuantityOrderedLB/KG` already carry the sales factor. If both come back clean, SSAS live
is genuinely the mandated route and the report becomes two tables with zero Power Query. If lead
time is missing — the likely outcome — EDW is the answer and the mandate is satisfied by having
checked.

---

## Open questions for the requester

1. Who owns this report / who receives the Excel? (Cogan? Ivan? planning team?)
2. Is `Lead Time Order to Ship` actually used downstream, or vestigial? It is the single column
   that decides SSAS-vs-EDW.
3. Is the two-sheet split wanted, or would one model with a real item↔order relationship be better?
   The Cognos version forces the join to happen in Excel.
4. The 6-month window and the six branch plants are hardcoded — should they become slicers?
