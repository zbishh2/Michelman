# Report 10 — Ivan SFC2023 Forecast — BUILD

> **REDEVELOPED 2026-07-13 — Forecast page now sourced from EDW `BIQL.FactForecast_v2`**
> (per Rohit's 2026-07-09 rejection: ODS cannot derive TM Name). The ODS/F3460 sections below
> are RETIRED for the Forecast page — kept for history; the superseded query is archived as
> `Forecast (ODS F3460 - superseded 2026-07-13).m`. New design: TM Name via BIQL.TbTerritoryManager,
> item whitelist -> slicer preset (user-editable), date window -> Requested Date range slicer
> (import floor: 12 months back, no ceiling). All 12 `-- TODO verify` markers resolved by the v2 view.
> Sales History page unchanged. See the new `Forecast.m` header for full column notes.



**Cognos source:** `DW_LEGACY` Oracle data warehouse (dimensional star schema).
**Rebuild target:** **ODSPROD / PRODDTA** base JDE tables, SQL Server T-SQL — because
there is **no DW_LEGACY connection**. Every DW column is reverse-mapped to its
underlying JDE F-table field (tables below).

Two pages, two independent tables — **no relationship between them** (both are flat lists):

| Page | Table (`.m`) | JDE base | Status |
|---|---|---|---|
| Sales History | `Sales_History.m` | **F4211 ∪ F42119** (SO detail + purged history) | built; **2026-07-05 added F42119 UNION** (risk #2 — F4211 alone had decayed to ~20 rows) |
| Forecast | `Forecast.m` | **F3460** (forecast file) | **UNVALIDATED best-effort** — the Cognos export sheet is empty **because the Cognos report itself is broken**, not because of anything in this rebuild. See Status below. |

Connection for both: `Sql.Database("ODSPROD","ODS")` → `Value.NativeQuery(..., [EnableFolding=true])`.

> **Naming:** this folder is `10 - Ivan SFC2023 Forecast`, but the PBIP/PBIX are named
> **`1 - Ivan FC 2023 Forecast`**. That is expected, not a mistake. Structural twin of
> `08 - Ivan SK 2023 Forecast`; the two differ only in filter literals.

---

## Status — 2026-07-09

> **Live open-items list lives in `PARITY_TODO.md` in this folder.** This section records
> what changed and what the reader must not misread. It is not the task list.

### ⚠ THE COGNOS FORECAST REPORT HAS RETURNED ZERO ROWS SINCE 1 JULY 2026

`Generated SQL (Cognos - raw).sql:13` filters:

```sql
"INVENTORY_DEMAND_MEASURE"."REQUESTED_DATE__GREG" between
      (sysdate+0 - NUMTODSINTERVAL( EXTRACT( DAY FROM sysdate+0 ), 'DAY' ) + INTERVAL '1' DAY)
  and DATE '2026-06-30'
```

The **lower** bound is dynamic — it evaluates to the 1st of the current month. The **upper**
bound is a frozen literal, `2026-06-30`. From 2026-07-01 onward Cognos therefore asks for rows
`between 2026-07-01 and 2026-06-30`: an **empty range**. Report 08 carries the identical filter.

### The Cognos report says so itself — this is not an inference from a date range

`Ivan Reports\Ivan FC 2023 Forecast.xlsx` was exported on 2026-07-05. Its `Forecast_1` sheet
(`xl/worksheets/Sheet1.xml`) holds **exactly one cell**, `A1` — and that cell is **not blank.**
It contains the shared string:

> **`No Data Available`**

That is **Cognos's own empty-state message** (`<noDataHandler>`), printed because the Forecast
query returned nothing. On the *same export*, the `Sales History_2` sheet (`Sheet2.xml`) holds
**908** `<row>` elements. `Ivan SK 2023 Forecast.xlsx` (report 08) is identical: `A1` =
`No Data Available`, **882** Sales History rows.

**The report ran. It connected. Sales History returned 908 rows. The Forecast query returned
nothing, and Cognos said so out loud.** This closes the question of whether the empty export was a
transient failure, an export error, or a permissions problem. It was none of those — the source
report is broken, and it has been telling anyone who opened it for months.

> **Parsing trap, recorded so nobody repeats it.** The cell is:
>
> ```xml
> <c r="A1" s="1" t="s"><v>0</v></c>
> ```
>
> The style attribute `s="1"` comes **before** `t="s"`. A regex that expects `t=` immediately
> after the cell reference will not match, fall through to reading `<v>0</v>` as a *numeric* value,
> and conclude the cell holds the number `0`. Match `t="s"` **anywhere in the tag**, then look up
> `sharedStrings[v]` — here index `0`, which is `No Data Available`. (Note also that the sheet
> *parts* are capitalised `Sheet1.xml` / `Sheet2.xml`, not `sheet1.xml`.)

**Three consequences, in order of how much damage they will do if missed:**

1. **The Forecast page cannot be reconciled against Cognos today, and will never tie while the
   Cognos literal stays in the past.** Anyone who runs a side-by-side will see our page return
   rows and Cognos return none, and will conclude we broke something. **Rohit must be told this
   before he tries**, not after.
2. **The long-standing note "UNVALIDATED best-effort — export sheet is EMPTY" now has a cause.**
   It was never evidence of a problem with F3460, with our field mapping, or with our rebuild.
   The export sheet is empty because *the source report is broken*. This is a **Cognos defect**.
3. **It does not clear a single `-- TODO verify` marker.** The 12 markers in `Forecast.m` are still
   open, and the empty export still means nothing can validate them. Cause identified ≠ risk retired.

### The date ceiling in our `.m` is dynamic, and that is deliberate — this doc used to say otherwise

The Forecast-page paragraph below **used to state** that the ceiling "is the literal `'2026-06-30'`
(kept verbatim from Cognos — parity-now)". **That was wrong, and is corrected below.** The shipped
code does not do that:

- `Forecast.m:57-58` records `[end made dynamic 2026-07-05; Cognos hard-coded 2026-06-30]`.
- `Forecast.m:134-135` reads
  `b.RequestedDate >= DATEADD(DAY, 1, EOMONTH(CAST(GETDATE() AS date), -1)) AND b.RequestedDate <= EOMONTH(CAST(GETDATE() AS date))`.

So our window is "the current calendar month", both ends dynamic. **The deviation is correct.**
Copying Cognos's frozen ceiling verbatim would have shipped a page that renders zero rows forever —
parity with a defect is not parity with intent. Recording it here, in `Forecast.m:57`, and in
`PARITY_TODO.md` item 7.2 is what makes it a disclosed deviation rather than a silent one. This is
almost certainly what the PBIX page title `Forecast (This Month)` was trying to say all along.

### Still open — do not read the above as an all-clear

| Item | Why it matters | Effort |
|---|---|---|
| **`MFFQT` field name + the `/10000` scaling** (markers 3, 6, 10) | **Every quantity on the Forecast page depends on it.** If `MFFQT` is stored whole, every number is currently 10,000× too small. | ~30 min with ODSPROD/JDE access |
| **`MFDRQJ` vs `MFRQDJ`** (markers 2, 9) | The date filter *and* the Year / Month / Week columns all hang on this one field choice. | ~15 min, same query |
| **`RELOAD_KEY = 'N'` omitted** | Cognos applies `"INVENTORY_DEMAND_MEASURE"."RELOAD_KEY" = N'N'` (a filter it names `[Active Forecast Only]`). It has **no F3460 equivalent** and was omitted. This is a **conscious, recorded omission, not a silent drop** — see `Forecast.m:57`. It is *probably* ETL load-control metadata; it has never been *checked*. If it in fact distinguishes forecast **versions**, this page double-counts. Confirm with the `DW_LEGACY` owner. | 30 min + one question |
| **`Revenue Business Unit` is a placeholder** | It is a copy of `Branch Plant`. Cognos reads a genuinely distinct dimension (`ORGANIZATION_ALIAS_RBU` on `ORGANIZATION_RBU_SID`). Every row of the rendered page currently shows the wrong value. | 1–2 hrs; needs a business decision |

We do **not** have ODSPROD/JDE access, so none of the first two could be closed here.

### Changes that landed in the PBIP on 2026-07-09

**PBIP changes do not reach the PBIX.** `FINAL - for handover\1 - Ivan FC 2023 Forecast.pbix` was
inspected on 2026-07-09 and contains no `Last Refreshed` table and no `card` visual. Someone must
open `PBIP\1 - Ivan FC 2023 Forecast.pbip` in Power BI Desktop and **re-save / publish**. Until
then, **nothing below is user-visible.**

- **`Last Refreshed` table + `Last Refreshed Label` measure + a `card` visual on every page (2 of 2).**
  The M uses `DateTimeZone.FixedUtcNow()` with explicit US DST handling (switch to `-4`/EDT at the
  2nd Sunday of March 07:00 UTC, back to `-5`/EST at the 1st Sunday of November 06:00 UTC).
  `DateTime.LocalNow()` is **deliberately avoided**: it returns UTC in the Power BI Service but
  *local* time on Desktop, so a Desktop-authored stamp would jump 4–5 hours on publish.
  The stamp is refresh-**start**, not refresh-finish — Power Query does not guarantee the order in
  which queries evaluate, so it fires at some point *during* the refresh. The label therefore reads
  "Last refreshed", never "finished". Format `MMM d, yyyy h:mm:ss AM/PM`, matching the Cognos
  page-footer run-date stamp.
- **Date formats corrected to `d MMM, yyyy`** (from `dd MMM yyyy`), matching Cognos
  `<dateFormat dateStyle="medium" displayOrder="DMY"/>`. Note that it is **`displayOrder`, not
  `dateStyle`, that makes the date day-first** — and that the old `dd MMM yyyy` was wrong *twice
  over*: a leading-zero day, and a missing comma.
- **PBIP page renamed `Forecast` → `Forecast (This Month)`**, matching the already-shipped PBIX.
  Only `displayName` changed; the section's stable `name` id `f8d3f74ee81842d9a40d` is untouched,
  so this is the same page renamed, not an extra page. **The PBIP is now a clean superset of the
  PBIX.** See the twin-asymmetry note below.

### Checked and cleared — Cognos defines neither of these anywhere in 07–10

Two of Rohit's escalations on other reports were about exactly these, so record the result:

- **Conditional formatting: none.** `<namedConditionalStyles>`, `<advancedConditionalStyle>` and
  `<conditionalStyleRef>` are all **0** in `Report XML.md`. The 92 `<CSS value="…"/>` elements are
  *static* styles (the red bold header, the 1pt black border).
- **Grouping: none.** `<listGroup>` = 0, `<listGroupFooter>` = 0, `<crosstab>` = 0, `<list ` = 2.

The two flat `tableEx` visuals are therefore the **correct** rebuild, not a shortcut or an omission.
A forecast report is a natural place to expect periods across columns; there are none. Cognos carries
`Year` / `Month` / `Week` as three ordinary **row** columns.

### Twin asymmetry introduced on 2026-07-09 — an open decision, not a bug

This report's PBIP page was renamed to `Forecast (This Month)`. **Report 08's page was deliberately
left as `Forecast`, and must not be changed unilaterally.** The within-report PBIX/PBIP mismatch is
now resolved; the **cross-twin** one is not — the two PBIPs previously agreed and now do not.

Both reports filter to the current month, so `(This Month)` is an accurate label for either — and
`Forecast` matches Cognos's `<page name="Forecast">`, so 08 is literally correct too. `(This Month)`
is the honest label for the dynamic-window deviation above. **Decide once and apply symmetrically:**
either rename 08's page in both its PBIP and its PBIX, or revert this one.

### `PRODCTL.F0005` — a documentation and permissions gap

`Sales_History.m:166` joins `PRODCTL.F0005` for the country UDC decode (`DRSY='00  '`, `DRRT='CN'`),
but the file's `SOURCE:` header (line 23) names only `ODSPROD / ODS`. `PRODCTL` is a **different
schema from `PRODDTA`** — a grants list that covers `PRODDTA` alone is **insufficient** and the
refresh will fail on this join. (Reports 07/09 do name it, at `Sales_Order_Summary.m:17-18`; the
gap is specific to the two forecast reports' `Sales_History.m`.)

---

## Folding self-check (per HANDOFF §4)

| File | parens open/close | leading `WITH` | `ORDER BY` |
|---|---|---|---|
| `Sales_History.m` | 84 / 84 ✅ | none ✅ | none ✅ |
| `Forecast.m` | 75 / 75 ✅ | none ✅ | none ✅ |

Both are a single nested derived table (`FROM (SELECT …) b`) with the aggregation in
the outer `SELECT`/`GROUP BY`; PBI's `SELECT * FROM (<query>)` wrapper is legal.
Sorts are **dropped** from SQL and set in the visual (see each page).

---

## PAGE: Sales History  (`Sales_History.m`, JDE **F4211**)

**Validation target:** `Ivan Reports\Ivan FC 2023 Forecast.xlsx`, sheet
`Sales History_2` = **908 data rows, 25 columns**. Refresh timestamp column ("DATE")
in the export = 2026-07-05.

### Columns (export/render order — all red bold headers, `color:red`, 1pt black border)

| # | Header | Type | Format | Source (F4211 = `sd`) |
|---|---|---|---|---|
| 1 | Order Company | text | | `sd.SDKCOO` |
| 2 | Branch Plant | text | | `sd.SDMCU` |
| 3 | Global Bulk Item | text | | `F554101.IMGBLK` |
| 4 | Bulk Item | text | | `F554101.IMBULK` |
| 5 | 2nd Item Number | text | | `sd.SDLITM` |
| 6 | Order Number | int | | `sd.SDDOCO` |
| 7 | Next Status | text | | `sd.SDNXTR` |
| 8 | Year | int | | `DATEPART(YEAR, SDPDDJ)` |
| 9 | Month | int | | `DATEPART(MONTH, SDPDDJ)` |
| 10 | Week | int | | `DATEPART(ISO_WEEK, SDPDDJ)` |
| 11 | Promised Ship Date | date | DMY medium | `SDPDDJ` (Julian→date) |
| 12 | Ordered Quantity KGs | number | 0 dp | KG CASE on primary UOM (below) |
| 13 | Revenue Business Unit | text | | `sd.SDEMCU` |
| 14 | Customer Code | text | | `sd.SDSHAN` (ship-to A/B #) |
| 15 | Customer Name | text | | `F0101(shipto).ABALPH` |
| 16 | Global Parent | int | | `F0101(shipto).ABAN86` |
| 17 | Global Parent Name | text | | `F0101(gp).ABALPH` (ABAN8=ABAN86) |
| 18 | TM Name | text | | GTM sales rep (below) |
| 19 | Country Name | text | | `F0005` decode of `F0116.ALCTR` (00/CN) |
| 20 | **Order Number (again)** | int | | `sd.SDDOCO` — **duplicate of col 6** |
| 21 | Ordered Quantity | number | ⚠ see note | `SUM(sd.SDPQOR/10000)` |
| 22 | Ordering Unit of Measure | text | | `sd.SDUOM` (transaction UOM, e.g. `TO`) |
| 23 | Ordered Quantity LBs | number | ⚠ see note | LB CASE on primary UOM (below) |
| 24 | Open Indicator | text | | derived from next status (below) |
| 25 | DATE | datetime | General Date | `GETDATE()` — Cognos `current_timestamp`, a genuine rendered column |

> **CORRECTION (2026-07-09) — cols 12 / 21 / 23 are NOT "0 dp" in Cognos.** This table used to
> say they were. The Cognos `<dataFormat>` block on `Ordered Quantity KGs`, `Ordered Quantity`
> and `Ordered Quantity LBs` contains **only** `<dateFormat dateStyle="medium" displayOrder="DMY"/>`
> — a Cognos authoring slip that applies a *date* format to a *numeric* column — and **no
> `<numberFormat>`** at all. They therefore render at default precision: export row 1 shows
> `22045.992`. The PBIP currently applies `formatString: #,0` to all three
> (`Sales_History.tmdl:99, 167, 186`), so `22045.992` displays as `22,046`. Change those three to
> `#,0.000` (or `#,0.###`). The **Forecast** page's `#,0` is correct — those three columns *do*
> carry `<numberFormat decimalSize="0"/>`. See `PARITY_TODO.md` item 7.10.

> **`Sales_History.m:19`'s header comment is WRONG and contradicts its own SQL.** It claims the
> F42119 leg uses *"SH-prefixed aliases mapped back to the SD names"*. It does not: lines 150-160
> select `SDKCOO, SDMCU, …` from **both** legs, and the inline comment at lines 155-157 correctly
> explains why. The header is a leftover from before the `SHKCOO` failure (see risk #2). Report 08's
> header makes no such claim. Delete the parenthetical. `PARITY_TODO.md` item 7.11.

**Duplicate "Order Number":** the Cognos list prints Order Number in **two** column
positions (6 and 20). Power Query can't hold two columns with the same name, so the
`.m` emits it **once** as `[Order Number]`. In the visual, **add the `[Order Number]`
field twice** (positions 6 and 20) to match the render.

**Sort (set in the VISUAL, dropped from SQL):** `Promised Ship Date` ascending.

### KG / LB conversion (house pattern, keyed on **primary UOM** `sd.SDUOM1`, applied to `q = SUM(SDPQOR/10000)`)

```
Ordered Quantity KGs:  LB → q*0.453593   KG → q            EA → q*20   else q
Ordered Quantity LBs:  LB → q            KG → q*2.2045992   EA → q*44   else q
```
The KG→LB factor is **2.2045992** (from the DW decode), **not** `1/0.453593 = 2.204598`.
Reason: it ties EXACTLY. Export row 1 = 10000 KG → **22045.992** LB = `10000*2.2045992`.
(`1/0.453593` would give 22045.986 — wrong in the 3rd decimal.) `EA` factors (20 / 44)
are the report-09 house values and are unverified for this dataset (no EA rows in the
sample) — flagged.

### Open Indicator
`CASE WHEN SDNXTR = '999' THEN 'N' ELSE 'Y' END`. Export sample rows are next-status
999 → `N`. Assumption; see risks.

### Header colors / plaintext
Every column header: `text-align:left; font-weight:bold; color:red; border:1pt solid black`.
Numeric bodies right-aligned. No page title/notes text in the XML (bare list).

---

## PAGE: Forecast  (`Forecast.m`, JDE **F3460**)  —  ⚠ UNVALIDATED
_PBIP/PBIX page display name: **`Forecast (This Month)`** (renamed 2026-07-09; see Status).
Cognos calls it `<page name="Forecast">`._

**The export "Forecast_1" sheet holds one cell, `A1` = `No Data Available` — Cognos's own
empty-state message. The Cognos report is broken.** Its frozen `DATE '2026-06-30'` ceiling has been
below its dynamic first-of-this-month floor since 2026-07-01, so Cognos has returned zero rows for
months, and the export records Cognos saying exactly that. The `Sales History_2` sheet of the same
export carries 908 rows, so the report ran and connected. See Status, at the top.
That identifies the *cause* of the empty export; it does **not** validate this page.

There is still nothing to tie to. This page remains a **best-effort** rebuild with
**`-- TODO verify` on every uncertain field** (12 real markers in `Forecast.m`; a 13th
`grep` hit is prose inside the file's warning banner). Do **not** trust the numbers until a
human with JDE access confirms the F3460 field names, the quantity scaling, and the
enrichment derivations.

> **⚠ FIELD-NAME CORRECTION (2026-07-09).** Earlier revisions of this document — and the
> `-- TODO verify` comments inside `Forecast.m` — named the F3460 fields `FTMCU` / `FTFQT` /
> `FTDRQJ` / `FTAN8`. **That prefix is wrong.** `MF` is the correct JDE data-dictionary
> prefix for F3460 (the Forecast File); `FT` is not, and those columns **do not exist**.
> The shipped SQL has always read `MFMCU` / `MFFQT` / `MFDRQJ` / `MFAN8` / `MFITM` /
> `MFLITM` / `MFTYPF` — **the code is right; the documentation was wrong**, and the
> documentation is precisely what a JDE-side verifier will read. This file is corrected
> below. The five `.m` comments still carry the old prefix (`PARITY_TODO.md` item 7.7).
> `ft` remains the *table alias* for `PRODDTA.F3460`; only the column prefix changed.

### Columns (Report XML "Forecast" list order — red bold headers)

| # | Header | Type | Source (F3460 = alias `ft`) | Confidence |
|---|---|---|---|---|
| 1 | Company Code | text | `F0006.MCCO` of branch | ⚠ TODO |
| 2 | Branch Plant | text | `ft.MFMCU` | ok |
| 3 | Global Bulk Item | text | `F554101.IMGBLK` | ok |
| 4 | Bulk Item | text | `F554101.IMBULK` | ok |
| 5 | 2nd Item Number | text | `ft.MFLITM` | ok |
| 6 | Year | int | `DATEPART(YEAR, MFDRQJ)` | ⚠ date field |
| 7 | Month | int | `DATEPART(MONTH, MFDRQJ)` | ⚠ date field |
| 8 | Week | int | `DATEPART(ISO_WEEK, MFDRQJ)` | ⚠ date field |
| 9 | Requested Date | date (DMY) | `ft.MFDRQJ` (Julian→date) | ⚠ **TODO (`MFDRQJ` vs `MFRQDJ`)** |
| 10 | Current Forecast KG | number 0dp | KG CASE on `im.IMUOM1` | ⚠ depends on qty |
| 11 | Revenue Business Unit | text | `ft.MFMCU` (**placeholder**) | ⚠ TODO (no distinct RBU) |
| 12 | Customer Code | text | `ft.MFAN8` | ⚠ TODO |
| 13 | Customer Name | text | `F0101(cust).ABALPH` | ⚠ |
| 14 | Global Parent | int | `F0101(cust).ABAN86` | ⚠ |
| 15 | Global Parent Name | text | `F0101(gp).ABALPH` | ⚠ |
| 16 | TM Name | text | GTM rep (as Sales History) | ⚠ |
| 17 | Current Forecast | number 0dp | `SUM(ft.MFFQT)` | ⚠ **TODO field + `/10000` scaling** |
| 18 | Primary UOM | text | `im.IMUOM1` | ok |
| 19 | Current Forecast LB | number 0dp | LB CASE on `im.IMUOM1` | ⚠ depends on qty |

The three Forecast numerics **do** carry `<numberFormat decimalSize="0"/>` in Cognos, so `#,0`
(0 dp) is correct **here**. It is *not* correct on the three Sales History quantities — see the
correction under that page.

**Sort (visual):** `Requested Date` ascending.

**Branch-plant filter (FC):** `ft.MFMCU NOT IN ('CINC','CIN2')` — an **exclusion** list. Report
08/SK instead uses a *positive include* list that **contains** CINC/CIN2. The two reports genuinely
disagree about those two plants in the Cognos source; both are reproduced verbatim.

**Bulk-item whitelist (FC):** 29 literals, **17 distinct** — Cognos's own list repeats `ME91735.S`
×5, `ME92040.S` ×4, `PP236A.S` ×3, `ME91240G.S` ×3. Copied verbatim; duplicates are harmless inside
`IN (…)`. **Do not deduplicate** — that would diverge from the source. (Report 08/SK: 99 literals,
99 distinct.)

**Date window — BOTH ends dynamic (corrected 2026-07-09).** `Forecast.m:134-135` reads:

```sql
WHERE b.RequestedDate >= DATEADD(DAY, 1, EOMONTH(CAST(GETDATE() AS date), -1))
  AND b.RequestedDate <= EOMONTH(CAST(GETDATE() AS date))
```

i.e. the current calendar month. **This paragraph previously claimed the ceiling was "the literal
`'2026-06-30'` (kept verbatim from Cognos — parity-now)". That claim was false** — the code has
read `EOMONTH(GETDATE())` since 2026-07-05, as `Forecast.m:57` records. The deviation is
**deliberate and correct**: Cognos's frozen ceiling makes its own report return zero rows (see
Status). We chose a page that works over parity with a defect, and disclosed it. The page's
`(This Month)` title is the user-facing statement of exactly this.

**Revenue Business Unit is a placeholder and renders a wrong value on every row.** `ft.MFMCU`
is the branch plant, so this column is **identical to `Branch Plant`** on every row. Cognos joins a
*separate* alias `ORGANIZATION_ALIAS_RBU` on `INVENTORY_DEMAND_MEASURE.ORGANIZATION_RBU_SID` — the
DW fact carries its own RBU key, independent of the branch org. Sales History gets this right
(`sd.SDEMCU`, a real field), so within one PBIX one page's RBU is correct and the other's is a
duplicate of its neighbouring column. Pick a real source or drop the column.

---

## DW → JDE MAPPING (full)

### Sales History  (DW `ORDER_ACTIVITY` / `ORDER_ACTIVITY_MEASURES` ⇒ F4211)
| DW column | JDE field |
|---|---|
| `substr(ORDER_LINE_ID,1,5)` (Order Company) | `F4211.SDKCOO` |
| `ORGANIZATION_ID` (Branch Plant) | `F4211.SDMCU` |
| `ITEM.GLOBAL_BULK_ITEM` | `F554101.IMGBLK` (join `IMITM = SDITM`) |
| `ITEM.BULK_ITEM` | `F554101.IMBULK` |
| `ITEM_NUMBER_2ND` | `F4211.SDLITM` |
| `ORDER_NUMBER` | `F4211.SDDOCO` |
| `NEXT_STATUS` | `F4211.SDNXTR` |
| `DUE_DATE` (Promised Ship Date) | `F4211.SDPDDJ` (Julian) |
| `REVENUE_BUSINESS_UNIT` | `F4211.SDEMCU` |
| `CUSTOMER_SHIP_TO.CUSTOMER_CODE` | `F4211.SDSHAN` (= `F0101.ABAN8`) |
| `CUSTOMER_SHIP_TO.CUSTOMER_NAME` | `F0101(shipto).ABALPH` |
| `CUSTOMER_SHIP_TO.GLOBAL_REPORTING` (Global Parent) | `F0101(shipto).ABAN86` |
| `CUSTOMER(GP).CUSTOMER_NAME` | `F0101(gp).ABALPH` where `ABAN8 = ABAN86` |
| `VENDOR.MAILING_NAME` / `SALES_REP_ID` (TM Name) | GTM rep: `F0006.MCRP01`→`||'GTM'`→`F42140`(CMAN8=SDSHAN, CMRTYPE)→`CMSLSM`→`F0101.ABALPH` |
| `CATEGORY_CODES_UDC.DESCRIPTION` (Country) | `PRODCTL.F0005.DRDL01` decode of `F0116.ALCTR`, `DRSY='00  '`, `DRRT='CN'` |
| `ORDERED_QTY` (Ordered Quantity) | `SUM(F4211.SDPQOR/10000)` |
| `ORDERING_UNIT_OF_MEASURE` | `F4211.SDUOM` |
| `CONVERSION_FACTOR_KG/LB` | replaced by primary-UOM CASE on `F4211.SDUOM1` |
| `OPEN_INDICATOR` | derived: `SDNXTR='999' → 'N' else 'Y'` |
| `SALES_FACTOR` | assumed **1** (sign carried by `SDPQOR`) |
| `current_timestamp` (DATE) | `GETDATE()` |

### Forecast  (DW `INVENTORY_DEMAND` / `INVENTORY_DEMAND_MEASURES`, TABLE_TYPE `%3460%` ⇒ F3460)

Column prefixes corrected `FT*` → `MF*` on 2026-07-09; see the correction callout on the Forecast
page above. `ft` is the table alias; `MF` is the F3460 column prefix.

| DW column | JDE field |
|---|---|
| `COMPANY.COMPANY_CODE` (excl 00024/00025) | `F0006.MCCO` of branch ⚠ |
| `COMPANYBRANCH_PLANT` | `F3460.MFMCU` |
| `ITEM.GLOBAL_BULK_ITEM / BULK_ITEM / ITEM_NUMBER_2ND` | `F554101.IMGBLK / IMBULK`, `F3460.MFLITM` |
| `REQUESTED_DATE__GREG` | `F3460.MFDRQJ` (Julian) ⚠ vs `MFRQDJ` |
| `CURRENT_FORECAST` | `F3460.MFFQT` ⚠ (name + /10000 scaling) |
| `CONVERSION_FACTOR_KG/LB` | primary-UOM CASE on `F4101.IMUOM1` ⚠ (Cognos reads a stored per-row factor first) |
| `ORGANIZATION_RBU.ORGANIZATION_CODE` | `F3460.MFMCU` placeholder ⚠ — Cognos reads a **distinct** dimension |
| `CUSTOMER.*` (Code/Name/Global Parent/Name) | `F3460.MFAN8` → `F0101`(cust/gp) ⚠ |
| `VENDOR.MAILING_NAME` (TM) | GTM rep (as Sales History) |
| `UNIT_OF_MEASURE__PRIMARY` | `F4101.IMUOM1` |
| `FORECAST_TYPE='SA'` | `F3460.MFTYPF='SA'` |
| `RELOAD_KEY='N'` | **omitted** — no F3460 equivalent. A **conscious, recorded** omission (`Forecast.m:57`), not a silent drop. Corresponds to the Cognos filter `[Inventory Demand Star Schema].[Active Forecast Only]`. Likely ETL load-control metadata; **confirm with the `DW_LEGACY` owner.** If it distinguishes forecast *versions*, this page double-counts. |
| `REQUESTED_DATE__GREG between _first_of_month(sysdate) and DATE '2026-06-30'` | `MFDRQJ` between `DATEADD(DAY,1,EOMONTH(GETDATE(),-1))` and `EOMONTH(GETDATE())` — **ceiling made dynamic on purpose**; Cognos's frozen literal returns 0 rows (see Status) |

---

## ASSUMPTIONS & VALIDATION RISKS  (ranked — scrutinize top-down)

1. **[Forecast] F3460 field names + quantity scaling — HIGHEST, STILL UNVALIDATED.**
   `MFFQT` (forecast qty), `MFDRQJ` (requested/forecast date), `MFAN8` (customer),
   and whether `MFFQT` carries the 4 implied decimals (`/10000`) are all **guessed**
   from JDE-standard aliases. The empty export means nothing can confirm them — and note
   that the export is empty because the **Cognos report is broken** (Status), which explains
   the absence of evidence but supplies none. A human must open F3460 and verify.
   **If `MFFQT` is stored as whole units (common for forecasts), remove the `/10000` — every
   quantity on the page is otherwise 10,000× too small.** If the qty field is `MFAFQ`/`MFFQT2`,
   swap it. If `MFRQDJ` is the real requested date, the date filter *and* Year/Month/Week are wrong.

   One query closes most of this, no JDE UI needed:

   ```sql
   SELECT COLUMN_NAME, DATA_TYPE, NUMERIC_SCALE
   FROM   INFORMATION_SCHEMA.COLUMNS
   WHERE  TABLE_NAME = 'F3460'
   ORDER  BY ORDINAL_POSITION;

   SELECT TOP 25 MFMCU, MFITM, MFLITM, MFTYPF, MFDRQJ, MFFQT, MFAN8
   FROM   PRODDTA.F3460
   WHERE  LTRIM(RTRIM(MFTYPF)) = 'SA' AND MFFQT > 0;
   ```

   Because 08 and 10 carry **identical** marker text, one verification session closes all 24
   markers across both reports. Do it once.

2. **[Sales History] Scope: F4211 vs F42119 — ✅ RESOLVED 2026-07-05, union is IN THE CODE.**
   *Original reasoning, retained as the evidence trail:* the export includes completed lines
   (next status 999) back to Nov-2025. F4211 keeps recently closed lines until purged; older
   closed lines move to the sales-history file **F42119**. "Build F4211-only first, count, then
   decide."

   **Outcome:** F4211-only had decayed to ~20 open rows against an expected ≈908, so the union was
   added. `Sales_History.m:148-161` now reads
   `(SELECT … FROM PRODDTA.F4211 UNION ALL SELECT … FROM PRODDTA.F42119) sd`.
   Expect *near* 908, not exact — the export was a point-in-time snapshot.

   > **The `SH`-prefix guidance in the original risk was WRONG for this instance.** The first
   > refresh failed with `Invalid column name 'SHKCOO'`. On **this ODSPROD instance F42119
   > mirrors F4211 with the same `SD*` column names**, not the JDE-standard `SH` prefix
   > (corroborated by `ssasprod.bim`, whose Sales fact reads `F4211|F42119` on `SDDGL`, `SDAN8`,
   > `SDPA8`, `SDSHAN`). Both legs of the union use `SD*`. Do not "fix" them to `SH*`.
   > `Sales_History.m:19`'s header comment still repeats the old `SH` claim — it is wrong; the SQL
   > and its inline comment at lines 155-157 are right.

3. **[Sales History] `SALES_FACTOR` — the #1 DW unknown.** Assumed **1**: the DW's
   `ORDERED_QTY*CONV_KG*SALES_FACTOR>0` filter and `SUM(...*SALES_FACTOR)` are
   reproduced by `SDPQOR/10000>0` and `SUM(SDPQOR/10000)`, because F4211's `SDPQOR`
   already carries its own sign (credits/returns negative). If SALES_FACTOR is instead
   a magnitude scaler (not just a sign), KG/LB/qty totals will be off — check totals
   against the export's Ordered-Quantity column.

4. **[Sales History] `BUDGET_FACTOR <> 1` — treated as no-op.** F4211 holds only actual
   SO lines (no budget/forecast pseudo-lines), so nothing to exclude. If Michelman loads
   budget as SO lines under a special document type (`SDDCTO`), add a `SDDCTO NOT IN (...)`
   exclusion. Low-medium risk.

5. **[Sales History] Cancelled-line filter = `SDCNDJ = 0`.** Maps
   `CANCELLED_INDICATOR<>'Y'` to "no cancel date". If cancellation is tracked by status
   (e.g. next status 980) rather than `SDCNDJ`, swap. The `SDPQOR>0` filter already drops
   most netted-to-zero cancels.

6. **[Sales History] Promised Ship Date = `SDPDDJ`.** Report 09 maps `SDPDDJ` to both
   "Promised Ship Date" and "Scheduled Pick Date". Confirm the DW `DUE_DATE` is `SDPDDJ`
   and not `SDDRQJ` (requested) — the whole date filter and Year/Month/Week hang on it.

7. **[both] `Week` = `DATEPART(ISO_WEEK, …)`.** Verified for the sample (2025-11-03 → 45).
   If Cognos "Gregorian Calendar Week" uses a different week convention (US week, Sun
   start), swap to `DATEPART(WEEK, …)`. Low risk (sample matched ISO).

8. **[both] TM Name (GTM sales rep) derivation.** Reproduces report 09's
   `F0006.MCRP01 → ||'GTM' → F42140 → F0101` chain, default `'Not Available'`. Complex,
   enrichment-only (no row-count impact). Export sample rows are all `Not Available`, so
   the default path is confirmed but the populated path is not. Medium risk on values.

9. **[both] `PRODCTL.F0005` reachability + an undocumented grant.** The country decode joins
   `PRODCTL.F0005` (UDC master) at `Sales_History.m:166` — a different schema from `PRODDTA`.
   If it is a separate database (not just a schema) on ODSPROD, the two-part name will fail —
   the builder may need a three-part name or a separate query. Verify on first refresh.

   **Documentation/permissions gap (2026-07-09):** `Sales_History.m`'s `SOURCE:` header (line 23)
   names only `ODSPROD / ODS`. It does **not** name `PRODCTL.F0005`, so a reader provisioning
   access from that header alone will request `PRODDTA` grants and the refresh will fail on this
   join. **`PRODDTA` grants are insufficient.** Add `PRODCTL.F0005` to the header and to the
   handover's required-grants list. (Reports 07/09 do name it, at `Sales_Order_Summary.m:17-18` —
   the omission is specific to the two forecast reports' `Sales_History.m`.) The join itself is
   confirmed correct against Cognos
   (`CUSTOMER_SHIP_TO.COUNTRY_CODE = T8.CATEGORY_CODE and T8.UDC_TABLEFIELD = N'00,CN'`).

10. **[Sales History] "Ordered Quantity" = primary qty `SDPQOR`, not transaction
    `SDUORG`.** Chosen so Qty/KG/LB all tie on the sample (all coincide when the
    transaction UOM ↔ primary UOM ratio is 1:1, as in the `TO`/`KG` sample rows). For an
    EA-primary item ordered in cases/bags they would differ — validate on a non-KG row.

11. **[Forecast] Company Code / Revenue Business Unit derivations** (`F0006.MCCO` /
    `MFMCU` placeholder) and the **00024/00025 company exclusion** are best-guess; no way
    to validate against the empty export. The company exclusion *filter* is confirmed
    (`Generated SQL (Cognos - raw).sql:8-10` builds `COMPANY2` with
    `JDE_COMPANY__CCCO<>'00024' and <>'00025'`); what is open is whether `F0006.MCCO` uses the
    same code form (`'00024'` vs `'24'`), and that Cognos **inner**-joins it while our
    `LEFT JOIN` + `ISNULL(...,'') NOT IN (…)` *keeps* branches missing from F0006.
    RBU is not merely unvalidated — it is a **known-wrong placeholder** (see the Forecast page).

12. **[both] Cognos star joins are INNER; the `.m` uses LEFT JOIN — MED, NEEDS REVIEW.**
    Every dimension join in the generated Cognos SQL sits in the `WHERE` clause, making it an
    inner join. So Cognos *drops* a forecast line whose branch is missing from the org dim, whose
    customer has no global parent, or which has no sales rep; we keep all three. Conformed DW
    dimensions normally carry an "unknown" member row, in which case the two are equivalent —
    **verify rather than assume**: compare row counts with and without the change on Sales History
    (which *is* validatable against the 908-row export) and carry the verdict to Forecast.

---

## VALIDATION CHECKLIST

- [x] **Sales History row count ≈ 908** vs `Ivan FC 2023 Forecast.xlsx` → sheet
      `Sales History_2`. **F42119 UNION added 2026-07-05** (risk #2 — F4211-only had
      aged down to ~20 open rows). Expect near-908, not exact (export was a snapshot).
      **NOTE:** risk #2's "SH-prefixed aliases" is WRONG for this instance — the first
      refresh failed with "Invalid column name 'SHKCOO'..." F42119 here mirrors F4211
      with the **same `SD*` column names** (confirmed by `ssasprod.bim`: Sales fact =
      F4211|F42119 on `F4211/F42119.SDDGL`, `SDAN8`, `SDPA8`, `SDSHAN`). The second
      SELECT now uses `SD*` from F42119, identical to the F4211 half.
- [ ] Spot-check row 1: Order `2551748`, `SING`/`00030`, `JS168.S`, next 999, promised
      2025-11-03, **KGs 10000**, **LBs 22045.992**, UOM `TO`, Open `N`.
- [ ] `Ordered Quantity KGs` / `LBs` totals tie to the export column sums (confirms the
      SALES_FACTOR=1 and KG→LB 2.2045992 assumptions).
- [ ] Country Name populates (F0005 / PRODCTL reachable **and granted**) — risk #9.
- [ ] TM Name: confirm populated rows, not just the `Not Available` default.
- [ ] Distinct `Ordering Unit of Measure` values look like transaction UOMs (`TO`, `KG`,
      `LB`, …); if it echoes the primary UOM, `SDUOM` was the wrong field (risk #10).
- [ ] **Forecast page:** open F3460 in JDE and confirm **`MFFQT`** (name + `/10000` scaling),
      **`MFDRQJ`** (vs `MFRQDJ`), **`MFAN8`** (populated?) — there is no export to check against,
      and there never will be while the Cognos report returns 0 rows (risk #1, Status).
- [ ] **Resolve `RELOAD_KEY='N'` / `[Active Forecast Only]`** with the `DW_LEGACY` owner, then
      replace the assumption at `Forecast.m:57` with the finding.
- [ ] **Decide a real source for `Revenue Business Unit`, or drop the column** (it currently
      duplicates `Branch Plant` on every row).
- [ ] Sorts set in visuals: Sales History = Promised Ship Date asc; Forecast = Requested
      Date asc.
- [ ] Headers red-bold, 1pt black borders; dates **`d MMM, yyyy`**; Forecast numerics `#,0`;
      **Sales History `Ordered Quantity` / `KGs` / `LBs` → `#,0.000`, not `#,0`** (see the
      correction on the Sales History page).
- [ ] **Open `PBIP\1 - Ivan FC 2023 Forecast.pbip` in Power BI Desktop, re-save, publish** —
      otherwise the `Last Refreshed` card is invisible to users (Status).
- [ ] **Tell Rohit the Cognos Forecast page returns zero rows** before any reconciliation is
      attempted (Status). Zero effort; must not be skipped.
- [ ] **Finish the cross-twin page-name decision** (`Forecast` vs `Forecast (This Month)`) — this
      report was renamed; 08 was not.
- [ ] **Delete the stale `SH`-prefix parenthetical from `Sales_History.m:19`** (it contradicts its
      own SQL).

---

## SEE ALSO

`PARITY_TODO.md` in this folder carries the live, prioritised open-items list, the full
`-- TODO verify` marker table with line numbers, and the twin-divergence analysis against
report 08. This file records *how the thing was built and why*; that file records *what is
still owed*.
