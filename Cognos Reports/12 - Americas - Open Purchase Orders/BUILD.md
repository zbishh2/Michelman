# Report 12 — Americas - Open Purchase Orders — BUILD SPEC

**Cognos path:** Public Folders > Michelman Reporting > Production and Shipping > Cogan Excel AD HOC Reports > *Americas - Open Purchase Orders*
**Report name (XML `reportName`):** `Americas - Open Purchase Orders`
**Tracker outline:** `1.27.27.13`
**Stage:** spec written — awaiting build. This document is the build spec + query files only; **no PBIP is authored at this stage.**

A three-page flat data-dump export (no charts, no subtotals, no conditional formatting). Each page is an independent Cognos list bound to its own query object; there are **no cross-page joins**, so the three pages become three independent tables/pages in one PBIP.

---

## 0. Intake integrity — READ FIRST

**The collected `Report XML.xml` is physically truncated.** Line 36 contains a literal `…3557 tokens truncated…` placeholder (confirmed: `grep -c truncated` = 1; the string is in the raw bytes, not a tool artifact). The truncation removed, from the XML only:

1. the **entire page-1 (PO) list layout** (all 17 columns, order, formats),
2. the **Sales-Ledger prohibited/enabled filter expression**, and
3. the **two leading columns of the Sales-Orders list** (Order Number, Line Number).

**All three were fully recovered from other intake material** — the XML is the *only* truncated file:

| Lost from XML | Recovered from | Confidence |
|---|---|---|
| PO page column set + order | `PO.0.sql` SELECT list — **its column order matches the rendered `Report Output.xlsx` "PO Static_1" sheet exactly** | HIGH |
| PO page date/number formats | xlsx cell styles (`styles.xml`) — see §5 | HIGH |
| Sales-Ledger filter `Last Updated By ≠ SCHED` | `Sales Ledger.2.sql` WHERE (`ORDER_LINE_LAST_UPDATED_BY not in ('SCHED')`) | HIGH |
| Sales-Orders leading columns | xlsx "Sales Order Static_2" headers + `Sales Orders - Static.1.sql` | HIGH |

**Completeness verdict: COMPLETE.** Every query object has generated SQL (3/3) and every page has rendered output (3/3 sheets). The XML defect degrades layout-detail provenance but leaves no page or query uncovered. Proceeding with the spec; the recovery sources are cited per-column below.

**Screenshot is unusable** — `Report - page 1.png` shows only the Cognos "report is running" spinner. The **xlsx is the row-count/validation target**, not the screenshot.

---

## 1. Source route — **ODS PRODDTA (JDE), SQL Server**

Evaluated SSAS → EDW → ODS per the team mandate. **Chosen: ODS**, matching reports 01/04/06/07/09/10.

### Why not SSAS (`BIQLTabular_v2`, Live Connection) — REJECTED
`v2.xmla` does model purchase orders (F4311 / "Purchase Order Detail" / "Purchase Order Receiver"), so SSAS clears the *first* bar. It fails the **100%-coverage** bar that a Live Connection (no local tables, SSAS 2019 non-composite) requires:
- **Page 3 (Sales Ledger = F42199 sales-order-ledger)** — an audit-ledger grain with `Order Line Last Updated By`, per-status-change rows — is not a standard cube fact and is almost certainly absent.
- The PO page needs **USD currency conversion** (rate-band join) and **LB weight conversion** as row-level derivations, plus per-row **Make Site / Ship Site** string attributes on page 2 — none guaranteed pre-modeled, and none addable under a Live Connection.
Partial fit → disqualified.

### Why not EDW (SQL Server) — REJECTED as single source
EDW covers pages 1–2 **well**: `dbo.FactPurchaseOrderDetail` carries Description1/2, DeliveryInstructions1/2, StatusCodeLast/Next, OrderDate/RequestedDate/PromisedShipmentDate/CancelDate, QuantityOpen/Ordered/Canceled(PricingUOM), AmountOpen/Extended + foreign amounts, UOMWeight/UnitWeight; `dbo.FactSalesDetail` carries every page-2 column (ItemNum2nd, DeliveryInstructions, FreightHandlingCode, CarrierNum, QuantityOrdered, PromisedShipmentDate, OrderDate). **But there is no F42199 sales-order-ledger fact in EDW** — only `FactSalesDetail` (F4211), `FactSalesHeader`, `FactSalesHistory_UOM_Fix` (F42119, a different table). Page 3 has no EDW home, so a single-source build can't sit on EDW.
> **Alternative worth flagging to the human:** if the team later chooses to split the report, pages 1–2 are a *clean* EDW rebuild (richer, USD/foreign amounts pre-computed, no Julian decoding). Page 3 would still need ODS. Recommendation below keeps all three on ODS for a uniform single-connection deliverable.

### Why ODS — CHOSEN
Only source that covers **all three** pages: `PRODDTA.F4311` (PO), `PRODDTA.F4211` (sales orders), `PRODDTA.F42199` (sales-order ledger), plus `F0101/F4101/F4102/F0006/F0015` enrichments. Native T-SQL, folds, and reproduces the DW_LEGACY logic directly. Reports 04 and 06 are close precedents (validated F4211/F4311 field names reused here).

> **Caveat that raises build risk vs. prior ODS reports:** report 12's Cognos SQL runs against the **DW_LEGACY Oracle star schema** (`PURCHASE_ACTIVITY`, `ORDER_ACTIVITY`, `SALES_ORDER_LEDGER`, …), *not* JDE-native like reports 04/06. So this is a **reverse-map** from star-schema columns back to JDE fields, and several mappings need SSMS confirmation — see §6 and `00_verify_tables.sql`.

Connection: `Sql.Database("ODSPROD","ODS")`, native query, `[EnableFolding=true]`. No CTEs (a leading `WITH` breaks folding — PBI wraps as `SELECT * FROM (<q>)`); no `ORDER BY` inside the folded query (illegal in SQL Server) — set sorts in the visual.

---

## 2. Query objects → files

| # | Cognos query | Rendered page / xlsx sheet | Rendered rows (xlsx) | Query file (+commented master) |
|---|---|---|---|---|
| 1 | `PO` | Page "PO Static_1" | **3,749** | `PO.m` / `PO.commented.m` |
| 2 | `Sales Orders - Static` | Page "Sales Order Static_2" | **12,196** | `Sales_Orders_Static.m` / `.commented.m` |
| 3 | `Sales Ledger` | Page "Sales Ledger_3" | **91,613** | `Sales_Ledger.m` / `.commented.m` |

Row counts are **as-of the captured xlsx**. All three carry rolling date floors (`sysdate ± N`), so today's live counts will differ — use these for order-of-magnitude, not exact parity. The window fixes at **refresh time** in an import model (same behaviour note as report 06 §5): schedule a daily refresh.

---

## 3. Page layouts (exact column order, headers, formats)

Headers below are the on-page labels. Every Cognos `listColumnTitle` renders the **data-item name** (no `label=` overrides exist in this report), so header = data-item name, confirmed against the xlsx header row. All headers are **bold red (`#FF0000`)** with a **1pt solid black** cell border (`border-collapse:collapse`); the whole grid is boxed. No page titles, no conditional formatting (verified: 0 `conditionalFormatting` blocks across all 3 sheets), no subtotals.

### Page 1 — "PO Static_1" (query `PO`) — 17 columns
Order recovered from `PO.0.sql` (matches xlsx exactly):

| # | Header | Align | Format | xlsx numFmt |
|---|---|---|---|---|
| 1 | Branch Plant | left | text | — |
| 2 | PO Number | left | integer text | — |
| 3 | Line Number | left | text | — |
| 4 | 2nd Item Number | left | text | — |
| 5 | PO Date | left | **`MMM d, yyyy`** (month-first) | 164 `mmm d, yyyy` |
| 6 | Requested Date | left | `MMM d, yyyy` | 164 |
| 7 | Promised Date | left | `MMM d, yyyy` | 164 |
| 8 | Receipt Date | left | `MMM d, yyyy` | 164 |
| 9 | Vendor ID | left | integer text | — |
| 10 | Vendor Name | left | text | — |
| 11 | Lead Time Level | right | `#0` (integer, no separator) | 165 |
| 12 | Quantity Cancelled | right | `#,##0` | 166 |
| 13 | PO Quantity Ordered LBs | right | `#,##0` | 166 |
| 14 | Open Quantity | right | `#,##0` | 166 |
| 15 | Open Quantity LBs | right | `#,##0` | 166 |
| 16 | Spend Amount USD | right | `$#,##0;($#,##0)` (USD, parens for neg) | 167 |
| 17 | Purchase Amount USD | right | `$#,##0;($#,##0)` | 167 |

> **Page 1 dates are month-first (`MMM d, yyyy`)** — the PO page's `<dateFormat>` block was in the truncated XML, but the xlsx cells prove numFmt 164 (`mmm d, yyyy`), i.e. **no `displayOrder="DMY"`**, same asymmetry report 06 documents. **Pages 2 and 3 are day-first** (`d MMM, yyyy`, numFmt 168) because their `<dateFormat>` carries `displayOrder="DMY"` — this is verbatim from each page's own styling; **do not harmonise them.** Power BI `formatString` is VBA-style: `d MMM, yyyy` renders `13 Jul, 2026` (comma literal); `MMM d, yyyy` renders `Jul 13, 2026`.

**Sort:** Cognos `sortList` = PO Number asc, then Line Number asc (from `PO.0.sql` `order by "PO_Number", "Line_Number"`). Set in the visual (query omits ORDER BY).

### Page 2 — "Sales Order Static_2" (query `Sales Orders - Static`) — 21 columns

| # | Header | Align | Format |
|---|---|---|---|
| 1 | Order Number | left | integer text |
| 2 | Line Number | left | text |
| 3 | Ordered Date | left | `d MMM, yyyy` (day-first, numFmt 168) |
| 4 | Promised Ship Date | left | `d MMM, yyyy` |
| 5 | CSR Name | left | text |
| 6 | Customer Name | left | text |
| 7 | 2nd Item Number | left | text |
| 8 | Description 1 | left | text |
| 9 | **Description 1** *(duplicate — see note)* | left | text |
| 10 | Delivery Instructions Line 1 | left | text |
| 11 | Delivery Instructions Line 2 | left | text |
| 12 | Next Status | left | text |
| 13 | Ordered Quantity | right | `#,##0` (`decimalSize=0`, numFmt 166) |
| 14 | Ordered Quantity LBs | right | `#,##0` |
| 15 | Customer Segmentation | left | text |
| 16 | TM Name | left | text |
| 17 | Make Site | left | text |
| 18 | Lead Time Order to Ship | left | text/number |
| 19 | Ship Site | left | text |
| 20 | Carrier Name | left | text |
| 21 | Freight Handling Code | left | text |

> **Columns 8 and 9 are BOTH headed "Description 1" and show the SAME value.** In the XML the data item named "Description 2" is defined with `expression = [Description 1]`, and its label resolves to "Description 1". The SQL aliases the same source (`T0.C7`) to both `Description_1` and `Description_2`. Reproduce faithfully: two adjacent identical columns, both labelled **Description 1**. In PBIR, the query returns them as distinct internal names (`Description 1` and `Description 1 (2)`); **rename column 9's `displayName` to "Description 1"** (a duplicate `nativeQueryRef` is a render error — keep distinct source names, override the display label).

**Sort:** Promised Ship Date asc (Cognos `sortList → Promised Ship Date`; SQL `order by "Promised_Ship_Date"`). Set in the visual.

### Page 3 — "Sales Ledger_3" (query `Sales Ledger`) — 10 columns

| # | Header | Align | Format |
|---|---|---|---|
| 1 | Order Company | left | text |
| 2 | Order Number | left | integer text |
| 3 | Line Number | left | text |
| 4 | 2nd Item Number | left | text |
| 5 | Ordered Date | left | `d MMM, yyyy` (numFmt 168) |
| 6 | Date Created | left | `d MMM, yyyy` |
| 7 | Last Status | left | text |
| 8 | Next Status | left | text |
| 9 | Order Line Last Updated | left | **datetime** (`d MMM, yyyy h:mm` — numFmt 169, carries time; xlsx sample `45971.509…`) |
| 10 | Order Line Last Updated By | left | text |

**Sort:** Order Number asc, then Order Line Last Updated asc, then Line Number asc (Cognos `sortList`). Set in the visual.

---

## 4. Filters (baked into each query — no prompts/slicers in this report)

There are **no Cognos prompts** in this report (unlike reports 04/06). Every filter is a static `detailFilter`, so it belongs **in the query**, not as a slicer:

| Page | Filter (Cognos) | Ported as |
|---|---|---|
| 1 PO | `Promised Date ≥ sysdate−365` | `PDPDDJ ≥ today−365` |
| 1 PO | `Branch Plant in ('CINC','CIN2','CIN4')` | `trim(PDMCU) IN (...)` |
| 1 PO | `PO Document Type in ('OP','OD')` | `PDDCTO IN ('OP','OD')` |
| 2 SO | `Promised Ship Date between sysdate−365 and sysdate+30` | `SDPDDJ BETWEEN today−365 AND today+30` |
| 2 SO | `Branch Plant in ('CINC','CIN2','CIN4')` | `trim(SDMCU) IN (...)` |
| 2 SO | tax-item exclusion `decode(GlobalBulkItem,'-',2ndItem,GlobalBulkItem) NOT IN ('IGST','CGST','SGST','CVD','ADD')` | `CASE`/`ISNULL` decode on `F554101.IMGBLK` |
| 3 Ledger | `Ordered Date ≥ 2024-01-01` | `SHTRDJ ≥ '2024-01-01'` |
| 3 Ledger | `Order Company = '00010'` | `SHKCOO = '00010'` |
| 3 Ledger | `Next Status in ('520','525','530')` | `SHNXTR IN (...)` |
| 3 Ledger | `Order Line Last Updated By NOT IN ('SCHED')` *(the truncated "prohibited"/enabled filter)* | `SHUSER <> 'SCHED'` |
| 3 Ledger | tax-item exclusion (as page 2) | same decode |

**Expired-date-ceiling check (defect C1 from prior reports): NONE FOUND.** No hard-coded upper date bound like `DATE '2026-06-30'` exists in any of the three SQLs. Page 1/2 floors are rolling (`sysdate−365`, `sysdate+30`); page 3 floor is a fixed `2024-01-01` **lower** bound with no ceiling. So no "zero rows since date X" risk. The only literal date is page 3's `2024-01-01` floor (preserved).

---

## 5. Fan-out / DISTINCT / scaling flags

- **Page 3 uses explicit `SELECT DISTINCT`** in `Sales Ledger.2.sql` — preserved in `Sales_Ledger.m`. (Pages 1 and 2 rely on `GROUP BY` to the line grain like reports 04/06.) Watch the F42199→F4211→item join for fan-out inflating the 91,613 count; if it over-counts, the DISTINCT should still collapse it, but validate.
- **JDE quantity scaling:** F4311/F4211 quantities are stored ×10000 → divide by `10000.0`; line numbers ×1000 → `/1000.0` (proven by reports 04/06). Validate displayed magnitudes against the xlsx (e.g. page-1 row 2 `Quantity Cancelled ≈ 42,990`).
- **LB and USD conversions are the two soft spots** — DW_LEGACY pre-computed `CONVERSION_FACTOR_LB` and a `FIN_CURRENCY_CONVERSION` rate; JDE has neither as a single field. The `.m` files currently emit the **un-scaled domestic value** as a placeholder for the four "LBs"/USD columns and flag them `-- TODO verify`. **These four page-1 columns will not tie to Cognos until the LB factor (F41002/F4101 weight) and the F0015 USD rate join are resolved** (verify blocks 5–6).

---

## 6. Field-mapping confidence (DW_LEGACY → JDE)

Full column-by-column mapping lives in each `.commented.m`. Summary of what needs SSMS confirmation (`00_verify_tables.sql`):

| Confidence | Fields |
|---|---|
| **HIGH** (proven by reports 04/06) | Branch/Company/Order#/Line#/2nd Item/Vendor id+name/Next status/Open Qty/Requested/Promised/Ordered dates; F4211 & F4311 core keys; Make Site / Ship Site CASE logic; all filters except currency/LB |
| **MEDIUM** (standard JDE, unproven here) | PO Date=`PDTRDJ`; Receipt Date=`PDRCDJ`; Lead Time Level=`F4102.IBLTLV`; Customer Segmentation=`F0101.ABAC06`; Freight=`SDFRTH`; Carrier=`SDCARS→F0101`; Date Created=`SHADDJ` |
| **LOW** (best-effort placeholder, must verify) | Quantity Cancelled (`PDPQOR−PDUOPN−PDUREC` vs a dedicated field); **LB conversion** (both "…LBs" columns); **USD currency conversion** (Spend/Purchase); CSR Name (type-9 rep chain); TM Name (`SALES_REP_ID` field); Order Line Last Updated datetime (`SHUPMJ`+`SHTDAY`) |
| **BLOCKER** | **`PRODDTA.F42199` existence + column prefix.** Not used anywhere else in this repo. Reports 08/10 found F42119 on this instance uses **`SD*`** names, not standard `SH*`. `Sales_Ledger.m` is written with `SH*` — if verify block 2 shows otherwise, swap every prefix. If F42199 is absent/empty, page 3 needs a rethink (candidate: F42119, or reconstruct the ledger from F4211 audit columns). |

---

## 7. PBIP authoring notes (for the build agent)

- **Author in PBIR format** (like reports 02/03), not the legacy `report.json`.
- **`summarizeBy: none` on every column** — especially the identifier/number columns (Order Number, PO Number, Line Number, Vendor ID, Lead Time Level, statuses). `summarizeBy: sum` on an identifier corrupts a table/matrix. These pages are flat **tables** (`tableEx`), not matrices — no grouping, no subtotals.
- **Values-level conditional formatting:** none in this report, so no `dataViewWildcard` selector concern here. The red bold headers are static column-header styling, not CF.
- **Duplicate header "Description 1" (page 2 col 9):** keep the query's distinct internal name (`Description 1 (2)`), set the PBIR `displayName` to `Description 1`. Do **not** point two columns at the same `nativeQueryRef` (render error).
- **Sorts** are visual-level (queries omit ORDER BY) — set per §3.
- **Three pages, one PBIP**, one table per page. Add the standard `Last Refreshed` card if matching the house pattern (the rolling windows make the as-of date load-bearing on pages 1–2).
- Ship PBIP **comment-free**; the commented masters (`*.commented.m`) stay in this folder in parallel.

---

## 8. Open questions for the human

1. **F42199 (page 3) is unproven on ODSPROD** and not referenced elsewhere in the repo. Does the Sales Order Detail Ledger exist here, and under `SH*` or `SD*` column names? (Blocks page 3 entirely — verify block 2.) If it's absent, do we fall back to F42119, or drop page 3?
2. **LB conversion source.** DW used a pre-computed `CONVERSION_FACTOR_LB`. Which JDE source do we standardise on — `F41002` UOM conversion to LB, or `F4101` unit weight + weight UOM? (Affects 3 page-1 columns + 1 page-2 column.)
3. **USD currency conversion.** DW joined `FIN_CURRENCY_CONVERSION` (rate type 'M', effective-date band). JDE `F0015` has no native "rate type". Confirm the F0015 keys and whether domestic amounts are already USD for these Americas branches (if so, the join may be a no-op). (Affects Spend/Purchase Amount USD.)
4. **CSR vs TM.** CSR Name = customer ship-to sales rep "type 9"; TM Name = order `SALES_REP_ID`. Confirm the F4211 field for each (`SDASN`/`SDSLSM`/other) and whether CSR needs the F42140/F03012 type-9 chain (as report 04 built TM).
5. **Quantity Cancelled** — is there a dedicated F4311 cancelled-units field, or is it derived (`ordered − open − received`)?
6. **EDW split option.** Pages 1–2 are a cleaner EDW rebuild (USD/foreign amounts and weights pre-computed, no Julian decode). Keep all three on ODS for uniformity (current spec), or split pages 1–2 to EDW and leave page 3 on ODS?
7. **Report XML was truncated at collection.** Layout was fully backfilled from SQL+xlsx (§0), but if an authoritative re-export of the Cognos XML is easy, it would remove residual reliance on inference for page-1 formats. Optional.

---

## 9. Build log — report-17 discovery port (2026-07-22)

Applied the proven findings from report 17's probe rounds 5–7 (`17 - Orders within Goal and Stretch\BUILD.md` §12.5–12.8) to all three artifacts per page (`.m` / `.commented.m` / PBIP TMDL partition). Model re-linted clean via MCP ConnectFolder (4 tables). **Not yet refreshed on the jumpbox.**

**Page 2 (Sales_Orders_Static) — restructured to the 17 batch shape (`EnableFolding=false`, #temp tables, unique clustered indexes):**
1. **Ordered Quantity basis fixed (17 §12.6, PROVEN):** now `SDUORG/10000 × SALES_FACTOR`, where SALES_FACTOR = `F41002.UMCONV/10⁷` converting the line's `SDUOM` → item primary `IMUOM1` (factor 1 when equal). This is the exact Cognos expression (`SUM(ORDERED_QTY × SALES_FACTOR)` in `Sales Orders - Static.1.sql`), verified on 17 against 975/998 Cognos ratios. Replaces the unverified `SDPQOR/10000` placeholder.
2. **Ordered Quantity LBs implemented:** Cognos = `SUM(ORDERED_QTY × CONVERSION_FACTOR_LB × SALES_FACTOR)` → qty-in-primary × `UMCONV(IMUOM1→'LB')/10⁷` (1 when primary is LB; fallback 1.0 when no conversion row). Mechanics 17-proven; the LB factor source itself still carries a TODO-verify vs xlsx.
3. **`#uom` deduped** (`GROUP BY` + `MAX(UMCONV)`, scoped to model items): raw F41002 has up to 18 rows per (item, from, to) triple on this ODS and fanned 17's SUM 2.3× (§12.7).
4. **CSR/TM lookups → `#csr`/`#tm` temp tables**, replacing the `OUTER APPLY TOP 1`s (repo rule: OUTER APPLY re-evaluates per row and has hung refreshes). CSR carries the **`CMCO <> '00000'` fix** (17's 2026-07-21 finding: 4 CMAN8 had two 'CSR' rows; the filter makes CMAN8 unique). TM stays `MIN()`-deduped (no CMCO evidence for the TM family).
5. **RULE A (SDNXTR/SDLTTR 980 exclusion) deliberately NOT ported** — 17's Cognos SQL filtered `CANCELLED_INDICATOR<>'Y'`; this report's generated SQL has **no** cancelled-line predicate, so adding it would break parity.
6. F4101 join moved to `IMITM = SDITM` (numeric key, 17-proven; was `IMLITM = SDLITM`, equivalent mapping). Promised-ship window now filters on Julian bounds inside `#so` (same semantics as the old decoded-date BETWEEN).

**Page 1 (PO) — stays foldable; LBs columns implemented:**
- Cognos = `qty × CONVERSION_FACTOR_LB` (no sales factor on this page → DW qty basis already primary). Both LBs columns now multiply by `UMCONV(IMUOM1→'LB')/10⁷` via a deduped F41002 GROUP-BY derived join + `F4101 im ON IMITM = PDITM` (added `PDITM` to the projection). Fallback 1.0 = old placeholder behaviour. TODO-verify vs xlsx (spot-check a non-LB-primary item).
- USD columns and Quantity Cancelled unchanged — 17 had no findings there (US branches are likely domestic-USD; F0015 join still open, §8 items 3/5).

**Page 3 (Sales_Ledger) — no changes.** The §6 "F42199 blocker" was already resolved 2026-07-14 (SL* prefixes); 17's production use of F42199/SL* independently confirms it.

**Next:** jumpbox refresh (watch page 2's first batch-mode refresh + the two new page-1 columns), then fresh tight-capture Cognos exports (all three pages have rolling windows — the July xlsx is order-of-magnitude only), key-level compare, workbook.

### §9.1 Refresh round 1 readout (2026-07-22, jumpbox refresh, validated locally via MCP DAX)

All three pages loaded, counts in expected range: **PO 3,764 / Sales Orders 12,316 / Sales Ledger 93,768**. Page 2's first batch-mode refresh succeeded. Factor logic provably active: LBs ≠ plain qty on 643 page-2 rows (Qty 69.94M vs LBs 70.46M) and 58 page-1 rows (Open 3.82M vs LBs 4.21M). TM Name 99.8% populated (28 blanks).

**DEFECT FOUND + FIXED: CSR Name blank on ALL 12,316 rows.** The ported `CMCO <> '00000'` #csr filter (17's pending Rohit fix) emptied the lookup — essentially every F42140 'CSR' row on this ODS carries `CMCO = '00000'`, so the predicate as remembered excludes the entire population (it only "works" on Rohit's 4 dupe CMAN8s). **Reverted #csr to plain `GROUP BY CMAN8 / MIN(CMSLSM)`** — identical semantics to the probe-validated 2026-07-14 `OUTER APPLY TOP 1 ORDER BY CMSLSM` — in `.m` / `.commented.m` / TMDL, and pushed live into the open Desktop model via MCP partition Update. Cross-report action: **do NOT apply the CMCO fix to report 17 as stated; reconfirm the predicate with Rohit** (plausible correct form is the inverse, `CMCO = '00000'`).

Local refresh attempt failed as expected (`EvaluateNativeQueryUnpermitted` — ODS refresh is jumpbox-only; transaction rolled back, model unharmed). **NEXT: carry the repo PBIP back to the jumpbox, re-refresh (Sales_Orders_Static is the only changed query — approve the native-query prompt), spot-check CSR Name populates, then fresh tight-capture Cognos exports of all three pages for the key-level compare.**

---

## §9.2 DAX-ownership rebuild (2026-07-22) — logic out of SQL, into the model

**Directive (Zack):** validation with Rohit is coming; every piece we struggled with or that carries tie-risk must be readable in DAX — joins as model relationships + `RELATED()` (or an explicit aggregate pick), not buried in native SQL. Modeled on report 17's §12.8 simplification. **Model = 9 tables / 6 relationships, MCP lint clean. NOT yet refreshed — the currently-open Desktop copy predates this; close it WITHOUT saving before reopening the repo PBIP.**

**Fetch queries (line grain, no business logic):** `PO` and `Sales_Orders_Static` are now plain population+attribute SELECTs (both back to `EnableFolding=true`, no temp tables, no GROUP BY, no OUTER APPLY). They expose raw quantities (`PO Quantity Ordered`/`Open Quantity`/`Quantity Received`; `Ordered Qty (units)`), the UOM pair (`Trans UOM`/`Primary UOM`), and join keys built in SQL (`Conv Key` = ITM|From|To, `LB Key` = ITM|Primary, `Line Key` = 4-part JDE key, `Item Key`, `Ship To Key`).

**New lookup tables (each its own `.m` + `.commented.m`):**
| Table | Source | Purpose |
|---|---|---|
| `UOM Conversions` | F41002 deduped (MAX(UMCONV)/10⁷) | SALES_FACTOR lookup (17 §12.6/12.7) |
| `UOM To LB` | F41002, To='LB', deduped | CONVERSION_FACTOR_LB lookup |
| `CSR Assignments` | F42140 'CSR' + F0111, **RAW — dupes + CMCO visible** | CSR pick, Rohit conversation happens in-model |
| `TM Assignments` | F42140 '%TM' + F0111, raw | TM pick |
| `PO Receipts` | MAX(F43121.PRRCDJ) per line, scoped | Receipt Date (PO_DETAIL_CLOSED_DATE stand-in) |

**Relationships:** `Sales_Orders_Static[Conv Key]`→`UOM Conversions`; `[LB Key]`→`UOM To LB` (both facts); `PO[Line Key]`→`PO Receipts` (all m:1, RELATED-readable); `[Ship To Key]`↔`CSR/TM Assignments` (m:m, browse/cross-filter only).

**DAX calc columns (the former tie-risk pieces, now inspectable):** `[Sales Factor]`, `[Ordered Quantity]`, `[LB Factor]`, `[Ordered Quantity LBs]` (page 2); `[Quantity Cancelled]` (= Ordered − Open − Received), `[LB Factor]`, both LBs columns, `[Receipt Date]` (page 1); `[CSR Name]`/`[TM Name]` = lowest-AN8 pick via MINX/MAXX over the assignment tables (= the probe-validated TOP 1 ORDER BY CMSLSM semantics, no CMCO predicate per §9.1).

**Grain / visual change:** facts are line grain; the two tableEx visuals now aggregate the quantity/amount fields with **Sum** (`Sum(Table.Col)` projections, `displayName` pinned to the original header so nothing renders as "Sum of …"). Identical display tuples merge additively = Cognos list behaviour (RULE B equivalent, visible in the field well). Identifier columns stay `summarizeBy: none`.

**Unchanged:** page 3 (`Sales_Ledger`), all Cognos filters (window/branches/GST; still NO 980 exclusion), `Last Refreshed`, USD amounts (raw domestic; F0015 open, §8.3).

**Next:** jumpbox full refresh (7 import queries now — approve the native-query prompts) → verify `[Ordered Quantity]`/LBs/`[CSR Name]` populate and page totals vs §9.1 baselines (12,316 rows / qty 69.9M ballpark, minus CSR fix drift) → fresh tight-capture Cognos exports → key-level compare + workbook. If refresh errors on a calc column, the DAX is file-editable without touching SQL.

---

## §10 SSAS rebuild (2026-07-22) — pages 1 & 2 on BIQLTabular_v2

Parallel deliverable to the ODS build above: **pages 1 and 2 rebuilt on the team's SSAS tabular model** so they can be maintained on the shared semantic model. Page 3 (Sales Ledger) is **not** in this variant — it is being split into its own report (§11). The ODS `PBIP\` folder is untouched and stays as the fallback.

**Deliverable:** `PBIP (SSAS)\Americas - Open Purchase Orders (SSAS)` — a 2-page PBIP (PO Static, Sales Order Static). Visuals, headers, formats, sorts, red-bold header styling and the Last Refreshed card are **byte-identical** to the ODS report (the Report folder was copied; only the SemanticModel was swapped and page 3 removed).

### Connection mode — IMPORT via `AnalysisServices.Database` DAX EVALUATE (report-08 pattern)

Shipped mode = **import**, one DAX `EVALUATE` per page against `AnalysisServices.Database("SSASPROD","BIQLTabular_v2", [Query=…, Implementation="2.0"])`. The cube's own relationships supply every join; all Cognos business logic lives in the DAX (readable, file-editable). Model = **3 tables** (`PO`, `Sales_Orders_Static`, `Last Refreshed`), **0 relationships**, **1 measure** — MCP `ConnectFolder` lint **clean** (3 tables / 1 measure loaded, no errors). Commented masters: `PO (SSAS).m`, `Sales_Orders_Static (SSAS).m`.

**Why not a thin LIVE connection (the team's stated preference):** a pure Live report (no local model) can only add report-level **measures**, but page 2 requires row-level **group-by string columns** — `Make Site` and `Ship Site` are `CASE`/`SWITCH` decodes on branch + item stock type, and there is **no such column in the cube** — plus a derived `Quantity Cancelled`. Group-by columns cannot be measures, and a Live report cannot add calculated columns, so pages 1–2 cannot ride a pure-Live thin report. Import is also what the shipped report-08 SSAS variant used. The proven Live byConnection shape (kept for the team, should the cube ever gain Make/Ship Site columns):

```json
"datasetReference": { "byConnection": {
  "connectionString": "Data Source=SSASPROD;Initial Catalog=BIQLTabular_v2;Cube=Model",
  "name": "EntityDataSource", "connectionType": "analysisServicesDatabaseLive" } }
```
> **CORRECTED 2026-07-22 (see §13):** this shape is WRONG for external SSAS — `byConnection` is Fabric-service only (single property `connectionString`). External AS live = `byPath` -> proxy SemanticModel containing only root-level `modelReference.json` (+ `.platform`, `definition.pbism`).

Perspectives ("Purchase Order Detail", "Sales Order") exist but were **not** used — the import binds the full model by table/column name, which is required because the two pages pull from tables in different perspectives (Sales + CSR + Territory Manager + Customer Ship To + Item Branch + Branch).

### Page 1 "PO Static" — column map (cube table `Purchase Order Detail` = F4311, partition `SELECT * FROM BIQL.TbPurchaseOrderDetail`, full population)

| # | Cognos header | cube table[column] | JDE lineage | Conf |
|---|---|---|---|---|
| 1 | Branch Plant | `Branch[Branch Plant]` (via BranchSKey) | F0006.MCMCU | HIGH |
| 2 | PO Number | `Purchase Order Detail[Order Num]` | F4311.PDDOCO | HIGH |
| 3 | Line Number | `Purchase Order Detail[Line Num]` | F4311.PDLNID | MED — verify ÷1000 scale |
| 4 | 2nd Item Number | `Item Branch[Item Num 2nd]` (via ItemBranchSKey) | F4102.IBLITM | MED (branch analog of PDLITM) |
| 5 | PO Date | `Purchase Order Detail[Order Date]` | F4311.PDTRDJ | HIGH |
| 6 | Requested Date | `Purchase Order Detail[Requested Date]` | F4311.PDDRQJ | HIGH |
| 7 | Promised Date | `Purchase Order Detail[Scheduled Pick Date]` | F4311.PDPDDJ | HIGH — **NOT** `[Promised Shipment Date]`=PDPPDJ (naming trap) |
| 8 | Receipt Date | `Purchase Order Detail[LastReceivedDate]` | max F43121.PRRCDJ = DW PO_DETAIL_CLOSED_DATE | MED-HIGH — verify Last vs First |
| 9 | Vendor ID | `Purchase Order Detail[Address Num PO]` | F4311.PDAN8 | HIGH (native) |
| 10 | Vendor Name | `Purchase Order Detail[Vendor Name]` | F0101.ABALPH for PDAN8 | HIGH (native) |
| 11 | Lead Time Level | `Item Branch[Lead time Level]` | F4102.IBLTLV | HIGH |
| 12 | Quantity Cancelled | `SUM(QuantityOrdered − QuantityOpen − QuantityReceived)` | derived (no direct cube col; DW QUANTITY_CANCELLED) | **LOW** |
| 13 | PO Quantity Ordered LBs | `SUM(QuantityOrderedLB)` | QuantityOrdered × ConversionFactorLB (pre-computed) | MED-HIGH |
| 14 | Open Quantity | `SUM(QuantityOpen)` | F4311.PDUOPN | HIGH |
| 15 | Open Quantity LBs | `SUM(QuantityOpenLB)` | QuantityOpen × ConversionFactorLB (pre-computed) | MED-HIGH |
| 16 | Spend Amount USD | `SUM(AmountExtendedPrice)` | F4311.PDAEXP (raw domestic) | MED — see USD note |
| 17 | Purchase Amount USD | `SUM(AmountOpen)` | F4311.PDAOPN (raw domestic) | MED — see USD note |

### Page 2 "Sales Order Static" — column map (cube table `Sales` = F4211 **∪** F42119, partition unions `TbSales_Detail_v2` + `TbSales_History_v2`; **open lines included** — F4211 partition has no CurrentDate cutoff, so page 2 rides the cube)

| # | Cognos header | cube table[column] | JDE lineage | Conf |
|---|---|---|---|---|
| 1 | Order Number | `Sales[Order Num]` | SDDOCO | HIGH |
| 2 | Line Number | `Sales[Line Num]` | SDLNID | MED — verify ÷1000 |
| 3 | Ordered Date | `Sales[Order Date]` | SDTRDJ | HIGH |
| 4 | Promised Ship Date | `Sales[Scheduled Pick Date]` | SDPDDJ | HIGH — naming trap (not `[Promised Shipment Date]`) |
| 5 | CSR Name | `CSR for Sales Orders[CSRName]` (via CompositeKey) | modeled type-9 ship-to CSR = DW SALES_REP_TYPE_9_NAME | HIGH |
| 6 | Customer Name | `Customer Ship To[Customer Ship To Name]` (via ShipToCustomerSKey) | F0101.ABALPH for SDSHAN | HIGH |
| 7 | 2nd Item Number | `Sales[Item Num 2nd]` | SDLITM | HIGH (native) |
| 8 | Description 1 | `Sales[Description 1]` | SDDSC1 | HIGH |
| 9 | Description 1 (dup) | `Sales[Description 1]` again, `displayName`="Description 1" | Cognos Description 2 = [Description 1] | HIGH |
| 10/11 | Delivery Instructions 1/2 | `Sales[Delivery Instructions Line 1/2]` | F4201.SHDEL1/2 (native) | HIGH |
| 12 | Next Status | `Sales[Status Code Next]` | SDNXTR | HIGH |
| 13 | Ordered Quantity | `SUM(QuantityOrderedPrimaryUOM)` | SDPQOR = DW ORDERED_QTY × SALES_FACTOR (pre-computed — no factor math needed) | MED-HIGH |
| 14 | Ordered Quantity LBs | `SUM(QuantityOrderedPrimaryUOMLB)` | SDPQOR × ConversionFactorLB (pre-computed) | MED-HIGH |
| 15 | Customer Segmentation | `Customer Ship To[Customer Segmentation]` | F03012.AIAC06 | MED (ODS used ABAC06; same AC06) |
| 16 | TM Name | `Territory Manager[Mailing Name]` (via TerritoryManagerSKey) | F42140 rep | MED — see TM note |
| 17 | Make Site | `SWITCH` on `Branch[Branch Plant]` + `Item Branch[Stocking Type]` (IBSTKT) | CASE, verbatim from Cognos SQL | HIGH |
| 18 | Lead Time Order to Ship | `Item Branch[Lead time Level]` | F4102.IBLTLV | MED — Cognos DW name was LEADTIME_MFG; ODS twin also uses IBLTLV |
| 19 | Ship Site | `SWITCH` on `Branch[Branch Plant]` | CASE, verbatim | HIGH |
| 20 | Carrier Name | `Sales[Carrier Name]` | F0101 ABALPH for SDCARS (native) | HIGH |
| 21 | Freight Handling Code | `Sales[Freight Handling Code]` | SDFRTH (native) | HIGH |

### Filter mapping (baked into each EVALUATE — no slicers)

| Page | Cognos filter | DAX |
|---|---|---|
| 1 | Promised Date ≥ sysdate−365 | `FILTER(ALL(POD[Scheduled Pick Date]), … >= TODAY()-365)` |
| 1 | Branch Plant in CINC/CIN2/CIN4 | `FILTER(ALL(Branch[Branch Plant]), … IN {…})` |
| 1 | PO doc type in OP/OD | `FILTER(ALL(POD[Order Type]), … IN {"OP","OD"})` |
| 2 | Promised Ship Date in [sysdate−365, sysdate+30] | `Sales[Scheduled Pick Date]` between `TODAY()-365` and `TODAY()+30` |
| 2 | Branch Plant in CINC/CIN2/CIN4 | `RELATED(Branch[Branch Plant]) IN {…}` |
| 2 | GST/duty exclusion `decode(GlobalBulk,'-',2ndItem,GlobalBulk) NOT IN (IGST,CGST,SGST,CVD,ADD)` | `IF(RELATED('Item Branch'[Item Num Global Bulk])="-" ‖ ISBLANK(…), Sales[Item Num 2nd], RELATED(…)) NOT IN {…}` (F554101.IMGBLK) |

Rolling windows are **evaluated at refresh time** (`TODAY()`) inside the import query — same behaviour as the ODS twin; schedule a daily refresh. No hard date ceiling exists (defect C1 clear).

### Mapping-confidence tally

| | mapped-clean (HIGH) | mapped-flagged (MED/LOW) | unmapped |
|---|---|---|---|
| Page 1 (17) | 9 | 8 | 0 |
| Page 2 (21) | 15 | 6 | 0 |

Zero columns faked or unmapped. Every flagged item has an explicit note above and an open question below.

### OPEN QUESTIONS (validate on the jumpbox / with Rohit)

1. **Line Number scale** (both pages) — does the cube `[Line Num]` (F4311/F4211.SDLNID) already present as `1.000`, or raw ×1000? If raw, divide by 1000 in the SELECTCOLUMNS. *(Highest-priority quick check — a factor-1000 error is obvious in the first refresh.)*
2. **Quantity Cancelled (page 1, LOW)** — no dedicated cube column. Shipped as `Ordered − Open − Received` (transaction-UOM basis, internally consistent). Confirm vs Cognos DW QUANTITY_CANCELLED; alternative candidate = `QuantityRelieved` (F4311.PDURLV). The ODS twin derives the same difference on a PDPQOR/PDUOPN/PDUREC basis.
3. **Spend / Purchase Amount USD (page 1)** — shipped as **raw domestic** `AmountExtendedPrice` (PDAEXP) / `AmountOpen` (PDAOPN), matching the validated ODS twin (US branches are domestic-USD). Cognos multiplies by an M-rate; the cube exposes a per-row `USDRate` column if true FX conversion is ever required (`SUMX(rows, Amount × USDRate)`). Confirm no foreign-currency POs on CINC/CIN2/CIN4.
4. **TM Name (page 2, MED)** — mapped to `Territory Manager[Mailing Name]` via `Sales[TerritoryManagerSKey]`. Cognos joined the **order's** `SALES_REP_ID` (SDASN) to the rep. Confirm the cube's `TerritoryManagerSKey` derives from the order sales rep (not a customer-commission default). `[Territory Manager]` (F0101.ABALPH) is the alt name column if Mailing Name is blank.
5. **LEFT-vs-INNER join drift (page 2)** — cube relationships are LEFT-join; Cognos INNER-joined TM / carrier / customer / item, so a few TM-less (or carrier-less) lines that Cognos **drops** may appear here with a blank value. The ODS twin saw ~0.2% blank TM. If live counts over-run Cognos, add `NOT ISBLANK` guards on the affected dims.
6. **Dual-resident F4211/F42119 (page 2)** — the cube `Sales` unions Detail_v2 + History_v2; a line resident in both could double a summed quantity. The ODS twin guards this with a `NOT EXISTS`. Cube-level concern — watch row multiplicity in the compare.
7. **2nd Item Number (page 1, MED)** — mapped to `Item Branch[Item Num 2nd]` (IBLITM) via the ItemBranchSKey relationship, the branch analog of the line's PDLITM. Native `Purchase Order Detail[Item Num_F4311]` is an undocumented alternative; both should equal PDLITM.
8. **Lead Time Order to Ship (page 2, MED)** — mapped to `Item Branch[Lead time Level]` (IBLTLV) to mirror the ODS twin. Cognos's DW field was named `LEADTIME_MFG`; the cube's native `Sales[Order to Ship Leadtime]` (meaning unconfirmed) is an alternative to compare.

### Jumpbox test steps (Zack)

1. Copy `PBIP (SSAS)\` to the jumpbox (the box with SSASPROD read access — an **Analysis Services role membership**, not a SQL grant; different from the ODS reports' SQL data source).
2. Open `Americas - Open Purchase Orders (SSAS).pbip` in Desktop; on refresh approve the **AnalysisServices.Database** native-query / privacy prompts (2 import queries + the local Last Refreshed).
3. Sanity the counts: PO ≈ **3.7–3.8k**, Sales Orders ≈ **12.2–12.4k** (rolling; the July xlsx is order-of-magnitude only). If either is off by ~1000×, that's the Line-Number scale (OQ1) — the numbers would still be right but confirm.
4. Spot-check per open question: Line Number shows `1, 2, …` (not `1000`); `Quantity Cancelled`/`Open Quantity LBs` ≠ 0 where expected; `CSR Name` and `TM Name` populate; `Make Site`/`Ship Site` show Kemper/Shell/OTHER; Receipt Date blank on un-received lines.
5. Fresh **tight-capture** Cognos exports of both pages (rolling windows — capture Cognos + PBI minutes apart), key-level compare (PO#+Line#, Order#+Line#), build the standard report-out workbook with live compare formulas.

---

## §11 Sales Ledger split-out (2026-07-22)

Extracted page 3 (**Sales Ledger**) into its own standalone PBIP so the refresh-proven ledger query (93,768 rows on 2026-07-22) ships as an independent report, decoupled from the heavier PO / Sales-Orders-Static pages.

**Created:** `PBIP (Sales Ledger)\` — a complete standalone PBIP named `Americas - Open Purchase Orders - Sales Ledger`:
- `Americas - Open Purchase Orders - Sales Ledger.pbip` + `.Report\` + `.SemanticModel\` (all artifacts renamed consistently; both `.platform` `displayName`s = `Americas - Open Purchase Orders - Sales Ledger`).
- **SemanticModel** keeps only two tables: `Sales_Ledger` (partition M copied verbatim — see note below) and `Last Refreshed` (+ its `Last Refreshed Label` measure). `model.tmdl` `PBI_QueryOrder` and `ref table` lines pruned to just those two, in that order. **No `relationships.tmdl`** — the source's six relationships all touched removed tables (Sales_Orders_Static / PO / UOM / CSR / TM / PO Receipts); none referenced the two kept tables, so the split model is relationship-free. `database.tmdl`, `definition.pbism`, culture, and `.pbi` settings copied; the stale `.pbi\cache.abf` data cache was **not** copied.
- **Report** keeps only the Sales Ledger page (id `972fe0125ac34cc98013`, display name "Sales Ledger") with its tableEx `7179b5a2d3d64ea39e46` and Last Refreshed card `4b301cff9a764584a2fd`, copied verbatim. `pages.json` `pageOrder`/`activePageName` set to that single page. `report.json` + theme resources unchanged.
- Both `.platform` files got **new** `logicalId` GUIDs (Report `e7f00021-2133-4645-9415-cc648459d1da`, SemanticModel `c64c5ab2-8318-4fbb-8245-eff059d26bb2`) to avoid workspace-identity collision with the source; the `.pbip` artifact reference and `.pbir` dataset reference both repoint to the new folder names.

**SQL is byte-identical to the validated master.** The `Sales_Ledger` partition M was copied verbatim from the source PBIP — no edit to the native query. The shared masters `Sales_Ledger.m` / `Sales_Ledger.commented.m` stay in place at the report-12 root as the single source of truth; the split report consumes the same query, so it **inherits page-3's validation** once refreshed.

**Verification (all passed):**
- powerbi-modeling MCP `ConnectFolder` on the new SemanticModel loaded cleanly: **2 tables / 1 measure / 0 relationships** (`Sales_Ledger` 10 cols, `Last Refreshed` 2 cols + 1 measure).
- Every produced JSON/`.pbip`/`.pbir`/`.pbism` parses; `pages.json` entry matches the on-disk page folder; both ledger visual.json copies untouched.
- Grep of the new folder for `Americas - Open Purchase Orders.Report` and for any removed-table token (Sales_Orders_Static / UOM / CSR / TM / PO Receipts / `ref table PO`) returns **zero hits**. One dangling linguistic-metadata entity in `en-US.tmdl` (a `Sales_Orders_Static` NLQ rename hint) was removed — `Entities` is now `{}` — since the referenced table no longer exists.

**Next steps:** jumpbox full refresh of the new PBIP (approve the single native-query prompt) → confirm 93,768-row ledger populates and Last Refreshed card stamps → publish target TBD.

---

## §12 SSAS validation round 1 (2026-07-22) — tight capture, all fixes applied

Compare inputs (captured 6 minutes apart — tight-capture holds):
- Cognos `Americas - Open Purchase Orders (2).xlsx` @ 11:49 (3 pages: 3,764 / 12,223 / 92,482 data rows)
- PBI `PO Static.csv` @ 11:55 + `SO Static.csv` — exports of the **SSAS** report (proven by the cube's `??????` unknown-member label)
- Ledger: model table in Desktop (93,813 rows, refreshed 10:58) vs the Cognos sheet

### Page 1 "PO Static" — population EXACT, four rule classes found & FIXED

3,764/3,764 keys tie (PO# + Line#). The 1 extra PBI row = PO 179025 created 2026-07-22 (nightly DW hadn't loaded it — expected drift). Dates/vendor/branch exact (1 vendor-name diff, `LUBRIZOL` vs `Lubrizol Advanced Materials`, PO 178499 — DW vs cube name-snapshot skew; 4 Promised-Date diffs = same-day-order drift).

Mismatch classes → root causes → fixes (all applied to `PO (SSAS).m` + TMDL partition):
1. **Purchase Amount USD (2,785 diffs)**: Cognos `PURCHASE_AMOUNT` ≡ `SPEND_AMOUNT` in **all 3,764 rows** (both = extended price). Was mapped to `AmountOpen`. → both columns now project `AmountExtendedPrice`.
2. **Quantity Cancelled (589 diffs)**: Cognos is **LB-basis** and only counts **explicit cancels**. 332 closed-short lines (received < ordered, line closed, no cancel) are 0 in Cognos; ungated `Ordered−Open−Received` over-flags them. → now `OrderedLB − OpenLB − ReceivedLB` **gated on `[Cancel Date]` not blank**.
3. **PO Quantity Ordered LBs (1,114 diffs)**: two rules — (a) Cognos **nets cancels out of ordered** (fully-cancelled → 0); (b) Cognos zeroes ALL LB columns for **unknown-item lines** (`Not Applicable`; cube `??????` defaults factor 1). → `QuantityOrderedLB − cancelledLB`, unknown-item → 0; same zero rule on Open LBs (its 84 diffs) and Cancelled. `??????` label mapped to `Not Applicable`.
4. **Spend zeroing (408 of 410 diffs)**: fully-cancelled lines (cancel date set, nothing open or received) show **0** spend/purchase in Cognos. → gated zero applied.
- **Receipt Date (806 diffs)**: 790 = Cognos renders null as `1900-01-01`, we render blank (cosmetic, accepted). 16 real: cube has no `PO_DETAIL_CLOSED_DATE`; `LastReceivedDate` differs on partially-received-open lines (14) and closed-later lines (2, +4 days). **Accepted residual, flagged to team.**
- **Accepted residuals**: 4 rows where DW claims a cancel F4311 doesn't show (e.g. PO 103151, 2017 — DW-side artifact); item `PT44X44RHT` LB factor 2000 (Cognos) vs 155 (cube) — **team investigate**; a handful of 2107/2108 Requested/Promised dates = genuine JDE entry typos (why ancient POs pass the rolling filter; both sides identical).

### Page 2 "Sales Order Static" — Cognos ⊂ PBI (0 missing keys), six classes found & FIXED

12,324 matched; 113 PBI extras — **112/113 have no CSR row** → Cognos's INNER join to the type-9 rep drops them (predicted OQ5). Fixes (all applied to `Sales_Orders_Static (SSAS).m` + TMDL):
1. **Ordered Quantity LBs (11,240 diffs — the big one)**: cube column `QuantityOrderedPrimaryUOMLB` **double-applies the container factor** — for lines already in primary-UOM (LB) it multiplies by per-container LBs again (8,228 rows off by exactly the container weight: ×2200/tote, ×691/drum, ×450, ×2600...). **CUBE DEFECT — report to team.** → remapped to `QuantityOrderedLB` (transaction qty × factor, the same family page 1 uses correctly).
2. **Lead Time Order to Ship (12,084 diffs ≈ all)**: `[Lead time Level]` (IBLTLV) is the wrong field for page 2 — Cognos uses `LEADTIME_MFG`. Cube has the exact lineage: `'Item Branch'[Lead Time MFG_BP]` (F4102.IBLTMF). → remapped. (Page 1 keeps IBLTLV — it tied 0-diff there.)
3. **CSR Name (100% of rows)**: format only — cube `Last, First`, Cognos `First Last`. After flipping, 44 remaining = Cognos `-` sentinel for blank. → DAX reformat + `-` sentinel; Base now also requires a related CSR **row** (`RELATED CSRNum` not blank) for INNER-join parity, while blank *names* still render `-`.
4. **Factor-null zeroing (882 qty / 2,977 LB diffs)**: Cognos zeroes `ORDERED_QTY` when the sales factor is unresolvable and LBs when no real LB conversion exists (all non-stock items: BILLABLE FREIGHT, FI, NEWITEMPKG...; the cube passes raw qty through). → heuristic: qty = 0 when `UOM <> UOM Primary` and cube qty = raw; LBs additionally 0 when `UOM <> "LB"` and LB = raw. **Verify on next capture** (the signal is inferred, not read from a null column).
5. **Sentinels**: blank delivery instructions → `-` (10,664/10,305 rows!), blank TM → `Not Available` (488). → applied.
6. **Drift, accepted**: 122 Next-Status diffs are all *forward* progressions (580→999, 550→560...) = live cube vs nightly DW; ~100 date diffs ride along; dup-key (Order#+Line#) merge artifacts explain the item/make-site "swaps"; cube nulls `Item Num 2nd` for text-only lines (RESTOCK, DISPOSAL FEE) — team note.

### Page 3 "Sales Ledger" — MODEL IS A STRICT SUPERSET; the gap is a Cognos DW LOAD DEFICIENCY

Model 93,813 rows / 15,102 distinct orders vs Cognos 92,482 / 14,929 → +1,331 rows / +173 whole orders, spread across **every year** and all CSR users (no category fingerprint). Key-level drill (order-number bisection) found the extras cluster in contiguous creation bursts. Smoking gun: **Cognos has ZERO ledger rows last-updated 2026-01-21 (model: 170)** — the DW's F42199 incremental load skipped the whole day; 19 orders whose only activity was that day are missing entirely, the rest lost those revisions. Partial shortfalls on many other days (e.g. 2026-01-22 +34, 01-26 +11, 01-29 +13, 01-30 +15; monthly diffs up to +235) with occasional small negatives (rows whose in-place updates ODS is stale on — tuple shifted buckets). Monthly recon sums to the exact +1,331. **Not our defect — report to the Cognos/DW owner.** Validation posture: ODS ledger ⊇ Cognos; document as known-superset, don't chase 1:1 against provably missing data.

### Ledger folded back into the SSAS report (per Zack, since it's import mode anyway)

`Sales_Ledger` table TMDL + the ledger page (`972fe0125ac34cc98013`, both visuals) copied verbatim from the `PBIP (Sales Ledger)\` split into `PBIP (SSAS)\`; `model.tmdl` QueryOrder/refs + `pages.json` updated. The SSAS report is now the **full 3-page report** (2 pages cube-import + 1 page ODS SQL — mixed sources are fine in import mode). MCP ConnectFolder lint: **4 tables / 1 measure — clean**. `PBIP (Sales Ledger)\` is now **superseded** (left on disk, decide whether to recycle). The ODS `PBIP\` stays untouched as fallback.

### Jumpbox next steps (Zack)
1. Refresh `PBIP (SSAS)` (now 4 queries: 2 × SSASPROD AnalysisServices + 1 × ODSPROD SQL + Last Refreshed — approve all prompts; needs BOTH the AS role and the SQL grant).
2. Fresh tight-capture Cognos export + full-table PBI exports (DAX query view, not the visual export) → round 2 compare should tie pages 1–2 to drift + the documented residuals; then build the standard report-out workbook.
3. Round-2 watch list: factor-null zeroing heuristic (fix 4), CSR-row INNER filter (the 44 `-` rows must survive, the 112 extras must drop), the 113th extra row, `PT44X44RHT`.

---

## §13 Live Connection rebuild (2026-07-22)

**Dave's mandate:** pages 1-2 must ship as a **pure SSAS Live Connection** — no report-side semantic model, no local tables, only **report-level measures** and page/visual filters. Page 3 (Sales Ledger) ships as the separate `PBIP (Sales Ledger)\` report (again a live deliverable per Dave). The §10/§12 `PBIP (SSAS)\` import variant is **retained untouched as the validated-logic reference**; the ODS `PBIP\` remains the fallback.

**Deliverable:** `PBIP (SSAS Live)\Americas - Open Purchase Orders (SSAS Live)` — a **Report-ONLY** PBIP (no `.SemanticModel` folder). `definition.pbir` uses the live `byConnection` shape (`Data Source=SSASPROD;Initial Catalog=BIQLTabular_v2;Cube=Model`, `analysisServicesDatabaseLive`); `.platform` got a **new** logicalId (`ecad1205-fff2-4272-8f2f-e0a7cc6dfcb6`). Two pages only (PO Static `475d2b543dcb4c9c90d9`, Sales Order Static `7b5cbe67461e4026985c`); ledger page dropped. Report folder (theme, report.json, styling, positions) copied byte-for-byte from `PBIP (SSAS)`; only field references, sorts, filters, and the Last Refreshed card binding changed. The stale machine-specific `.pbi\localSettings.json` was not copied.

### CORRECTION (same day): live reference = byPath + modelReference.json proxy, NOT byConnection

First jumpbox open failed: "Property 'name' has not been defined... Path 'datasetReference.byConnection.name'". Per the Desktop `Microsoft.PowerBI.Packaging.dll` schema strings (authoritative): **`byConnection` may only point at a Fabric-service-hosted semantic model and accepts a single property, `connectionString`. Connections to any other Analysis Services model must use a `byPath` reference to a semantic-model definition containing a `modelReference.json`.** Fixed shape now in place:

- `definition.pbir` -> back to `byPath: "../Americas - Open Purchase Orders (SSAS Live).SemanticModel"` (definitionProperties 2.0.0, version 4.0).
- New **proxy** `...(SSAS Live).SemanticModel\`: `.platform` (fresh logicalId), `definition.pbism` (v4.2), and `modelReference.json` **at the folder ROOT** — no `definition\` folder at all, no TMDL, no tables. (Second jumpbox error taught the placement: an empty/modelReference-only `definition\` folder makes Desktop fall back to TMSL-format detection and demand `model.bim`; the Packaging.dll artifact table lists `modelReference.json` alongside the root files `definition.pbism`/`model.bim`/`diagramLayout.json`.)

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/semanticModel/modelReference/2.0.0/schema.json",
  "connectionString": "Data Source=SSASPROD;Initial Catalog=BIQLTabular_v2;Cube=Model",
  "connectionType": "analysisServicesDatabaseLive"
}
```

**Confirmed against a native Desktop live save** (Zack generated `Cognos Reports\Analysisnalysis.pbip` on the jumpbox via Get Data > AS > Connect live > Save as PBIP): identical layout and contents — root-level modelReference.json, pbism 4.2, byPath pbir; Desktop omits `isMultiDimentional`, so ours does too. (`isMultiDimentional` exists in the schema; `connectionType` enum from the DLL: pbiServiceLive / pbiServiceXmlaStyleLive / atScaleDatabaseLive / **analysisServicesDatabaseLive** / cdmLive / pbiServiceOnPrem.) The `.pbip` still lists only the Report artifact. This is exactly how Desktop itself saves a live-connection PBIP.

### Report-level measures — `definition\reportExtensions.json`
Schema confirmed from the Power BI Desktop WebView bundle (`desktop.schema.json.6.min.js`, `reportExtension/1.0.0/schema.json`): each `ReportExtensionMeasure` **requires `name`, `dataType` (PrimitiveTypeName enum), `expression`**; `formatString`/`hidden` optional; **`lineageTag` is NOT a valid property** (`additionalProperties:false`) — omitted. Measures carry an `R12 ` prefix to avoid colliding with the cube's native `PO Qty Ordered` / `PO Amt Open` etc.; visual `displayName`s pin the Cognos headers so the prefix is invisible. 17 measures total. Every §12 validated rule is now encoded as DAX (the cube's own relationships supply the joins that the import EVALUATE used):

**Home `Purchase Order Detail` (page 1):**
- `R12 PO Quantity Cancelled` — LB-basis cancel (OrderedLB minus OpenLB minus ReceivedLB) gated on Cancel Date; unknown-item (`??????`/blank Item Num 2nd) to 0.
- `R12 PO Ordered LBs` — QuantityOrderedLB net of cancelled LB; unknown-item to 0.
- `R12 PO Open Quantity` — SUM(QuantityOpen).
- `R12 PO Open LBs` — SUM(QuantityOpenLB); unknown-item to 0.
- `R12 PO Spend USD` — AmountExtendedPrice, zeroed on fully-cancelled lines (cancel set, nothing open/received).
- `R12 PO Purchase USD` — identical expression (Cognos PURCHASE_AMOUNT is the same field as SPEND_AMOUNT); kept separate so the two columns stay independent.
- `R12 PO Include` *(hidden)* — 1 when Scheduled Pick Date at least TODAY()-365; drives the visual-level rolling-window filter.

**Home `Sales` (page 2):**
- `R12 SO Ordered Quantity` — QuantityOrderedPrimaryUOM, zeroed when factor is unresolvable (UOM not equal primary and cube passed raw qty through). Never uses the defective `QuantityOrderedPrimaryUOMLB`.
- `R12 SO Ordered LBs` — QuantityOrderedLB, zeroed on factor-null and on no-real-LB-conversion.
- `R12 SO CSR Name` — cube "Last, First" to "First Last"; blank to "-" sentinel.
- `R12 SO TM Name` — Mailing Name; blank to "Not Available" sentinel.
- `R12 SO Delivery Instr 1` / `R12 SO Delivery Instr 2` — blank to "-" sentinel.
- `R12 SO Make Site` — SWITCH on Branch Plant + Item Branch Stocking Type (Kemper/Shell/OTHER).
- `R12 SO Ship Site` — SWITCH on Branch Plant (Kemper/Shell/OTHER).
- `R12 SO Description 1` — `MAX('Sales'[Description 1])`, the second "Description 1" column (a live tableEx cannot project the same cube column twice — duplicate queryRef is a render error, report 09 precedent).
- `R12 SO Include` *(hidden)* — 1 when Scheduled Pick Date in [TODAY()-365, TODAY()+30] **and** GST/duty item excluded (Global-Bulk fallback to 2nd item) **and** a related CSR row exists (INNER-join parity); drives the visual-level filter.

### Filters — placed at VISUAL level (both tableEx visuals)
- Page 1: `Branch[Branch Plant]` In {CINC,CIN2,CIN4} (Categorical); `Purchase Order Detail[Order Type]` In {OP,OD} (Categorical); `R12 PO Include` = 1 (Advanced measure comparison, ComparisonKind 0).
- Page 2: `Branch[Branch Plant]` In {CINC,CIN2,CIN4} (Categorical); `R12 SO Include` = 1 (Advanced measure comparison).

All filters live in each tableEx's `filterConfig` (measure filters must be visual-level; the categorical ones are kept there too so the full filter set is co-located). Rolling windows evaluate at query time via `TODAY()` — the same live-date behavior as the import twin.

### Visual rewiring
Both tableEx visuals repointed from the import tables (`PO`, `Sales_Orders_Static`) to cube entities + the R12 measures. All styling preserved (red bold `#FF0000` headers, black 1pt grid, totals off, stylePreset None, positions). Group columns are plain `Column` projections with `displayName` pinning the Cognos header (cube names differ: Order Num to "PO Number", Line Num to "Line Number", Item Num 2nd to "2nd Item Number", Order Date to "PO Date", Scheduled Pick Date to "Promised Date", LastReceivedDate to "Receipt Date", Address Num PO to "Vendor ID", Lead time Level to "Lead Time Level", etc.). Measures are bare `Measure` references (queryRef `"<Home>.<Measure>"`, no aggregation wrapper). Sorts reference projected columns (PO#+Line# asc on page 1; Promised Ship Date asc on page 2). No values-level conditional formatting exists in this report, so no `dataViewWildcard` selector concern. **Last Refreshed cards** on both pages rebound from the (now-absent) local `Last Refreshed`/`Last Refreshed Label` to the cube's `'Audit'[Last Refreshed On]` measure (`"Last Refreshed: " & [Last Updated]`, General Date) — card styling kept.

### Residuals unique to live mode
1. **2nd Item Number renders `??????`** for unknown-item lines (cube's unknown-member label). In import mode the DAX remapped it to "Not Applicable"; a live report cannot relabel a column per-row. Cosmetic only — the LB columns still zero correctly for those lines via the `unk` guard in the measures.
2. **Date/number format on group columns now comes from the cube**, not the report. The import model set `MMM d, yyyy` (page 1) / `d MMM, yyyy` (page 2) per column; in live mode the cube's own column format strings apply. Measures still carry explicit `formatString`s (`#,##0`, `$#,##0;($#,##0)`).
3. **Last Refreshed text** is the cube's ("Last Refreshed: <date>", date only) rather than the import card's local timestamp with time + EDT/EST zone.
4. **Grain / fan-out** now depends on the cube relationships rather than a pre-filtered SUMMARIZE. At (Order#+Line#) grain each row's attributes are single-valued, but the dual-resident F4211/F42119 union and the CSR m:m browse relationship carry the same multiplicity risk the import twin's OQ6/OQ5 flagged — watch row counts in the round-2 compare.

### Jumpbox test steps (Zack)
1. Copy `PBIP (SSAS Live)\` to the jumpbox (SSASPROD Analysis Services role membership). Open `Americas - Open Purchase Orders (SSAS Live).pbip` in Desktop — it will prompt to connect to SSASPROD (live). **No refresh/native-query approval is needed** (a live connection issues no import queries).
2. Confirm both pages render red-bold-header tables with the pinned Cognos headers; counts after filters approximately **PO 3.7-3.8k / SO 12.2-12.4k** (matches §9.1/§12 baselines).
3. Spot-check per §12 round-2 watch list: CSR Name "First Last" with `-` blanks; TM Name "Not Available" blanks; Make/Ship Site Kemper/Shell/OTHER; Ordered Quantity LBs not container-doubled; unknown items show `??????` but zero LBs; Last Refreshed card stamps from the cube Audit table.
4. Fresh tight-capture Cognos export + PBI DAX-query-view export, then key-level compare (PO#+Line#, Order#+Line#) should reproduce §12's tie-to-drift + documented residuals; build the standard report-out workbook.

### §13.1 Model-update request submitted to the BI team (2026-07-22)

Zack requested 5 calculated columns in BIQLTabular_v2 (hybrid live plan — raw-column Sums + these; report-side R12 measures retire as they land):
- **`Sales`**: `Make Site`, `Ship Site` (branch + stocking-type SWITCHes, verbatim from the Cognos SQL).
- **`Purchase Order Detail`**: `Quantity Cancelled LB` (Cancel-Date-gated OrderedLB−OpenLB−ReceivedLB), `Quantity Ordered LB Net` (ordered net of cancelled), `Amount Extended Price Net` (0 on fully-cancelled lines). Ticket notes the Cancel-Date gate is intentional (closed-short ≠ cancelled) and that logic was validated row-level vs Cognos 7/22.

Once added, the report needs NO report-side measures except possibly the duplicate-column stand-ins (2nd "Description 1", "Purchase Amount USD" = same value as Spend — a column can't project twice). NOT yet requested (second-wave items, §12): QuantityOrderedPrimaryUOMLB double-factor defect, factor-null zeroing on Sales quantities, CSR display-name format, closed-date column, rolling-window flag.

**Interim state of `PBIP (SSAS Live)` (hand-finished on the jumpbox):** raw-column Sums (QuantityOrderedLB / QuantityOpen / QuantityOpenLB / AmountExtendedPrice; Sales QuantityOrderedPrimaryUOM / QuantityOrderedLB), static-date window filters (page 1 ≥ 7/22/2025; page 2 7/22/2025–8/21/2026 — bump when re-validating), CSRNum-not-blank + two GST "is not" filters, R12 text measures only where no column exists (Make/Ship Site, optionally Quantity Cancelled). Known accepted deltas quantified in §12/§13. The generated reportExtensions.json measures did not resolve on jumpbox 2.146 (root cause undiagnosed — awaiting Desktop-saved copy-back to diff); Zack recreated needed measures via UI.
