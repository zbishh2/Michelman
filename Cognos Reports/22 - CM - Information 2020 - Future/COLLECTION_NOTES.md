# Cognos source collection — Report 22

- **Report name:** `CM - Information 2020-Future` (`<reportName>` in the XML; the folder and the
  request use `CM – Information 2020 – Future`)
- **Cognos path:** _(pending — not in the XML)_
- **Cognos package:** `/content/package[@name='Data Warehouse']/model[@name='model']` — DW_LEGACY.
  Five stars plus two plain `[Data Warehouse]` namespaces: **Receipt Activity**, **Order
  Activity**, **Inventory Demand**, **Work Order**, `[Data Warehouse].[Bill of Material]`,
  `[Data Warehouse].[Item]`.
- **Run output format:** the export is a six-sheet Excel workbook (`spreadsheetML`).
- **Prompts / parameters:** none. Every filter is hard-coded; the only dynamic date is
  `{sysdate}` in Forecast and BOM.
- **Assigned to Zack 2026-08-19.** Dave Bubash has a PBIP roughly 80% built; it is the starting
  point, not a from-scratch rebuild.

## Delivery plan

1. **PBIP first** — finish and correct Dave's build, validate it against the Cognos export.
2. **RDL after** — once the PBIP ties out, derive the paginated variant, same as reports 19 and 21.

## Collected

| File | What it is |
|---|---|
| `Intake\Native SQL (filed 2026-08-19).txt` | **Native Oracle SQL** for six of the seven queries (Receiving, Shipments, Forecast, Work Order Summary with its two CTEs, BOM, Item Receipts) |
| `Intake\Report XML (filed 2026-08-19).txt` | Full report XML — 7 queries, 6 pages |
| `Intake\Cognos export - CM - Information 2020-Future (filed 2026-08-19).xlsx` | Six-sheet Cognos output, downloaded 2026-08-19 morning |
| `Daves PBIP\` | Dave's build, `CM - Information 2020 - Future_7_27_26.pbip` — 6 tables, 5 pages, cache saved 2026-07-27 (copied in 2026-08-19) |

The export is **not yet a tight capture** (§7 method): it was pulled 2026-08-19 but nothing on
the PBI side has been refreshed against it. Receipts / Shipments / Work Orders / Item Details are
history-stable enough that a same-week PBI refresh will compare cleanly; **Forecast and BOM are
`sysdate`-anchored and will drift** — re-pull those two sheets the morning of the validation run.

---

## Report anatomy

Six pages, one flat list each, no grouping, no summaries, no prompts, `noDataHandler` on every
list. Dates `dateStyle="medium"` with **no `displayOrder`** → month-first `MMM d, yyyy`. Every
numeric column `decimalSize="0"`. Five of six lists sort `Global Bulk Item, Bulk Item, 2nd Item
Number` (Item Details adds `Branch Plant`; BOM sorts `Branch Plant, Parent Second Item Number,
2nd Item Number`).

The report is anchored on a **hard-coded list of 70 bulk items** (the "CM" set), repeated
verbatim in four queries (Shipments, Forecast, Work Orders' `Item Branch` CTE, BOM), and a **list
of 15 vendor IDs** in Receiving. The Item Receipts query uses a **different 58-entry list: 47
distinct items, a strict subset of the 70**, with ten duplicates (`181193EU.E` ×3; `MD4020`,
`MD4021`, `MDU2012B.E`, `MDU4075.E`, `MDU4075B.E`, `MDU440B.E`, `U201`, `U502.E`, `WD40` ×2).
The 23 items in the 70 but not the 47: `181020CX.E`, `181136IX`, `181192IX`, `191011CX`,
`191026CX.E`, `23409A`, `ABEX2525`, `ET2012.E`, `ET2022.E`, `ET4075.E`, `ET440.E`, `MD4020S`,
`MD4021S`, `MD4022`, `MPEG2000`, `NP4LF`, `OMS`, `U2022EU.E`, `U2023`, `U204EU.E`, `U502X1.E`,
`U802`, `WD40T`. Carry the two lists separately; do not "fix" the short one.

| Sheet | Query | Rows | Cols | Grain / notes |
|---|---|---|---|---|
| `Receipts_1` | Receiving | **1,854** | 20 | receipt line × transaction date. Vendor ID ∈ 15-list, `Date ≥ 2020-01-01` (`TIME_OTHER_DATE` via `RECEIPT_ACTIVITY__FISCAL_SID`). A `[Bulk Item] in ('WD40')` filter exists but is `use="prohibited"` — inert. Measures: Received Qty / LBs / KGs, Amount Received / USD / EUR (rate type `M` on `RECEIPT_DATE`). |
| `Shipments_2` | Shipments | **2,864** | 27 | order line. Bulk ∈ 70-list, `Promised Ship Date ≥ 2020-01-01`, Exclude Freight Line Types (`LINE_TYPE not like '%F%'`), Exclude Cancelled, Exclude Budget (`BUDGET_FACTOR<>1`), Bulk ∉ (`ML156`,`CARN3`), GST-style items excluded. Measures: Order Net Amount USD / EUR, Ordered Qty LBs / KGs, **Raw Material Margin USD / EUR** (= net − A1 cost − delivery freight − warehouse − additional freight, all × SALES_FACTOR). Note `Line Number` is a string like `1.5`, Order Company `00010`. |
| `Forecast_3` | Forecast | **2,276** | 21 | forecast row × requested date. `CURRENT_FORECAST > 0`, Active Forecast Only (`RELOAD_KEY='N'`), `Forecast Type = 'SA'`, `Table Type contains 'F3460'`, Bulk ∈ 70-list, **date between first-of-current-month and last-of-month(sysdate+450)**, companies `00024`/`00025` excluded. Measures: Current Forecast, LB, KG (zero-factor fallback to LB↔KG constants). |
| `Work Orders_4` | Work Order Summary | **1,592** | 19 | WO × component line. Built as `Item Branch` (70-list) **inner-joined** to `Work Orders` on `(Branch Plant, Component 2nd Item Number)` — i.e. WOs whose **component** is a CM item, any parent. `Qty Ordered + Issued > 0`, `Start ≥ 2020-01-01 OR Completion ≥ 2020-01-01`. Year/Month from Completed Date. Two sets of item columns (WO parent + component), both named identically in the sheet. |
| `BOM_5` | BOM | **160** | 6 | branch × parent × component. `M` bills, `Effective Through ≥ sysdate`, component Bulk ∈ 70-list, branch ∉ (`LABO`,`LABS`,`LABA`). Measure: Quantity. |
| `Item Details_6` | Item Receipts | **754** | 18 | item-branch attributes for the **47-item list**, branch `not contains 'LAB'`. Supplier / Planner / Buyer names via `VENDOR_DIM_ID`. No activity filter — every item-branch appears. |

---

## Dave's build vs. Cognos — gap list

Mounted `Daves PBIP` cache (saved 2026-07-27) and counted rows; compared with the export.

| Dave's table | Source | Rows (cache) | Cognos sheet / rows | Verdict |
|---|---|---|---|---|
| `Receipts` | **`ssasdev`** / BIQLTabular — `Purchase Order Receiver` | 1,915 | Receipts_1 / 1,854 | Close. Points at **dev** — must be `ssasprod`. Adds filters Cognos lacks (Document Type ∈ OV/OW, Order Type ∈ OP/OD, Match Record Type = 1, `Address Num PO = Supplier Num`); reconcile line-by-line. Joins `ItemBranch` for item columns via `ItemBranchSKey` + bidi relationship. |
| `ItemBranch` | **`ssasdev`** | 120,648 | — | Support dim for Receipts, unfiltered (whole `Item Branch`). Dev → prod; or fold the item columns into the Receipts query and drop the dim. |
| `Shipments` | `ssasprod` — `Sales` | 3,382 (3,353 order-lines) | Shipments_2 / 2,864 | ~18% more rows. Missing: **Order Net Amount EUR**, **Raw Material Margin USD/EUR**, Description 2; `Order Company` (uses `Branch Company[Company]` — check it equals Cognos's `substr(ORDER_LINE_ID,1,5)`), Line Number comes as double not string. Missing Cognos filters: Exclude Cancelled, Exclude Budget, Bulk ∉ (ML156, CARN3), GST exclusion. Has `Order Net Amt SPD` (local ccy) in place of EUR. |
| `WO` | `ssasprod` — `Work Order` + `Work Order Parts List` | **501** | Work Orders_4 / 1,592 | **Capped: the DAX carries Desktop's `TOPN(501, …)`** — data stops at WO start 2022-05-06. Also filters `Start Date ≥ 2020` only (Cognos is Start **or** Completion), and the Cognos join is on the *component* item ∈ CM list, not the parent. Missing Year/Month (Completed Date). |
| `Item Receipts` (misnamed — it is Item Details) | `ssasprod` — `Item Branch` | 288 | Item Details_6 / 754 | Also `TOPN(501)`, and the `SUMMARIZECOLUMNS` carries two `COUNTROWS` measures, which **drops every item-branch with no PO activity**. Cognos lists all item-branches. Missing `Buyer Number`. `Lead Time Order to Ship` is carried as `Lead Time MFG_BP` — confirm the mapping. Sheet has `Buyer Name` twice. |
| `BOM` | **ODS** `PRODDTA.F3002` via a 7-level staged explosion (multi-statement T-SQL, `#temp` tables) | 43 | BOM_5 / 160 | Wrong shape and wrong branch set: `@Branches = CINC,CIN2,CIN4,COLR` (Cognos: everything except LAB*), and Cognos's BOM is **single-level** `F3002` rows, not an explosion. BIQLTabular has **`Bill Of Material Expanded`** (`Component Item Num 2nd`, `Parent Item`, `Component Branch`, `Type Bill of Material`, effective dates, `ComponentQuantity`) — evaluate it before keeping ODS, per the source ladder. |
| _(none)_ | — | — | **Forecast_3 / 2,276** | **Page missing entirely.** BIQLTabular now carries a wired **`FactForecast`** (`ForecastType`, `RequestedDate`, `QuantityForecast` + `LB`/`KG`, `Bulk Item`, `Global Bulk`, `Company`, relationships to `Item Branch`, `Address`, `Business Unit`, `Territory Manager`, `Date`) — the `Forecast` perspective. Needs `RELOAD_KEY`/"Active Forecast Only" and `Table Type contains 'F3460'` equivalents identified. |

Cross-cutting:

- Two of six tables point at **`ssasdev`**; everything must be `ssasprod` / `BIQLTabular`.
- Dave's queries are Desktop-style `SUMMARIZECOLUMNS` + `TOPN(501)` captures. Per the preferred
  SSAS-Import shape, rewrite as `FILTER` + `SELECTCOLUMNS` + `RELATED`, stable predicates in the
  native query, no `TOPN`, no query-scoped `COUNTROWS`.
- Five auto-date `LocalDateTable_*` tables + `__PBI_TimeIntelligenceEnabled = 1` — turn auto
  date/time off.
- Report: 5 pages of `tableEx` + logo + title textboxes; no `Last Refreshed` card; no Forecast page.
  Column order and headers need to follow the Cognos sheets.
- `Shipments[Sales[Order Num]]` / `[Line Num]` ride as **aggregated** fields in the table visual
  (`summarizeBy: sum`) — set identifiers to `none`.

## Probe results

Every table was probed against production before the build; `PROBE\FINDINGS.md` holds the
predicates, the column rules and the reconciliation counts per sheet. Headlines:

- Receipts, Shipments, Forecast, Work Orders, Item Details come from `SSASPROD` / `BIQLTabular`
  (SSAS Import). **BOM comes from EDW `BIQL.DimBillOfMaterial`** — `Bill Of Material Expanded` is
  empty in production `BIQLTabular`, so the ladder falls to EDW at the table level.
- Three Cognos columns have no SSAS source: **Raw Material Margin** (not carried — Dave; the
  candidate definitions are in `RAW_MATERIAL_MARGIN.md` for the cube-measure review), Forecast
  **Revenue Business Unit** (omitted), and Forecast **TM Name** — carried via a field-level EDW
  lookup (`BIQL.TbTM_Max_Assignment`, FC-group TM else CS-group; matches Cognos 41/41 customers).
- Everything else reproduces the Cognos sheets to the row, with the residuals listed in FINDINGS
  being legacy-DW-only rows that do not exist in JDE.

## Build status

The corrected PBIP lives in `22 - CM - Information 2020 - Future (SSAS Import)\` and is published
to `Zack (Validation)` as `22 - CM - Information 2020 - Future (SSAS Import)` (model + report),
gateway-bound and refreshed. `BUILD.md` carries the model/report spec, the validation log and the
publish recipe. Dave's PBIP stays as the untouched starting point.

## Open questions (for Dave)

- **Forecast Revenue Business Unit** — the legacy warehouse stamps it on the forecast fact at ETL
  time; EDW never ported the column. The stamp is the customer's commission-TM role suffix
  (CS → x220, FC → x240 — 41/41) on the TM's company rolled to the revenue-booking entity
  (SARL 00021 → 20 Internat. Belgium, India 00035 → 30 Asia-Pacific; 10/30/34 map to themselves).
  The role suffix is reproducible from `TbTM_Max_Assignment`; the two-entry company rollup exists
  in no production table. Is RBU needed — and if so, can the rollup (which legal entity books each
  sales company's revenue) be confirmed as a business rule we may encode? (TM Name itself is
  carried: EDW `TbTM_Max_Assignment` lookup, matches Cognos 41/41.)
- **BOM explosion** — Cognos's BOM is single-level `F3002`, which the EDW query reproduces 160/160.
  Dave's 7-level ODS explosion is a different product; is it a newer requirement?
- **Item Details `N/A` rows** — 147 of the 754 Cognos rows are item-master rows with no branch
  (legacy-DW join artefact). The build excludes them. Does anyone read them?
- **Work Orders Year/Month** — Cognos prints `0/0` for open WOs; the build leaves them blank.
- Cognos path / portal folder — not in the XML.
- Receipts: Dave's added filters (OV/OW, OP/OD, Match Record Type) are not Cognos rules and are
  not needed to reproduce the sheet; confirm there is no separate business reason for them.
- **Receipts `Not Applicable` lines** — 5 Cognos rows are non-stock PO lines (quantity 1, item
  `Not Applicable`) that Cognos carries through its item-master join; SSAS `Item Branch` cannot
  resolve them and they are 5 of 88 such rows, the other 83 of which Cognos also drops. The build
  omits them ($21,963 in Amount Received). Does anyone need them?
