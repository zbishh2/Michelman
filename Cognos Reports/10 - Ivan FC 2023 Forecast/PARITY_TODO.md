# Parity TODO — 10 - Ivan SFC2023 Forecast
_Source of truth: PBIP. Structural twin of `08 - Ivan SK 2023 Forecast`._
_Note: this report's PBIP/PBIX are named "Ivan **FC** 2023 Forecast", not "SFC". That is expected._

## Status — 2026-07-09

**Read this first: the forecast data-layer risks in section 6 and items 7.1–7.6 are all still open.** The
only things that changed on 2026-07-09 were the addition of a "last refreshed" timestamp and the PBIP page
rename. `Forecast.m` is unchanged and remains an **unvalidated, best-effort** rebuild.

**And: both changes are in the PBIP only — neither is in the PBIX.**
`FINAL - for handover\1 - Ivan FC 2023 Forecast.pbix` was opened and inspected on 2026-07-09: it contains
no `Last Refreshed` table and no `card` visual (it does already carry the `Forecast (This Month)` page
name — see below). Someone must open `PBIP\1 - Ivan FC 2023 Forecast.pbip` in Power BI Desktop and
re-save / publish before any user sees the timestamp.

What shipped into the PBIP (each row checked against the file, not taken on report):

| Change | Location | Verified |
|---|---|---|
| `Last Refreshed` table — a single-row `#table` computing US Eastern time from `DateTimeZone.FixedUtcNow()` | `…SemanticModel/definition/tables/Last Refreshed.tmdl` | Yes |
| Columns `Last Refreshed` (`formatString: MMM d, yyyy h:mm:ss AM/PM`) and `Time Zone` (`EDT` / `EST`) | same file | Yes |
| Measure `Last Refreshed Label` | same file | Yes |
| Registered in the model — `ref table 'Last Refreshed'` plus an entry in `PBI_QueryOrder` | `…SemanticModel/definition/model.tmdl` | Yes |
| A `card` visual bound to that measure on **every page — 2 of 2** (`x=8, y=4, 300×34`, above the table at `y=42`) | `…Report/report.json` | Yes |
| PBIP page `Forecast` renamed to `Forecast (This Month)` — `displayName` only; the section's stable `name` id `f8d3f74ee81842d9a40d` is unchanged | `…Report/report.json` | Yes |
| Model still loads | MCP `ConnectFolder` → 3 tables, 1 measure, 0 relationships | Yes |
| `report.json` re-parses and all 13 nested `config` / `filters` / `query` payloads are still JSON-encoded strings | `…Report/report.json` | Yes |

**Effect of the rename:** this report's PBIP and PBIX now agree, and the PBIP is a clean superset of the
PBIX. The *within-report* mismatch of item 7.9 is closed. The *cross-twin* mismatch is not — 08's PBIP and
PBIX both still say `Forecast`, so the two twins' PBIPs, which previously agreed, now disagree. See 7.9.

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
5 of which survive into `Query Exports for Rohit\10 - Ivan SFC2023 Forecast\Forecast.txt`), the
`Revenue Business Unit` placeholder, the dynamic date ceiling, the `RELOAD_KEY` omission, the LEFT-vs-INNER
joins, the `formatString: #,0` on the three Sales History quantities, the `FT*` → `MF*` documentation
errors, the stale `SH`-prefix parenthetical at `Sales_History.m:19`, and the missing `PRODCTL.F0005`
`SOURCE:` header. Each was re-checked against the files on 2026-07-09 and each is unchanged. Date formats
were already corrected repo-wide to `d MMM, yyyy` before this build; that is not new work.

## Summary

The visual layer is a faithful rebuild: Cognos ships two flat `<list>` visuals with zero conditional
formatting, zero grouping, zero subtotals and zero prompts, and the PBIP reproduces both as flat
`tableEx` visuals with matching column order, matching ascending sorts, and totals switched off.
Sections 1–5 below are therefore genuinely **N/A**, not gaps.

The risk in this report is entirely in the **data layer of the Forecast page**, which was reverse-mapped
from the `DW_LEGACY` Oracle warehouse onto JDE `PRODDTA.F3460` with no connection to the original and an
empty validation export. Twelve `-- TODO verify` markers remain — all twelve still present as of
2026-07-09. Beyond those, this audit found four substantive issues the markers do not cover: the Cognos
`RELOAD_KEY='N'` filter was omitted (a conscious choice, recorded in the code at `Forecast.m:57` — not a
silent drop, but not a verified one either); `Revenue Business Unit` is a placeholder copy of `Branch
Plant` where Cognos reads a genuinely distinct dimension; the Cognos date ceiling was changed from a hard
literal to a dynamic month-end (which is why the export is empty and why this page can never tie to Cognos
as it stands); and every star-schema join Cognos performs as an INNER join is a LEFT join here.

This report had two report-specific defects: a **PBIX/PBIP page-name mismatch** (`Forecast (This Month)`
vs `Forecast`) and a **`Sales_History.m` header comment that contradicts its own SQL**. The first was
resolved on 2026-07-09 by renaming the PBIP page to match the PBIX — though the *cross-twin* naming
decision is still open (item 7.9). The second is still open (item 7.11).

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
| Forecast | `<sortItem refDataItem="Requested Date" sortOrder="ascending"/>` | `Requested Date`, `Direction: 1` (asc) |
| Sales History | `<sortItem refDataItem="Promised Ship Date" sortOrder="ascending"/>` | `Promised Ship Date`, `Direction: 1` (asc) |

Report 08's `<sortItem>` elements omit the `sortOrder` attribute (Cognos defaults to ascending); this
report's carry it explicitly. Same effective sort — cosmetic XML difference only.
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
`Ivan Reports\Ivan FC 2023 Forecast.xlsx` is empty (`A1:A1`), so nothing ties this page to anything.

`grep -c -- '-- TODO verify'` returns **13**, but one hit (line 16) is prose inside the warning banner,
not a marker. There are **12 real markers**: 7 in the DW→JDE field-map comment block and 5 inline in the
SQL. Line numbers below are for `10 - Ivan SFC2023 Forecast/Forecast.m`; the twin's line numbers are in
parentheses.

> **Read this before working the table.** The markers name the F3460 fields as `FTFQT`, `FTDRQJ`, `FTAN8`
> — but the SQL beside them reads `MFFQT`, `MFDRQJ`, `MFAN8`. `MF` is the correct JDE data-dictionary
> prefix for F3460 (the Forecast File); `FT` is not. **The code is right and the comments/BUILD.md are
> wrong.** Anyone taking the markers literally will look up columns that do not exist. See item 7.7.

| # | Marker | Line (10 / 08) | What it assumes | How to confirm or refute |
|---|---|---|---|---|
| 1 | Company Code source (map) | 33 (35) | `COMPANY.COMPANY_CODE` ≡ `F0006.MCCO` of the branch plant | **Shape already confirmed** by `Generated SQL (Cognos - raw).sql:11,13`: Cognos joins the forecast's org SID → `ORGANIZATION` → `COMPANY2.COMPANY_SID`, i.e. the company **of the branch**. What is still open is whether `F0006.MCCO` equals the DW's `JDE_COMPANY__CCCO`. Run `SELECT DISTINCT MCMCU, MCCO FROM PRODDTA.F0006` and compare to the JDE Business Unit master (P0006). |
| 2 | `Requested Date` = `MFDRQJ` (map) | 38 (40) | `REQUESTED_DATE__GREG` ≡ `MFDRQJ`, not `MFRQDJ` | `SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'F3460'` — see which of `MFDRQJ` / `MFRQDJ` exists. If both, compare distributions against the JDE forecast revisions screen (P3460). Year/Month/Week (list cols 6–8) and the whole date filter hang on this field. |
| 3 | `Current Forecast` = `sum(MFFQT)` + `/10000` (map) | 39 (41) | Forecast qty field is `MFFQT`, stored with 4 implied decimals | Two questions. **Name:** confirm `MFFQT` exists (query above); candidates if not are `MFAFQ` / `MFFQT2`. **Scaling:** `SELECT TOP 50 MFFQT FROM PRODDTA.F3460 WHERE LTRIM(RTRIM(MFTYPF))='SA' AND MFFQT>0` and eyeball the magnitude against a known forecast line in P3460. Authoritative check: read the display-decimals of data item `FQT` in the JDE data dictionary (`F9210`/`F9860`). **If `MFFQT` is stored whole, delete the `/10000` — every quantity on this page is currently 10,000× too small.** |
| 4 | `Revenue Business Unit` placeholder (map) | 42 (44) | F3460 has no distinct RBU, so `MFMCU` (the branch) is used | **Refuted as a faithful mapping.** `Generated SQL (Cognos - raw).sql:13` joins a *separate* alias `ORGANIZATION_ALIAS_RBU` on `INVENTORY_DEMAND_MEASURE.ORGANIZATION_RBU_SID` — the DW fact carries its own RBU key, independent of the branch org. As shipped, `Revenue Business Unit` is **identical to `Branch Plant` on every row**. Decide a real source (customer's `F03012`, a `F0006` category code on the branch, or the sales-order RBU) or drop the column. See item 7.3. |
| 5 | `Customer Code` = `MFAN8` populated (map) | 43 (45) | The forecast's address number is the customer | `SELECT COUNT(*), SUM(CASE WHEN MFAN8 = 0 THEN 1 ELSE 0 END) FROM PRODDTA.F3460 WHERE LTRIM(RTRIM(MFTYPF))='SA'`. If `MFAN8` is mostly zero, this page's Customer Code / Name / Global Parent / Global Parent Name / TM Name columns are all empty and the mapping is wrong. Cognos reads `INVENTORY_DEMAND_MEASURE.INVENTORY_DEMAND__CUSTOM_SID → CUSTOMER3`. |
| 6 | `CURRENT_FORECAST > 0` → `MFFQT > 0` (map) | 56 (58) | Sign survives the `/10000` scaling | Follows from marker 3. `x/10000 > 0 ⟺ x > 0`, so the predicate is safe **regardless** of the scaling answer. Resolve marker 3 and this one closes with it. Low risk. |
| 7 | Company exclusion `00024`/`00025` (map) | 62 (66) | The DW's company exclusion maps to `F0006.MCCO` | **The filter itself is confirmed**: `Generated SQL (Cognos - raw).sql:8-10` builds `COMPANY2` as `… where JDE_COMPANY__CCCO<>'00024' and <>'00025'` and **inner-joins** it. Two open points: (a) is `F0006.MCCO` the same code as `JDE_COMPANY__CCCO` (leading zeros, `'00024'` vs `'24'`)? Run `SELECT DISTINCT MCCO FROM PRODDTA.F0006`. (b) Cognos's inner join *drops* rows; our `LEFT JOIN` + `ISNULL(...,'') NOT IN (…)` *keeps* branches missing from F0006. See item 7.4. |
| 8 | `CompanyCode` in SQL | 102 (106) | `ISNULL(LTRIM(RTRIM(bu.MCCO)),'')` | Same as marker 7. Note the `ISNULL(…,'')` makes an unmatched branch pass the exclusion test. |
| 9 | `MFDRQJ` is the requested date, in SQL | 107 (111) | Julian → Gregorian conversion on `MFDRQJ` | Same as marker 2. The conversion arithmetic itself (`DATEADD(DAY, (j % 1000) - 1, DATEFROMPARTS(1900 + (j / 1000), 1, 1))`) is the house pattern and is already validated in `Sales_History.m` against the export — only the *field choice* is open. |
| 10 | `MFFQT` name + `/10000` in SQL | 111 (115) | `ft.MFFQT / 10000.0 AS q` | Same as marker 3. **Highest-value single check in this report** — it scales every number on the page. |
| 11 | RBU placeholder in SQL | 113 (117) | `LTRIM(RTRIM(ft.MFMCU)) AS RevBU` | Same as marker 4. |
| 12 | `MFAN8` in SQL | 114 (118) | `CAST(ft.MFAN8 AS varchar(20))` | Same as marker 5. Also drives the `F42140` GTM-rep join on line 125, so an empty `MFAN8` silently makes every `TM Name` read `'Not Available'`. |

Because 08 and 10 carry **identical** marker text, a single JDE-side verification session closes all 24
markers across both reports. Do it once.

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

The rebuild **omitted it, and recorded the omission in the code**: `Forecast.m:57` reads
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
(`Forecast.m:134-135`).

**Today is 2026-07-09, so the Cognos window is `2026-07-01 … 2026-06-30` — an empty range.** The Cognos
Forecast page currently returns zero rows, which is exactly why the `Forecast_1` export sheet is empty.
The rebuild quietly repaired this by making the ceiling `EOMONTH(GETDATE())`.

This is almost certainly the right behaviour, but it means **the Forecast page cannot be reconciled
against the Cognos original at all** while the original's hard-coded ceiling remains in the past. Rohit
must be told this explicitly rather than discovering that the two do not tie. Two things to fix:
- `BUILD.md:130-131` still claims *"ceiling is the literal `'2026-06-30'` (kept verbatim from Cognos —
  parity-now)"*. The shipped `.m` does not do that. Stale — correct it.
- This is very likely what this report's PBIX page title `Forecast (This Month)` was trying to say. As of
  2026-07-09 the PBIP page carries that title too. See item 7.9.

### 7.3 `Revenue Business Unit` is a copy of `Branch Plant` — HIGH
Covered as marker 4 above; restated here because it is a *visible, wrong value on every row of the
rendered page*, not just an unverified field name. Cognos sources this column from a distinct
`ORGANIZATION_RBU_SID` on the fact table. Sales History gets this right (`sd.SDEMCU`, a real field), so
within the same PBIX one page's RBU is correct and the other's is a duplicate of the neighbouring column.

### 7.4 Cognos star joins are INNER; the `.m` uses LEFT JOIN — MED, NEEDS REVIEW
Every dimension join in the generated Cognos SQL sits in the `WHERE` clause, making it an inner join.
On the Forecast query that is `ORGANIZATION` (branch), `COMPANY2` (the 00024/00025-filtered subquery),
`ITEM`, `TIME_OTHER_DATE`, `CUSTOMER3`, `CUSTOMER_ID`, `CUSTOMER_ALIAS_GP`, `VENDOR_ALIAS_TM` and
`ORGANIZATION_ALIAS_RBU`. `Forecast.m:122-127` LEFT-joins `F0006`, `F0101` (customer), `F0101` (global
parent), `F42140` and `F0101` (rep).

So Cognos drops a forecast line whose branch is missing from the org dim, whose customer has no global
parent, or which has no sales rep; we keep all three. On the Sales History query the same applies,
including the country UDC join (`T8`, inner) which `Sales_History.m:166` LEFT-joins.

Mitigating: conformed DW dimensions normally carry an "unknown" member row, in which case the inner
joins drop nothing and LEFT is equivalent — and `Sales_History.m:118`'s `'Not Available'` default was
observed to match blank TM rows in the export, which is consistent with that. **Verify rather than
assume:** compare row counts with and without the LEFT-vs-INNER change on Sales History (which *is*
validatable against the 908-row export) and carry the verdict over to Forecast.

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
   contributes nothing), whereas `Forecast.m:85,98` passes the raw quantity straight through, and the
   `'EA'` factors 20 / 44 are invented house values with no source. Any non-KG/LB item on this page
   produces a number that exists in neither system.

**Fix:** enumerate the distinct `im.IMUOM1` values actually returned by this query. If they are only
`KG`/`LB`, close this as N/A with evidence. If not, source the real conversion from JDE `F41002`.

### 7.6 `Ordered Quantity KGs > 0` reproduced as `SDPQOR/10000 > 0` — MED
Cognos filters on the *converted* quantity: `(ORDERED_QTY * CONVERSION_FACTOR_KG) * SALES_FACTOR > 0`
(`Generated SQL (Cognos - raw).sql`, Sales History `where`). `Sales_History.m:175` filters the raw
primary quantity instead. Where `CONVERSION_FACTOR_KG = 0` (an item with no KG conversion), Cognos
evaluates `qty * 0 * SF = 0`, which is not `> 0`, and **drops the row**; we keep it. Same root cause as
7.5 item 3. Resolve together.

### 7.7 `.m` comments and `BUILD.md` name F3460 fields with the wrong prefix — MED (correctness of the handover doc)
`BUILD.md` uses `FTMCU` / `FTFQT` / `FTDRQJ` / `FTAN8` throughout (lines 109, 113–116, 118–119, 124, 166,
168–169, 171–172, 183–187, 241 …), and the `-- TODO verify` markers inside `Forecast.m` (lines 17, 38,
107, 111, 114) do the same. The shipped SQL uses `MFMCU` / `MFFQT` / `MFDRQJ` / `MFAN8` / `MFITM` /
`MFLITM` / `MFTYPF`. `MF` is the correct F3460 prefix. **The code is right; the documentation is wrong**,
and the documentation is precisely what a JDE-side verifier will read.
**Fix:** rewrite `FT*` → `MF*` in `BUILD.md` and in the five `.m` comments. Zero code change.

### 7.8 `PRODCTL.F0005` is queried but appears in no `SOURCE:` header — LOW (documentation / permissions)
`Sales_History.m:166` joins `PRODCTL.F0005` for the country UDC decode (`DRSY='00  '`, `DRRT='CN'`), a
different schema from `PRODDTA`. The file's `SOURCE:` header (line 23) names only `ODSPROD / ODS`.
`BUILD.md` risk #9 flags reachability but no `SOURCE:` header lists `PRODCTL`. Confirmed correct against
Cognos (`CUSTOMER_SHIP_TO.COUNTRY_CODE = T8.CATEGORY_CODE and T8.UDC_TABLEFIELD = N'00,CN'`), so this is
a docs/permissions gap, not a logic bug. **Fix:** add `PRODCTL.F0005` to the `SOURCE:` header and to the
handover's required-grants list.

### 7.9 Page name — PBIX/PBIP mismatch RESOLVED 2026-07-09; cross-twin decision STILL OPEN — MED, NEEDS REVIEW
The original finding, retained as the evidence trail:

- PBIP `1 - Ivan FC 2023 Forecast.Report/report.json` → `sections[0].displayName = "Forecast"`
  (`name = "f8d3f74ee81842d9a40d"`).
- PBIX `FINAL - for handover/1 - Ivan FC 2023 Forecast.pbix` → `Report/Layout` →
  `sections[0].displayName = "Forecast (This Month)"`, **same** `name = "f8d3f74ee81842d9a40d"`, so it is
  the same page renamed, not an extra page.
- Cognos `Report XML.md` → `<page name="Forecast">`.
- Report 08's PBIX **and** PBIP both say `Forecast`. This report is the only one that diverged.

`(This Month)` is not noise — it is an accurate, useful label for the dynamic-window deviation described in
item 7.2, and someone added it on purpose. Option B (honest labelling) was therefore chosen over reverting
it, and on **2026-07-09** this report's PBIP page was renamed `Forecast (This Month)`: `displayName` only,
with the section's stable `name` id `f8d3f74ee81842d9a40d` left untouched, so the PBIP is now a clean
superset of the PBIX. Verified in `report.json`.

**What is done:** this report's PBIX and PBIP agree.
**What is not done:** Option B said *apply it to both twins*. Report 08 was not touched — its PBIP and PBIX
both still say `Forecast`. So the two PBIPs, which previously agreed, now disagree, and the page name no
longer matches Cognos's `<page name="Forecast">` in this report. That is a defensible trade (an honest
label beats a literal one on a page whose date window genuinely deviates), but it is a **decision someone
must ratify and finish**, not something to leave half-applied. Either rename 08's page in both its PBIP and
its PBIX, or revert this one. ~15 min.

### 7.10 `Ordered Quantity` / `KGs` / `LBs` display 0 decimals; Cognos does not — MED, NEEDS REVIEW
The Cognos `<dataFormat>` block on each of these three Sales History columns contains **only**
`<dateFormat dateStyle="medium" displayOrder="DMY"/>` — a Cognos authoring slip that applies a date
format to a numeric column — and, importantly, **no `<numberFormat>`**. They therefore render at default
precision (the export's row 1 shows `22045.992`). The three Forecast page numerics *do* carry
`<numberFormat decimalSize="0"/>`, so 0 decimals is correct there.

The PBIP applies `formatString: #,0` to all six
(`…SemanticModel/definition/tables/Sales_History.tmdl:99, 167, 186`), so on the Sales History page
`22045.992` displays as `22,046`. **Fix:** change those three `formatString` values to `#,0.000` (or
`#,0.###`). The Forecast page's `#,0` is correct — leave it. `BUILD.md` describing these three as "0 dp"
is also wrong.

### 7.11 `Sales_History.m` header contradicts its own SQL — LOW
`Sales_History.m:19` states the query reads *"F4211 UNION ALL F42119 (SH-prefixed aliases mapped back to
the SD names)"*. The SQL does no such thing: lines 150–160 select `SDKCOO, SDMCU, …` from **both** legs,
and the inline comment at lines 155–157 correctly explains that *"On THIS ODSPROD instance F42119 mirrors
F4211 with the SAME SD* column names (NOT the JDE-standard SH prefix)"*. The header is a leftover from
before the `SHKCOO` failure. Report 08's header does not make this claim. **Fix:** delete the
parenthetical on line 19. (`BUILD.md:251-254` already records the correction — only the `.m` header lags.)

### 7.12 Confirmed non-issues (do not "fix" these)
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
- **The bulk-item whitelist contains duplicates** (`ME91735.S` ×5, `ME92040.S` ×4, `PP236A.S` ×3,
  `ME91240G.S` ×3 — 29 entries, 17 distinct). This is copied verbatim from the Cognos XML, which has the
  same duplicates. Harmless inside `IN (…)`. Leave it; deduplicating would diverge from the source.

## 8. Model-level defects found

**Identifier columns with `summarizeBy: sum`: none.** All 19 `Forecast` columns and all 24
`Sales_History` columns carry `summarizeBy: none`, including `Order Number` (int64) and `Global Parent`
(int64), both of which also correctly use `formatString: 0` so no thousands separator appears on an
identifier. Clean in both tables. (Harmless in today's flat `tableEx`; this is what would have bitten if
anyone later converts a page to a matrix.)

| Finding | Evidence | Severity |
|---|---|---|
| Sales History quantity format strings — see 7.10 | `Sales_History.tmdl:99, 167, 186` | MED |
| Auto date/time correctly **off** | `…SemanticModel/definition/model.tmdl:11` → `__PBI_TimeIntelligenceEnabled = 0`, and no `DateTableTemplate_*.tmdl` in `definition/tables/`. **Report 08 has it on** — fix 08, not this one. | **Clean here** |
| No relationships defined | `definition/relationships.tmdl` empty in both models | **Correct** — two independent flat lists. No action. |

## 9. Twin divergence (08 vs 10)

`diff` of the two `Forecast.m` SQL bodies yields exactly two substantive lines; `diff` of the two
`Sales_History.m` SQL bodies yields exactly two. Everything else — column list, joins, KG/LB `CASE`,
GTM-rep chain, GST decode, `GROUP BY`, typing — is byte-identical. The rebuild's structural-twin claim
holds.

### Intentional, and faithful to each report's own Cognos XML — no action

| # | Divergence | 10 (this report) | 08 | Cognos evidence |
|---|---|---|---|---|
| 1 | Forecast branch-plant filter | `MFMCU NOT IN ('CINC','CIN2')` | `MFMCU IN ('AUBA','AUB2','SING','SNG4','MUM3','SHAN','CINC','CIN2','CIN4')` — a **positive include list that contains CINC/CIN2** | `<detailFilter>` `[Branch Plant] not in ('CINC','CIN2')` vs `[Branch Plant] in (…)`. Reproduced verbatim. The two reports genuinely disagree about CINC/CIN2 in the source. |
| 2 | Bulk-item whitelist | 29 entries, **17 distinct** (with the source's own duplicates) | 99 entries, 99 distinct (SK family) | Both copied verbatim from each XML. |
| 3 | Sales History `DUE_DATE` floor | `2025-11-01` | `2026-03-01` | `[Promised Ship Date] between 2025-11-01 …` vs `… between 2026-03-01 …`. This is why 08's row count is the smaller of the two. |
| 4 | `<sortItem>` attribute | `sortOrder="ascending"` | no `sortOrder` (defaults ascending) | Cosmetic XML difference; identical effective sort. |

### Unintentional — asymmetries that are themselves findings

| # | Divergence | Verdict |
|---|---|---|
| 5 | **Page name — changed 2026-07-09.** *Was:* this report's PBIX said `Forecast (This Month)` and its PBIP said `Forecast`. *Now:* this report's PBIP was renamed to `Forecast (This Month)` and matches its PBIX. 08's PBIX and PBIP both still say `Forecast`; Cognos says `Forecast`. | The within-report defect is **fixed**. The cross-twin one is **not**: the twins' PBIPs previously agreed and now do not. Item 7.9 — ratify the choice and apply it to 08, or revert. STILL OPEN, NEEDS REVIEW. |
| 6 | **`Sales_History.m` header accuracy.** This report's header (line 19) claims the F42119 leg uses `SH`-prefixed aliases; its own SQL and inline comment say otherwise. 08's header makes no such claim. | Defect in **this** report. Item 7.11. |
| 7 | **`BUILD.md` F42119 documentation.** This report's is current (line 12 lists `F4211 ∪ F42119`; lines 249–254 record the `"Invalid column name 'SHKCOO'"` failure and the `SD*` correction). 08's still says F4211-only and still tells the reader to build F4211-only first. | This report is **cleaner**. Port these corrections into 08's `BUILD.md`. |
| 8 | **Auto date/time.** `= 0` here, `= 1` in 08 (plus an orphan `DateTableTemplate_*.tmdl`). | This report is **clean**. Fix 08. |

### F42119 verdict for this report

**PRESENT.** `Sales_History.m:148-161` reads
`(SELECT … FROM PRODDTA.F4211 UNION ALL SELECT … FROM PRODDTA.F42119) sd`, using `SD*` column names for
**both** legs. This report received the fix first (2026-07-05, after F4211-only decayed to ~20 rows) and
report 08 has it too. No data-loss bug in either twin. Only this report's `.m` header narrative lags
(item 7.11).

### Re-checked after the 2026-07-09 refresh-stamp build
Both twins received the same `Last Refreshed` table, measure, `model.tmdl` registration, and a card visual
on every page with identical geometry (`x=8, y=4, w=300, h=34, z=4000`). Stripped of `lineageTag` GUIDs,
the two `Last Refreshed.tmdl` files are byte-identical. No asymmetry there.

The build **did** introduce one asymmetry, and it is row 5 above: this report's PBIP page was renamed and
08's was not. Deliberate here — it aligns this PBIP with its own PBIX — but it leaves the twins disagreeing
at the PBIP layer. It must be decided, not left.

## Open items checklist

- [x] Add a visible "last refreshed" timestamp to every page — **DONE 2026-07-09** — PBIP only; the PBIX still needs a Power BI Desktop re-save before users see it (see Status)
- [x] Align this report's PBIP page name with its PBIX (`Forecast` → `Forecast (This Month)`, `displayName` only) — **DONE 2026-07-09** — the *cross-twin* decision below is still open
- [ ] **Verify `MFFQT` name + `/10000` scaling** (markers 3, 6, 10) — every quantity on the Forecast page depends on it — HIGH — 30 min with an ODSPROD connection, closes both twins at once
- [ ] **Verify `MFDRQJ` vs `MFRQDJ`** (markers 2, 9) — the date filter and Year/Month/Week hang on it — HIGH — 15 min (same query)
- [ ] **`Revenue Business Unit` is a duplicate of `Branch Plant`** (marker 4, item 7.3) — pick a real source or drop the column — HIGH — 1–2 hrs, needs a business decision
- [ ] **Disclose the dynamic date-ceiling deviation to Rohit** (item 7.2) — the Cognos original returns 0 rows today; the pages can never tie — HIGH — 0 effort, but must not be skipped
- [ ] **Verify `MFAN8` is populated** (markers 5, 12) — if not, five enrichment columns are silently blank — MED — 15 min (same query)
- [ ] **Resolve `RELOAD_KEY='N'` / `[Active Forecast Only]`** (item 7.1) — the omission is recorded at `Forecast.m:57`, but unverified; confirm with the `DW_LEGACY` owner that it is ETL load-control metadata, then replace the assumption in the `.m` with that finding — MED — 30 min + one question to the DW owner
- [ ] **Enumerate distinct `IMUOM1` / `SDUOM1` values; source real conversions from F41002 if any are not KG/LB** (items 7.5, 7.6) — MED — 1 hr
- [ ] **LEFT vs INNER join cardinality** (item 7.4) — test on the validatable Sales History page, carry the verdict to Forecast — MED — 1 hr
- [ ] **Finish the page-name decision across the twins** (item 7.9) — this report's PBIP/PBIX now agree on `Forecast (This Month)`; 08 still says `Forecast` in both. Ratify Option B and rename 08's PBIP + PBIX, or revert this report — MED — 15 min
- [ ] **Fix `formatString` on `Ordered Quantity` / `KGs` / `LBs`** → `#,0.000` (item 7.10) — MED — 10 min
- [ ] **Rewrite `FT*` → `MF*`** in `BUILD.md` and the five `Forecast.m` comments (item 7.7) — MED — 20 min, no code change
- [ ] **Delete the stale `SH`-prefix parenthetical from `Sales_History.m:19`** (item 7.11) — LOW — 2 min
- [ ] **Add `PRODCTL.F0005` to the `SOURCE:` header and the required-grants list** (item 7.8) — LOW — 5 min
- [ ] Sections 1–5 confirmed N/A — no conditional formatting, no grouped lists, no subtotals, sorts match, no prompts — nothing to do
