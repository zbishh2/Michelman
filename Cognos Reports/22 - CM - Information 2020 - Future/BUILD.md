# Report 22 — CM - Information 2020 - Future — BUILD SPEC

**Cognos report name (XML `reportName`):** `CM - Information 2020-Future`
**Cognos package:** `/content/package[@name='Data Warehouse']/model[@name='model']` — DW_LEGACY, five
stars (Receipt Activity, Order Activity, Inventory Demand, Work Order) plus `[Bill of Material]` and
`[Item]`.
**Assigned:** Zack, 2026-08-19, starting from Dave Bubash's PBIP (`Daves PBIP\`, ~80%).
**Delivery plan:** PBIP first, validated against the Cognos export; RDL variant after the PBIP ties.

**Stage:** ✅ **PBIP built, published to `Zack (Validation)`, refreshed through the gateway, and tied
out against the 2026-08-19 Cognos export; report-out workbook delivered; RDL variant emitted.**
Next: Zack eyeballs the published report, the open questions go to Dave, the RDL gets its render
check in Report Builder on the jumpbox.

| Service item (workspace `Zack (Validation)`) | Id |
|---|---|
| `22 - CM - Information 2020 - Future (SSAS Import).SemanticModel` | `89c6fd75-66e1-4f6c-8db0-5906e64e9451` |
| `22 - CM - Information 2020 - Future (SSAS Import).Report` | `a5b34c40-3140-4737-97a7-e8e7232faea0` |

Gateway `MichelmanDataWarehouse` (`004d6ed3-…`), bound to datasources `ssasprod / biqltabular` and
`edwprod / edw`. A full refresh runs in about 20 seconds.

---

## 0. The shape of the thing

Six pages, one flat list each, no grouping, no summaries, no prompts. Every filter is hard-coded;
the only dynamic dates are `sysdate` in Forecast and BOM. Two item lists: **70 bulk items** (Receipts
is vendor-scoped instead; Shipments, Forecast, Work Orders, BOM) and **47 bulk items** (Item
Details). Both lists are Cognos's verbatim — `COLLECTION_NOTES.md`.

Sources, by the ladder (SSAS Live → SSAS Import → EDW → ODS):

| Page | Source | Why not higher |
|---|---|---|
| Receipts | SSAS Import — `BIQLTabular` `'Purchase Order Receiver'` | Live is ruled out for the whole report: the sheets need a primary-UOM quantity, a month-end EUR rate and a Work-Order parent lookup that only a native query expresses. |
| Shipments | SSAS Import — `Sales` | — |
| Forecast | SSAS Import — `FactForecast` | TM Name is a field-level EDW lookup — see §2.3. |
| Work Orders | SSAS Import — `'Work Order Parts List'` + `'Work Order'` + `'Work Order Detail'` | — |
| **BOM** | **EDW Import — `BIQL.DimBillOfMaterial`** | `BIQLTabular`'s `'Bill Of Material Expanded'` holds **no rows in production** (`PROBE\13_bom_lines.dax`). Documented EDW dependency. |
| Item Details | SSAS Import — `'Item Branch'` | — |

Every decision below is proven in `PROBE\FINDINGS.md`, with the probe `.dax` / `.sql` / `.csv` and
the reconciliation scripts beside it. Probes ran against production through the `Validation` host
model (CLAUDE.md method).

## 1. Files

```
22 - CM - Information 2020 - Future\
  BUILD.md                          this file
  COLLECTION_NOTES.md               intake, Dave-vs-Cognos gap list, open questions
  RAW_MATERIAL_MARGIN.md            the margin definitions handed to Dave / Greg / Rohit for cube-measure review
  Intake\                           native SQL, report XML, Cognos export (2026-08-19)
  Daves PBIP\                       Dave's starting point, untouched
  PROBE\                            probes, pulls, FINDINGS.md; build_*.dax / build_bom.sql = the shipped queries
  <Table>.m / <Table>.commented.m   shipped query (comment-free) + commented master, one pair per table
  gen_pbip.py                       emits the PBIP
  build_rdl.py                      emits the RDL from the same .m queries
  22 - CM - Information 2020 - Future (SSAS Import)\
    CM - Information 2020 - Future.pbip
    CM - Information 2020 - Future.SemanticModel\   TMDL, 8 tables, no relationships
    CM - Information 2020 - Future.Report\          PBIR, 6 pages
  22 - CM - Information 2020 - Future (RDL)\
    CM - Information 2020 - Future.rdl              paginated variant, 6 named tabs (PageName = Excel sheet)
```

The PBIP is the source of truth. The `.m` files at the report root are the same code as the
partitions, kept for review and for the RDL; `.commented.m` is the defense document for each.

**RDL variant.** `build_rdl.py` reads the `<Table>.m` queries verbatim and emits one Rectangle
per page, each a tablix grouped on the displayed attributes with the `(Line)` columns summed — the
PBIP table visuals' grain. Forecast's TM Name cell is a `Lookup` into the `dsTMAssignment` dataset
on Customer Code — the RDL analog of the PBIP's LOOKUPVALUE column. Embedded datasources
`SSASPROD / BIQLTabular` (OLEDB-MD, DAX) and `EDWPROD / EDW` (SQL, BOM + TM Assignment);
PBIRB 2016/01 namespace; Cognos-look 7pt cells, red bold headers,
black borders; ExecutionTime footer; `dsRefresh` stamps the cube's `Audit[DateUpdated]`. The XML is
well-formed, every `Fields!` reference resolves, and the element vocabulary is a subset of the
validated report 14 RDL. Render and Excel-export check needs Report Builder on the jumpbox.

## 2. Semantic model

Compatibility 1600, `__PBI_TimeIntelligenceEnabled = 0`, culture en-US. Seven import tables, **no
relationships** — each page is its own flat extract, as in Cognos. Every column is
`summarizeBy: none`, identifiers included. Dates `MMM d, yyyy` (Cognos `dateStyle="medium"`, no
`displayOrder`). Quantities and amounts are imported as hidden `… (Line)` columns at source-row
grain and surfaced as `SUM` measures formatted `#,##0`; the table visuals group on their displayed
columns, which reproduces Cognos's row grain exactly (§4).

| Table | Rows (2026-08-19) | Measures |
|---|---|---|
| Receipts | 1,892 lines → 1,844 display rows | Received Quantity, Received Quantity LBs/KGs, Amount Received, Amount Received USD/EUR |
| Shipments | 2,864 | Order Net Amount USD/EUR, Ordered Quantity LBs/KGs |
| Forecast | 2,304 | Current Forecast, Current Forecast LB/KG |
| Work Orders | 2,452 lines → 1,585 display keys | Issued Quantity, Quantity Ordered |
| BOM | 162 lines → 160 display keys | Quantity |
| Item Details | 615 | — |
| Last Refreshed | 1 | Last Refreshed Label |

Per-table query shape: `FILTER` with the stable row-eligibility predicates, `SELECTCOLUMNS` with
`RELATED` for attributes, `ADDCOLUMNS` only where a lookup has to happen once per row (the
Shipments rate date and month-end rate, Work Orders parent keys). No query-scoped measures, no
`SUMMARIZECOLUMNS`, no `TOPN`.
`Table.TransformColumnNames` strips the `[…]` the AS connector puts on DAX column names. BOM is
`Sql.Database("EDWPROD","EDW")` + `Value.NativeQuery(…, null, [EnableFolding = false])`.

### 2.1 Receipts

`[Match Record Type] = "1"` (RECEIPT_ACTIVITY = receipt rows, not voucher matches) ·
`[Address Num PO] IN {15 vendors}` (VENDOR_ID is the PO address number; filtering `Supplier[Supplier
Num]` loses the 2 rows whose SupplierSKey is unresolved) · `[Received Date] >= 2020-01-01` ·
`RELATED('Item Branch'[Item Num 2nd]) <> "??????"` (Cognos inner-joins ITEM).

Received Quantity is the **primary-UOM** quantity: `IF(UOM Primary="LB", QuantityReceivedLB,
IF(="KG", QuantityReceivedKG, QuantityReceived))`. Vendor Name falls back to
`LOOKUPVALUE('Address'[Address Name], 'Address'[Address Num], [Address Num PO])` (Address Num is
unique, 37,360 rows). Receipt Transaction Type = Document Type on every row. Bulk Item blank stays blank (Cognos prints the legacy warehouse's `-` on 8 rows).
USD/EUR are SSAS's JDE transaction-rate values (Cognos converts at its monthly rate M; ~1% on some
rows, accepted).

### 2.2 Shipments

`TRIM(RELATED('Item Branch'[Item Bulk])) IN {70}` · `[Promised Shipment Date] >= 2020-01-01` ·
`[Cancelled_Flag] = 0` · `NOT [Order Type] IN {"SB","SR"}` (Cognos's inner join to
PRICE_ORDER_SUMMARY drops call-in and vendor-return lines; the cube's "active order types" filter
is **wrong** here — it also drops SA/SD lines Cognos keeps).

Net USD = `AmountOrderNetUSD` — the cube's stored net amount, the base column of the cube's
`[Order Net Amt SPD USD]` measure. Net EUR is the cube's native `AmountOrderNetEUR` for
EUR-currency companies; USD-local companies (00010/00030), which the cube does not rate into
EUR, convert as USD ÷ the month-end EUR/USD rate A of the GL date (the cube's own
`Currency Rates` table, one row per month end) — the same monthly conversion Cognos applies,
so the column is populated on every line. Consequences, accepted: back-ordered lines show 0 in
both columns (the cube carries that value in `BackOrderedExtendedAmount`, outside the net;
2 lines), and amounts differ from Cognos at rate level — Cognos re-converts every line at its
own monthly rate.
Cognos's Raw Material Margin USD/EUR columns are **not carried** (Dave Bubash: the
report consumers do not need them); the candidate definitions are written up in
`RAW_MATERIAL_MARGIN.md` for Dave / Greg / Rohit to review as cube measures — Cognos subtracts the
legacy warehouse's A1 cost plus freight/warehouse charges, which no production source carries.
TM Name and Description 2 stay blank where the cube has
no value (Cognos shows the legacy warehouse's `Not Available` / `-`).
Order Company keeps its leading zeros (text).

### 2.3 Forecast

`TRIM(RELATED('Item Branch'[Item Bulk])) IN {70}` · `[RequestedDate]` from the **first of the
current month** to `EOMONTH(TODAY()+450, 0)` · `[QuantityForecast] > 0`. FactForecast's positive
rows already equal Cognos's F3460/SA/RELOAD_KEY=N set — no decode predicate. Cognos's lower bound
carries sysdate's clock time, so rows on the 1st at 00:00 fall out of Cognos (an Oracle artefact);
this build includes them deliberately (+28 rows, 1.2%).

**Revenue Business Unit is omitted** — nothing on FactForecast or its customer resolves it (open
question). **TM Name is the one field-level EDW lookup**: Cognos stamps the customer's commission
TM (JDE F42140), which SSAS carries only for FC-group customers (FactForecast's own TM, blank on
730 CS-group rows). The hidden `TM Assignment` table reads `BIQL.TbTM_Max_Assignment` — the
FC-group TM per ship-to, else the CS-group TM — and `Forecast[TM Name]` is a calculated column
`LOOKUPVALUE` on Customer Code. Matches Cognos on all 41 forecast customers, no blanks
(`PROBE/11e_edw_customer_tm.csv`).

### 2.4 Work Orders

On `'Work Order Parts List'` rows, *before* the visual sums: component `Item Bulk IN {70}` ·
`[QuantityOrdered] + [QuantityTransaction] > 0` per row (reversal pairs drop individually) ·
WO start **or** completion ≥ 2020-01-01 · `[Work Order Type] = "WO"` (WB orders have no resolvable
parent; Cognos's ITEM join drops them). Parent branch and item come through `'Work Order Detail'`
(`WorkOrderSKey` → `BranchSKey` / `ItemBranchSKey`, one detail row per WO) because the parts-list
row's own Item Branch is the **component**. Issued = `QuantityTransaction` (`QuantityShipped` is
the WO header repeated per row). Completion Date 1900 → blank; Year/Month blank where Cognos prints
0 (flagged).

The sheet shows Branch Plant / Global Bulk Item / Bulk Item / 2nd Item Number **twice** — parent,
then component. Model columns are prefixed `Component …`; the visual's projections carry
`displayName` overrides so the captions match the Cognos sheet. Duplicate display names on one
`tableEx` are accepted by the PBIR validator and the service; duplicate `nativeQueryRef` would not be.

### 2.5 BOM (EDW)

`BIQL.DimBillOfMaterial` ⋈ `BIQL.DimItemBranch` (component) ⟕ `BIQL.DimItemBranch` (parent),
`TypeBillofMaterial = 'M'` (case-sensitive name), `EffectiveThruDate >= today`, component
`ItemBulk IN {70}`, `Branch NOT IN (LABO, LABS, LABA)`. Quantity = `QuantityStandardRequired / 100`
(JDE implied decimals). EDW's nchar codes are right-aligned → `LTRIM(RTRIM())` on every code.

### 2.6 Item Details

`TRIM([Item Bulk]) IN {47}` · `TRIM([Business Unit]) <> ""` (46 SSAS rows with a blank branch are
not in Cognos) · `NOT CONTAINSSTRING([Business Unit], "LAB")`. Lead Time Order to Ship = `Lead Time
MFG_BP`; Safety Stock blank → 0; Supplier / Planner / Buyer Name stay blank where Cognos shows
`Not Available`. No measures.

### 2.7 Last Refreshed

Report 19's one-row Eastern-time `#table` with explicit US DST; `[Last Refreshed Label]` on a card
on every page.

## 3. Report

PBIR; pages **Receipts, Shipments, Forecast, Work Orders, BOM, Item Details**, 1280×720
FitToPage. Each page: Dave's chrome (title textbox, `Submit Helpdesk Ticket` mailto box,
`Report Author: Nick Bubash`, Michelman logo from `RegisteredResources`), the Last Refreshed card,
and one `tableEx` in the Cognos column order with Cognos's sort (Global Bulk Item, Bulk Item, 2nd
Item Number — BOM: Branch Plant, Parent Second Item Number, 2nd Item Number; Item Details adds
Branch Plant). Table style: totals off, red bold headers, black 1px grid, numeric/date columns
left-aligned, `stylePreset None`, no border, no title. Theme `CY24SU10`.

`powerbi-report-author validate`: 0 errors / 0 warnings; baseline stored
(`pbip-validate-drift.ps1`).

## 4. Validation log

Cognos export pulled 2026-08-19 morning; model refreshed 2026-08-19 15:45 UTC. Display-grain rows
are `SUMMARIZE` over the visual's columns.

| Sheet | Cognos rows | PBI display rows | Residual |
|---|---|---|---|
| Receipts | 1,854 | 1,844 | 10 Cognos-only: 5 legacy-DW receipts that do not exist in JDE/SSAS (docs 228157/228158 line 4, 223259/223260 line 1, 26001558 line 1) and 5 non-stock lines Cognos renders as item `Not Applicable` through its item-master join, which SSAS `'Item Branch'` cannot resolve (5 of 88 unresolved rows; nothing separates them from the 83 Cognos also drops). Together qty 178,965 / amount 341,567. |
| Shipments | 2,864 | 2,864 | exact |
| Forecast | 2,276 | 2,304 | +28 first-of-month rows (§2.3), all other rows match |
| Work Orders | 1,592 keys | 1,585 keys | 7 Cognos-only keys absent from JDE/SSAS; 16 keys with an inflated legacy Ordered while Issued matches |
| BOM | 160 | 160 | exact, Quantity 14,667.32 both sides |
| Item Details | 754 | 615 | −147 item-master `N/A` rows (excluded by decision), +8 CINC item-branches absent from the legacy DW; 607/607 branch rows match |

Totals (Cognos → PBI): Receipts Amount Received 33,320,852 → 33,010,777 (the 10 rows above);
Shipments Net USD 53,817,847 → 53,793,278 (−0.05%) and Net EUR 48,290,178 → 48,144,097 (−0.30%),
both the rate/back-order classes in FINDINGS; Forecast
944,604 → 952,809 (+28 rows); WO Issued 5,683,534 → 5,683,534 **exact**, Ordered 7,715,170 →
7,579,106 (legacy inflation); Item Details Safety Stock 26,160 both. Cognos's `-` and
`Not Available` are legacy-warehouse defaults, not cube values, and PBI leaves those cells blank;
the blank counts match Cognos's sentinel counts exactly: Receipts Bulk Item 8, Shipments
Description 2 2,617 and TM Name 419, Forecast Item Description 2 on every row, Item Details
supplier 372 / planner 24 / buyer 321. No blank Safety Stock. Forecast TM Name has no blanks:
the EDW commission lookup names every customer, matching Cognos 41/41.

Forecast and BOM are `sysdate`-anchored: re-pull those two sheets the morning of the report-out
capture and refresh the model the same hour (tight-capture method).

**Report-out workbook**: `Excel Validation\_report_out\22 - CM - Information 2020 - Future.xlsx`
(STANDARD layout: Notes, one Comparison sheet per page, RS). Builder and PBI pulls live in
`Excel Validation\_validation_work\22 - CM - Information 2020 - Future\` (`pull_pbi.py` pulls each
page at display grain via `executeQueries`; `build_workbook.py` aligns by business key, writes live
compare formulas, lists leftovers and recurring-FALSE columns with reasons on RS). Rerun both after
any refresh or Cognos re-pull.

## 5. Known, disclosed differences

1. Receipts: 10 Cognos-only rows (§4). USD/EUR at the JDE transaction rate, not Cognos's monthly rate M.
2. Shipments: Order Net Amount USD is the cube's stored net (back-ordered lines show 0); EUR is native cube EUR for EUR-currency companies, else USD at the cube's month-end rate A — residual differences vs Cognos are rate-basis (Cognos re-converts every line at its own monthly rate). Raw Material Margin USD/EUR not carried (Dave); definitions handed over in `RAW_MATERIAL_MARGIN.md`.
3. Forecast: first-of-month rows included; Revenue Business Unit omitted; TM Name looked up from EDW `TbTM_Max_Assignment` (FC else CS), the report's second EDW dependency.
4. Work Orders: 7 legacy-only keys; 16 inflated legacy Ordered values; Year/Month blank (not 0) for open WOs.
5. Item Details: 147 item-master `N/A` rows excluded; 8 CINC rows added; Planner Name `First Last` with diacritics.
6. BOM reads EDW, the one step down the ladder.

## 6. Publishing

```powershell
fab import "Zack (Validation).Workspace/22 - CM - Information 2020 - Future (SSAS Import).SemanticModel" -i ".\22 - CM - Information 2020 - Future (SSAS Import)\CM - Information 2020 - Future.SemanticModel" -f
# report: publish a COPY whose definition.pbir is byConnection (schema 2.0.0 takes connectionString only):
#   Data Source="powerbi://api.powerbi.com/v1.0/myorg/Zack (Validation)";Initial Catalog="22 - CM - Information 2020 - Future (SSAS Import)";Integrated Security=ClaimsToken;semanticModelId=<model id>
fab import "Zack (Validation).Workspace/22 - CM - Information 2020 - Future (SSAS Import).Report" -i "<copy>.Report" -f
fab api -A powerbi "groups/<ws>/datasets/<model>/Default.BindToGateway" -X post -i bind.json   # gateway 004d6ed3-… + ssasprod/biqltabular + edwprod/edw datasource ids
fab api -A powerbi "groups/<ws>/datasets/<model>/refreshes" -X post
```

The gateway binding survives a model re-import. PPU has no ExportToFile, so visual checks are in
the browser, signed in.

## 7. Open questions (Dave) — also in COLLECTION_NOTES.md

Forecast Revenue Business Unit · BOM explosion vs
single-level · Item Details `N/A` rows · WO Year/Month blank vs 0 · Receipts `Not Applicable`
non-stock lines · Cognos folder path.

## 8. Next

Zack's visual pass on the published report → Dave's answers → RDL render check in Report Builder
on the jumpbox (open `CM - Information 2020 - Future.rdl`, run, export to Excel, confirm the six
tabs land on the Cognos row counts).
