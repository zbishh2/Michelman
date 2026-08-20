# Report 22 — production probe findings

Every decision the corrected PBIP is built on, with the probe that proves it. Probes ran against
production through the `Validation` host model (SSASPROD / `BIQLTabular` for DAX, EDWPROD / `EDW`
for T-SQL); the `.dax` / `.sql` files in this folder are the exact queries, the `.json` files the
probe-table definitions, the `.csv` files the full pulls, and `an_*.py` / `cmp_*.py` the
reconciliations against the Cognos export in `..\Intake\`. The Cognos export was pulled
2026-08-19 morning; counts below compare against it.

The two item lists (70 bulks; 47 bulks for Item Details) are the Cognos lists verbatim — see
`COLLECTION_NOTES.md`. `B70` / `B47` in `mk_11_14.py` are the canonical copies.

---

## Receipts — SSAS `Purchase Order Receiver`

Probes: `01_receipts_decodes.dax`, `02_receipts_lines.dax` (+csv), `03*`, `04_receipts_uom_rows.dax`.

Row set (Cognos 1,854):

| Predicate | Why |
|---|---|
| `[Match Record Type] = "1"` | Cognos reads RECEIPT_ACTIVITY, which is the match-type-1 receipt rows only (types 2 PV / 3 / 4 are voucher-match rows). |
| `[Address Num PO] IN {15 vendors}` | Cognos VENDOR_ID is the PO address number. Filtering on `Supplier[Supplier Num]` instead loses 2 rows whose SupplierSKey is unresolved. |
| `[Received Date] >= 2020-01-01` | Cognos RECEIPT_TRANSACTION_DATE is the SSAS Received Date, and Cognos's `Date` column equals it. |
| `RELATED('Item Branch'[Item Num 2nd]) <> "??????"` | Cognos inner-joins ITEM; 83 receipt rows have no item branch. |

Result: 1,842 display keys (SSAS carries 2–3 receipt rows for 42 doc/line/date keys that Cognos
shows once and sums; the table visual does the same) + the 2 Address-Num-PO rows match Cognos;
**10 Cognos rows are not reproducible**: 5 legacy-DW-only receipts that do not exist in SSAS (docs
228157/228158 line 4, 223259/223260 line 1, 26001558 line 1) and 5 non-stock lines (277510 line 3,
24002318 line 3, 25000603 line 7, 246684/246685 line 2 — quantity 1, item `Not Applicable`) that
Cognos carries through its item-master join while SSAS `Item Branch` returns `??????` for them.
They are 5 of 88 unresolved match-type-1 rows and nothing in SSAS separates them from the 83
Cognos also drops, so the `<> "??????"` predicate stands. Published model: 1,892 lines, 1,844
display rows, vs Cognos 1,854.

Columns:

- Vendor Name = `Supplier[Supplier Name]`, falling back to `LOOKUPVALUE('Address'[Address Name], 'Address'[Address Num], [Address Num PO])` for the 2 rows whose SupplierSKey is unresolved (322976 "Granite Branch Plant"). `Address Num` is unique in `Address` (37,360 rows = 37,360 numbers; `15_uniqueness.dax`), so the lookup cannot fan out.
- **Received Quantity is the primary-UOM quantity**:
  `IF([UOM Primary]="LB",[QuantityReceivedLB], IF([UOM Primary]="KG",[QuantityReceivedKG],[QuantityReceived]))`.
  The 58 WD40-UN rows are DR→LB ×350; EA-primary cartons have factor 1.
- `AmountReceived` exact. **USD/EUR differ ~1%** (313 / 1,386 rows): Cognos converts at its own
  monthly rate type `M` on receipt date; SSAS carries the JDE transaction rate. Use SSAS
  `AmountReceivedUSD` / `AmountReceivedEUR`.
- Qty LB/KG: 16/25 rows differ (MW40504-C2 / MW40514-C2 2020 factor drift; SSAS KG factor = 1 on
  EA-primary cartons where Cognos applies ×0.4536). Use SSAS columns.
- Bulk: SSAS `''` where Cognos prints the legacy `-` (8 rows) — left blank.

Dave's extra filters (Document Type OV/OW, Order Type OP/OD, `Address Num PO = Supplier Num`) are
not Cognos rules; the Cognos set is OV 1,834 / OW 20 and OP 1,777 / OD 77, which the predicates
above reproduce without them.

## Shipments — SSAS `Sales`

Probes: `05_shipments_decodes.dax`, `06_shipments_lines.dax` (+csv), `07_sales_rates.dax`,
`08_currency_rates.dax`, `09_shipments_amounts.dax` (+csv), `10_currency_month_rates.dax` (+csv);
`cmp_ship.py`, `an_ship2.py`, `an_ship3.py`.

Row set (Cognos 2,864 rows / 2,840 order-lines):

| Predicate | Why |
|---|---|
| `TRIM(RELATED('Item Branch'[Item Bulk])) IN {70}` | `Item Bulk` and `Item Num Bulk` agree on this set. |
| `[Promised Shipment Date] >= 2020-01-01` | Cognos "Promised Ship Date". |
| `[Cancelled_Flag] = 0` | Cognos "Exclude Cancelled" (533 cancelled rows). |
| `NOT [Order Type] IN {"SB","SR"}` | The 4 SSAS-only lines are SB "Call In Order" (1 line, $115K) and SR "Vendor Returns" / line type SV (3 lines, negative); Cognos's inner join to PRICE_ORDER_SUMMARY drops them. `Filter - Active Order Types = "Yes"` is **wrong** here — it also drops SA (97) and SD (39) lines Cognos keeps. |

For this set every row is already `Record Type = "Sales Detail"`, `Exclude Freight Line Types = "Y"`,
`Exclude Budget Data = "Y"`, `Order Exclude = "Show"`, no F line types, no ML156/CARN3 — the
remaining Cognos filters are satisfied without being restated. All 2,840 Cognos lines are present.

Columns:

- **Order Net Amount USD** = `Sales[AmountOrderNetUSD]` — the base column of the cube's
  `[Order Net Amt SPD USD]` measure, so this report shows the same numbers as every cube-based
  report. Differences from Cognos, both accepted: rate basis (JDE order-time rate vs Cognos's
  monthly `M` rate from its own FIN_CURRENCY_CONVERSION, which no SSAS rate kind matches exactly;
  exact on ~1,916/2,704), and 2 back-ordered lines where the cube holds 0 (`AmountOrderNetUSD` is
  zero when a line is back-ordered — `BackOrderedExtendedAmount` carries that value separately and
  the measure does not include it). Plus 1 sign-flipped line (1581592). Row-level tie-out to the
  cube is exact: same-instant totals 53,799,081.94 USD / 2,867 rows on both sides.
- **Order Net Amount EUR** = `Sales[AmountOrderNetEUR]` — the base column of
  `[Order Net Amt SPD EUR]`, same reasoning. Blank for USD-local companies (00010/00030) — the
  cube only rates EUR-local companies into EUR — so it is not comparable to Cognos's
  every-line converted EUR column. Same-instant tie-out 14,825,602.97 EUR, 1,829 blank rows.
  (`Currency Rates` background, kept for reference: ToRateA is one EUR→USD row per month end,
  300 rows 2005-01..2029-12, `15_uniqueness.dax`; a ToRateA-converted EUR lands within 1% on
  2,688/2,704 rows, RateM much worse — that derivation is not shipped.)
- **Raw Material Margin USD/EUR is not reproducible** from SSAS or EDW — Cognos needs the A1
  cost per sales line plus PRICE_ORDER_SUMMARY delivery freight / warehouse / additional freight;
  none exists outside the legacy DW. The closest cube definition is the standard-cost margin
  (USD − `[AmountExtendedCostUSD]`; EUR-company NetEUR(+BO) − `[AmountExtendedCostEUR]`,
  USD-company margin USD / RateA): total 15,217,561 vs Cognos 15,033,380 (+1.2% net, 5.4% abs,
  1,854 / 2,864 lines exact). **Not carried in the report** (Dave); the definitions and tie-out are
  in `..\RAW_MATERIAL_MARGIN.md` for the cube-measure review.
- Text: Order Company / Branch / Bulk / Global Bulk / 2nd / Desc1 / RBU / Customer Name / Country /
  Chemist 0 mismatches; Desc2 `''` = Cognos `-` (2,617); TM blank = Cognos `Not Available` (419); Global Parent 12,
  Open Flag 2, Next Status 3, FHC 1, dates 12 = live drift since export.
- LB mismatch 184 (191245PX-T2 2300 vs 2400 tote factor drift; MW40504-C2 ×0.4169), KG 85 — use
  SSAS `QuantityOrderedLB`/`KG`.
- Line Number is a string in Cognos (`1.5`); Order Company `00010`.

## Forecast — SSAS `FactForecast`

Probes: `11_forecast_lines.dax` (+csv), `11b_forecast_customers.dax`, `11c_customer_rbu.dax`,
`11d_customer_sales_rbu_tm.dax`, `11e_edw_customer_tm.csv`; `an_fc.py`, `an_fc2.py`.

Row set (Cognos 2,276):

- `TRIM(RELATED('Item Branch'[Item Bulk])) IN {70}`, `[RequestedDate]` between the first of the
  current month and `EOMONTH(TODAY()+450)`, `[QuantityForecast] > 0`.
- Every positive row is ForecastType SA / DWSource 1 / RevisedFlag `''` / Bypass N / OrderType FC —
  SSAS FactForecast **already equals** Cognos's `RELOAD_KEY='N'` + `TABLE_TYPE like '%F3460%'` +
  `FORECAST_TYPE='SA'` set; no extra decode predicate. Companies 00024/00025 do not occur.
- All 2,276 Cognos rows present, plus **28 rows dated the 1st of the current month**: Cognos's lower
  bound carries sysdate's clock time, so rows on the 1st at 00:00 fall out (Oracle artifact, 1.2%).
  Implement first-of-month inclusive; document.

Columns: Company, Branch (`[BusinessUnit]` trimmed), Global Bulk, Bulk, 2nd, Desc1, Desc2
(`''` = Cognos `-`), UOM, Current Forecast, LB exact; KG within 0.01 on 141 rows (Cognos constant
0.453597189 vs SSAS CFKG 0.4536 — invisible at 0 dp; use `QuantityForecastKG`). Customer Code =
`AddressNum`, Customer Name = `Address[Address Name]`, Global Parent = `Address[Global Parent Desc]`,
Chemist = `'Item Branch'[Chemist Name]` — all match. Date / Year / Month from `RequestedDate`.

Two columns are not in SSAS:

- **TM Name** — Cognos = the customer's commission assignment (JDE F42140; EDW
  `BIQL.TbTM_Max_Assignment` / `DimCustomerCommissionTM`, roles CSGTM/FCGTM/PPGTM).
  `FactForecast → 'Territory Manager'[Mailing Name]` matches for FC-group customers (23/41) only and
  is blank for CS-group customers (730 rows, Cognos `Not Available`). Decision: field-level EDW
  lookup — hidden `TM Assignment` table (`TbTM_Max_Assignment` joined to `TbTerritoryManager`,
  FC-group row first else CS-group, `ROW_NUMBER` on role then `CommissionLineNum`) and
  `Forecast[TM Name]` = `LOOKUPVALUE` on Customer Code. Matches Cognos **41/41** customers /
  2,304 rows, 0 blanks (`11e_edw_customer_tm.csv`, Kind=`MaxAssign`); the sales-history TM covers
  only 324 of the 730 CS rows, so the commission table is the source.
- **Revenue Business Unit** — the legacy fact stamps it at ETL time (`INVENTORY_DEMAND_MEASURE.
  ORGANIZATION_RBU_SID` in the Cognos native SQL); EDW's `FactForecast` never ported that column.
  The stamp decomposes exactly as `<prefix><suffix>`: suffix from the customer's commission-TM role
  (CS→220, FC→240; 41/41), prefix from the TM's company rolled to the revenue-booking entity
  (00010→10, 00021→20, 00030→30, 00034→34, 00035→30 — SARL books under Internat. Belgium,
  India under Asia-Pacific). The rollup exists in no production attribute — checked `DimBusinessUnit`
  (parent/category codes empty), `DimCompany`, `TbRevenueBusinessUnit` (controller codes echo the
  RBU's own prefix; 21xxx/35xxx rows exist so it is not nearest-existing), `DimAddress` regions
  (China holds both 30- and 34-company TMs), and the forecast row's own `Company Code` (36/41 —
  follows the branch, not the TM, on 5 customers). Not derivable from SSAS either (Sales
  latest-line RBU matches only 27/41 customers). Decision: omit unless Dave confirms it is needed;
  an exact rebuild needs the two-entry company rollup confirmed as a business rule.

## Work Orders — SSAS `Work Order Parts List` + `Work Order` + `Work Order Detail`

Probes: `12_wo_lines.dax` (+csv), F2 diagnostic (in transcript); `an_wo.py`, `an_wo2.py`.

Cognos grain is **(WO Num, parts-list `BusinessUnit` trimmed, Component Item Num 2nd, UOM)** —
the parts-list BusinessUnit is the WO's branch, not the component's Branch relationship.

Row set (Cognos 1,592 keys), applied on `'Work Order Parts List'` rows **before** summing:

| Predicate | Why |
|---|---|
| `TRIM(RELATED('Item Branch'[Item Bulk])) IN {70}` (component item branch) | Cognos joins Item Branch to Work Orders on the **component** item. |
| `[QuantityOrdered] + [QuantityTransaction] > 0` per row | Reversal rows (±x) must drop individually, as Cognos's per-row `QUANTITY_ORDERED+ISSUED_QTY>0` does. |
| `RELATED('Work Order'[Start Date]) >= 2020-01-01 \|\| RELATED('Work Order'[Completed Date]) >= 2020-01-01` | Cognos Start **or** Completion. |
| `RELATED('Work Order'[Work Order Type]) = "WO"` | WB-type orders have no resolvable parent (`??????`, BU 10130/10100); Cognos's inner join to ITEM drops them. |

**Issued = `QuantityTransaction`**; `QuantityShipped` is the WO-header quantity repeated per row.
Measures sum `QuantityOrdered` and `QuantityTransaction` over the key.

Result: 1,585 of 1,592 Cognos keys match; every attribute (parent branch / item / global bulk /
bulk, start / completed dates, status, component global bulk / bulk / stock type) matches except 2
statuses that advanced after the export. Residuals are legacy-DW artefacts: 7 Cognos-only keys
(4 NM73R3X WOs' 161190PX-T2 rows, 477065/U201, 466393/U201, 450411 MDU4075.E-TO LB) that do not
exist in JDE/SSAS (confirmed by the F2 diagnostic), and 16 keys where Cognos's Ordered is inflated
while Issued matches.

Columns: parent item attributes via `'Work Order Detail'[ItemBranchSKey]` → `Item Branch`
(LOOKUPVALUE on WorkOrderSKey; `Work Order` has no branch column), parent branch via
`'Work Order Detail'[BranchSKey]` → `Branch`; component attributes via the parts-list
`ItemBranchSKey` → `Item Branch`; Year/Month from `Completed Date`. Cognos prints `0/0` for the 89
open (null-completion) rows; PBI leaves them blank — flag.

## BOM — EDW `BIQL.DimBillOfMaterial` (SSAS table is empty)

Probes: `13_bom_lines.dax` (SSAS, 0 rows), `13b_bom_diag.dax`, `13c_bom_diag2.dax` (row counts),
`13d_edw_bom.sql` (+`13_bom_edw.csv`), `13e_bom_cols.csv` (INFORMATION_SCHEMA of the 4 EDW BOM
tables); `an_bom.py`.

`BIQLTabular` carries `Bill Of Material Expanded` but it holds **no rows in production** — the
source ladder falls to EDW at the table level. `BIQL.DimBillOfMaterial` reproduces Cognos exactly:

- Filters: `TypeBillofMaterial = 'M'`, `EffectiveThruDate >= CAST(GETDATE() AS date)`, component
  `ItemBulk ∈ {70}` (via `ComponentItemBranchSKey → BIQL.DimItemBranch`; `dbo.DimItem` via
  `ComponentItemSKey` agrees 100%), `LTRIM(RTRIM(Branch)) NOT IN ('LABO','LABS','LABA')`.
- Keys: Branch (trimmed — EDW nchar codes are right-aligned), parent 2nd via
  `ParentItemBranchSKey → DimItemBranch.ItemNum2nd` (`ParentItemNum2nd` on the row is blank),
  component 2nd / bulk / global bulk via `ComponentItemBranchSKey → DimItemBranch`.
- **Quantity = `SUM(QuantityStandardRequired) / 100`** — exact on all 160 keys; 2 keys carry 2 rows
  each and Cognos sums them too.
- `DWIsCurrent = 0` on every row — **do not filter on it**.
- The column is `TypeBillofMaterial` (lower-case "of"); EDW column names are case-sensitive and
  `edw_schema/edw_columns_current.csv` spells it `TypeBillOfMaterial`.

Cognos's BOM is single-level F3002; Dave's 7-level ODS explosion is a different product. The
single-level EDW query ships; the explosion intent is a question for Dave.

## Item Details — SSAS `Item Branch`

Probes: `14_item_details.dax` (+csv); `an_id.py`.

Row set (Cognos 754 = 607 item-branch rows + 147 `N/A`-branch rows):

- `TRIM([Item Bulk]) IN {47}`, `NOT CONTAINSSTRING([Business Unit], "LAB")`, **`[Business Unit] <> ""`**
  (46 SSAS rows have a blank branch and are not in Cognos).
- 607/607 Cognos item-branch rows match on (Branch, 2nd). 8 SSAS-only CINC item-branches
  (191245PX-PL/-FD, HP1432AT-PL, U2022-T2, U470, MDU20, 191245PX, U501B; ActiveFlag Y) exist in JDE
  but not in the legacy DW — they ship.
- The **147 `N/A` rows are item-master rows** (one per distinct 2nd item, carrying item-master
  defaults: MPF FEC, lead time 1, PTF 8, supplier `-`, planner/buyer `0`). They are a legacy-DW
  join artefact, not branch data; **excluded**, documented, ask Dave whether anyone reads them.

Columns (all match on the 607): Global Bulk, Bulk, Stock Type, MPF, Lead Time Level,
**Lead Time Order to Ship = `Lead Time MFG_BP`**, Planning Code, PTF days, Shelf Life Days, Supplier
/ Planner / Buyer numbers. Render rules:

- Safety Stock: SSAS blank where Cognos 0 (the 4 nonzero values match) → `COALESCE(…, 0)`.
- Supplier Name / Buyer Name: blank (number 0) where Cognos shows `Not Available`; stays blank.
- Planner Name: SSAS `Planner Name` is "First Last" (`Lance Murphy`, `Joël Bertrand`), Cognos is
  the JDE alpha name "Last, First" ASCII (`Murphy, Lance`, `Bertrand, Joel`); planner 0 → blank
  (Cognos `Not Available`). SSAS `Planner` is a category (`Other`), not the name. The cube's
  `Address[Address Name]` carries the alpha name and matches Cognos exactly on all 18 planners
  (probed), so `LOOKUPVALUE ( 'Address'[Address Name], 'Address'[Address Num], [Planner Num] )` is
  an exact source-native reproduction if ever wanted. Ship SSAS `Planner Name`; the format
  difference is cosmetic — the same person on every row — and documented.

---

## Cross-cutting rules for the build

- Source: SSAS Import (`SSASPROD` / `BIQLTabular`) for Receipts, Shipments, Forecast, Work Orders,
  Item Details; EDW native T-SQL for BOM only. Nothing points at `ssasdev`.
- Shape: `FILTER` + `SELECTCOLUMNS` + `RELATED`, stable predicates in the native query, no `TOPN`,
  no query-scoped measures; simple local measures over imported additive columns.
- Rendering: dates `MMM d, yyyy`; numerics 0 dp; no sentinels — cube blanks stay blank where
  Cognos shows the legacy warehouse's `-` / `Not Available` (source values, nothing to explain).
- Known, documented differences from the Cognos sheets: Receipts 5 legacy-only rows and rate-basis
  USD/EUR; Shipments rate-basis USD/EUR, Raw Material Margin not carried; Forecast 28
  first-of-month rows, TM Name from the EDW commission assignment, RBU absent; WO 7 legacy-only keys + 16 inflated Ordered,
  Year/Month blank vs 0; BOM none; Item Details 147 item-master rows excluded, 8 CINC rows added,
  planner-name format.
