# Report 17 — Orders within Goal and Stretch — BUILD SPEC

**Cognos path:** Public Folders > Michelman Reporting > Customer Service
**Report name (XML `reportName`):** `Orders within Goal and Stretch`
**Rendered frame title:** `IBM Cognos Viewer - Orders within Goal and Stretch` (the page body's own title textItem is **empty** — `<staticValue/>`, XML line 130)
**Migration tracker ID:** 137
**Prior owner:** Lilly (LillySc) → Zack 2026-07-14. **Highest-risk report in the Lilly handover batch.**
**Stage:** ⬜ INTAKE COMPLETE — spec ready for build. Intake artifacts all present and untruncated (§0). Rendered export + report screenshot captured 2026-07-16 10:10 → **validation target locked (§0/§10)**.

A single-page flat operational list: one row per sales-order **line** that reached both pick-confirm (next status **525**) and ship (next status **540**) within an order-date window, scored on how many **business days** elapsed between confirm and ship, and flagged **Goal / Stretch / >48h / <72h / >72h**. A single grand-total footer counts the lines and sums the five flags. Two required date prompts bound the order-date window; five optional dropdowns (Company / Business Group / Customer / Bulk Item / CSR) narrow it.

---

## 0. Intake integrity — READ FIRST

| Artifact | Status | Notes |
|---|---|---|
| Report XML | **COMPLETE, untruncated** | `Intake\XML.txt`, 47,492 bytes, report/12.0 schema, closes on `</report>` (line 276). 8 query objects + 1 report page (`Page1`) + 1 prompt page. |
| Generated SQL | **COMPLETE** | `Intake\Queries.txt`, all 6 tree nodes (4 prompt queries captured ×2, CSR, and the main `Sales Ledger/Orders` query). Dates land as `:PQ1`/`:PQ2` binds → no expired-date-ceiling risk. Optional prompt filters (Company/BG/Customer/BulkItem/CSR) are **absent** from the captured SQL because nothing was selected at capture — expected; their definitions are in the XML `<detailFilters>` (line 40, 74). |
| Prompt page screenshot | **PRESENT** | `Intake\Prompt page.png` — 5 optional dropdowns + 2 required date editboxes. |
| **Rendered report screenshot** | **PRESENT** | `Intake\Report page June run (2026-07-16 10-10).png` — page 1 of the **June-2026 run**. Confirms column order, right-alignment of Ordered Quantity + the two Customer Segmentation columns, month-first `m/d/yy` dates, the Ship-To=Sold-To quirk (§6.1), and the full metric decode (worked rows in §3.4). |
| **Rendered export (xlsx)** | **PRESENT — validation target** | `Intake\Cognos export June run (2026-07-16).xlsx`, sheet `Page1_1`. **997 data rows** + one `Overall - Total` row. Grand totals: **Total Order Lines 997 · Goal 706 · Stretch 645 · >48h 187 · <72h 810 · >72h 117** (§10). Internally consistent with the metric decode (Stretch⊂<72h, <72h+>48h=997, >72h⊂>48h). **Prompt range CONFIRMED (Zack): Jun 1 → Jun 30, 2026.** |
| Failed-validation story | **STILL PENDING** | Lilly: *"original validation never passed — historical data returning the wrong values."* The specific wrong values vs the truth were never captured. This spec's root-cause analysis (§5) identifies the almost-certain cause from the SQL, but **confirm with Lilly/team**. |

**Two findings from the export that shape the build (COLLECTION_NOTES "SECOND smoking gun" + "THIRD finding"):**
- **The 525/540 dates are DATETIMES.** The export serials carry time fractions — Order Date `46174.336` (Jun 1 08:04), Confirmation Date `46174.4548` (Jun 1 10:54). DW `ORDER_LINE_LAST_UPDATED` = JDE `SLUPMJ` (date) + `SLTDAY` (time). Cognos's MIN-window therefore orders same-day status events by **timestamp**. **Build requirement: reconstruct the datetime as SLUPMJ+SLTDAY** (§3.1, §7.2). Shipped/Requested are date-only integers — only the ledger-derived (525/540) columns carry time.
- **The displayed "Order Date" is NOT the order-date filter.** The window filters JDE order date; the "Order Date" column shows the **525 datetime** (§6.2). A June-order-date line whose 525/540 events land in July appears in the June run with a July "Order Date" (the export has 3 such orders: 26001182, 2727528, 2742995). **Filter on JDE order date (`SDTRDJ`/`SLTRDJ`); never on the displayed 525 column** (§5, §6.7).

**No conditional formatting or drill-through anywhere.** The XML has only an empty `<drillBehavior/>` — no `conditionalStyle`, no `FillRule`, no `<drillLinks>` targets. The Goal/Stretch "1" values render **blue because they are Cognos measure (fact) data items** (default fact link color), not CF and not a drill. Nothing to port; no `dataViewWildcard` values-CF concern.

**Completeness verdict:** query logic, layout, formats, prompts, AND a validation target are all in hand. This is a fully specified build. The one open input is the *story* of Lilly's failure (nice-to-have; §5 explains it from first principles regardless).

### Why extra rigor (failed-validation history)
Report 137 is the **only report in the batch Lilly could not validate.** Her T-SQL (`Goal and Stretch rewrite (Lilly 2026-07-10).sql`) is therefore **REFERENCE ONLY** — and specifically a *cautionary* reference, since it is the artifact that produced wrong numbers. The build derives entirely from the **Cognos generated SQL + XML**, which are authoritative. §5 diffs every place Lilly departs from Cognos and rates whether it explains her failure. **The headline finding: Lilly measured the wrong time interval** — order→confirm instead of confirm→ship — so every Goal/Stretch/bucket flag on her output is computed against the wrong number. That alone accounts for "historical data returning the wrong values."

---

## 1. Source route — **ODS PRODDTA (JDE), SQL Server, single import model** (recommended)

Evaluated SSAS → EDW → ODS per the standing mandate.

### The deciding constraint: the 525/540 event timestamps live only in the ledger (F42199), which is ODS-only
The metric is built from **when each line crossed next-status 525 and next-status 540** — i.e. two rows out of the sales-order **status-change ledger**. In JDE that ledger is **`PRODDTA.F42199`** (Sales Order Detail Ledger; one row per status transition per line). Report 12 already proved F42199 is reachable on **ODSPROD** with **`SL*`** column names (`SLKCOO/SLDOCO/SLDCTO/SLLNID/SLNXTR/SLUPMJ/SLTDAY`). Neither SSAS nor EDW models the raw per-transition ledger with an earliest-525 / earliest-540 selection, so the metric can only be reproduced on ODS.

### SSAS (`SSASPROD BIQLTabular_v2`, Live Connection) — **REJECTED**
Two hard blockers: (1) no perspective exposes the F42199 status-change events with the min-per-line selection this report needs; (2) a Live Connection permits **no local tables**, so the two-CTE ledger extraction + business-day arithmetic cannot be built at all. A live+import hybrid is banned by the mandate, so SSAS cannot even host the Orders half while ODS hosts the ledger.

### EDW (`EDWPROD`, SQL Server) — **REJECTED**
`dbo.FactSalesDetail` (F4211) could supply the Orders side, but **not the F42199 status ledger** (same gap as report 12 page 3). You would still need ODS for the ledger, and mixing EDW + ODS buys nothing over doing both on ODS/PRODDTA (both are SQL Server; ODS reproduces the Cognos generated SQL almost 1:1).

### ODS PRODDTA — **CHOSEN**
Both halves come from PRODDTA on ODSPROD, joined on the JDE 4-part order-line key:
- **Orders side** (order attributes, quantity, all the row-eligibility filters) = **`F4211` ∪ `F42119`** (open + purged-to-history sales detail — the same union reports 08/10/12 needed; F42119 mirrors F4211's `SD*` names on this instance, NOT EXISTS-guarded against dual residency).
- **Ledger side** (525 / 540 event dates) = **`F42199`** (`SL*`).
- **Enrichment**: `F0006` (branch → company, MCRP02/MCRP03), `F0010` (company name), `F0101` (sold-to + ship-to address), `F0005` (segmentation decode), `F554101` (global bulk item, GST exclusion), `F42140` (CSR, optional filter).

Connection: `Sql.Database("ODSPROD","ODS")`, native T-SQL, `[EnableFolding=true]` where it folds. **No leading `WITH`** (folding wraps as `SELECT * FROM (<q>)`); rewrite the Cognos `with …` chain as nested derived tables / a `#temp` extract (§7). **No `ORDER BY`** inside the folded query (illegal in SQL Server) — sort in the visual. Precedents: report 12 (`Sales_Ledger.commented.m`, the F42199+F4211∪F42119 pattern) and reports 04/15 (F4211 + F0101 + F42140 CSR).

> **Folding vs `#temp` note (house rule).** The 525/540 "earliest event per line" is a plain `GROUP BY … MIN(...)` — it folds and needs **no** correlated subquery. Do **not** use `OUTER APPLY` or a `ROW_NUMBER()` derived table for it (both re-evaluate per row on this SQL Server and have hung refreshes — see report 14). If the full joined query is too heavy to fold in one shot, materialize the ledger extract (`#l525`, `#l540`, or a combined `#ledger`) into indexed `#temp` tables in a multi-statement batch sent via `Value.NativeQuery(..., [EnableFolding=false])`, exactly like report 14's `#lbf` pattern.

---

## 2. Query objects → files

| # | Cognos query | Role | Build artifact |
|---|---|---|---|
| 1 | `Sales Ledger/Orders` | **The page.** Join of `Orders` (1:1) to `Sales Order Ledger` (1:1) on `[Orders].[JDE Order Line ID] = [Sales Order Ledger].[Order Line ID]` (XML line 14). Adds the Goal/Stretch/bucket CASEs + 6 grand-total summaries. | Main table `Orders_GS.m` (+ `.commented.m`) |
| 2 | `Orders` | Order-line master from the DW `Order Activity Star Schema`. 20 data items; 4 required + 5 optional detail filters (XML line 40). | folded into `Orders_GS.m` (the F4211∪F42119 half) |
| 3 | `Sales Order Ledger` | Join of `@525` (1:1) to `@540` (1:1) on `Order Line ID`; computes Days-Between + Weekend-Days + **Business Days Between 525 and 540**. | folded into `Orders_GS.m` (the F42199 half) |
| 4 | `Sales Order Ledger @525` | F42199 rows at Next Status **525**, restricted to the **earliest** event per (Order, Line) via `Order Line Last Updated = minimum([525 Date] for [Order Number],[Line Number])`. | `#l525` extract / derived table |
| 5 | `Sales Order Ledger @540` | Same, Next Status **540**, earliest per line. | `#l540` extract / derived table |
| 6 | `Company` / `Business Group` / `Customer` / `Bulk Item` / `CSR` | Prompt-population queries (last-150-days active values). | **not rebuilt** — PBI slicers/params derive their values from the data or from PQ parameters (§7.4). |

**PBI needs ONE table** (`Orders_GS`). The prompt-population queries are Cognos plumbing (they only fill the dropdowns); PBI slicers list distinct values natively.

---

## 3. Full decode of the main query (`Intake\Queries.txt` lines 70–101)

The generated SQL is one statement with five CTEs: `COMPANY_ALIAS_RBU`, `Orders11`, `Sales_Order_Ledger__5259` (the 525 side), `Sales_Order_Ledger__54010` (the 540 side), `Sales_Order_Ledger12` (their join + metric), then the final SELECT joins `Orders11` to `Sales_Order_Ledger12`.

### 3.1 The ledger 525 / 540 extraction (the min-window) — SQL lines 79–94
Both `@525` and `@540` are identical except the status literal:

```
-- 525 side (Sales_Order_Ledger__5259):
SELECT ... ORDER_LINE_LAST_UPDATED AS C5,
       MIN(ORDER_LINE_LAST_UPDATED) OVER (PARTITION BY ORDER_NUMBER, <line#>) AS C9
FROM   SALES_ORDER_LEDGER  JOIN  SALES_ORDER_LEDGER_MEASURES
WHERE  ORDERED_DATE between :PQ1 and :PQ2  AND  NEXT_STATUS = N'525'
-- outer:  WHERE C5 = C9         -> keeps the EARLIEST 525 event per (order, line)
```
`<line#>` = `substr(ORDER_LINE_ID, 1+instr(ORDER_LINE_ID, ',', -1), 5)` — the segment after the last comma of the composite `ORDER_LINE_ID`. So the partition key is **(Order Number, Line Number)**, and `525 Date` = the **earliest** `ORDER_LINE_LAST_UPDATED` among that line's 525 events. `@540` is the same with `NEXT_STATUS = N'540'` → `540 Date` = earliest 540 event per line.

Then `Sales_Order_Ledger12` joins the two on **`Order_Line_ID`** (the full composite, XML line 50) and computes the metric (§3.3). The whole ledger block then joins to `Orders11` on **`Orders11.JDE_Order_Line_ID = Sales_Order_Ledger12.Order_Line_ID`** (SQL line 99; XML line 14).

> **The ledger stamp is a DATETIME — reconstruct SLUPMJ+SLTDAY (build requirement).** The export proves `ORDER_LINE_LAST_UPDATED` carries a time component (serials `46174.336` / `46174.4548`), so Cognos orders same-day 525/540 events by full timestamp. **Build the ledger event as a datetime = `SLUPMJ` (date) + `SLTDAY` (time)** — reuse report 12's exact idiom (`DATEADD(SECOND, (SLTDAY/10000)*3600 + ((SLTDAY/100)%100)*60 + (SLTDAY%100), CAST(<Julian-decoded date> AS datetime2))`). Do the `MIN()` over that datetime; `TRUNC`/`CAST(... AS date)` **only** inside the business-day arithmetic. This is required for (a) faithful reproduction and unambiguous same-day ordering, and (b) display/export fidelity — the two displayed ledger-date columns carry the time in the Cognos xlsx.
>
> **Nuance the build agent should know (so a date-only fallback is understood, not silently wrong):** the *metric date* and the *flag counts* are actually **invariant** to date-only-vs-datetime, because `date(MIN(datetime)) = MIN(date)` and the `C5=C9` survivors on the earliest day collapse under `SELECT DISTINCT` to one row per line. So the 997 / 706 / 645 / 187 / 810 / 117 targets do not depend on the time component. What *does* depend on it: (1) the displayed 525/540 columns' time part (export byte-parity), and (2) Lilly's `MAX(525) ≤ Date540` selection (§5.2), where date-only genuinely changes which 525 she picks and how the ≤-comparison ties resolve — which is why her date-only `SLUPMJ` is **smoking gun #2**. Build with datetime + `MIN` and neither issue can occur.

### 3.2 The `Orders11` side — SQL lines 76–100
One row per **`JDE_ORDER_LINE_ID`** (in the GROUP BY, line 79). `Ordered_Quantity = SUM(ORDERED_QTY * SALES_FACTOR)` per line. FROM = `ORDER_ACTIVITY` + `ORDER_ACTIVITY_MEASURES` (the DW's blended sales fact) + company/org/item/customer/customer-type dims. Row-eligibility filters (SQL line 78), mapped to JDE (`§3.5`):

| # | Cognos filter (generated SQL) | Meaning |
|---|---|---|
| a | `BUDGET_FACTOR <> 1` | keep actual sales lines, drop budget rows |
| b | `CANCELLED_INDICATOR <> N'Y'` | drop cancelled lines |
| c | `ORDER_TYPE_CODE not in (N'S5', N'ST')` **and** `ORDER_TYPE_CODE <> N'ST'` | drop order types S5, ST (ST twice — redundant) |
| d | `SHIP_TO_AC01_CUSTOMER_TYPE_CODE <> N'INT'` | drop intercompany ship-tos (category code AC01 = INT) |
| e | `DESCRIPTION_1 not in (case when SALES_OR_GL='Budget Detail' then '51210' else '99999')` and same for `'61121'` | exclude Budget-Detail GL accounts 51210 / 61121 |
| f | `decode(GLOBAL_BULK_ITEM,'-',ITEM_NUMBER_2ND,GLOBAL_BULK_ITEM) not in ('IGST','CGST','SGST','CVD','ADD')` | exclude GST / duty tax items |
| g | `JDE_COMPANY__CCCO <> '00024' and <> '00025'` (in `COMPANY_ALIAS_RBU`, SQL line 4) | exclude companies 00024, 00025 |
| h | `TIME_OTHER_DATE.GREGORIAN_CALENDAR_DATE between :PQ1 and :PQ2` | **order-date window** (the required prompts) |

Selected/displayed Orders attributes: Company Code + Name, Company Level 2 Code (Goal split only — **not displayed**), Branch Plant (`ORGANIZATION_ID`), Freight Handling Code, Order Number, Ordered Quantity, 2nd Item Number, Sold-To Code + Name, Ordered Date (filter only — **not displayed**), Shipped Date, Requested Date, Scheduled Pick Date (**not displayed**), Revision Reason (**not displayed**), JDE Order Line ID (join key), Customer Segmentation code + description (from **ship-to** AC06).

### 3.3 The business-day metric — XML lines 53–55, SQL line 92
Day-of-week is Monday-anchored to **2003-01-06 (a Monday)**, so **Mon=1 … Sat=6, Sun=7** (`_day_of_week([d],1)`). The three data items:

```
Days Between 525 and 540 = _days_between([540 Date], [525 Date])          -- calendar days (540 - 525)
Weekend Days             = floor((Days + dow525)/7)*2
                           - if dow525 = 7 then 1 else 0
                           + if dow540 = 6 then 1 else 0
Business Days 525→540    = Days Between - Weekend Days                      -- this is the metric (c10)
```
`dow525 = _day_of_week([525 Date],1)`, `dow540 = _day_of_week([540 Date],1)`, using the **raw** 525/540 dates.

> **Dead code, do not port.** The `@525`/`@540` subqueries also compute `525 Date (Business Days)` / `540 Date (Business Days)` (roll Sat→+2, Sun→+1; XML lines 60–64, 69–73). These are **never referenced** by `Sales_Order_Ledger12` — it uses the raw dates. They are computed and discarded. Ignore them.

### 3.4 Worked examples (verified against the June-run screenshot)
Endpoints are **525 Date → 540 Date** (confirm → ship):

| 525 (dow) | 540 (dow) | calendar diff | weekend days | **business days (c10)** | note |
|---|---|---|---|---|---|
| Mon (1) | Mon (1) | 0 | `⌊(0+1)/7⌋·2 −0 +0 = 0` | **0** | same day (screenshot row 1: 6/1→6/1) |
| Mon (1) | Thu (4) | 3 | `⌊4/7⌋·2 = 0` | **3** | screenshot **order 26001039**: 6/1→6/4 ⇒ Goal 0, >48h 1 ✓ |
| Mon (1) | Fri (5) | 4 | `⌊5/7⌋·2 = 0` | **4** | screenshot **order 26001051**: 6/1→6/5 ⇒ >48h 1, >72h 1 ✓ |
| Fri (5) | Mon (1) | 3 | `⌊(3+5)/7⌋·2 = 2` | **1** | Fri confirm, Mon ship = 1 business day |
| Mon (1) | Mon+7 (1) | 7 | `⌊8/7⌋·2 = 2` | **5** | one full work week |
| Thu (4) | Tue+5 (2) | 5 | `⌊9/7⌋·2 = 2` | **3** | Thu→Fri→Mon→Tue |
| Sat (6) | Mon (1) | 2 | `⌊(2+6)/7⌋·2 = 2` | **0** | Sat confirm treated as Monday |
| Fri (5) | Sat (6) | 1 | `⌊6/7⌋·2 +1(dow540=6) = 1` | **0** | Sat ship isn't a business day |

The screenshot rows tie 1:1 to this decode, so the metric definition is confirmed correct, not inferred.

### 3.5 T-SQL equivalent of the metric (build exactly this — NOT Lilly's formula)
DATEFIRST-independent, matching Cognos's Monday-anchored numbering:
```sql
-- dow: Mon=1..Sun=7, anchored to 2003-01-06 (Monday), independent of SET DATEFIRST
-- dow(d) = ((DATEDIFF(DAY,'2003-01-06',d) % 7) + 7) % 7 + 1
;  diff   = DATEDIFF(DAY, d525, d540)                          -- 540 - 525, calendar days (both TRUNC'd to date)
   wkend  = ((diff + dow525) / 7) * 2                          -- integer div = FLOOR for non-negative operands
            - CASE WHEN dow525 = 7 THEN 1 ELSE 0 END
            + CASE WHEN dow540 = 6 THEN 1 ELSE 0 END
   c10    = diff - wkend                                       -- Business Days Between 525 and 540
```
Integer division in T-SQL truncates toward zero; `diff ≥ 0` and `dow525 ≥ 1` make the dividend non-negative, so `(diff+dow525)/7` equals Oracle `FLOOR(...)`. **Compute this as a SQL column** (folds, deterministic). Do **not** substitute a "cleaner" business-day count — the floor formula has deliberate edge behavior (Sat/Sun endpoints → 0; see §3.4) that a naïve count would not reproduce.

### 3.6 Goal / Stretch / bucket flags — SQL line 97, XML lines 17–33
Using **c10** (business days 525→540) and **Company Level 2** (RAME / REUR / RASI):
```
Goal    = 1 if (Level2='RAME' and c10<=1) or (Level2='REUR' and c10<=2) or (Level2='RASI' and c10<=2) else 0
Stretch = 1 if c10<=1 else 0
>48h    = 1 if c10>2  else 0
<72h    = 1 if c10<3  else 0
>72h    = 1 if c10>3  else 0
```
Note the asymmetry: **Goal** is region-dependent (Americas gets 1 day, Europe/Asia get 2); **Stretch** is a flat ≤1 everywhere. `<72h` (c10≤2) and `>48h` (c10≥3) partition all lines; `>72h` (c10≥4) ⊂ `>48h`. Company Level 2 is **not displayed** — it only drives Goal.

### 3.7 Grand totals — SQL line 95 (`sum(...) over ()`)
The final query groups by every display column (so one group = one line, `min(1)=1`) and window-sums six things over the whole result:
- **Total Order Lines** = count of lines
- **Total Goal / Stretch / >48h / <72h / >72h** = sums of the respective 0/1 flags

June-run targets (§10): 997 / 706 / 645 / 187 / 810 / 117. In PBI these are DAX measures (`COUNTROWS` and `SUM` of the flag columns), one grand-total footer row (§4.3).

---

## 4. Layout spec (XML `Page1` / `List1`, lines 83–122)

**Structure: a FLAT list** (`<list name="List1">`) with a `sortList` (Order Number, then 2nd Item Number) and a **single `listOverallGroup` grand-total footer** — **no `listGroup` nesting** (unlike report 16). Build as **one flat `tableEx`** with a totals row (not a matrix). Page header title is **empty**; page footer has date / page-number / time (not reproduced in PBI beyond the house Last-Refreshed card).

### 4.1 The 22 columns (left→right, XML `listColumns` order)
Headers render the **data-item name**, except the two `label=` overrides (col 14/15). Alignment: columns whose `listColumnBody` carries `CSS text-align:left` are left; those without it (Ordered Quantity, both Segmentation cols, and the five flags) inherit the `lm` default and render **right** (confirmed in the screenshot).

| # | Header (displayName) | Source (Cognos → JDE, §3.5) | Align | Format |
|---|---|---|---|---|
| 1 | Company Code | company (F0010 `CCCO`) via branch→company | left | text (`00020`) |
| 2 | Company Name | company (F0010 `CCNAME`) | left | text |
| 3 | Branch Plant | `ORGANIZATION_ID` = F0006 `MCU` (order's branch, `SDMCU`) | left | text (`AUBA`) |
| 4 | Freight Handling Code | `FREIGHT_HANDLING_CODE_` = `SDFRTH` | left | text |
| 5 | Order Number | `SDDOCO` | left | text/string — no separator, **string sort** (§4.2) |
| 6 | Ordered Quantity | `SUM(ORDERED_QTY·SALES_FACTOR)` = `SUM(SDUORG/10000)` | **right** | `#,##0` |
| 7 | 2nd Item Number | `SDLITM` | left | text |
| 8 | Sold To Customer Code | sold-to `SDAN8` | left | integer/text |
| 9 | Sold To Customer Name | sold-to `F0101.ABALPH` | left | text |
| 10 | Ship To Customer Code | **= Sold To Code** (Cognos quirk §6.1) | left | integer/text |
| 11 | Ship To Customer Name | **= Sold To Name** (Cognos quirk §6.1) | left | text |
| 12 | Customer Segmentation | ship-to AC06 code (`F0101.ABAC06`) | **right** | text (`DO/BR/PL/GD`) |
| 13 | Customer Segmentation Description | AC06 description (F0005 `00/06` decode) | **right** | text |
| 14 | **Order Date** (`label=`) | = **525 Date** (earliest 525 event) | left | date `m/d/yy` |
| 15 | **Confirmation Date** (`label=`) | = **540 Date** (earliest 540 event) | left | date `m/d/yy` |
| 16 | Shipped Date | Orders `SHIPPED_DATE` = `SDADDJ`? (ship date; §8) | left | date `m/d/yy` |
| 17 | Requested Date | Orders `REQUESTED_DATE` = `SDDRQJ` | left | date `m/d/yy` |
| 18 | Goal | flag (§3.6) | **right** | integer `0` |
| 19 | Stretch | flag | **right** | `0` |
| 20 | >48h | flag | **right** | `0` |
| 21 | <72h | flag | **right** | `0` |
| 22 | >72h | flag | **right** | `0` |

> **displayName renames needed in PBIR** (query column internal name → header): the two `label=` overrides — the 525-date column must read **`Order Date`** and the 540-date column **`Confirmation Date`** (XML line 17). Every other header equals its data-item name, so no rename. **No duplicate header names** → no dup-`nativeQueryRef` render trap. Keep the header strings `>48h`, `<72h`, `>72h` verbatim.

**Date format:** all five date columns use `<dateFormat dateStyle="short"/>` with **no `displayOrder`** → month-first short. The screenshot renders `6/1/26`, `6/12/26`, `7/15/26` → **`m/d/yy`** (2-digit year). PBI `formatString` is VBA-style: `m/d/yy`. Keep the two ledger columns (**Order Date** = 525, **Confirmation Date** = 540) as **datetime** in the model (they carry a time component in the export — §3.1) but format `m/d/yy` so the on-report render matches (date-only) while a raw export preserves the time like Cognos. Shipped/Requested are date-only.

**Not displayed** (selected but absent from `List1`): Company Level 2 Code (Goal only), Ordered Date (filter only), Scheduled Pick Date, Revision Reason, JDE Order Line ID (join key). Carry Company Level 2 and the JDE order-line key **hidden** in the model; the rest can be dropped.

### 4.2 Sort
`<sortList>`: **Order Number asc, then 2nd Item Number asc** (XML line 122; matches the generated SQL `order by "Order_Number" asc nulls last, "C_2nd_Item_Number" asc nulls last`). Set in the visual (query omits `ORDER BY`). PBI ascending puts blanks first; none expected on these keys. **Order Number sorts as a STRING** in the export (`26001037` … `2727528` … `2733006` — i.e. `26001037 < 2733006` lexically, not numerically). Keep Order Number a **text** column (or sort-by a text key) so the row order matches Cognos; a numeric sort would reorder the whole list.

### 4.3 Grand-total footer (XML `listOverallGroup`, line 122)
One row, cells offset exactly as Cognos lays them out:

| Spans columns | Content |
|---|---|
| 1–15 (`colSpan="15"`) | static `Overall` + ` - ` + `Total` → renders **"Overall - Total"** |
| 16 (Shipped Date position) | static label **"Total Order Lines"** (right-aligned) |
| 17 (Requested Date position) | **Total(Total Line Count)** = 997 |
| 18 (Goal) | **Total(Goal)** = 706 |
| 19 (Stretch) | **Total(Stretch)** = 645 |
| 20 (>48h) | **Total(>48h)** = 187 |
| 21 (<72h) | **Total(<72h)** = 810 |
| 22 (>72h) | **Total(>72h)** = 117 |

**PBI build of the footer.** A flat `tableEx` totals row sums each numeric column **under its own column**, so the five flag totals land under Goal/Stretch/>48h/<72h/>72h automatically — matching Cognos's positions for columns 18–22. Two deviations PBI's native totals row can't avoid, both cosmetic (disclose like report 16's subtotal-label gap):
- The Cognos **"Total Order Lines" count sits under the Requested Date column** (col 17), offset from the flags. A `tableEx` total can't place a count there; supply **Total Order Lines** as a `COUNTROWS` measure shown either in a small card beside the table or as a totals-row cell (recommend a card labelled "Total Order Lines"). 
- The "Overall - Total" wording in the merged left block renders as PBI's default `Total` label.
- **Ordered Quantity (col 6) has no Cognos total** — turn its column total **off** in the `tableEx` (Cognos's footer shows nothing there). The five flags total **on**; everything else off.

### 4.4 Prompts (XML prompt page, lines 205–274)
7 prompts, 5 optional single-select dropdowns + 2 required date editboxes:

| Prompt | Param | Required | Cognos filter (XML line 40) | Populated from |
|---|---|---|---|---|
| Company Name | `Company` | no | `[Company].[Company Code] = ?Company?` (single `=`) | `Company` query, last-150-days active, ex-budget |
| Business Group Description | `BusinessGroup` | no | `[Organization RBU].[Business Group] = ?BusinessGroup?` | `Business Group` query |
| Customer Name | `Customer` | no | `[Customer Sold To].[Customer Code] = ?Customer?` | `Customer` query |
| Bulk Item | `BulkItem` | no | `[Item].[Bulk Item] = ?BulkItem?` | `Bulk Item` query |
| CSR Name | `CSR` | no | `[Customer Ship To Sales Rep].[CSR Number] = ?CSR?` | `CSR` query (all CSRs) |
| Order Start Date | `FromDate` | **yes** | `[Time Order Date].[Date] between ?FromDate? and ?ToDate?` | editbox, default today |
| Order End Date | `ToDate` | **yes** | (same `between`) | editbox, default today |

All five dropdowns are **single-select equality** (Cognos `selectValue`, no `multiSelect`), display Name and submit Code (Company: display Company Name, submit Company Code; etc.). Prompt → PBI mapping in §7.4.

---

## 5. Cognos-vs-Lilly divergence table (build follows **Cognos** everywhere)

Lilly's rewrite (`Goal and Stretch rewrite (Lilly 2026-07-10).sql`) is REFERENCE ONLY. Every divergence below resolves to the **Cognos** generated SQL. ★ = plausibly explains her wrong historical values.

| # | Aspect | **Cognos** (authoritative) | **Lilly** (reference, mistrusted) | Explains her failure? |
|---|---|---|---|---|
| 1 ★★★ | **Business-day metric endpoints** | Business days **525 → 540** (confirm → ship). SQL `Sales_Order_Ledger12.c10` on `C_540_Date` − `C_525_Date`. | Business days **Order_Date → 525** (order → confirm): `DATEDIFF(DAY, Order_Date_Business, Date525_Business) − DATEDIFF(WEEK,…)*2`, mislabeled `Business_Days_Between_525_540` (her lines 149–151). | **YES — the primary cause.** She measures a different interval, so **every** Goal/Stretch/bucket flag is wrong. |
| 2 ★ | **525-event selection** | **MIN** (earliest 525 per line), unconditional (`C5=C9`, min-window). | **MAX** 525 that is `≤ Date540` (last confirm before ship), her `Ledger525`. | Yes when a line has >1 525 event — probe 3a quantifies. |
| 3 | 540-event selection | MIN (earliest 540 per line). | MIN(540) — **agrees.** | No. |
| 4 ★ | **Weekend/business-day algorithm** | Floored-week formula w/ endpoint corrections (§3.3). | `DATEDIFF(DAY) − 2·DATEDIFF(WEEK)`. | Can differ ±1 near weekends even with the same endpoints; compounds #1. |
| 5 | Order-date weekend-adjust | none. | Adjusts `Order_Date` off `DATENAME(WEEKDAY, Date540)` — a nonsensical copy-paste (her lines 139–143). | Moot once #1 is fixed. |
| 6 ★ | **Source topology** | **Two sources**: `Orders` (F4211∪F42119) for attributes/qty/filters + `F42199` ledger for 525/540 dates, joined on order-line ID. | **F42199 only** — pulls qty (`SLUORG`), customers, dates all from the ledger. | Yes — different grain and different filters available. |
| 7 ★ | **Row-eligibility filters** | BUDGET_FACTOR<>1, CANCELLED<>'Y', ship-to AC01<>'INT', budget-detail 51210/61121, GST items, company 00024/00025 (§3.2). | **None of these** — only status 525/540, order type ∉{S5,ST}, order-date window. | Yes — her result set includes rows Cognos excludes. |
| 8 | Ship-To display | shows **Sold-To** name/code (quirk §6.1). | shows **real** ship-to (`SLSHAN`→F0101). | Cosmetic; not the number bug. |
| 9 | Company + name | Company from branch→company hierarchy; **Company Name displayed** (F0010). | `Company_Code = SLKCOO`; **no Company Name**. | Cosmetic/attribution. |
| 10 ★ | **Company Level 2 (Goal split)** | `COMPANY_HIERARCHY.COMPANY_LEVEL_02_CODE` (company-keyed). | `F0006.MCRP02` (branch-keyed). | Yes **if the two disagree** → wrong Goal flags. Probe 4c. |
| 11 | CSR | **filter-only**, not displayed. | displays CSR Number + Name. | Cosmetic. |
| 12 | Business Group | filter-only, not displayed. | displays `Business_Group`. | Cosmetic. |
| 13 | Customer Segmentation (AC06) | displays code + description. | omitted. | Cosmetic. |
| 14 | Requested / Shipped date source | from Orders (F4211). | Requested from ledger `SLDRQJ`; "Shipped" = `Date540`. | Minor. |
| 15 | Prompt cardinality | single-select `=`. | `STRING_SPLIT` multi-select. | Behavioral, not the historical bug. |
| — | Dormant order-599788 filter | `use="prohibited"` (disabled) → **absent from generated SQL** → **do NOT port**. | n/a | n/a |

**Count: 15 substantive divergences.** The failure is over-determined by #1 (wrong interval), amplified by #2/#4 (selection + formula) and #7/#10 (wrong row set + wrong Goal split). The build sidesteps all of them by porting the Cognos SQL.

---

## 6. Cognos quirks / defects to port faithfully (disclose to the business)

1. **"Ship To Customer" columns display the SOLD-TO customer.** SQL line 74 reuses `CUSTOMER_SOLD_TO` code/name (`C8`/`C9`) for both the Sold-To *and* Ship-To display columns; the screenshot confirms identical values in cols 8–9 and 10–11. The **real** ship-to (`CUSTOMER_SHIP_TO`) is used only for the AC01 intercompany filter and the AC06 segmentation — never displayed. Port: display Ship-To = Sold-To; use true ship-to (`SDSHAN`→F0101) for the AC01/AC06 logic. **Disclose** — likely a legacy modeling bug, but it's what the deployed report shows.
2. **"Order Date" column is the 525 (confirm) date; "Confirmation Date" is the 540 (ship) date.** The `label=` overrides (XML line 17) rename the two ledger dates to business-friendly-but-inverted labels. Ordered Date and true Shipped Date are separate columns (Ordered Date isn't shown; Shipped Date is col 16). Port the labels verbatim.
3. **Budget-Detail (51210/61121) and BUDGET_FACTOR<>1 filters are no-ops on ODS sales detail.** They target the DW's blended budget/GL rows; `F4211`/`F42119` contain only actual order lines (no GL account, no budget rows), so reading those tables already satisfies filters (a) and (e) of §3.2. Document the equivalence; don't invent an account column.
4. **Redundant `ORDER_TYPE_CODE <> 'ST'`** appears twice (inside the `not in (S5,ST)` and again standalone). Collapse to `SDDCTO NOT IN ('S5','ST')`.
5. **Dormant order-599788 exclusion** (`<detailFilter use="prohibited">[Order Number]='599788'`, XML line 40) is **disabled** — it does not appear in the generated SQL. Do **not** port it (the generated SQL is authoritative; same principle as report 06's disabled duplicate).
6. **No expired date ceiling** (defect C1 family): the only date bounds are the `:PQ1`/`:PQ2` prompts. No hard-coded upper literal. Report is parameterized-historical, not a broken live report.
7. **Fan-out is possible but not by design.** The join chain is intended 1:1 (one earliest-525 and one earliest-540 per line; Orders is one row per line). Verify no multiplicity leaks (probe 3) — if a line has tying earliest events or the Orders GROUP BY splits, quantities/counts inflate. Reproduce Cognos's behavior; disclose if it over-counts.
8. **The order-date window filters the JDE order date, NOT the displayed "Order Date" (525) column.** Both the Orders filter (`[Time Order Date].[Date] between ?FromDate? and ?ToDate?`) and the ledger filters (`[Sales Order Ledger].[Ordered Date] between …`) bind the **order date** (`SDTRDJ` / `SLTRDJ`). The displayed "Order Date" column is the **525 confirmation datetime** (`[Sales Order Ledger].[525 Date]`, XML line 17; final select `C13`), which can fall **outside** the window: the June run legitimately shows 4 rows / 3 orders with July 525 dates — **26001182 (×2 lines), 2727528, 2742995** — because their JDE order date is in June while their 525 confirm happened in July.

   > **Correction to the intake "THIRD finding" hypothesis.** COLLECTION_NOTES hypothesizes the displayed Order Date is `ORDER_ACTIVITY_MEASURE.ORDERED_DATE` (an order-entry timestamp) — a *different* fact from the filter. The XML/SQL say otherwise: the display is the **525 ledger date**, and `ORDER_ACTIVITY.ORDERED_DATE` is selected **only for the WHERE filter** (Orders11 `C10`) and is **never displayed**. So there is **no third "entry-timestamp" column to chase** — the July "Order Dates" are simply 525 confirmations of June-dated orders. This makes the design *simpler*, not more complex.

   Consequence for the build: **apply `FromDate`/`ToDate` to `SDTRDJ`** (order date) on the Orders side; the 525/540 event dates are whatever they are; display the 525 datetime in the "Order Date" column. Do **not** filter on the 525 column, and do **not** invent an entry-timestamp column. The un-windowed ledger extract + windowed-Orders inner join (§3.1) reproduces Cognos exactly **and includes those 4 July-525 rows** — if the rebuild drops them, the window was bound to the wrong column.

---

## 7. Proposed Power BI design

### 7.1 Routing recap
**ODS PRODDTA, single import model, native T-SQL** (§1). One table `Orders_GS`.

### 7.2 `.m` structure (`Orders_GS.m` + `Orders_GS.commented.m`)
Recommended shape — a multi-statement batch that (1) builds the earliest-525 and earliest-540 extracts into `#temp`, (2) joins them to compute the metric, (3) joins to the F4211∪F42119 order master + enrichment, emitting the 22 display columns + hidden `Company Level 2` + hidden JDE order-line key. Sent via `Value.NativeQuery(Source, "<batch>", null, [EnableFolding=false])` (batch/`#temp` ⇒ folding off, like report 14's `#lbf`). If a single folding query proves fast enough on the jumpbox, that's also acceptable — but lead with the `#temp` form given the join breadth.

Skeleton (fill JDE columns per §3.5 / probe results):
```sql
SET NOCOUNT ON;

-- @FromJul / @ToJul come from PQ params FromDate/ToDate, converted to JDE Julian:
--   (YEAR(d)-1900)*1000 + DATENAME(DAYOFYEAR,d)      [see Lilly lines 11-16 for the idiom]

-- earliest 525 event per line
SELECT SLKCOO, SLDOCO, SLDCTO, SLLNID,
       MIN(DATEADD(SECOND,(SLTDAY/10000)*3600+((SLTDAY/100)%100)*60+(SLTDAY%100),
                   CAST(DATEADD(DAY,(SLUPMJ%1000)-1,DATEFROMPARTS(1900+SLUPMJ/1000,1,1)) AS datetime2))) AS Date525  -- SLUPMJ+SLTDAY datetime (§3.1)
INTO #l525
FROM PRODDTA.F42199
WHERE SLNXTR = '525'
GROUP BY SLKCOO, SLDOCO, SLDCTO, SLLNID;
CREATE UNIQUE CLUSTERED INDEX ix5 ON #l525 (SLKCOO,SLDOCO,SLDCTO,SLLNID);

-- earliest 540 event per line
SELECT SLKCOO, SLDOCO, SLDCTO, SLLNID,
       MIN(DATEADD(SECOND,(SLTDAY/10000)*3600+((SLTDAY/100)%100)*60+(SLTDAY%100),
                   CAST(DATEADD(DAY,(SLUPMJ%1000)-1,DATEFROMPARTS(1900+SLUPMJ/1000,1,1)) AS datetime2))) AS Date540  -- SLUPMJ+SLTDAY datetime (§3.1)
INTO #l540
FROM PRODDTA.F42199
WHERE SLNXTR = '540'
GROUP BY SLKCOO, SLDOCO, SLDCTO, SLLNID;
CREATE UNIQUE CLUSTERED INDEX ix4 ON #l540 (SLKCOO,SLDOCO,SLDCTO,SLLNID);

-- lines confirmed AND shipped, with the business-day metric
SELECT a.SLKCOO, a.SLDOCO, a.SLDCTO, a.SLLNID,
       b.Date525, c.Date540,                          -- keep DATETIME for the displayed columns (export carries time)
       /* diff/dow/wkend/c10 per §3.5, computed on CAST(Date525 AS date) & CAST(Date540 AS date) */ AS BusinessDays
INTO #metric
FROM #l525 b JOIN #l540 c
  ON b.SLKCOO=c.SLKCOO AND b.SLDOCO=c.SLDOCO AND b.SLDCTO=c.SLDCTO AND b.SLLNID=c.SLLNID
CROSS APPLY (SELECT ... ) x;   -- scalar arithmetic only; safe (no per-row table lookup)

-- order master = F4211 UNION ALL F42119 (NOT EXISTS guard), filtered per §3.2, order-date window
;WITH o AS ( <F4211 ∪ F42119 with SD* filters + order-date window> )
SELECT <22 display cols>, o.CompanyLevel2, o.JDEOrderLineKey
FROM o
JOIN #metric m ON <4-part key>
LEFT JOIN PRODDTA.F0010 co ON ...
LEFT JOIN PRODDTA.F0101 st ON st.ABAN8 = o.SDAN8          -- sold-to (also the DISPLAYED ship-to, §6.1)
LEFT JOIN PRODDTA.F0101 sh ON sh.ABAN8 = o.SDSHAN         -- true ship-to: AC01 filter + AC06 segmentation
LEFT JOIN PRODCTL.F0005 seg ON seg.DRSY='01' AND seg.DRRT='06' AND seg.DRKY = sh.ABAC06   -- PRODCTL not PRODDTA (house gotcha); SYSTEM 01 not 00 (AB cat codes; 00/06 empty on ODS, probe round 1 2026-07-17)
LEFT JOIN PRODDTA.F554101 tag ON tag.IMITM = <item ITM>   -- GLOBAL_BULK_ITEM for GST exclusion
WHERE sh.ABAC01 <> 'INT'
  AND CASE WHEN ISNULL(tag.IMGBLK,'-')='-' THEN o.SDLITM ELSE tag.IMGBLK END NOT IN ('IGST','CGST','SGST','CVD','ADD')
  AND <company 00024/00025 exclusion>;
```
Notes: Julian decode `DATEADD(DAY,(j%1000)-1,DATEFROMPARTS(1900+j/1000,1,1))` (house standard); implied decimals `SDUORG/10000.0`, `SDLNID/1000.0`; `CROSS APPLY (SELECT scalar…)` for the metric is safe (no table re-scan) — it's the `OUTER APPLY`/`ROW_NUMBER` **table** re-evaluation that hangs, not a scalar CROSS APPLY. Company/company-name/company-level-2 lineage per probe (§8).

### 7.3 Model, columns, measures
- **Columns:** `summarizeBy: none` on every identifier/code (Order Number, Sold-To/Ship-To codes, Branch Plant, Freight, 2nd Item, Company Code, and the hidden JDE key). The five **flags** (Goal/Stretch/>48h/<72h/>72h) `summarizeBy: sum` so the totals row counts them; Ordered Quantity `summarizeBy: sum` but **column total OFF** in the visual (§4.3). Hide `Company Level 2` and the JDE order-line key.
- **Formats:** dates `m/d/yy`; Ordered Quantity `#,##0`; Order Number `0`; flags `0`.
- **Measures:** `Total Order Lines = COUNTROWS('Orders_GS')`; `Total Goal = SUM('Orders_GS'[Goal])`; and Stretch/>48h/<72h/>72h likewise. These feed the footer/card (§4.3).
- Auto date/time **OFF** (`__PBI_TimeIntelligenceEnabled = 0`; no LocalDateTable). Add the house **`Last Refreshed`** card (report-12 pattern).

### 7.4 Prompts → PBI (recommendation)
- **FromDate / ToDate → required PQ parameters** (Date type) interpolated into the batch as `@FromJul`/`@ToJul`. They shape the (expensive) ledger+order extraction and cannot be sliced on a displayed column (the true Ordered Date isn't displayed — cols 14/15 are the 525/540 dates). **Default:** pick a sensible window (e.g. first-of-month → today) rather than Cognos's today/today, and document it — a today/today default returns almost nothing. The captured validation run is **June 2026** (order dates from 6/1/26); use `FromDate=2026-06-01`, `ToDate=2026-06-30` to reproduce §10.
- **Company / Customer / Bulk Item → slicers** on the displayed model columns (Company Code, Sold-To Code, 2nd Item Number). Single-select in Cognos; PBI slicers can stay multi (minor divergence, note it).
- **Business Group / CSR → PQ parameters** (default null = no filter), NOT slicers. Neither is a displayed column, and adding CSR to the model grain would re-introduce the F42140 fan-out (report 15 §5.3). Interpolate optional `AND (@BusinessGroup IS NULL OR MCRP03 = @BusinessGroup)` / `AND (@CSR IS NULL OR <csr number> = @CSR)`. CSR requires the F42140 join **inside** the filter subquery only (not the grain), keyed on ship-to per §8.
- **Alternative** (if the team wants full interactivity): expose Business Group + a hidden CSR-number helper as slicers, accepting the CSR fan-out on the Other-like grain. Not recommended; note in §9.

### 7.5 Visual + PBIR authoring
- **PBIR format** (like reports 02/03/12/15/16). One page, one **flat `tableEx`** (22 columns in §4.1 order) + a **Total Order Lines** card + the **Last Refreshed** card. No matrix, no CF (this report defines none). Theme `CY24SU10.json` (copy from report 12/16).
- `displayName` renames: only the two ledger-date columns → `Order Date` / `Confirmation Date` (§4.1). Keep `>48h`/`<72h`/`>72h` literal.
- Totals row: ON for the five flags, OFF for Ordered Quantity and everything else. Sort: Order Number asc, 2nd Item asc.
- Ship the PBIP **comment-free**; keep `Orders_GS.commented.m` in the folder in parallel.
- On copy-back to the jumpbox, watch the `definition.pbir` 2.0.0↔1.0.0 skew (now usually moot — local Desktop ≥2.155 accepts 2.0.0; jumpbox may still knock it down).

---

## 8. JDE lineage — confirmed vs to-probe

**Confirmed (report 12/15 precedent + generated SQL):** F42199 = `SL*`; F4211∪F42119 = `SD*` (NOT EXISTS-guarded union); Julian decode; `/10000` qty; F0101 `ABALPH`/`ABAN8`; GST exclusion via F554101 `IMGBLK` fallback to `SDLITM`; order date `SDTRDJ`, requested `SDDRQJ`, line `SDLNID/1000`.

**Ambiguous → put in the probe plan, do not guess:**
- **Company + Company Name + Company Level 2 source.** Cognos derives Company via `ORGANIZATION.COMPANY_SID → COMPANY` (branch→company) and **Company Level 2** via `COMPANY_HIERARCHY.COMPANY_LEVEL_02_CODE` (company-keyed). JDE candidates: company from `F0006.MCCO` by branch (`SDMCU`), name from `F0010.CCNAME`; Level 2 from `F0006.MCRP02` (Lilly's guess, branch-keyed) **or** a company-level category code. **This drives the Goal split (RAME/REUR/RASI)** → HIGH priority. Probe both and confirm the values are RAME/REUR/RASI and which key reproduces the Cognos Goal totals.
- **`CANCELLED_INDICATOR` JDE definition** — likely `SDNXTR='980'` (cancelled status) or `SDCNDJ>0` (cancel date). Confirm which the DW's flag maps to.
- **`SALES_FACTOR`** — does any surviving line need a sign flip on `SDUORG`, or is it always 1 after the S5/ST + budget exclusions? Affects Ordered Quantity only.
- **Shipped Date column** — Orders `SHIPPED_DATE`. In JDE the actual ship date is `SDADDJ`; confirm vs the DW field (report 12 warned `SLADDJ`=actual ship date). Cross-check against the export.
- **CSR "Customer Ship To Sales Rep" / `SALES_REP_TYPE_9`** — Lilly used `F42140` `CMRTYPE='CSR'` joined on ship-to `CMAN8`, rep number `CMSLSM`. Report 12 probes found CSR = `CMRTYPE='CSR'` on this instance. Confirm for the CSR optional filter (low urgency — filter-only, single-select).
- **Freight Handling Code** — `SDFRTH` vs a header field; confirm against the export (values EXW/DAP seen).

---

## 9. Probe plan (run once on the jumpbox before first refresh; deliver as a probe PBIP)

Package as `PROBE\R17 Probe.pbip` (report 12/16 template — one table per block, no visuals, ORDER BY blocks use `[EnableFolding=false]`). Six categories:

1. **Column existence** — `SELECT TOP 1 *`-style existence for: F42199 `SLKCOO/SLDOCO/SLDCTO/SLLNID/SLNXTR/SLUPMJ/SLTDAY`; F4211 & F42119 `SDKCOO/SDDOCO/SDDCTO/SDLNID/SDMCU/SDAN8/SDSHAN/SDLITM/SDUORG/SDTRDJ/SDDRQJ/SDFRTH/SDADDJ/SDCNDJ`; F0006 `MCMCU/MCCO/MCRP02/MCRP03`; F0010 `CCCO/CCNAME`; F0101 `ABAN8/ABALPH/ABAC01/ABAC06`; F0005 `DRSY/DRRT/DRKY/DRDL01`; F554101 `IMITM/IMGBLK`; F42140 `CMAN8/CMRTYPE/CMSLSM`.
2. **Join drops** — for the June window: lines with a 525 event but no 540 (dropped by the inner join — expected, these never shipped); lines with 540 but no 525; ship-to `SDSHAN` with no F0101 row; branch `SDMCU` with no F0006 row; count how many Orders lines survive all §3.2 filters.
3. **Fan-out / multiplicity + SLTDAY (the key Lilly probes)** — **3a:** `#lines with >1 distinct 525 event` = `COUNT(*) FROM (… GROUP BY order,line HAVING COUNT(*)>1)` where `SLNXTR='525'` → quantifies exactly how many lines make Cognos-MIN and Lilly-MAX-≤540 diverge (divergence #2). **3b:** same for 540. **3c (SLTDAY):** confirm `SLTDAY` is populated and in `HHMMSS` integer form (e.g. `MIN/MAX(SLTDAY)`, `%` distribution), and that same-day 525 lines actually carry differing times (proves the datetime reconstruction matters for ordering, per §3.1); also confirm `date(MIN(datetime)) = MIN(date)` (should always hold — the counts are invariant). **3d:** verify Orders↔#metric is 1:1 (no line appears twice).
4. **Code decodes + lineage** — **4a:** distinct `SLNXTR` values present (confirm 525 & 540 exist with volume). **4b:** distinct order types surviving (confirm S5/ST excluded). **4c (HIGH):** Company Level 2 values via both candidate sources (`F0006.MCRP02` by branch **and** the company-keyed hierarchy) — are they RAME/REUR/RASI, and which reproduces the Goal split? **4d:** AC01 values (is 'INT' present and excluded?); AC06 segmentation codes (DO/BR/PL/GD…) and their F0005 descriptions. **4e (order-date window check):** for orders **26001182 / 2727528 / 2742995** (June order-date lines whose displayed 525 date is July — §6.8), confirm `SDTRDJ` (JDE order date) decodes into **Jun 1–30** and the 525 datetime into July → proves the window binds `SDTRDJ` and these lines are correctly **included** in the Jun 1–30 run. No hunt for a separate "entry-timestamp" column — the display is the 525 date (XML-proven).
5. **Count parity (validation)** — reproduce the **June-2026** run (`FromDate=2026-06-01`, `ToDate=2026-06-30`) and compare to §10: **997 lines, Goal 706, Stretch 645, >48h 187, <72h 810, >72h 117.** Tight-capture rule doesn't bite here (order-date window is fixed, not `sysdate`-relative) — but the underlying ledger can still gain late 540 events, so capture the Cognos re-run and the PBI refresh close together if the totals don't tie exactly.
6. **Format / metric spot-checks** — decode sanity: business-day values in a sane range (0…~30); the worked rows from §3.4 (order 26001039 → c10=3, Goal 0/>48h 1; order 26001051 → c10=4, >72h 1) reproduce exactly; Ordered Quantity magnitudes (`/10000`, e.g. 21,720 / 21,960 / 10,000 seen); dates decode month-first; the offset footer totals land in the right columns.

---

## 10. Validation target (June-2026 run, `Intake\Cognos export June run (2026-07-16).xlsx`, sheet `Page1_1`)

- **Prompt range CONFIRMED (Zack): `FromDate = 2026-06-01`, `ToDate = 2026-06-30`** (both 12:00 AM). Reproduce with exactly these.
- **997 order lines** (rows 1–2 blank/title, row 3 header, rows 4–1000 = the 997 detail rows, then the `Overall - Total` row, then a page-footer artifact row with the run date/time serial).
- Grand totals: **Total Order Lines 997 · Total Goal 706 · Total Stretch 645 · Total >48h 187 · Total <72h 810 · Total >72h 117.**
- Internal-consistency checks (all pass): `Stretch(645) ⊆ <72h(810)`; `<72h(810) + >48h(187) = 997`; `>72h(117) ⊆ >48h(187)`; `Goal(706) ≥ Stretch(645)`.
- The run is **company 00020 / branch AUBA** (Michelman International Belgium; Company Level 2 = **REUR** → Goal threshold ≤2 business days). JDE order dates 6/1–6/30; note the displayed "Order Date" (525) column can read July on 3 orders (§6.8) — expected, not a filter miss.
- Sort is **Order Number as STRING** (§4.2). Header row and per-cell formats in the xlsx are the authoritative format reference (dates `m/d/yy`; the 525/540 serials carry a time fraction — §3.1; Ordered Quantity `#,##0`).
- **Not sysdate-relative** → the order-date window is fixed, so this target is stable. The only moving part is late 540 events landing in the ledger between the export and a later PBI refresh; if the totals don't tie exactly, re-capture Cognos and refresh PBI close together (tight-capture).

---

## 11. Open questions for Zack / team

1. **Failed-validation story (nice-to-have).** §5 pins the cause on Lilly's wrong metric interval (order→confirm vs confirm→ship) from first principles. Confirm with Lilly/team if the specific wrong values match that diagnosis — but the build doesn't depend on it (it ports Cognos).
2. **Company Level 2 source (HIGH — drives Goal).** F0006 `MCRP02` by branch (Lilly) vs the company-keyed hierarchy (Cognos). Probe 4c decides; if they disagree, the Cognos source wins and Lilly's Goal flags were wrong for a second reason.
3. **`CANCELLED_INDICATOR` JDE mapping** — `SDNXTR='980'` vs `SDCNDJ>0` vs other. Probe/confirm.
4. **Prompts: PQ parameters vs slicers, and single- vs multi-select.** §7.4 recommends dates + Business Group + CSR as PQ params, Company/Customer/Bulk Item as (multi-select) slicers. Confirm the interactivity trade-off. Also confirm the **default date window** (recommend first-of-month→today, not Cognos's today/today).
5. **Ship-To-shows-Sold-To quirk (§6.1).** Port verbatim (recommended, deployed parity) or "fix" to show the real ship-to? Fixing diverges from the live report.
6. **Footer layout deviations (§4.3).** PBI can't offset "Total Order Lines" under the Requested-Date column or render "Overall - Total"; recommend a card + a totals row on the five flags. Acceptable?
7. **Ordered Quantity `SALES_FACTOR` sign** and **Shipped Date field** — confirm via probe/export (§8).
8. **Rendered export is a single date window (June).** Consider capturing a second window to validate the metric across a weekend boundary (e.g. a line that confirms Friday, ships Monday → c10=1) so the business-day edge cases are exercised, not just same-week lines.

---

## §12 Probe findings — 2026-07-17 (rounds 1-2, jumpbox refreshed, read via MCP)

**Validated (row-level, vs same-day Cognos export of 998 detail rows):**
- Ledger datetime reconstruction (SLUPMJ+SLTDAY) ties Cognos **to the second** — 949/998 rows match on (order, 525-datetime, 540-datetime) exactly (export shows some .999ms artifacts; round half-up to seconds when comparing).
- **Business-day formula: 0 mismatches** on Stretch / >48h / <72h / >72h across all 949 matched rows. §3.5 port is correct.
- Segmentation decode = **UDC 01/06** (address-book cat codes are system 01; 00/06 is empty on ODS). All 7 codes decode to the export's descriptions exactly. F0005 lives in **PRODCTL**, not PRODDTA.
- No join drops (F0101/F0006 100% hit rate); SLTDAY populated on 9.92M of 9.92M ledger rows.

**RESOLVED — Company Level 2 (§8 risk #10, was the gate):** F0006 MCRP02/MCRP03 are EMPTY on ODS both branch-keyed and company-BU-keyed (round 2 probed the zero-stripped company key too). Replaced with a **company-keyed CASE decode, derived empirically from the export's Goal flags** (clean threshold separation on 949 rows): 00010→RAME (≤1), 00020→REUR (≤2), 00030/00035→RASI (≤2), 00034→RASI (region prior; its matched rows were all ≤1-and-Goal=1 so 1-vs-2 is unproven for China). Applied to Orders_GS (.m + TMDL) and probes 12/14. DISCLOSE: a new JDE company requires extending the CASE.

**OPEN #1 — event-selection rule (49 rows):** for lines with multiple 525/540 events, Cognos picks a **different (later) event than our MIN** — e.g. 2708703 (Cognos 525 = 6/25 13:13, 1 min before its 540; ours = 5/29), 26001181 (Cognos 525 = 6/23 03:20:49 batch stamp; ours = 6/22 15:53), 26001153 (Cognos 540 LATER than our MIN 540). Evidence points at last-not-first (Lilly's construct may have been right after all, contra §5 divergence #2); the 03:20:4x / 05:51:36 clusters look like nightly JDE batch ledger rows. Probe 15 (per-line MIN/MAX/count per status, 91 mismatch orders) decides: if Cognos-picked == MAX everywhere → flip #l525/#l540 MIN→MAX; if intermediate values appear → last-≤-540 construct.
**OPEN #2 — +66 extra lines (53 orders, probe ⊇ export, no shorts):** we emit lines Cognos lacks (e.g. 2715940: 26 vs 22; whole orders 2728566/2726950/2729283 absent from Cognos). Not dup-4-part-keys (0 involved), not order type alone (111 S4 + 4 SA), all companies affected, bd mostly 0-2. Probe 15's current-status/qty/src columns test the exclusion hypotheses (later-cancelled, zero-qty, re-statused, purged-only).

**Probe hygiene:** answered probes 01-11+13 moved to `PROBE\retired\` (no VCS — restore by moving back + re-adding the two model.tmdl refs). Live probe set = 12 (count parity, expect Goal≈706 now), 14 (final keys re-dump), 15 (event rules). MCP DAX read caps at 100 rows — chunk 14/15 via `MOD(VALUE([order_number]) + INT([line_number]*1000), 13)`.

### §12.1 Round 3 (2026-07-17 ~12:11) — probe 15 read out, state saved pre-compact

**Data saved to `PROBE\captured 2026-07-17\`**: `probe14_final_keys_round2.csv` (1,064 rows: order, line, type, company, bd, min-525, min-540) and `probe15_event_rules_round3.csv` (468 rows: per (line,status) event_count/min/max + cur_next/cur_last status + src F4211/F42119 + qty, for the 91 mismatch orders). Fresh Cognos capture filed as `Intake\Cognos export June run (2026-07-17 fresh capture).xlsx` (**998 detail rows; totals 706/645/188/810/118** — supersedes §10's 997-row targets for comparisons vs today's probes). Probe 12 after the company-CASE fix: 1064 lines / **Goal 770** / Stretch 712 / 191 / 873 / 124 — Goal works; residual vs Cognos = the 66 extras.

**Round-3 observations (probe 15):**
1. **Daily ~5:50 AM batch 540 rows accumulate on lines sitting at next-status 540** — e.g. 2713483 line 2: 129 `540` events 6/5→7/17, cur status 540/535 (pick confirmed, never shipped). Several such 540/535 lines are among the 66 extras (2724545, 2724561, 2724579, 2724711, 2724198, 2724233, 2724217, 2727125, 2726966, 2727933…). BUT cur-540 lines with **cur_last 900** (26001182 ln4/5, 2727477, 2727932) ARE in Cognos, dated at our MIN-540 — so "exclude lines still at 540" is NOT the rule; the discriminator is finer (probably which program/transaction wrote the ledger row).
2. **3:20/3:46 AM stamps are real F42199 events** (nightly JDE batch), and Cognos sometimes picks an event that is neither our MIN nor the MAX (26001181 525: Cognos 6/23 03:20:49, ours 6/22 15:53:56, max 6/24 03:46:24; 26001153 540 likewise intermediate). Selection rule NOT resolvable from min/max aggregates.
3. **Fractional line numbers (x.001/x.01/x.1, cur_last 912/924/984) have zero 525/540 events** → never in either side; not the extras.
4. Extras include fully-completed lines too (999/620 — e.g. 2726950 whole order, 2715940 lines 19-26), so no single current-status rule explains them. 2715940's extra lines have near-identical event shapes to its included lines — **check Cognos render-DISTINCT collapse** (identical display rows dedup, house gotcha) for the same-order extras: compare full display-column tuples, not just dates.

**NEXT STEPS (in order):**
1. Local (no jumpbox): test render-DISTINCT hypothesis — for orders where probe has more lines than export (esp. 2715940 26v22, 2726950 3v0, 2722060/2722153/2713312 3v1), build the full Cognos display tuple (item, qty, dates, flags) from probe data + export and check if export row set == DISTINCT(probe row set). If yes for most, the 66 shrinks dramatically.
2. Design probe 16 "Event Detail": FULL F42199 row dump (SLLTTR, SLNXTR, SLUPMJ+SLTDAY datetime, **SLPID program id**, SLUSER, SLJOBN) for ~15 exemplar lines: 26001181 ln1 (525 intermediate), 26001153 ln3 (540 intermediate), 2708703 ln1 (525≈max), 26001182 ln4 (min-540, in Cognos, 540/900), 2724711 ln1 + 2713483 ln2 (extras, 540/535 daily-batch), 2726950 ln1-3 + 2715940 ln17vs19 (extras, completed), 2727544 ln1. Goal: identify which program's rows Cognos/DW selects (real transaction P4205-style vs nightly batch) → derive the exact reproducible rule.
3. If the rule proves DW-ETL-history-dependent (unreproducible from ODS), decision for Dave: accept 949/998 exact + principled first-event rule, disclose the ~5% + extras as legacy-DW nightly-snapshot artifacts.
4. Production PBIP already carries: PRODCTL.F0005 + UDC 01/06 + company-CASE Level 2. First refresh still HELD pending the event-rule decision (may flip MIN→other construct).

### §12.2 Step-1 results (2026-07-17, local analysis of captured CSVs vs fresh export) + probe 16 authored

**Export column mapping (for all future compare scripts):** export **Order Date** = our MIN-525 event datetime (order-entry; carries .999ms artifacts), export **Confirmation Date** = our MIN-540 event datetime, export **Shipped Date** = SDADDJ (date-only, separate field — production already sources it from SDADDJ, no gap), Requested Date = SDDRQJ (date-only). The Goal/Stretch metric runs Order→Confirmation (525→540), confirming §3.5. Date-only matcher on (Order Date, Confirmation Date) rounded half-up to seconds reproduces the known **949/998 matched**.

**Hypotheses killed:**
1. **Render-DISTINCT collapse: DEAD as the main explanation.** Partial display tuple (qty, d525, d540) per order: only 3 orders / 4 extra lines are even collapse-*candidates* (26001138 14→12, 2721404 2→1, 2713502 5→4); the other 62 extras have MORE distinct tuples than the export has rows — they are genuinely absent lines, not merged ones.
2. **Batch-timestamp exclusion: DEAD as a timestamp rule.** Batch signatures (hourly :50:0x, 3:01 PM, 3:20/3:46 AM, 5:51 AM) on d540 hit **26% of MATCHED lines** (246/949) vs 34% of unmatched — no separation. Cognos includes plenty of lines whose confirmation datetime is a batch stamp (e.g. 2710964 ln1 d540=:50:08, 2711439 ln1 d540=3:01 PM, both matched). If a program-level rule exists it is not recoverable from timestamps alone.

**Extras profile (115 unmatched probe lines = 66 true extras + ~49 event-selection mismatches):** all current statuses represented — 999/620 (73), 999/900 (58), 999/980 (24), 540/535 (17), 540/900 (5) — so no current-status rule either. Within extras, d540 tends to be order-constant (order-level confirmation events). 2715940: matched greedily = lines 1–22, extras = 23–26 (display tuples near-identical; which four are "extra" is arbitrary).

**Probe 16 "Event Detail" AUTHORED + lint-clean (4 tables load via ConnectFolder):** (readout below in §12.3; note the `26001059` cohort label in the probe SQL says "whole order absent" — that was wrong, it's a 6v5 partial and IS in Cognos) full F42199 dump (all statuses; SLLTTR/SLNXTR, event datetime + raw UPMJ/TDAY, **SLPID/SLUSER/SLJOBN**) for 24 exemplar lines across three labeled cohorts (`cohort` column in output): CTRL (26001037 ln1 clean; 2710964 ln1 + 2711439 ln1 batch-stamp-but-matched; 2715940 ln17/18), MISMATCH (26001181 ln1, 26001153 ln3, 2708703 ln1, 26001182 ln4/5, 2727544 ln1), EXTRA (2724711 ln1, 2713483 ln1/2, 2726950 ln1-3, 2715940 ln23/26, 26001059 ln1, 2722060 ln1-3, 2728566 ln1). Decision logic on readout: (a) if Cognos-picked events share a distinct SLPID/SLJOBN (interactive program) vs batch rows → port as PID-filtered MIN; (b) if extras' events are PID-indistinguishable from controls' → exclusion is DW-ETL-history-dependent → step 3 escalation to Dave. Expected ~400-600 rows → chunk MCP reads via MOD on line/upmj. **Next jumpbox cycle: refresh R17 probe (now 4 tables: 12/14/15/16).**

### §12.3 Round 4 (2026-07-17 PM) — probe 16 readout: mystery decomposed, event rule declared irreproducible, probe 17 authored

Probe 16 refreshed on jumpbox and read via MCP (795 rows / 24 lines / 16 distinct SLPIDs; key extracts saved to `PROBE\captured 2026-07-17\probe16_*.csv`).

**Program landscape (F42199 SLPID):** normal lines write `EP42101` (interactive order entry, real user) + an `R42750` echo ~3s later for (x,525); confirmations come from `ER42565` (invoice print — both interactive users and hourly `SCHED` runs at :50:0x / 3:01 PM, which is why batch *timestamps* don't discriminate) plus `EP42117/8`, `EP42101`. **`ER42950` (batch repricing, user=SCHED, nightly ~3:20+3:46 AM) re-stamps each open line's CURRENT (last,next) status pair daily** — it wrote 344 of the 412 (x,540) rows in the sample. These echoes are what our MIN sometimes picks up and what Cognos sometimes picks instead of the real event.

**The 66 "extra lines" decompose into four causes (three now proven):**
1. **RULE A — canceled lines (~24):** lines with `SDLTTR=980` (canceled; incl. next=999 closed-after-cancel) are excluded by Cognos. Our WHERE only excludes `SDNXTR='980'`. → **production fix candidate: also exclude `SDLTTR='980'`** (or the Cognos original's equivalent — re-check §5 for how the original filters cancels).
2. **RULE B — Cognos list GROUPs + SUMS (~10-15):** the Cognos list aggregates identical display tuples and **SUMS Ordered Quantity** (NOT simple DISTINCT). Proven: 2722060 export = 1 row qty 9500 = SUM of 3 lines (1+5+4=10 drums × 950); 2722153 = 1 row 35150 = SUM(10+7+20=37 × 950). Same-order collapses (2715940 26→22, 26001138 14→12, 2713502 5→4, 2721404 2→1…) are this. NOT an exclusion — quantities aggregate. Match/validate at the display-tuple level with qty summed.
3. **RULE C — capture-time drift (≥2):** lines whose first (x,540) event postdates the Cognos run are absent (no Confirmation yet): 26001200 (first 540 = 7/17 2:17 PM, export ran 11:26 AM), 26001232 ln2 (525 at 11:42). Self-heals; tight capture handles it.
4. **UNEXPLAINED (~20 lines):** the 6/22-23 cluster — consecutive orders 2726799…2727160 (+2718961, 2724200, 2727910/11/30/32/33 bulk-water ~44t) — single-line S4 orders, many entered and invoice-printed within seconds-to-minutes (e.g. 2726950 entry 3:47:56 PM, ER42565 3:48:29 PM), completed 999/620-900, absolutely absent from Cognos while lookalike neighbors **2726914/2726915 ARE in Cognos**. No ledger/event/timestamp discriminator exists. → **probe 17 "Line Attrs" AUTHORED + lint-clean (5 tables)**: F4211∪F42119 attribute dump (SDLNTY line type, SDAEXP ext amount — zero-dollar/no-charge suspicion, F4201 SHHOLD hold code, sold/ship ABAC01+ABAT1+AC06, IMGBLK, branch) for the 21 absent + 5 control orders. Next jumpbox refresh answers it.

**OPEN #1 (event-selection) — VERDICT: DW-ETL-history-dependent, NOT exactly reproducible from ODS.** Cognos's picks are inconsistent under every closed-form rule tried (MIN, MAX, last-before-progression, last-before-first-ETL-frozen, first/last-of-batch-day — each fits some exemplars, fails others): 26001181 ord = 2nd-day 3:20:49 echo while 26001153 ord = true first entry despite a same-day echo; 2727544/26001153 conf = next-morning 3:20/5:51 echo while 2708703/26001181 conf = the real ER42565. Mechanically it's the legacy DW's nightly incremental capture (~3:25-3:50 AM window) interacting with ER42950 echoes and status regressions.
**Impact quantified (fresh export, 998 rows): 949 exact + 12 date-different-but-flags-identical + 37 rows (3.7%) with flag differences.** Structure of the 37: a consecutive RAME block (2723942-2724781, entered Thu/Fri 6/18-19, confirmed Mon 6/22) where Cognos picked the Tue 3:20 AM echo → its bd = ours+1 (Cognos reports these as Goal-misses; our real-event pick says they hit goal); 26001181 (echo pick makes Cognos bd better: 2 vs our 3); 2708703 (re-entered order: Cognos bd 0, ours 19); 2726914/15 (Cognos conf predates our earliest 540 event — investigate w/ probe 17 controls). **Recommendation for Dave: keep the principled first-real-event (MIN) rule, disclose the 3.7% as legacy-DW nightly-batch artifacts — in the flagged block our numbers are arguably more correct (Cognos penalizes Fri-entry orders one extra day via its overnight capture).**

**NEXT:** (1) jumpbox refresh R17 probe (5 tables) → read probe 17 → decide the cluster rule; (2) apply RULE A (SDLTTR 980) to production + probes 12/14 after confirming against Cognos original's filter; (3) then production first refresh → tight capture (match at display-tuple level w/ qty summed, half-up seconds, expect ~96% exact + known deltas) → workbook; (4) Dave decision note on the 3.7%.

### §12.4 Round 5 (2026-07-17 PM) — probe 17 readout: cluster closed as DW artifact; RULE A applied to production

**Probe 17 "Line Attrs" readout (jumpbox refresh, 47 rows):** NO attribute discriminates the absent 6/22-23 cluster from its in-Cognos controls — same branch (CIN2/CINC), same customer categories (sold/ship AC01 = PPG/CSG, AT1 = C), no hold codes, no GST blocks, real nonzero extended amounts, plain S line types (plus normal FS billable-freight and .001/.01/.1 fractional companions). Clincher from the flags analysis: controls 2726914/2726915 display a Cognos confirmation of 6/23 (bd=1) but their EARLIEST F42199 (x,540) event is 6/24 — Cognos's own confirmation timestamp doesn't exist in the ledger. **Verdict: the cluster is the same legacy-DW nightly-capture artifact family as the 37 flag-delta rows — fold into the disclosure, no reproducible filter exists.** The absent-lines disclosure total ≈ 20 lines (~2% of 1,064) + their event-pick cousins.

**RULE A APPLIED (production + probes12/14, all lint-clean):** `AND o.SDLTTR <> '980'` added beside `SDNXTR <> '980'` (SDLTTR added to both union arms). Basis: Cognos generated SQL filters `ORDER_ACTIVITY.CANCELLED_INDICATOR<>'Y'`, which round-4 evidence shows also covers post-completion cancels (999/980) — ~24 of our former extras; clean confirming cases 2713312 ln1/2 (excluded, ln3 shown), 2726897 ln1, 2726949 ln1 (excluded; their sibling lines present). Commented master documents it.

**STATE: probe cycles COMPLETE. Production PBIP is UNBLOCKED for first refresh** (carries: PRODCTL.F0005, UDC 01/06, company-CASE Level 2, SDLTTR-980 exclusion). Expected first-refresh parity vs a same-time Cognos capture: ~96% of rows exact to the second; residuals = ~37 event-pick flag deltas (±1 bd, mostly Cognos-worse-than-reality on Fri-entered RAME) + ~20 DW-absent lines we correctly include + GROUP/SUM display collapses (match at display-tuple level with qty summed) + live drift. Then: tight capture → report-out workbook (include the Dave note on the 3.7%) → publish.

### §12.5 Workbook readout (2026-07-17 tight capture 13:12/13:17) — NEW DEFECT: Ordered Quantity unit basis; probes 18-20 authored

**Workbook agent results** (deliverable: `Cognos Reports\Excel Validation\_report_out\17 - Orders within Goal and Stretch.xlsx`, STANDARD layout, live formulas, verified via Excel COM full recalc):
- **998/998 Cognos rows matched a PBI row — 0 unclassified.** Residual-class reconciliation over the 1,026 grouped tuples: 168 fully exact, 758 qty-units, 50 event-pick, 22 ship-drift (PBI Shipped=2026-07-17 not yet in the nightly legacy DW), 28 dw-absent (PBI-only; refresh 13:12 predates capture 13:17 so not new-order drift).
- Footer ties both sides: Cognos 998/706/645/188/810/118; PBI 1041/753/695/189/852/122.
- Per-column FALSE counts = exactly the residuals; all 12 identity/text columns 100% TRUE.

**THE DEFECT (rebuild-side, NOT a legacy-DW artifact): Ordered Quantity basis.** 825/998 rows differ because Cognos `Ordered_Quantity = SUM(ORDERED_QTY × SALES_FACTOR)` is **sales weight**, while our §5 mapping `SDUORG/10000` is **order units (drums)**. Per-row ratio = the item's SALES_FACTOR (950/1000/480 kg-per-drum; 2.205 = kg→lb on some items). Only 173 factor-1 items tie. This was §8's open question ("assume factor=1") — the export proves the assumption wrong. Also retro-explains §12.3 RULE B exemplars (2722060: 9500 = 10 drums × 950).

**Probe round 5 authored (probe = 8 tables, lint-clean) — find SALES_FACTOR's JDE source:**
- **18 Qty Basis** — F4101 × F41002 (item-specific UOM conversions: UMITM/UMUM/UMRUM/UMCONV, conv = UMCONV/10^7) for the **500 distinct 2nd items** in the refreshed production model (list pulled live via DAX, embedded as IN-list).
- **19 Item Weights** — F4101 IMITWT (raw + /10^4) + IMWTUM + IMUOM1 for the same items (alternate source if the factor is the item-master unit weight).
- **20 Std UOM Conv** — F41003 full dump (standard non-item conversions; where a 2.205 KG→LB would live).
- Validation plan: per item, Cognos ratio (from workbook) vs F41002 conv for (uom_from = order UOM, uom_to = KG or LB) and vs IMITWT — whichever reproduces all 500 wins; then production gets `SDUORG/10000 × factor` + the RULE B GROUP BY in one edit round.

**Two production changes now pending (apply together, one jumpbox round): (1) SALES_FACTOR on Ordered Quantity [needs probe 18-20 verdict], (2) RULE B group-and-sum to Cognos display grain [team parity mandate — approved in principle, awaiting user go].** Workbook will need a rebuild after both. Publish HELD.

**§12.5 amendment (jumpbox round-5 attempt 1):** 19/20 errored — this ODS's `PRODDTA.F4101` has no `IMITWT`/`IMWTUM` and `F41003` has no `UB*` columns (guessed names wrong; tables themselves exist — errors were column-level). Both rewritten schema-agnostically with the `FOR JSON PATH` row-dump trick (19 = item2nd + RowJson for the 500 items; 20 = TOP 1000 RowJson of F41003); column names get decoded locally after refresh. 18 Qty Basis (F41002 `UM*` names) did not appear in the error dialog — presumed loaded; dialog said "3 queries blocked" vs 2 errors listed, so watch for a third error on the re-run. Probe re-lints clean (8 tables).

### §12.6 Round 6 (2026-07-17 PM) — probe 18-20 readout: SALES_FACTOR SOURCED, qty fix applied to production

Jumpbox refresh succeeded (18 = 4,606 conv rows / 486 items, 19 = 500 item JSON, 20 = 59 F41003 rows). Probe 18's `UM*` names were correct — no third error. Read via MCP DAX; observed per-item ratios extracted from the workbook Comparison sheet (Excel COM: Cognos qty col 6 ÷ PBI qty col 53, 998 rows).

**VERDICT — SALES_FACTOR = `F41002.UMCONV / 10⁷`, converting the LINE's transaction UOM (`SDUOM`) → the item's PRIMARY UOM (`IMUOM1` from F4101); factor = 1 when `SDUOM = IMUOM1`.** Cognos `Ordered_Quantity` is in the item **primary UOM** (KG or LB for weight items, EA for count items) — not a fixed weight. Coverage: **975/998 observed ratios reproduced** by an F41002 to-primary conv (or 1). The 23 residuals are NOT counter-evidence: 18 = EA-primary items (`DP680.S-B1`/`Q4310A.S-B1`/`DPV9000.S-B1`, true factor 1, the 0.05 ratios are RULE-B group/sum noise in the workbook); 2 = items absent from probe 18's 500-item snapshot (`MDU2012B.E-TO` ratio 1000, `ME59240.C-OP` ratio 200 — match siblings' `TO:1000`/`DR:200`); 3 = large-qty mixed/partial RULE-B groups. **Probes 19 (item weight) and 20 (F41003) are MOOT** — the factor is item-specific F41002, not item-master weight nor standard conv. Why per-line and not per-item: the 21 "inconsistent-ratio" items swing 1↔pack-factor because the same item is sometimes ordered in KG (=primary→1) and sometimes in a pack UOM — so the fix MUST key on the line's `SDUOM`, not the item alone.

**PRODUCTION FIX APPLIED (Orders_GS.m + .commented.m, 2026-07-17):** added `SDUOM` through the #ord pipeline (both union arms + projection); added `LEFT JOIN F4101 im ON im.IMITM = o.SDITM` (primary UOM) and `LEFT JOIN F41002 uom ON UMITM=SDITM AND UMUM=SDUOM AND UMRUM=IMUOM1` (forward pack→primary lookup, validated by probe 18's uom_to=primary filter); `[Ordered Quantity]` now `(SDUORG/10000.0) * CASE WHEN SDUOM=IMUOM1 THEN 1 ELSE ISNULL(UMCONV/10⁷,1) END`. Not yet refreshed on the jumpbox.

**RULE B group-and-sum APPLIED (user go 2026-07-17, all 3 artifacts):** the final SELECT is now wrapped as a derived table `g` with an outer `GROUP BY` over all 22 display columns + hidden `[Company Level 2]`, `SUM(g.[Ordered Quantity])` (the factored qty) and `MIN(g.[JDE Order Line ID])` (representative key; `STRING_AGG` avoided — unproven on this ODS, no prior repo use). This collapses output to Cognos's display grain, so it ALSO corrects the row-count and flag totals: the per-line model overcounted (PBI footer was 1041/753/… vs Cognos 998/706/…) because multi-line display tuples repeated each flag; grouping makes `Total Order Lines = COUNTROWS` and `SUM(flag)` tie to Cognos's grouped 998/706/645/188/810/118. **No model measure/column changes needed** — the 24-column schema is unchanged; `[JDE Order Line ID]` stays text (now a MIN), Ordered Quantity stays `summarizeBy: sum` with column-total OFF.

**STATE: both production changes (SALES_FACTOR + RULE B) applied to Orders_GS .m/.commented.m/.tmdl, not yet refreshed. NEXT: jumpbox refresh of the production PBIP → tight capture (Cognos re-run + PBI refresh minutes apart) → expect near-1:1 now (qty basis + grain both fixed; residuals = the ~37 event-pick flag deltas + ~20 DW-absent lines, both disclosed) → rebuild report-out workbook (Dave note on the 3.7%) → publish. Publish HELD until that capture passes.**

### §12.7 Round 7 (2026-07-17 PM) — first production refresh: qty FAN-OUT caught + fixed (F41002 dedup)

First production refresh done on jumpbox; fresh Cognos export `Downloads\Orders within Goal and Stretch (3).xlsx` (Page1_1, **998 data rows, NO total row** — data-only export; totals computed by summing). Tight capture via MCP DAX (production port 52619) vs export:

| | Rows | Goal | Stretch | >48h | <72h | >72h | **Ordered Qty** |
|---|---|---|---|---|---|---|---|
| **Cognos** | 998 | 706 | 645 | 188 | 810 | 118 | **4,560,879** |
| **PBI (fanned)** | 1026 | 740 | 682 | 187 | 839 | 121 | **10,522,835** |

**Flags/rows validate as expected** (PBI ⊇ Cognos: 1026 = 998 matched + 28 PBI-only dw-absent; Goal +34 etc = the disclosed extras). **BUT Ordered Qty was 2.3× inflated → NEW DEFECT: F41002 fan-out.** Per-row qty was correct (workbook proved it), yet the SUM doubled because `LEFT JOIN PRODDTA.F41002` returns **up to 18 rows per (item, from-UOM, to-UOM)** on this ODS (branch/historical dups — 872 of 1048 triples duplicated, probe-18 model confirmed). RULE B's `GROUP BY` dedups the identical fanned display rows (so row count stayed sane) but `SUM(Ordered Quantity)` multiplied each affected line by its multiplicity. F4101 (`im`) is clean (probe 19 = 500 items → 500 rows, IMITM unique); the fan is entirely F41002.

**FIX APPLIED (all 3 artifacts):** materialize a deduped **`#uom`** temp = `SELECT UMITM, TRIM(UMUM), TRIM(UMRUM), MAX(UMCONV) FROM F41002 WHERE EXISTS(#ord item) GROUP BY UMITM,UMUM,UMRUM` (unique-indexed on the triple), and repoint the final join to `#uom` instead of raw F41002. Foldable `GROUP BY` (no per-row eval, no OUTER APPLY hang). `MAX(UMCONV)` is lossless for 1025/1048 triples; only 23 have >1 distinct conv (branch/historical variants — negligible, within disclosed residuals). **Needs a re-refresh.** Expected after: Ordered Qty total ≈ Cognos 4.56M + the ~28 dw-absent lines' qty; flags unchanged. Then tight capture → workbook → publish. HELD.


### 12.8 Model simplification (2026-07-21) - logic to DAX, prompts to slicers

User directive: "mental ownership" + "make the model very simple". Applied after the 2026-07-21 tight capture PASSED (sec 12.7 fix verified: 971/1,003 qty-exact, -0.31%,
workbook rebuilt + recalc-verified 165 tagged FALSE).

1. FLAGS AND BUSINESS DAYS MOVED TO DAX. New hidden calc column [Business Days]
   (exact floored-week formula; WEEKDAY(..,2); TRUNC toward zero = T-SQL int division)
   + the 5 flags as one-line DAX calc columns. Verified 0 diffs vs the SQL CASEs on all
   1,030 rows BEFORE the swap (test columns side-by-side, SUMX(ABS(diff))=0 per flag);
   totals after swap identical (1030/740/682/191/839/125). Total * measures rebound by
   name. SQL CASEs + CROSS APPLY business-day block removed from the partition.
2. PROMPTS RETIRED. FromDate/ToDate/BusinessGroup/CSR PQ parameters deleted
   (expressions.tmdl removed, PBI_QueryOrder trimmed). Import window = rolling 365 days
   on SDTRDJ. Three new fetch columns: [Order Entry Date] (SDTRDJ decoded),
   [Business Group] (MCRP03), [CSR Name] (#csr = MIN(CMSLSM) per ship-to where
   CMRTYPE='CSR', deduped one-row-per-CMAN8 -> cannot fan out; F0111.WWMLNM name).
   All three enter the final SELECT as MIN() aggregates - the RULE B display grain is
   UNCHANGED (not in GROUP BY).
3. PAGE: slicer row re-flowed to 6 (Company/Customer/Item at w=195 + new Business
   Group dropdown, CSR dropdown, Order Entry Date Between slicer). New visuals
   e004/e005/e006. No default date range set (shows full rolling year until picked).
4. TOOLING GOTCHA: MCP partition Update is hard-blocked while the table state is
   Incomplete (empty errorMessage, instant fail; Calculate refresh does NOT clear it).
   The DAX swap was applied live (worked); partition/params/columns/slicers were file
   edits with Desktop closed. Lint clean after (2 tables / 7 measures).
5. VALIDATION CONTRACT: after the next jumpbox FULL refresh (also fixes the stale
   Last Refreshed stamp), filter Order Entry Date to 2026-06-01..06-30 and the totals
   must tie the 2026-07-21 capture: 1,030+drift / 740 / 682 / 191 / 839 / 125 (PBI-side
   numbers; Cognos matched-row equivalents 707/646/192/811/122 + extras). Row count
   UNFILTERED will be ~12x (rolling year). The workbook is unaffected (flag values
   identical; it captured the June window).
Files touched: Orders_GS.m / Orders_GS.commented.m / Orders_GS.tmdl (partition + 3 col
defs) / expressions.tmdl (deleted) / model.tmdl / pages ...a001 visuals e001-e006 /
Column Logic doc. Publish target: Michelman - Validation (Sales Order).

### 12.9 Refresh validated + Business Group retired (2026-07-21)

Jumpbox refresh of the restructured PBIP VALIDATED: June slice ties the contract
EXACTLY (1,030 / 740 / 682 / 191 / 839 / 125); 13,472 rows total spanning
2025-07-21..2026-07-21 (rolling window working). CSR Name live: 17 reps, 1,226 rows
(~9%) blank = ship-to has no F42140 CSR row.

BUSINESS GROUP RETIRED: the column came back empty on ALL rows -- expected, per the
round-2 probe result in section "RESOLVED -- Company Level 2": F0006.MCRP02/MCRP03 are
EMPTY on ODS. The Cognos prompt fed from the legacy DW [Organization RBU] hierarchy
(no populated JDE counterpart). Wiring it to MCRP03 was a rebuild mistake, caught in
validation. Disposition: slicer e004 deleted (by Zack in Desktop), column HIDDEN
(isHidden + description in TMDL) but kept in the fetch; remaining 5 slicers re-flowed
(dropdowns w=230 at x=8/246/484/722, date Between w=312 at x=960). RESURRECTION PATH:
get the Cognos prompt's dropdown value list; if values map from Branch/Company, add a
DAX SWITCH calc column + restore the slicer -- no SQL change, no jumpbox refresh.

Last Refreshed stamp: jumpbox refresh was table-only again (stamp stuck at 7/17);
fixed locally by Zack (right-click table > Refresh data -- the stamp table is pure M,
no SQL source, firewall-immune). NOTE for publish: service refresh must be refresh-ALL.

Lint clean (2 tables / 7 measures), 9 visuals parse. PUBLISH-READY pending the team's
ship-vs-chase verdict.

### 12.10 Comment exception (2026-07-21)

Zack's call: report 17 ships WITH light section comments in the partition M --
explicit exception to the repo-wide no-comments rule, in service of the mental-
ownership goal (the query self-narrates when opened in Power Query). The banners
are Rohit-safe: STEP 1..6 + FINAL ASSEMBLY, how-it-works only, no build/parity
internals. File layout now: Orders_GS.m = lightly-commented = EXACTLY the PBIP
partition (kept byte-matched from here on); Orders_GS.commented.m = heavy master
unchanged. TMDL partition swapped file-side (Desktop closed), lint clean.
Comments-only change -- no refresh needed; if Desktop prompts to apply changes on
open, the cached data is still valid.

## §12.10 Validation page (2026-07-21, reworked same day) — two plain ODS queries

New second report page **'Validation'** (page id 1700000000000000a002) for walking Rohit
through the known Cognos differences live. Design principle (Zack): no custom/hardcoded
tables — query the population, filter to the problem orders, expose the data, narrate the
story verbally. (First cut had a static 108-row mismatch snapshot + DAX pick-marker
columns; ripped out same day per Zack.)

**Top table = the production Orders_GS query itself** — no new model table. A PAGE-level
filter restricts the page to the 93 orders implicated by the 2026-07-21 workbook (81
Comparison FALSE rows + 27 RS pbi-only lines). Columns identical to the main page table.

**Bottom table = new Revision History table** — live ODS native query: EVERY F42199
ledger row (no MIN, no status filter) for the same 93 orders, hardcoded IN-list in the
SQL. Exposes the meaningful ledger fields: order/type/line, 2nd item, branch, last/next
status, reconstructed Event Datetime plus RAW SLUPMJ/SLTDAY (matches what SSMS shows),
qty (SLUORG/1e4) + UOM, ship-to, Program ID / User ID / Workstation / Originator.
Pure data — no derived/story columns.

Relationship: Orders_GS[Order Number] ↔ Revision History[Order Number], many-to-many,
single direction (Orders_GS filters history). M2M because neither side is unique at order
grain; nothing aggregates across it, display-only.

Page: title + explainer textbox, Order Number dropdown slicer (Orders_GS), Next Status
dropdown slicer PRESET to 525+540 (report-10 preset pattern — clear it for the full
stream), production-table (top), ledger table (bottom). Lint clean via MCP ConnectFolder:
3 tables / 7 measures / 1 relationship.

**Cognos comparison (added same day):** new `Cognos Capture` table = Cognos side of the
2026-07-21 export (86 rows — the 93 problem orders minus the dw-absent ones), entered as
report-side data (#table, no source, refreshes anywhere; regen via gen_cognos_capture.py
after a new capture). DAX columns on Orders_GS: `Order Date (ts)` / `Confirmation Date (ts)`
(same values, full-timestamp format — page 1's m/d/yy parity format untouched) and
`Cognos Order Date` / `Cognos Confirmation Date` (lookup by Company + Order + Item with
qty tie-break; BLANK = row absent from the Cognos export). Validation table shows PBI and
Cognos 525/540 side by side with seconds so the exact picked ledger row reads straight off
the Revision History table below. Shipped/Requested stay date-only (no time in SDADDJ/SDDRQJ).
Relationship re-keyed to hidden `Order Key` (Company|Order) both sides — JDE order numbers
are only unique per company.

**Refresh note:** `Revision History` needs a jumpbox refresh (ODS firewall); `Cognos
Capture` is source-less. Page is VISIBLE — decide ship vs hide/delete before publish.
Known pending fix NOT yet applied: Rohit's `CMCO <> '00000'` filter for the #csr join.

## §12.11 DAX Line Explorer PBIP (2026-07-21) — separate file, line-grain rebuild

Zack: the order-grain UI link on the Validation page still requires manually recognizing
which lines belong to a row; the lowest-grain relationship is what *explains* the join.
=> **new standalone PBIP** `PBIP (DAX Line Explorer)\Orders GS - Line Explorer (DAX).pbip`
that rebuilds the report's logic in DAX at LINE grain (lint clean: 3 tables / 8 measures /
1 relationship):

- **`Order Lines`** — one row per JDE line (no RULE B grouping), same eligibility filters
  as production (S5/ST, 980s both sides, rolling 365d SDTRDJ, co 24/25, INT ship-to,
  GST items — all applied in #ord). Carries TRUE ship-to (SDSHAN), current statuses,
  Source Table (F4211/F42119), factored qty (deduped #uom), CSR. Hidden `Line Key` =
  KCOO|DOCO|DCTO|LNID.
- **`Revision Ledger`** — F42199 events for those lines, **filtered to SLNXTR IN
  (525,540)** to control size (Zack's suggestion), same #ord population rebuilt in its
  own batch. Same columns as the Validation page's Revision History + Line Key.
- **Relationship: `Revision Ledger[Line Key] *:1 `Order Lines`[Line Key]`** — a clean
  many-to-one at the true grain; clicking a line shows exactly its considered events.
- **All metric logic in DAX** on Order Lines: `First 525`/`First 540` =
  MINX(RELATEDTABLE(...)) per status; `In Population` = both present (the production
  INNER JOIN semantic); `Business Days` = same floored-week formula; Goal/Stretch/>48h/
  <72h/>72h same thresholds, BLANK when not in population. Measures: Lines Loaded,
  Lines In Population, Total Goal/Stretch/>48h/<72h/>72h.
- One page "Line Explorer": Order + In Population slicers, 6 measure cards, lines table
  (top), ledger table (bottom).

**Parity caveat:** totals here are LINE-grain — expect them slightly above the production
display-grain numbers (RULE B groups identical tuples; cf. round-7's 1041/753 pre-group
vs 998/706 grouped). This file is an explainer, not a parity artifact; production PBIP
unchanged. Needs jumpbox refresh (both queries hit ODS). Ledger volume note: 525/540
events incl. nightly ER42950 echoes for lines that sat between statuses — if refresh is
heavy, tighten with a SLUPMJ window or drop echo rows (SLPID <> 'ER42950') — NOT done by
default to keep the stream faithful.

### §12.11.1 JDE Oracle source table added to Line Explorer (2026-07-21 evening)

Discovery while chasing "show Cognos's work": ODSPROD carries a linked server
**ORCJDEPD_LS** (OraOLEDB.Oracle -> CyrFlPdDBJD:1521/ORCJDEPD) = the **JDE production
Oracle** (PRODDTA/PRODCTL/PD920 schemas confirmed via all_users; NO DW_LEGACY schema
there — the legacy DW is a different Oracle DB with no SQL-side bridge; EDWPROD's linked
servers are SQL-only). DW row-set evidence therefore comes from a throwaway Cognos list
report (Sales Order Ledger subject, raw dump: 93-order IN list + June Ordered Date guard
+ Next Status in 525/540, Auto Group & Summarize = No, validated XML/SQL — no DISTINCT,
no MIN; Excel 2007 Data export).

Line Explorer gained a 4th table: **`JDE Source Ledger`** = `OPENQUERY(ORCJDEPD_LS,
PRODDTA.F42199 ...)` for the 93 validation orders, SLNXTR IN (525,540) — the SOURCE OF
RECORD one step upstream of ODS. Second `Line Key` *:1 relationship to Order Lines.
Page bottom split side-by-side: **ODS Revision Ledger (left) vs JDE Oracle F42199
(right)**, titles on. If the two panes match row-for-row (expected), replication is
proven and the legacy DW is the only divergent copy. Lint clean: 4 tables / 8 measures /
2 relationships. Refresh on jumpbox (OPENQUERY runs on ODSPROD, so the firewall path is
unchanged).

**§12.11.1 OUTCOME (same evening): JDE Source Ledger REMOVED.** Probe-first in SSMS hit
ORA-00942 on `PRODDTA.F42199`; all_tables and all_synonyms for F42199 both EMPTY for the
linked login -> ORCJDEPD_LS's credential is purpose-scoped (dictionary views + selected
schemas only, cf. WERCS_READ) and cannot read JDE sales tables. Route closed; table,
relationship, and right-half visual deleted; ODS Revision Ledger back to full width
(titles kept; table columns trimmed to Zack's set: lines = Order/First 525/First 540/
Line/Type/Item; ledger = Order/Line/Last/Next/Event Datetime). Lint clean 3 tables /
8 measures / 1 relationship. Source-of-record evidence stands on ODS (replication) +
the Cognos raw-dump export (DW side).
