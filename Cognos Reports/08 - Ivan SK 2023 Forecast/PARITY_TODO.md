# Parity TODO — 08 - Ivan SK 2023 Forecast
_Source of truth: PBIP. Structural twin of `10 - Ivan SFC2023 Forecast`._

## Status — 2026-07-10 review verdict: Forecast page REJECTED, Sales History ACCEPTED

Reviewer feedback (2026-07-10) supersedes parity-now for the **Forecast page only**:

- **Forecast page needs redevelopment.** Stated reason: ODS has no logic to derive TM Name (Cognos
  populates it from DW_LEGACY `VENDOR_ALIAS_TM`). This is the failure mode already predicted by marker 12
  below — the F42140 GTM chain hangs on `MFAN8`. Source options, in preference order:
  - **Option 1 — Forecast Perspective.** Check with Nick Bubash and Jim; Jim may need to add Customer
    information to the Perspective. Nick to share the Cognos screen + required column list with Jim.
  - **Option 2 — EDW** (if Perspective will take longer). Coordinate with Nick / Dave for the TM Name and
    other enrichment-column logic.
- **Rebuild requirements regardless of source:** (a) the date filter becomes a user prompt/slicer — users
  currently edit the Cognos date filter each month (the item 7.2 hard-coded-ceiling behavior); (b) the
  item filter becomes a prompt **preselected to the current whitelist** and user-editable (replaces the
  99-entry hard-coded `IN (…)` list).
- **Sales History page accepted** ("looks good"). Retest it once the Forecast page is rebuilt, and use the
  SAME item-filter selection mechanism on both pages.
- Consequence: the section-6 `-- TODO verify` F3460 field-mapping work is **moot if the page is re-sourced**
  from Perspective or EDW — do not spend the ODSPROD verification effort until the source decision lands.

## Status — 2026-07-09

**Read this first: the forecast data-layer risks in section 6 and items 7.1–7.6 are all still open.** The
only thing that changed on 2026-07-09 was the addition of a "last refreshed" timestamp. `Forecast.m` is
unchanged and remains an **unvalidated, best-effort** rebuild.

**And: the timestamp is in the PBIP only — it is not in the PBIX.**
`FINAL - for handover\1 - Ivan SK 2023 Forecast.pbix` was opened and inspected on 2026-07-09: it contains
no `Last Refreshed` table and no `card` visual. Someone must open
`PBIP\1 - Ivan SK 2023 Forecast.pbip` in Power BI Desktop and re-save / publish before any user sees this.

What shipped into the PBIP (each row checked against the file, not taken on report):

| Change | Location | Verified |
|---|---|---|
| `Last Refreshed` table — a single-row `#table` computing US Eastern time from `DateTimeZone.FixedUtcNow()` | `…SemanticModel/definition/tables/Last Refreshed.tmdl` | Yes |
| Columns `Last Refreshed` (`formatString: MMM d, yyyy h:mm:ss AM/PM`) and `Time Zone` (`EDT` / `EST`) | same file | Yes |
| Measure `Last Refreshed Label` | same file | Yes |
| Registered in the model — `ref table 'Last Refreshed'` plus an entry in `PBI_QueryOrder` | `…SemanticModel/definition/model.tmdl` | Yes |
| A `card` visual bound to that measure on **every page — 2 of 2** (`x=8, y=4, 300×34`, above the table at `y=42`) | `…Report/report.json` | Yes |
| Model still loads | MCP `ConnectFolder` → 4 tables, 1 measure, 0 relationships | Yes |
| `report.json` re-parses and all 13 nested `config` / `filters` / `query` payloads are still JSON-encoded strings | `…Report/report.json` | Yes |

Three things to state accurately when handing this over:

- **It is a refresh-*start* stamp, not a completion stamp.** Power Query does not guarantee the order in
  which queries evaluate, so `DateTimeZone.FixedUtcNow()` fires at some point during the refresh, not at
  the end of it. The label deliberately reads "Last refreshed", not "finished". Do not describe it to
  users as a completion time.
- **`DateTime.LocalNow()` is deliberately not used.** It returns UTC in the Power BI Service but local
  time on Power BI Desktop, so a Desktop-authored stamp would shift by 4–5 hours the moment it is
  published. The partition instead derives the Eastern offset explicitly, switching to `-4` (EDT) at the
  2nd Sunday of March 07:00 UTC and back to `-5` (EST) at the 1st Sunday of November 06:00 UTC. Those are
  the current US rules, hard-coded; if the rules change, the `.m` needs one edit.
- **The stamp renders month-first (`Jul 9, 2026 3:04:12 PM`) while `Requested Date` and `Promised Ship
  Date` render day-first (`9 Jul, 2026`, per Cognos `dateStyle="medium" displayOrder="DMY"`).** The
  month-first choice was made to match Cognos's rendered page-footer run-date. That footer does not appear
  in `Report XML.md` — Cognos generates it at render time — so the justification could not be confirmed
  from anything in this repo. Cosmetic; change the column's `formatString` if a reviewer objects.

Deliberately **not** changed, and therefore still open below: `Forecast.m` (12 `-- TODO verify` markers,
5 of which survive into `Query Exports for Rohit\08 - Ivan SK 2023 Forecast\Forecast.txt`), the
`Revenue Business Unit` placeholder, the dynamic date ceiling, the `RELOAD_KEY` omission, the LEFT-vs-INNER
joins, the `formatString: #,0` on the three Sales History quantities, auto date/time
(`__PBI_TimeIntelligenceEnabled = 1`, plus the orphan `DateTableTemplate_*.tmdl` — both still present), the
`FT*` → `MF*` documentation errors, and the missing `PRODCTL.F0005` `SOURCE:` header. Each was re-checked
against the files on 2026-07-09 and each is unchanged. Date formats were already corrected repo-wide to
`d MMM, yyyy` before this build; that is not new work.

**One new twin asymmetry, introduced deliberately in 10 and not mirrored here.** Report 10's PBIP page was
renamed `Forecast (This Month)` so that its PBIP matches its own PBIX. This report's PBIP and PBIX both
still say `Forecast`. The twins' PBIPs, which previously agreed, now disagree. That is a real change of
state for item 9.5 — the cross-twin naming decision is **still open**, it has just moved. See 9.5.

## Summary

The visual layer is a faithful rebuild: Cognos ships two flat `<list>` visuals with zero conditional
formatting, zero grouping, zero subtotals and zero prompts, and the PBIP reproduces both as flat
`tableEx` visuals with matching column order, matching ascending sorts, and totals switched off.
Sections 1–5 below are therefore genuinely **N/A**, not gaps.

The risk in this report is entirely in the **data layer of the Forecast page**, which was reverse-mapped
from the `DW_LEGACY` Oracle warehouse onto JDE `PRODDTA.F3460` with no connection to the original and an
empty validation export. Twelve `-- TODO verify` markers remain — all twelve still present as of
2026-07-09. Beyond those, this audit found four substantive issues the markers do not cover: the Cognos
`RELOAD_KEY='N'` filter was omitted (a conscious choice, recorded in the code at `Forecast.m:59` — not a
silent drop, but not a verified one either); `Revenue Business Unit` is a placeholder copy of `Branch
Plant` where Cognos reads a genuinely distinct dimension; the Cognos date ceiling was changed from a hard
literal to a dynamic month-end (which is why the export is empty and why this page can never tie to Cognos
as it stands); and every star-schema join Cognos performs as an INNER join is a LEFT join here.

The F42119 union **is present** in this report's `Sales_History.m` — no data-loss bug. `BUILD.md` has not
been updated to say so, and still instructs the reader to build F4211-only first.

---

## 1. Conditional formatting

**None in Cognos — nothing to port.** Verified, not assumed.

| Check | Cognos `Report XML.md` | PBIP `report.json` |
|---|---|---|
| `<namedConditionalStyles>` | 0 | — |
| `<advancedConditionalStyle>` | 0 | — |
| `<conditionalStyleRef>` | 0 | — |
| `FillRule` / `Conditional` / `backColor` | — | 0 / 0 / 0 |

The 92 `<CSS value="…"/>` elements in the XML are all **static** styles (`text-align`, `border:1pt solid
black`, and `font-weight:bold;color:red` on every `listColumnTitle`). The PBIP's only two `fontColor`
occurrences are the static red bold column-header style on each visual
(`singleVisual.objects.columnHeaders[0].properties.fontColor = '#FF0000'`, `bold = true`), which
correctly reproduces the Cognos header CSS. No action.

## 2. Grouped lists rendered as flat tables

**None in Cognos — nothing to port.** Verified.

`<listGroup>` = 0, `<listGroupFooter>` = 0, `<crosstab>` = 0, `<list ` = 2. Both Cognos visuals are flat
detail lists. The PBIP has exactly 2 pages, each with one `visualType: "tableEx"`. Flat-to-flat is the
**correct** rebuild here; converting either to a `pivotTable` would be a regression.

Note for the handover conversation: a forecast report is a natural place to expect periods across
columns, and there are none. Cognos carries `Year` / `Month` / `Week` as three ordinary **row** columns
(list columns 6–8), not as a crosstab axis. There is no crosstab to miss.

## 3. Subtotals / summary rows

**None in Cognos — nothing to port.** `<listGroupFooter>` = 0, `<summary>` = 0, `<overallFooter>` = 0,
`<listFooter>` = 0. Correspondingly both PBIP visuals set
`singleVisual.objects.total[0].properties.totals = false`. Match.

Do not be misled by the 5 `aggregate="total"` data items in the XML (`Current Forecast KG`,
`Current Forecast LB`, `Ordered Quantity`, `Ordered Quantity KGs`, `Ordered Quantity LBs`). In Cognos
that attribute is the **query rollup** that drives the `GROUP BY`, not a rendered footer row. It is
reproduced by the `GROUP BY` in each `.m`. Confirmed against `Generated SQL (Cognos - raw).sql`: the
Forecast block groups by 16 keys and the `.m` groups by the same 16; the Sales History block groups by
20 keys and the `.m` groups by the same 20.

## 4. Sort order

**Match.** No action.

| Page | Cognos | PBIP `prototypeQuery.OrderBy` |
|---|---|---|
| Forecast | `<sortItem refDataItem="Requested Date"/>` | `Requested Date`, `Direction: 1` (asc) |
| Sales History | `<sortItem refDataItem="Promised Ship Date"/>` | `Promised Ship Date`, `Direction: 1` (asc) |

Report 08's `<sortItem>` elements omit the `sortOrder` attribute (Cognos defaults to ascending); report
10's carry `sortOrder="ascending"` explicitly. Same effective sort — cosmetic XML difference only.
Both `.m` files correctly omit `ORDER BY` so the native query keeps folding; the sort lives in the visual.

## 5. Prompts / parameters

**None in Cognos — nothing to port.** `<promptPage>` = 0, `<parameter>` = 0, `<selectValue>` = 0. Every
filter is a hard-coded literal, and the PBIP correspondingly has no slicers, no report-level filters, no
page-level filters and no visual-level filters (`report.filters`, `section.filters` and `visualContainer.filters`
are all empty).

One consequence worth stating explicitly for the handover: because there is no date prompt, the Cognos
report's date window is frozen in the report definition. See item 7.2.

## 6. UNVALIDATED forecast rebuild — open `-- TODO verify` items

`Forecast.m` is a best-effort reverse-mapping of `DW_LEGACY.INVENTORY_DEMAND` (`TABLE_TYPE like '%3460%'`,
`FORECAST_TYPE='SA'`) onto `PRODDTA.F3460`. The validation export sheet `Forecast_1` in
`Ivan Reports\Ivan SK 2023 Forecast.xlsx` is empty (`A1:A1`), so nothing ties this page to anything.

`grep -c -- '-- TODO verify'` returns **13**, but one hit (line 18) is prose inside the warning banner,
not a marker. There are **12 real markers**: 7 in the DW→JDE field-map comment block and 5 inline in the
SQL. Line numbers below are for `08 - Ivan SK 2023 Forecast/Forecast.m`; the twin's line numbers are in
parentheses.

> **Read this before working the table.** The markers name the F3460 fields as `FTFQT`, `FTDRQJ`, `FTAN8`
> — but the SQL beside them reads `MFFQT`, `MFDRQJ`, `MFAN8`. `MF` is the correct JDE data-dictionary
> prefix for F3460 (the Forecast File); `FT` is not. **The code is right and the comments/BUILD.md are
> wrong.** Anyone taking the markers literally will look up columns that do not exist. See item 7.7.

| # | Marker | Line (08 / 10) | What it assumes | How to confirm or refute |
|---|---|---|---|---|
| 1 | Company Code source (map) | 35 (33) | `COMPANY.COMPANY_CODE` ≡ `F0006.MCCO` of the branch plant | **Shape already confirmed** by `Generated SQL (Cognos - raw).sql:11,13`: Cognos joins the forecast's org SID → `ORGANIZATION` → `COMPANY2.COMPANY_SID`, i.e. the company **of the branch**. What is still open is whether `F0006.MCCO` equals the DW's `JDE_COMPANY__CCCO`. Run `SELECT DISTINCT MCMCU, MCCO FROM PRODDTA.F0006 WHERE MCMCU IN ('AUBA','AUB2','SING','SNG4','MUM3','SHAN','CINC','CIN2','CIN4')` and compare to the JDE Business Unit master (P0006). |
| 2 | `Requested Date` = `MFDRQJ` (map) | 40 (38) | `REQUESTED_DATE__GREG` ≡ `MFDRQJ`, not `MFRQDJ` | `SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'F3460'` — see which of `MFDRQJ` / `MFRQDJ` exists. If both, compare distributions against the JDE forecast revisions screen (P3460). Year/Month/Week (list cols 6–8) and the whole date filter hang on this field. |
| 3 | `Current Forecast` = `sum(MFFQT)` + `/10000` (map) | 41 (39) | Forecast qty field is `MFFQT`, stored with 4 implied decimals | Two questions. **Name:** confirm `MFFQT` exists (query above); candidates if not are `MFAFQ` / `MFFQT2`. **Scaling:** `SELECT TOP 50 MFFQT FROM PRODDTA.F3460 WHERE LTRIM(RTRIM(MFTYPF))='SA' AND MFFQT>0` and eyeball the magnitude against a known forecast line in P3460. Authoritative check: read the display-decimals of data item `FQT` in the JDE data dictionary (`F9210`/`F9860`). **If `MFFQT` is stored whole, delete the `/10000` — every quantity on this page is currently 10,000× too small.** |
| 4 | `Revenue Business Unit` placeholder (map) | 44 (42) | F3460 has no distinct RBU, so `MFMCU` (the branch) is used | **Refuted as a faithful mapping.** `Generated SQL (Cognos - raw).sql:13` joins a *separate* alias `ORGANIZATION_ALIAS_RBU` on `INVENTORY_DEMAND_MEASURE.ORGANIZATION_RBU_SID` — the DW fact carries its own RBU key, independent of the branch org. As shipped, `Revenue Business Unit` is **identical to `Branch Plant` on every row**. Decide a real source (customer's `F03012`, a `F0006` category code on the branch, or the sales-order RBU) or drop the column. See item 7.3. |
| 5 | `Customer Code` = `MFAN8` populated (map) | 45 (43) | The forecast's address number is the customer | `SELECT COUNT(*), SUM(CASE WHEN MFAN8 = 0 THEN 1 ELSE 0 END) FROM PRODDTA.F3460 WHERE LTRIM(RTRIM(MFTYPF))='SA'`. If `MFAN8` is mostly zero, this page's Customer Code / Name / Global Parent / Global Parent Name / TM Name columns are all empty and the mapping is wrong. Cognos reads `INVENTORY_DEMAND_MEASURE.INVENTORY_DEMAND__CUSTOM_SID → CUSTOMER3`. |
| 6 | `CURRENT_FORECAST > 0` → `MFFQT > 0` (map) | 58 (56) | Sign survives the `/10000` scaling | Follows from marker 3. `x/10000 > 0 ⟺ x > 0`, so the predicate is safe **regardless** of the scaling answer. Resolve marker 3 and this one closes with it. Low risk. |
| 7 | Company exclusion `00024`/`00025` (map) | 66 (62) | The DW's company exclusion maps to `F0006.MCCO` | **The filter itself is confirmed**: `Generated SQL (Cognos - raw).sql:8-10` builds `COMPANY2` as `… where JDE_COMPANY__CCCO<>'00024' and <>'00025'` and **inner-joins** it. Two open points: (a) is `F0006.MCCO` the same code as `JDE_COMPANY__CCCO` (leading zeros, `'00024'` vs `'24'`)? Run `SELECT DISTINCT MCCO FROM PRODDTA.F0006`. (b) Cognos's inner join *drops* rows; our `LEFT JOIN` + `ISNULL(...,'') NOT IN (…)` *keeps* branches missing from F0006. See item 7.4. |
| 8 | `CompanyCode` in SQL | 106 (102) | `ISNULL(LTRIM(RTRIM(bu.MCCO)),'')` | Same as marker 7. Note the `ISNULL(…,'')` makes an unmatched branch pass the exclusion test. |
| 9 | `MFDRQJ` is the requested date, in SQL | 111 (107) | Julian → Gregorian conversion on `MFDRQJ` | Same as marker 2. The conversion arithmetic itself (`DATEADD(DAY, (j % 1000) - 1, DATEFROMPARTS(1900 + (j / 1000), 1, 1))`) is the house pattern and is already validated in `Sales_History.m` against the export — only the *field choice* is open. |
| 10 | `MFFQT` name + `/10000` in SQL | 115 (111) | `ft.MFFQT / 10000.0 AS q` | Same as marker 3. **Highest-value single check in this report** — it scales every number on the page. |
| 11 | RBU placeholder in SQL | 117 (113) | `LTRIM(RTRIM(ft.MFMCU)) AS RevBU` | Same as marker 4. |
| 12 | `MFAN8` in SQL | 118 (114) | `CAST(ft.MFAN8 AS varchar(20))` | Same as marker 5. Also drives the `F42140` GTM-rep join on line 129, so an empty `MFAN8` silently makes every `TM Name` read `'Not Available'`. |

**Fastest path to closing markers 2, 3, 5, 9, 10, 12 at once** (one query, no JDE UI needed):

```sql
SELECT COLUMN_NAME, DATA_TYPE, NUMERIC_SCALE
FROM   INFORMATION_SCHEMA.COLUMNS
WHERE  TABLE_NAME = 'F3460'
ORDER  BY ORDINAL_POSITION;

SELECT TOP 25 MFMCU, MFITM, MFLITM, MFTYPF, MFDRQJ, MFFQT, MFAN8
FROM   PRODDTA.F3460
WHERE  LTRIM(RTRIM(MFTYPF)) = 'SA' AND MFFQT > 0;
```

## 7. Other parity gaps

### 7.1 `RELOAD_KEY = 'N'` filter omitted — MED, NEEDS REVIEW, STILL OPEN
Cognos applies a named model filter `[Inventory Demand Star Schema].[Active Forecast Only]`
(`Report XML.md`, Forecast query `<detailFilter>`), which the generated SQL resolves to
`"INVENTORY_DEMAND_MEASURE"."RELOAD_KEY" = N'N'` (`Generated SQL (Cognos - raw).sql:13`).

The rebuild **omitted it, and recorded the omission in the code**: `Forecast.m:59` reads
`// RELOAD_KEY = 'N' -> (no F3460 equivalent; omitted - document)`. This was a conscious, documented
decision, not a silent drop. What it is not, is a *checked* one.

That is probably right — `RELOAD_KEY` reads like a DW ETL housekeeping flag marking the current load,
with nothing in F3460 to correspond to. But *probably right* is not the same as *checked*, and the
failure mode is a silent duplicate-row over-count on a page nobody can validate.
**Fix:** confirm with whoever owns `DW_LEGACY` that `RELOAD_KEY` is load-control metadata, then replace
the `.m` comment with that finding instead of an assumption. If it turns out to distinguish forecast
*versions*, this page double-counts.

### 7.2 Cognos date ceiling changed from a literal to a dynamic month-end — HIGH (disclosure, not a bug)
Cognos: `[Requested Date] between _first_of_month({sysdate}+0) and 2026-06-30`.
Ours: `b.RequestedDate BETWEEN DATEADD(DAY,1,EOMONTH(GETDATE(),-1)) AND EOMONTH(GETDATE())`
(`Forecast.m:138-139`).

**Today is 2026-07-09, so the Cognos window is `2026-07-01 … 2026-06-30` — an empty range.** The Cognos
Forecast page currently returns zero rows, which is exactly why the `Forecast_1` export sheet is empty.
The rebuild quietly repaired this by making the ceiling `EOMONTH(GETDATE())`.

This is almost certainly the right behaviour, but it means **the Forecast page cannot be reconciled
against the Cognos original at all** while the original's hard-coded ceiling remains in the past. Rohit
must be told this explicitly rather than discovering that the two do not tie. Two things to fix:
- `BUILD.md:153-154` still claims *"ceiling is the literal `'2026-06-30'` (kept verbatim from Cognos —
  parity-now)"*. The shipped `.m` does not do that. Stale — correct it.
- This is very likely what report 10's PBIX page title `Forecast (This Month)` was trying to say. As of
  2026-07-09 report 10's PBIP page carries that title too; this report's does not. See item 9.5.

### 7.3 `Revenue Business Unit` is a copy of `Branch Plant` — HIGH
Covered as marker 4 above; restated here because it is a *visible, wrong value on every row of the
rendered page*, not just an unverified field name. Cognos sources this column from a distinct
`ORGANIZATION_RBU_SID` on the fact table. Sales History gets this right (`sd.SDEMCU`, a real field), so
within the same PBIX one page's RBU is correct and the other's is a duplicate of the neighbouring column.

### 7.4 Cognos star joins are INNER; the `.m` uses LEFT JOIN — MED, NEEDS REVIEW
Every dimension join in the generated Cognos SQL sits in the `WHERE` clause, making it an inner join.
On the Forecast query that is `ORGANIZATION` (branch), `COMPANY2` (the 00024/00025-filtered subquery),
`ITEM`, `TIME_OTHER_DATE`, `CUSTOMER3`, `CUSTOMER_ID`, `CUSTOMER_ALIAS_GP`, `VENDOR_ALIAS_TM` and
`ORGANIZATION_ALIAS_RBU`. `Forecast.m:126-131` LEFT-joins `F0006`, `F0101` (customer), `F0101` (global
parent), `F42140` and `F0101` (rep).

So Cognos drops a forecast line whose branch is missing from the org dim, whose customer has no global
parent, or which has no sales rep; we keep all three. On the Sales History query the same applies,
including the country UDC join (`T8`, inner) which `Sales_History.m:170` LEFT-joins.

Mitigating: conformed DW dimensions normally carry an "unknown" member row, in which case the inner
joins drop nothing and LEFT is equivalent — and `Sales_History.m:122`'s `'Not Available'` default was
observed to match blank TM rows in the export, which is consistent with that. **Verify rather than
assume:** compare row counts with and without the LEFT-vs-INNER change on Sales History (which *is*
validatable against the 881-row export) and carry the verdict over to Forecast.

### 7.5 KG / LB conversion never reads a per-row conversion factor — MED, NEEDS REVIEW
Cognos computes (`Generated SQL (Cognos - raw).sql:11`):

```
Current_Forecast_KG = sum(CURRENT_FORECAST * decode(CONVERSION_FACTOR_KG, 0,
                            decode(UNIT_OF_MEASURE__PRIMARY, 'KG', 1, 'LB', 2.2045992, 0),
                            CONVERSION_FACTOR_KG))
Current_Forecast_LB = sum(CURRENT_FORECAST * decode(CONVERSION_FACTOR_LB, 0,
                            decode(UNIT_OF_MEASURE__PRIMARY, 'LB', 1, 'KG', 0.453597189003788, 0),
                            CONVERSION_FACTOR_LB))
```

i.e. it uses a **stored per-row factor** and only falls back to a UOM `decode` when that factor is 0.
Our `.m` always takes a UOM `CASE` and never reads a stored factor. Three consequences:

1. For KG- and LB-primary rows the two agree, *provided* the stored factor is the physical one. The
   Sales History export confirms it is (`10000 KG → 22045.992 LB`), and that is the factor our `CASE`
   uses. Fine.
2. The Cognos **fallback** literals are physically inverted (it converts LB→KG by ×2.2045992 and
   KG→LB by ×0.4536 — backwards). This looks like a latent Cognos-side bug that only fires when the
   stored factor is 0. Our `CASE` is physically correct. **Do not "fix" our code to match it** without
   deciding whether parity-with-a-bug is wanted.
3. For any primary UOM that is neither KG nor LB, Cognos's fallback yields factor **0** (the row
   contributes nothing), whereas `Forecast.m:89,102` passes the raw quantity straight through, and the
   `'EA'` factors 20 / 44 are invented house values with no source. Any non-KG/LB item on this page
   produces a number that exists in neither system.

**Fix:** enumerate the distinct `im.IMUOM1` values actually returned by this query. If they are only
`KG`/`LB`, close this as N/A with evidence. If not, source the real conversion from JDE `F41002`.

### 7.6 `Ordered Quantity KGs > 0` reproduced as `SDPQOR/10000 > 0` — MED
Cognos filters on the *converted* quantity: `(ORDERED_QTY * CONVERSION_FACTOR_KG) * SALES_FACTOR > 0`
(`Generated SQL (Cognos - raw).sql`, Sales History `where`). `Sales_History.m:179` filters the raw
primary quantity instead. Where `CONVERSION_FACTOR_KG = 0` (an item with no KG conversion), Cognos
evaluates `qty * 0 * SF = 0`, which is not `> 0`, and **drops the row**; we keep it. Same root cause as
7.5 item 3. Resolve together.

### 7.7 `.m` comments and `BUILD.md` name F3460 fields with the wrong prefix — MED (correctness of the handover doc)
`BUILD.md` uses `FTMCU` / `FTFQT` / `FTDRQJ` / `FTAN8` throughout (25 `FT*` mentions: lines 128, 131–135,
137–138, 143, 150, 189, 191–192, 194–195, 210, 264 …), and the `-- TODO verify` markers inside
`Forecast.m` (lines 19, 40, 111, 115, 118) do the same. The shipped SQL uses `MFMCU` / `MFFQT` / `MFDRQJ`
/ `MFAN8` / `MFITM` / `MFLITM` / `MFTYPF`. `MF` is the correct F3460 prefix. **The code is right; the
documentation is wrong**, and the documentation is precisely what a JDE-side verifier will read.
**Fix:** rewrite `FT*` → `MF*` in `BUILD.md` and in the five `.m` comments. Zero code change.

### 7.8 `PRODCTL.F0005` is queried but appears in no `SOURCE:` header — LOW (documentation / permissions)
`Sales_History.m:170` joins `PRODCTL.F0005` for the country UDC decode (`DRSY='00  '`, `DRRT='CN'`), a
different schema from `PRODDTA`. The file's `SOURCE:` header (line 26) names only `ODSPROD / ODS`.
`BUILD.md` risk #9 flags reachability but no `SOURCE:` header lists `PRODCTL`. Confirmed correct against
Cognos (`CUSTOMER_SHIP_TO.COUNTRY_CODE = T8.CATEGORY_CODE and T8.UDC_TABLEFIELD = N'00,CN'`), so this is
a docs/permissions gap, not a logic bug. **Fix:** add `PRODCTL.F0005` to the `SOURCE:` header and to the
handover's required-grants list.

### 7.9 `BUILD.md` is stale on the F42119 union — LOW
`Sales_History.m:152-165` already unions `PRODDTA.F42119`. But `BUILD.md:26` still lists the Sales
History base as **F4211**; `BUILD.md:212-220` (risk #2) still says *"Build F4211-only first, count, then
decide"* and asserts F42119 uses `SH`-prefixed aliases; and `BUILD.md:271-272` still carries the
unticked *"If short → add F42119 UNION"* checklist item. Report 10's `BUILD.md` was updated with all of
this (including the note that the `SH` prefix is wrong on this instance). **Fix:** port report 10's
`BUILD.md` corrections back into 08. See item 9.6.

### 7.10 `Ordered Quantity` / `KGs` / `LBs` display 0 decimals; Cognos does not — MED, NEEDS REVIEW
The Cognos `<dataFormat>` block on each of these three Sales History columns contains **only**
`<dateFormat dateStyle="medium" displayOrder="DMY"/>` — a Cognos authoring slip that applies a date
format to a numeric column — and, importantly, **no `<numberFormat>`**. They therefore render at default
precision (the export's row 1 shows `22045.992`). The three Forecast page numerics *do* carry
`<numberFormat decimalSize="0"/>`, so 0 decimals is correct there.

The PBIP applies `formatString: #,0` to all six
(`…SemanticModel/definition/tables/Sales_History.tmdl:99, 167, 186`), so on the Sales History page
`22045.992` displays as `22,046`. **Fix:** change those three `formatString` values to `#,0.000` (or
`#,0.###`). The Forecast page's `#,0` is correct — leave it. `BUILD.md:72,81,83` describing these three
as "0 dp" is also wrong.

### 7.11 Confirmed non-issues (do not "fix" these)
- **`Sales_History.Order Number 2`** in `report.json` is not a broken reference. `prototypeQuery.Select`
  contains `{"Name": "Sales_History.Order Number 2", "Column": {… "Property": "Order Number"}}` — a
  projection alias that renders the same column twice, correctly reproducing Cognos's duplicate
  `Order Number` at list positions 6 and 20. There is deliberately no `Order Number 2` column in the TMDL.
- **`DATE` with `formatString: General Date`** is *not* a hidden technical column. It is Cognos list
  column 25, with its own bold-red `listColumnTitle` and a right-aligned body, and it carries **no**
  `<dataFormat>` — a plain rendered `current_timestamp`. `dateTime` + `General Date` is a faithful match.
  No action.
- **`d MMM, yyyy`** on `Requested Date` / `Promised Ship Date` correctly matches Cognos's
  `<dateFormat dateStyle="medium" displayOrder="DMY"/>`. Already fixed; no action.

## 8. Model-level defects found

**Identifier columns with `summarizeBy: sum`: none.** All 19 `Forecast` columns and all 24
`Sales_History` columns carry `summarizeBy: none`, including `Order Number` (int64) and `Global Parent`
(int64), both of which also correctly use `formatString: 0` so no thousands separator appears on an
identifier. Clean in both tables. (Harmless in today's flat `tableEx`; this is what would have bitten if
anyone later converts a page to a matrix.)

| Finding | Evidence | Severity |
|---|---|---|
| Auto date/time is **on** in this model but off in the twin | `…SemanticModel/definition/model.tmdl:11` → `__PBI_TimeIntelligenceEnabled = 1`, plus an orphan `definition/tables/DateTableTemplate_13e223e7-872e-4324-a83f-c056e37bd3a0.tmdl`. Report 10 has `= 0` and no template. | MED |
| Sales History quantity format strings — see 7.10 | `Sales_History.tmdl:99, 167, 186` | MED |
| No relationships defined | `definition/relationships.tmdl` empty in both models | **Correct** — two independent flat lists, as `BUILD.md:22` intends. No action. |

**Fix for auto date/time:** set `__PBI_TimeIntelligenceEnabled = 0` and delete the `DateTableTemplate_*`
table. It silently builds a hidden date hierarchy behind every date column, bloating the model and
exposing a date hierarchy in the field list that Cognos has no concept of.

## 9. Twin divergence (08 vs 10)

`diff` of the two `Forecast.m` SQL bodies yields exactly two substantive lines; `diff` of the two
`Sales_History.m` SQL bodies yields exactly two. Everything else — column list, joins, KG/LB `CASE`,
GTM-rep chain, GST decode, `GROUP BY`, typing — is byte-identical. The rebuild's structural-twin claim
holds.

### Intentional, and faithful to each report's own Cognos XML — no action

| # | Divergence | 08 (this report) | 10 | Cognos evidence |
|---|---|---|---|---|
| 1 | Forecast branch-plant filter | `MFMCU IN ('AUBA','AUB2','SING','SNG4','MUM3','SHAN','CINC','CIN2','CIN4')` — a **positive include list that contains CINC/CIN2** | `MFMCU NOT IN ('CINC','CIN2')` | `<detailFilter>` `[Branch Plant] in (…)` vs `[Branch Plant] not in ('CINC','CIN2')`. Reproduced verbatim. |
| 2 | Bulk-item whitelist | 99 entries, 99 distinct (SK family) | 29 entries, **17 distinct** (Cognos's own list repeats `ME91735.S` ×5, `ME92040.S` ×4, `PP236A.S` ×3, `ME91240G.S` ×3) | Both copied verbatim from each XML. The duplicates are harmless inside `IN (…)`. |
| 3 | Sales History `DUE_DATE` floor | `2026-03-01` | `2025-11-01` | `[Promised Ship Date] between 2026-03-01 …` vs `… between 2025-11-01 …`. This is the main driver of 08's smaller row count. |
| 4 | `<sortItem>` attribute | no `sortOrder` (defaults ascending) | `sortOrder="ascending"` | Cosmetic XML difference; identical effective sort. |

### Unintentional — asymmetries that are themselves findings

| # | Divergence | Verdict |
|---|---|---|
| 5 | **Page name — state changed 2026-07-09, still open.** *Was:* 08's PBIX and PBIP both said `Forecast`; 10's PBIX said `Forecast (This Month)` while its PBIP said `Forecast`. *Now:* 10's PBIP was renamed to `Forecast (This Month)` to match its own PBIX (`displayName` only; the section's stable `name` id `f8d3f74ee81842d9a40d` is untouched, so 10's PBIP is a clean superset of its PBIX). 08 is untouched — PBIX and PBIP both still `Forecast`. | The within-10 mismatch is resolved. The **cross-twin** mismatch is not: the two PBIPs previously agreed and now do not. `Forecast` matches Cognos `<page name="Forecast">`, so 08 is still literally correct; `(This Month)` is the honest label for the dynamic-window deviation of item 7.2. **Decide once and apply symmetrically** — either rename 08's page (PBIP *and* PBIX) to `Forecast (This Month)`, or revert 10. STILL OPEN, NEEDS REVIEW. |
| 6 | **`BUILD.md` F42119 documentation.** 10's is current (line 12 lists `F4211 ∪ F42119`; lines 249–254 record that the `SH*` aliases failed with *"Invalid column name 'SHKCOO'"* and that F42119 mirrors F4211's `SD*` names on this instance). 08's still says F4211-only. | 08's `BUILD.md` is stale. Port 10's corrections back. Item 7.9. |
| 7 | **`Sales_History.m` header accuracy.** 10's header (line 19) claims *"F42119 (SH-prefixed aliases mapped back to the SD names)"*, contradicting its own SQL and its own inline comment. 08's header makes no such claim. | 08 is **cleaner** here. Fix 10. |
| 8 | **Auto date/time.** `= 1` here, `= 0` in 10. | 08 is the defective one. Item 8. |

### F42119 verdict for this report

**PRESENT.** `Sales_History.m:152-165` reads
`(SELECT … FROM PRODDTA.F4211 UNION ALL SELECT … FROM PRODDTA.F42119) sd`, using `SD*` column names for
**both** legs (correct for this ODSPROD instance — the `SH*` prefix from JDE-standard docs does not exist
here). No data-loss bug. Only the `BUILD.md` narrative lags.

### Re-checked after the 2026-07-09 refresh-stamp build
Both twins received the same `Last Refreshed` table, measure, `model.tmdl` registration, and a card visual
on every page with identical geometry (`x=8, y=4, w=300, h=34, z=4000`). Stripped of `lineageTag` GUIDs,
the two `Last Refreshed.tmdl` files are byte-identical. No asymmetry there.

The build **did** introduce one asymmetry, and it is row 5 above: 10's PBIP page was renamed and 08's was
not. That is deliberate on 10's side (its PBIP now matches its PBIX) but leaves the twins disagreeing at
the PBIP layer. It must be decided, not left.

## Open items checklist

- [x] Add a visible "last refreshed" timestamp to every page — **DONE 2026-07-09** — PBIP only; the PBIX still needs a Power BI Desktop re-save before users see it (see Status)
- [ ] **Verify `MFFQT` name + `/10000` scaling** (markers 3, 6, 10) — every quantity on the Forecast page depends on it — HIGH — 30 min with an ODSPROD connection
- [ ] **Verify `MFDRQJ` vs `MFRQDJ`** (markers 2, 9) — the date filter and Year/Month/Week hang on it — HIGH — 15 min (same query)
- [ ] **`Revenue Business Unit` is a duplicate of `Branch Plant`** (marker 4, item 7.3) — pick a real source or drop the column — HIGH — 1–2 hrs, needs a business decision
- [ ] **Disclose the dynamic date-ceiling deviation to Rohit** (item 7.2) — the Cognos original returns 0 rows today; the pages can never tie — HIGH — 0 effort, but must not be skipped
- [ ] **Verify `MFAN8` is populated** (markers 5, 12) — if not, five enrichment columns are silently blank — MED — 15 min (same query)
- [ ] **Resolve `RELOAD_KEY='N'` / `[Active Forecast Only]`** (item 7.1) — the omission is recorded at `Forecast.m:59`, but unverified; confirm with the `DW_LEGACY` owner that it is ETL load-control metadata, then replace the assumption in the `.m` with that finding — MED — 30 min + one question to the DW owner
- [ ] **Enumerate distinct `IMUOM1` / `SDUOM1` values; source real conversions from F41002 if any are not KG/LB** (items 7.5, 7.6) — MED — 1 hr
- [ ] **LEFT vs INNER join cardinality** (item 7.4) — test on the validatable Sales History page, carry the verdict to Forecast — MED — 1 hr
- [ ] **Fix `formatString` on `Ordered Quantity` / `KGs` / `LBs`** → `#,0.000` (item 7.10) — MED — 10 min
- [ ] **Turn off auto date/time**: `__PBI_TimeIntelligenceEnabled = 0`, delete `DateTableTemplate_*.tmdl` (item 8) — MED — 10 min
- [ ] **Rewrite `FT*` → `MF*`** in `BUILD.md` and the five `Forecast.m` comments (item 7.7) — MED — 20 min, no code change
- [ ] **Port report 10's F42119 corrections into this `BUILD.md`** (items 7.9, 9.6) — LOW — 20 min
- [ ] **Add `PRODCTL.F0005` to the `SOURCE:` header and the required-grants list** (item 7.8) — LOW — 5 min
- [ ] **Decide the `Forecast` vs `Forecast (This Month)` page name once, apply to both reports** (item 9.5) — 10's PBIP was renamed on 2026-07-09 to match its own PBIX; this report was not, so the two PBIPs now disagree — LOW — 10 min
- [ ] Sections 1–5 confirmed N/A — no conditional formatting, no grouped lists, no subtotals, sorts match, no prompts — nothing to do
