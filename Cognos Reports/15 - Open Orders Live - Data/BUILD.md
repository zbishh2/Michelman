# Report 15 — Open Orders - Live Data — BUILD SPEC

**Cognos path:** Public Folders > Michelman Reporting > Customer Service > US CSRs
**Report name (XML `reportName`):** `Open Orders - Live Data`
**Migration tracker ID:** 144 (Reports Detail row 14)
**Stage:** **VALIDATED (2026-07-16)** — probes all green AND tight-capture validation PASSED (Cognos export 09:27 vs PBI refresh 09:15): 5/5 pages shape-match, 398=398 rows, 392 byte-identical across all 15 columns, residuals = 5 rows of 12-minute live drift (status/MOT progressions) + 1 DI2 letter-case source diff (2744089, ODS stale-on-UPDATE bucket). Details in `probe_results.txt`. Block 4 disproved the "stale CSR names" theory (see §5.1). **Report-out workbook delivered 2026-07-16** (`Excel Validation\_report_out\15 - Open Orders Live.xlsx`) + `Txt Queries\Open Orders.txt` exported. **REDESIGNED same day per Dave Bubash (post-validation): the 5 per-CSR pages are GONE — single page `Open Orders` + multi-select `CSR Name` dropdown slicer** (the 4 name pages were permanently empty — former book owners; validation was done against the 5-page shape, data unchanged). `Kim Window` flag column retained in the model but no longer applied anywhere (Kim's +30-day filter lived only on her page — resurrect as a slicer if asked). `CSR Page` helper column also retained, unused. Report JSONs re-parse clean; model lint 2 tables/1 measure/0 errors. Remaining: publish, §8 business decisions. Previously: BUILT 2026-07-15, both semantic models lint-clean. Lilly's prior PBI build is NOT the baseline (full from-scratch rebuild, per COLLECTION_NOTES). Artifacts: `PBIP\Open Orders - Live Data.pbip` (table `Open Orders` + `Last Refreshed`, 1 page) and `PROBE\R15 Probe.pbip` (6 probe tables).

A five-page flat data-dump export. No charts, no subtotals, no conditional formatting, no prompts, no parameters, no footers. Each of the five Cognos pages is an independent list bound to a query object that is **identical except for one CSR-name filter** (plus one extra filter on the Kim page). Because those four hard-coded CSR names no longer match any live assignment, **four of the five pages are empty and every order lands on "Other"** (see §0 and §5).

---

## 0. Intake integrity — READ FIRST

**Verdict: COMPLETE and UNTRUNCATED.** The collected `Queries + XML.txt` holds the generated SQL for all 5 query objects followed by the full report XML. Checks:

| Check | Result |
|---|---|
| Truncation markers (`truncated` / `[…]` / `snip` / `elided` / `tokens`) | **0 hits** across the whole file |
| XML terminates cleanly | ends `…<reportName>Open Orders - Live Data</reportName></report>` |
| Query objects with generated SQL | **5 / 5** (`Tammy.0` `Nae.1` `Kim.2` `Shannon.3` `Other.4`) |
| Pages with rendered output | **5 / 5** xlsx sheets (`Tammy_1` `Nae_2` `Kim_3` `Shannon_4` `Other_5`) |
| Column order / headers / formats provenance | XML `listColumns` **and** xlsx header row + cell numFmts agree exactly |

**No screenshots were collected — the xlsx export is the render evidence** (the four named sheets literally render `No Data Available`; `Other_5` carries the 394 data rows). The xlsx `Other_5` sheet is the row-count/validation target.

Deliverables split out of the intake into the report root, byte-faithful: `Report XML.xml`, and `Tammy.0.sql` / `Nae.1.sql` / `Kim.2.sql` / `Shannon.3.sql` / `Other.4.sql`.

---

## 1. Source route — **ODS PRODDTA (JDE), SQL Server**

Evaluated SSAS → EDW → ODS per the team mandate. **Chosen: ODS**, matching reports 01/04/06/07/09/10. Report **04 (CM Open Sales Orders Live)** is the direct precedent — same `F4211` + `F42140`(CSR) + `F0101` chain, same Julian decode, same derived-table nesting.

### Why not SSAS (`BIQLTabular_v2`, Live Connection) — REJECTED
The Cognos report runs on a JDE-native package model called **"Open Order Star Schema - JDE"** (namespace `[Open Order Star Schema - JDE].[Open Orders]`) that is **not** the SSAS cube. Coverage probe against `..\v2.xmla`:

| Field probed in v2.xmla | Hits |
|---|---|
| `Open Orders` (the fact this report needs) | **0** |
| `CSR Name` | **0** |
| `Pricing Quantity` (the Weight measure) | **0** |
| `Next Status` | **0** |
| `Promised Ship` | 19 (present, but on other facts) |
| `Hold Orders` / `Delivery Instructions` / `Carrier Name` / `Order Type` | present on unrelated facts |

There is **no cube fact at the F4211 open-order-line grain** carrying this column set. A Live Connection (no local tables, SSAS 2019 non-composite) also **cannot add** the two derivations this report needs: the `Weight` = Pricing-Quantity UOM-decode measure, and the `CSR Page` grouping. Partial fit → disqualified.

### Why not EDW (`EDWPROD`, SQL Server) — REJECTED as single source
EDW's `dbo.FactSalesDetail` (F4211) carries the sales-order columns, but this report needs **F4201 order-header attributes joined per line** — `SHHOLD` (Hold), `SHMOT` (MOT), `SHDEL1/SHDEL2` (Delivery Instructions) — plus the **F41002 pricing-UOM conversion** used by the Weight decode and the **F42140 CSR** lineage. Those are not pre-joined on the EDW fact, so a single-source EDW build would re-introduce the same JDE joins with less faithful field names. ODS reproduces the Cognos SQL almost 1:1.

### Why ODS — CHOSEN
Covers 100% of the report from the same tables the Cognos SQL names directly: `PRODDTA.F4211` (open lines), `PRODDTA.F4201` (order header), `PRODDTA.F0101` (sold-to + carrier + CSR-rep names), `PRODDTA.F42140` (CSR assignment), `PRODDTA.F41002` (pricing-UOM conversion). Native T-SQL, folds, reproduces the logic verbatim. This is **open orders only** (`SDNXTR < '570'`) — **no `F42119` history union is needed** (that union only matters for shipped/closed sales-history reports like 09/10; open lines never leave F4211).

Connection: `Sql.Database("ODSPROD","ODS")`, native query, `[EnableFolding=true]`. No CTEs (a leading `WITH` breaks folding — PBI wraps as `SELECT * FROM (<q>)`; the Cognos `with …` chain is rewritten as nested derived tables); no `ORDER BY` inside the folded query (illegal in SQL Server) — sort in the visual.

---

## 2. Query objects → files

All five Cognos queries share **one selection and one layout**; they differ only in the WHERE line. Rendered rows are from the captured xlsx (2026-07-15); all filters are live/`sysdate`-relative so live counts drift — tight-capture rule applies at validation.

| # | Cognos query | Page / xlsx sheet | Rendered rows | CSR filter (the only difference) |
|---|---|---|---|---|
| 0 | `Tammy`   | `Tammy_1`   | **0** (No Data Available) | `CSR Name = 'Runyan, Tammy'` |
| 1 | `Nae`     | `Nae_2`     | **0** (No Data Available) | `CSR Name = 'McCrary, Nae'` |
| 2 | `Kim`     | `Kim_3`     | **0** (No Data Available) | `CSR Name = 'Benjamin, Kim'` **+ `Promised Ship < sysdate+30`** |
| 3 | `Shannon` | `Shannon_4` | **0** (No Data Available) | `CSR Name = 'Garner, Shannon'` |
| 4 | `Other`   | `Other_5`   | **394** | `CSR Name NOT IN (the four names above)` |

**Chosen build: ONE table `Open Orders`** (`OpenOrders.m` / `OpenOrders.commented.m`) feeding all five pages via a derived `CSR Page` filter. Rationale in §6.

### Page ↔ query binding (the `refQuery` quirk — resolved)
Every `<page>` element carries **`refQuery="Tammy"`** at the page level (a copy-paste authoring artifact), while the **`<list>` inside each page binds to its own query**:

| Page | page `refQuery` | list name | list `refQuery` (the real data binding) |
|---|---|---|---|
| Tammy   | Tammy | List1 | **Tammy** |
| Nae     | Tammy | List2 | **Nae** |
| Kim     | Tammy | List3 | **Kim** |
| Shannon | Tammy | List4 | **Shannon** |
| Other   | Tammy | List5 | **Other** |

The page-level `refQuery` is **inert** here: the only page-level content is a static `"Open Orders - Live Data"` header (no page-level data expression), so it has zero effect on output. The list `refQuery` is what drives each grid. Do not be misled by the four `refQuery="Tammy"` attributes.

---

## 3. Page layout (identical on all 5 pages) — 15 columns

Header row on-page = the Cognos `label=` override on each data item (confirmed against the xlsx header row, row 2). Column order is the `<listColumns>` order (identical to the xlsx column order). Page title `Open Orders - Live Data` sits above the grid (xlsx row 1). Dates are **month-first short** (`m/d/yy`) — the `<dateFormat dateStyle="short"/>` has **no `displayOrder` attribute**, so NOT day-first.

| # | On-page header (label) | Data item (query) | JDE source | Align | Format | xlsx numFmt |
|---|---|---|---|---|---|---|
| 1 | **Order** | Order Number | `F4211.SDDOCO` | left | integer, no separator | `#0` |
| 2 | **Customer** | Customer Name | sold-to `F0101.ABALPH` (via `SDAN8`) | left | text | General |
| 3 | **Next** | Next Status | `F4211.SDNXTR` | left | text | General |
| 4 | **BP** | Branch Plant | `F4211.SDMCU` | left | text | General |
| 5 | **Requested** | Requested Date | `F4211.SDDRQJ` (Julian) | left | **`m/d/yy`** | `m/d/yy` |
| 6 | **Promised Ship** | Promised Ship Date | `F4211.SDPDDJ` (Julian) | left | **`m/d/yy`** | `m/d/yy` |
| 7 | **Qty** | Quantity | `SUM(F4211.SDUORG/10000)` | **right** | `#,##0` | `#,##0` |
| 8 | **UOM** | Unit Of Measure | `F4211.SDUOM` | left | text | General |
| 9 | **Weight** | Pricing Quantity | `SUM(`decode over `SDUOM4`, see §5`)` | **right** | `#,##0` | `#,##0` |
| 10 | **Item** | 2nd Item Number | `F4211.SDLITM` | left | text | General |
| 11 | **Hold** | Hold Orders Code | `F4201.SHHOLD` | left | text | General |
| 12 | **Carrier** | Carrier Name | carrier `F0101.ABALPH` (via `SDCARS`) | left | text | General |
| 13 | **MOT** | Mode of Transportation | `F4201.SHMOT` | left | text | General |
| 14 | **DI1** | Delivery Instructions 1 | `F4201.SHDEL1` | left | text | General |
| 15 | **DI2** | Delivery Instructions 2 | `F4201.SHDEL2` | left | text | General |

Right-aligned columns (Qty, Weight) use Cognos style `lm` (list-measure); all others use `lc` (list-cell). Headers use style `lt`.

**Extra helper columns** (added by the single-table build, NOT in the Cognos output): `CSR Name` (hidden; drives paging), `CSR Page` (the page filter), and `Kim Window` (hidden 0/1 flag; the Kim page's `Promised Ship < sysdate+30` — see §4). All three are model-level `isHidden`; do not surface them in any grid.

**Sort (all pages):** Cognos `sortList` = **Promised Ship Date asc, then Order Number asc** (matches each SQL `order by "Promised_Ship_Date" asc nulls last, "Order_Number" asc nulls last`). Queries omit `ORDER BY` (folding) — set the sort in the visual; blanks last on ascending matches Cognos nulls-last.

**Label overrides to carry into PBIR** (query column internal name → displayName): `Order Number`→`Order`, `Customer Name`→`Customer`, `Next Status`→`Next`, `Branch Plant`→`BP`, `Requested Date`→`Requested`, `Promised Ship Date`→`Promised Ship`, `Quantity`→`Qty`, `Unit Of Measure`→`UOM`, `Pricing Quantity`→`Weight`, `2nd Item Number`→`Item`, `Hold Orders Code`→`Hold`, `Carrier Name`→`Carrier`, `Mode of Transportation`→`MOT`, `Delivery Instructions 1`→`DI1`, `Delivery Instructions 2`→`DI2`. **No duplicate column names** (unlike report 12's double "Description 1") — all 15 headers are distinct. The `.m` already emits the final header names, so PBIR needs no renames if it keeps the query column names.

**noDataHandler:** each list defines a `No Data Available` block (`padding:10px 18px`). Under parity the four named pages render exactly that. In PBIR, reproduce with a card/text "No Data Available" shown when the page's `CSR Page` filter yields no rows (or simply let the empty `tableEx` stand — match the house pattern used elsewhere).

---

## 4. Filters (baked into the query — no prompts/slicers)

There are **no Cognos prompts or parameters** in this report. Every filter is a static `detailFilter`. Shared by all five queries:

| Filter (Cognos) | Ported as (T-SQL) |
|---|---|
| `[Next Status] < '570'` | `SDNXTR < '570'` (open orders) |
| `[Order Company] = '00010'` | `SDKCOO = '00010'` |
| `[Line Type] not in ('FS','T')` | `SDLNTY NOT IN ('FS','T')` |
| `[Order Type] <> 'SQ'` | `SDDCTO <> 'SQ'` (exclude quotes) |
| `[CSR Name] = <name>` / `not in (…)` | reproduced as derived `[CSR Page]` + per-page filter (§6) |

Per-page extra:

| Page | Extra filter (Cognos) | Ported as |
|---|---|---|
| **Kim** | `[Promised Ship Date] < ({sysdate} + 30)` | **`Kim Window` helper column** (`CASE WHEN Promised_Ship_Date < DATEADD(DAY,30,CAST(GETDATE() AS date)) THEN 1 ELSE 0 END`, in the shared query, NULL date → 0), filtered `Kim Window = 1` on the Kim page only (page filter = `CSR Page = 'Kim'` AND `Kim Window = 1`). **NOT a PBI relative-date filter** — see the change note below. |

**Kim filter — CHANGE (orchestrator decision 2026-07-15, supersedes the earlier "page-level relative-date visual filter" plan in this doc §4/§6/§7 and open question #6).** A PBI relative-date filter (`Promised Ship` in the next 30 days) is a **two-sided** window and would wrongly **exclude overdue orders** (past promised-ship dates), which the Cognos one-sided `< sysdate+30` **includes**. So Kim's window is materialized as the 0/1 `Kim Window` helper column in `OpenOrders.m` and applied as an equality page filter (`Kim Window = 1`). `Kim Window` is hidden. Only the Kim page carries it; the other four pages filter on `CSR Page` alone. NULL promised-ship → 0 (SQL `NULL < date` is unknown → `ELSE 0`), matching Oracle's NULL-comparison exclusion.

**Expired-date-ceiling check (defect C1 pattern): NONE FOUND.** No hard-coded upper date bound (`DATE '2026-06-30'` etc.) exists in any query. The only date logic is the open-status filter and Kim's rolling `sysdate+30`. xlsx `Promised Ship` ranges 2026-07-14 → 2027-03-31 and `Requested` 2026-02-17 → 2027-02-22, all live — no zero-rows-since-date risk.

---

## 5. Defects, quirks, fan-out & scaling flags

1. **DEFECT — four dead pages (flag prominently), BUT the "stale names" explanation is DISPROVED (probe block 4, 2026-07-16).** All four literals — Runyan/Benjamin/McCrary/Garner — **are live CMRTYPE='CSR' assignments** (1639/1136/1130/97 customers respectively), yet **zero of the 409 open lines map to any of them** — everything still lands on **Other**, exactly matching the Cognos render (xlsx: 4 sheets empty, `Other_5` = 394). So parity is intact, but *why* four active CSRs with ~4,000 combined customer assignments catch no open orders is unexplained. Candidate theories: F42140 assignment keyed to sold-to while the report joins on **ship-to `SDSHAN`**; name-string mismatch between the F42140-linked F0101 row and the literal; **RESOLVED same day** (DAX over the refreshed main PBIP): the open-order rows map to exactly **six** CSRs — Chatman (99), Dowd (104), Corcoran (103), Sifuentes (60), Bachler (28), Buchheim (4) — none of them the four page names, and no string/padding artifact (LEN-checked). The four names are valid CSRs whose books simply contain no ship-tos with open orders; the active books moved to other reps. The pages reference **former owners** → permanently empty. Recommended fix unchanged and strengthened: a live **CSR Name slicer** instead of four literals (the CSR set demonstrably shifts).

2. **CSR join is effectively INNER (NULL-CSR orders dropped from ALL pages).** In Oracle both `ABALPH = 'x'` and `ABALPH not in (…)` on the LEFT-joined CSR exclude NULL. So orders whose ship-to (`SDSHAN`) has **no** CMRTYPE='CSR' row in F42140 appear on **no page at all**. The `.m` uses an INNER JOIN to reproduce this faithfully. Consequence: even after fixing the stale names, CSR-less orders still won't show — flag for the business. Probe **block 5** quantifies how many lines this drops.

3. **FAN-OUT risk — customers with >1 CSR row.** The CSR subquery keys on `CMAN8` only; a customer with two CMRTYPE='CSR' rows (two `CMSLSM`) fans each order line to two rows, and since CSR is not in the Cognos group-by, `Qty`/`Weight` **double-count**. This is a **pre-existing Cognos quirk, reproduced**. Probe **block 3** lists such customers; if any exist, record the over-count as accepted at validation.

4. **`Weight` (Pricing Quantity) UOM decode.** Oracle `decode(SDUOM4, SDUOM1,SDPQOR/10000, SDUOM2,SDSQOR/10000, SDUOM,SDUORG/10000, nvl((UMCONV/10000000*SDUORG)/10000,0))` → ported as a `CASE` (see `.m`). Expresses the ordered quantity in the **pricing UOM** (`SDUOM4` = F41002 `UMRUM`); the default branch uses the F41002 conversion factor `UMCONV` (7 implied decimals) and the LEFT-joined `conv` row (NULL → 0 via `ISNULL`).

5. **JDE implied decimals:** `SDUORG`, `SDPQOR`, `SDSQOR` are ÷`10000.0`; `UMCONV` ÷`10000000.0`. `SDDOCO` (Order) is raw. There is **no line-number column** in this report, so no `SDLNID/1000` scaling. Validate magnitudes vs xlsx via probe **block 6** (e.g. a `PL` line Qty≈48, Weight≈1920).

6. **`SELECT DISTINCT` not needed.** The Cognos query dedups via `GROUP BY` to the display grain (not render-DISTINCT), reproduced by the `.m`'s `GROUP BY`. xlsx confirms line-grain multiplicity is intended (394 rows / 346 distinct orders, up to 5 lines per order) — that multiplicity is faithful, not a dedup miss.

7. **Untrimmed display values (parity).** The Cognos SQL does **not** trim, so the xlsx shows JDE storage padding — BP right-justified (`'        CIN2'`), Item/Customer/Carrier/Hold/MOT/DI space-padded. The `.m` preserves this (no `LTRIM/RTRIM` on display columns) for byte parity with the xlsx. See open decision #2.

---

## 6. Single table vs five tables — RECOMMENDATION

**Firm recommendation: ONE table (`Open Orders`) + a derived `CSR Page` column, five report pages each filtered `CSR Page = <name>`.** Delivered as `OpenOrders.m` / `OpenOrders.commented.m`.

Why one table, not five:
- The five queries are **byte-identical except one WHERE line**. Five tables = 5× the M to maintain and 5× refresh, for **four grids that are permanently empty** under parity.
- One table makes the stale-name **defect visible and trivially fixable**: `CSR Page` derives from the live `CSR Name`, so correcting the names (or swapping to a slicer) repopulates the pages with no query change.
- `CSR Name` is **not an output column** on any Cognos page (it is filter-only), so surfacing it as a hidden helper changes nothing the user sees.

The **one documented deviation**: to page a single table, `CSR Name` is added to the query grain (one extra `GROUP BY` column) vs Cognos where CSR is filter-only. In practice CSR is a function of the order's ship-to, so this never splits a real row; the sole edge case is the >1-CSR-per-customer fan-out (§5.3), where the single-table grain keeps the copies as separate rows rather than summing them into one — an obscure, arguably-more-correct difference on the Other page.

**Kim's extra `Promised Ship < sysdate+30`** is handled via the hidden `Kim Window` 0/1 helper column (computed in the shared query) plus a `Kim Window = 1` page filter on the Kim page only (see §4 change note). The column is 0 for every row that fails the Kim window, so the flag is inert on the other four pages (they don't filter on it). This is the one reason a pure "single query for all pages" isn't literally identical across pages; the helper column + Kim-page filter covers it cleanly, and — unlike a PBI relative-date filter — it keeps overdue orders the way Cognos does.

**Fallback if the human demands strict per-query byte parity:** ship five verbatim tables (`Tammy.0.sql`…`Other.4.sql` each become a table with its CSR filter and Kim's +30 baked in). Not recommended — see above. The five SQL files are already extracted if this path is chosen.

---

## 7. PBIP authoring notes (for the build agent)

- **Author in PBIR format** (like reports 02/03/12), not legacy `report.json`.
- **`summarizeBy: none` on every column** — especially `Order`, `Next`, `BP` (identifiers/codes). `summarizeBy: sum` on an identifier corrupts a table. These are flat **tables** (`tableEx`), not matrices.
- **Five pages, one table.** Each page: a `tableEx` with the 15 columns in §3 order, plus a page-level filter `CSR Page = 'Tammy' | 'Nae' | 'Kim' | 'Shannon' | 'Other'`. **Kim page** also gets `Kim Window = 1` (the hidden 0/1 helper, NOT a relative-date filter — see §4 change note). Hide `CSR Name`, `CSR Page`, and `Kim Window` from the grids (model-level `isHidden`).
- **Header labels** per §3 (already the query column names — no rename needed if the query names are kept; if PBIR renames, set `displayName` per the override list). No duplicate names.
- **Formats:** `Order` = `0` (no separator); `Qty`, `Weight` = `#,##0`; `Requested`, `Promised Ship` = `m/d/yy` (PBI `formatString` VBA-style, month-first). Right-align Qty & Weight; left-align the rest.
- **Sort** (visual): Promised Ship asc, then Order asc.
- **Page titles:** static text `Open Orders - Live Data` above each grid (xlsx row 1).
- **noDataHandler:** show `No Data Available` when a page's filter is empty (matches the four named pages under parity), or let the empty table stand per house pattern.
- **Refresh:** rolling windows (Kim +30, open-status live) fix at refresh time → schedule a daily refresh; add the standard `Last Refreshed` stamp on each page (Rohit handover action item).
- Ship the PBIP **comment-free**; `OpenOrders.commented.m` stays in this folder in parallel.
- **Run `00_verify_tables.sql` on the jumpbox first** (house rule: probes before first refresh) and record results in `probe_results.txt`.

---

## 8. Open questions for the human

1. **Stale CSR names (the core defect).** Reproduce verbatim (current spec, four empty pages) — or repoint to the current CSR names / replace with a live **CSR Name slicer** so the report self-maintains? Probe block 4 shows who the CSRs are today. **Recommend the slicer** as a fast-follow after parity sign-off.
2. **Trim display values?** The xlsx shows JDE padding (leading spaces on BP, trailing on text). Current `.m` preserves it for byte parity. Prefer clean `LTRIM(RTRIM())` values (one-line change, breaks exact xlsx string match but improves UX)?
3. **CSR fan-out over-count.** If probe block 3 finds customers with >1 CSR row, accept the reproduced Cognos double-count, or de-dup (pick one CSR per customer)?
4. **CSR-less orders are dropped from every page** (INNER CSR join, faithful to Cognos). Is that intended, or should orders without a CSR assignment appear somewhere (e.g. an "Unassigned" bucket)?
5. **Single vs five tables** — confirm the single-table recommendation (§6) vs strict five-table byte parity.
6. **Kim's `+30` window** — RESOLVED (orchestrator 2026-07-15): implemented as the hidden `Kim Window` 0/1 helper column + `Kim Window = 1` Kim-page filter, NOT a PBI relative-date filter (which would drop overdue orders Cognos keeps). See §4 change note. Confirm at validation that Kim's row set matches Cognos's `< sysdate+30` (once the stale CSR name is also fixed, since Kim renders empty today).
