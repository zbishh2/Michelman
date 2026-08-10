# Report 11 — BOM WERCS Integrity Check — BUILD SPEC

_Spec written 2026-07-13. Awaiting build. Author this PBIP in **PBIR** format (like reports 02/03)._

_Report-out workbook delivered 2026-07-16 → `Excel Validation/_report_out/11 - BOM WERCS Integrity Check.xlsx` (formula-based, single `Comparison` sheet, mirrors the standard Notes/Comparison/RS format). Reproduces the 2026-07-14 capture pair via live formulas: 5,019 Cognos rows pair 1:1 (0 unmatched, 0 JDE% diffs), 8 PBI-only rows (`NYS2106`/`NYCS6202`) + 18 WERCS PBI-populated/Cognos-blank rows carried to RS as disclosed residuals; count-distinct 982 vs 984 noted. All Compare cells real formulas; verified._

Cognos path: `Public Folders > Michelman Reporting > MDG > BOMs > BOM WERCS Integrity Check`
Tracker outline: `1.22.12`. Cognos model package: **Data Warehouse** (`DW_LEGACY`, Oracle star schema).

---

## 1. What this report is

A **data-integrity check**: it compares each manufactured BOM's component percentages as recorded in
**JDE** against the same BOM as recorded in **WERCS** (the regulatory / product-stewardship system's
"Bulk Bill of Material"), and lists only the parent items where the two disagree.

- JDE side and WERCS side are matched on **(Parent 2nd Item Number, Component 2nd Item Number)**.
- Per component line, `Difference = ABS(JDE% − ISNULL(WERCS%, 0))`.
- A parent BOM is shown only if `SUM(Difference)` over that parent is **≠ 0** (the `summaryFilter`).
- In the rendered screenshot **every WERCS column is blank** — i.e. the visible discrepancies are all
  JDE BOMs that have **no matching WERCS record at all** (`WERCS% → 0`, so `Difference = JDE%`).

This is why WERCS data is not optional to the report: without a real WERCS table the LEFT JOIN can never
match, every JDE BOM would appear, and the "integrity check" would degrade into "list every BOM."

---

## 2. Source routing — CHOSEN: **ODS / PRODDTA** (T-SQL port), conditional on locating the WERCS table

Evaluated in the mandated order SSAS → EDW → ODS.

### SSAS `BIQLTabular_v2` (Live Connection) — REJECTED
- The cube **has** the JDE side (`grep` of `v2.xmla`: "Bill Of Material" ×44, "BOM" ×12) but has **zero**
  occurrences of `WERCS` and no component-percent / regulatory-composition measure.
- SSAS 2019 Live Connection permits **no local or composite tables**, so the WERCS half cannot be supplied
  alongside the cube. A JDE-only cube cannot produce a JDE-vs-WERCS comparison. **Disqualified.**

### EDW (SQL Server) — REJECTED
- EDW **fully covers the JDE side**: `dbo.DimBillOfMaterial` / `BIQL.DimBillOfMaterial` (ParentItemSKey,
  ComponentItemSKey, TypeBillofMaterial, Branch, component quantities), `DimItem` (2nd item number, stock
  type), `DimBusinessUnit` (branch type). This would be the *cleaner* JDE source.
- But EDW has **no WERCS table**: `grep -i wercs` and `-i "component.*percent"` over `edw_schema/` return
  nothing regulatory; the only `Percent*` columns on `DimBillOfMaterial` are yield/scrap/rework, not the
  WERCS composition percent. A single-source EDW query therefore cannot join to WERCS. **Disqualified.**
  (A cross-server merge — JDE from EDW, WERCS from ODS, joined in Power Query — is possible in an import
  model but is fragile, off-pattern, and still needs the WERCS location resolved. Not chosen.)

### ODS / PRODDTA (SQL Server, T-SQL port) — CHOSEN
- This is the **established route for every DW_LEGACY-package report** (08, 10 were rebuilt here per the
  2026-07-05 user decision — "we have no DW_LEGACY connection"). It is the **only** route where the JDE
  side and a WERCS table could coexist in one native query.
- JDE side maps cleanly to base JDE files: `PRODDTA.F3002` (Bill of Material), `PRODDTA.F4101` (Item
  Master), `PRODDTA.F0006` (Business Unit / branch type). All confirmed present in prior reports.

> ### ✅ BLOCKER RESOLVED (2026-07-14) — WERCS mapped and probed live
> David Bubash (Teams): **the WERCS tables exist only in ODS**, as the `PRODDTA.T_*` family
> (`T_PRODUCTS`, `T_PROD_COMP`, `T_PROD_DATA`, `T_COMP_DATA`, `T_PROD_TEXT`, `T_TEXT_DETAILS`,
> `T_PDF_MSDS`). Same-day column dumps + probes off ODSPROD settled the full mapping:
> **`T_PROD_COMP`** = `BILL_OF_MATERIAL_WERCS` (`F_PRODUCT` → parent 2nd item, `F_COMPONENT_ID`
> → component, `F_PERCENT` → percent; decimal(20,10), no scaling). No other `T_*` table is needed.
>
> **Key finding (4d-2):** WERCS stores a **chemical rollup**, not a raw-material bulk BOM — the
> screenshot's "discrepancy" parents ARE in WERCS, but keyed by CAS-linked component IDs
> (`2893` = water, hybrids like `9005-00-9 - BRIJS2.E`) with raw materials decomposed (JDE
> `GLUT50` 0.113 → CAS 111-30-8 at 0.0565 = ×50% solution strength). Those IDs never equal a JDE
> item code, never match the LEFT JOIN, and drop out — which is exactly why the render shows
> blank WERCS columns. Interpretation shift: **most manufactured BOMs will list as discrepancies**;
> only components that are themselves registered WERCS products can match.
>
> **Probe results (2026-07-14):** exact-equality join confirmed (the DW did not split hybrid IDs —
> a split would have rendered NEO2512 non-blank); **no `F_UNITS` filter** (4d-6: zero pairs mix
> unit bases; 4d-5: PPH and blank are both ~percent, per-product sums ≈ 100; TRACE/PPM = 3 rows);
> item-code bridge proven (4d-3: 13,812 of 18,681 WERCS products match `F4101.IMLITM`).
> `Report.m` is final. Also fixed same day off live dumps: **F3002's prefix is `IX*`, not `IB*`**,
> and the `/10000.0` percent scaling was confirmed (997500 + 2500 → 100%).

---

## 3. Query objects (from `Report XML.xml`)

| # | Query | Role | Generated SQL | Ported to |
|---|-------|------|---------------|-----------|
| 1 | `JDE` | BOM side; subquery of `Report` | folded into `Report.1.sql` | `Report.m` (inner derived table `j`) |
| 2 | `WERCS` | WERCS side; subquery of `Report` | folded into `Report.1.sql` | `Report.m` (inner derived table `w`) — **placeholder** |
| 3 | `Report` | the list (JDE ⟕ WERCS) | `Report.1.sql` | `Report.m` |
| 4 | `Branch` | prompt value list | `Branch.0.sql` | `Branch.m` |

**Intake completeness: COMPLETE.** `JDE` and `WERCS` are join operands consumed only by `Report`, so Cognos
folds them into `Report.1.sql` — they correctly have no standalone SQL file. The two data-producing outputs
(the list `Report`, the prompt `Branch`) each have their generated SQL. One page, one list; screenshot
covers page 1 (Cognos paginates lists at 20 rows).

---

## 4. DW_LEGACY → JDE field map (the port)

> **CORRECTED 2026-07-14:** F3002's real ODS column prefix is **`IX*`**, not `IB*` (`IB` is
> F4102 Item Branch's prefix — likely the source of the original mix-up). Confirmed by a live
> `TOP 5` dump off ODSPROD. F3002 also carries both 2nd item numbers directly (`IXKITL` parent,
> `IXLITM` component); the F4101 joins are kept because `IMSTKT` is needed regardless.

| DW_LEGACY column | JDE field | Notes |
|---|---|---|
| `BILL_OF_MATERIAL.BILL_OF_MATERIAL_KIT__IT_SID` | `F3002.IXKIT` | parent (kit) short item number (`IXKITL` = its 2nd item) |
| `BILL_OF_MATERIAL.BILL_OF_MATERIAL__ITEM_SID` | `F3002.IXITM` | component short item number (`IXLITM` = its 2nd item) |
| `BILL_OF_MATERIAL.QUANTITY` | `F3002.IXQNTY` | component quantity-per — **scaling CONFIRMED, see flag 1** |
| `BILL_OF_MATERIAL.FIXED_OR_VARIABLE_QUANTITY` | `F3002.IXFVBT` | selected in `JDE` query but **not displayed** (per dump, `V` sits in `IXFVBT`; harmless either way) |
| `BILL_OF_MATERIAL.TYPE_OF_BILL` | `F3002.IXTBM` | filter `= 'M'` (manufacturing BOM) |
| `BILL_OF_MATERIAL.BRANCH_PLANT` | `F3002.IXMMCU` | branch/plant (`IXCMCU` = component branch, not used) |
| `BILL_OF_MATERIAL.EFFETIVE_THROUGH_DATE` | `F3002.IXEFFT` | Julian; used only in `Branch` prompt filter; `140366` = "never expires" convention |
| `ITEM.ITEM_NUMBER_2ND` | `F4101.IMLITM` | 2nd (long) item number — join key to WERCS |
| `ITEM.STOCK_TYPE_CODE` | `F4101.IMSTKT` | filter `= 'M'` on the **parent** item |
| `ORGANIZATION.BRANCH_TYPE` | `F0006.MCSTYL` | business-unit type; filter `<> 'LAB'` |
| `BILL_OF_MATERIAL_WERCS.PERCENT` | `T_PROD_COMP.F_PERCENT` | decimal(20,10) — true decimal, **no implied-decimal scaling** (4b dump 2026-07-14) |
| `BILL_OF_MATERIAL_WERCS.ITEM_NUMBER_2ND_PARENT` | `T_PROD_COMP.F_PRODUCT` | varchar(50) WERCS product code; bridge to `F4101.IMLITM` proven by 4d-3 |
| `BILL_OF_MATERIAL_WERCS.ITEM_NUMBER_2ND_COMPONENT` | `T_PROD_COMP.F_COMPONENT_ID` | varchar(35) — ✅ CONFIRMED item-code-shaped by 4c samples (`2020NPR.E`, `ACTM10S.E`); CAS-style IDs also exist but simply won't match the JDE join. **Open: `F_UNITS` mixed basis** (blank = weight-%, `PPH` = parts-per-hundred) — 4d-5/4d-6 decide whether the WERCS SUM needs a unit filter |

### ⚠ Porting flags (validate against Cognos before sign-off)

0. **First-refresh data validation (2026-07-14) found and fixed three JDE-side defects:**
   (a) **LAB exclusion** — `F0006.MCSTYL` is NOT the DW's `ORGANIZATION.BRANCH_TYPE`: LABA/LABO/
   LABC/LABS all passed `MCSTYL <> 'LAB'` (≈14.5k of 27.6k rows) while LAB-only parents (`1314EU`,
   `151012PX`) are provably absent from the Cognos render. Port now also excludes branches named
   `LAB*` (evidence-based stand-in; true type column = open probe, verify SQL §5a/5b).
   (b) **NULL-safety** — `NULL MCSTYL <> 'LAB'` silently dropped rows (suspected cause of
   `1%CAR934` vanishing); F0006 join now LEFT + `ISNULL`. Confirm via verify SQL §5c.
   (c) **Branch grain** — ~~one branch per BOM via `DENSE_RANK`~~ **REVERSED by the full Cognos
   xlsx export (rework #3, same day): the DW keeps ALL branches that survive the F4102
   stock-type filter.** Evidence: `NYS3205` + the `SX` family appear at BOTH CIN2 and CINC in
   the Cognos export; `DPE3500` carries both CIN2's `-T2` transfer BOM and USCM's real
   16-component formula. Most parents are stocked 'M' at exactly one branch — which is why the
   render *looked* single-branch and pass 3 measured zero multi-branch parents. The `DENSE_RANK`
   pick was removed; the natural F4102-filtered grain IS the Cognos grain.

   **Rework #2 (same day, second validation pass):** stock type moved **F4101 master →
   `F4102.IBSTKT` branch grain** (flag #2 resolved in favor of branch). Evidence: `1%CAR934`
   (in Cognos) was still missing while AUBA `.E` parents (`151165PX.E`, `161107PX.E`) appeared
   that Cognos provably skips — both explained by branch-grain stock type, and the DW SQL's
   `ITEM` dim carries `BRANCH_PLANT` (= F4102 grain). Both F4101 joins dropped (`F4102.IBLITM` +
   `F3002.IXLITM` supply the 2nd item numbers). Confirm via `_tools\probes\11-bom-wercs.sql`
   (Results 2–4); Result 3 also tests whether branch stock type collapses multi-branch BOMs
   naturally, making the `DENSE_RANK` a no-op safety net.

1. **`IXQNTY` scaling — ✅ CONFIRMED on ODS 2026-07-14** (was the #1 validation risk, `MFFQT`/10000
   family). Live `TOP 5` F3002 dump: parent `171195PX.E` @ `AUBA` has two components with `IXQNTY`
   `997500` + `2500` → `/10000` = `99.75 + 0.25` = **exactly 100%**. `ROUND(IXQNTY / 10000.0, 4)`
   stands (= 6 implied decimals as a fraction, ×100 for percent). Final tie-out at validation:
   `181139INT / DIH2O = 55.4802`.
2. **Stock-type grain.** DW `ITEM.STOCK_TYPE_CODE` is filtered `= 'M'` on the parent. Ported as master-level
   `F4101.IMSTKT`. If the DW `ITEM` dimension is branch-grain, the true source is `F4102.IBSTKT`; they
   usually agree. Flag if the row count drifts.
3. **`COUNT(DISTINCT …) OVER ()` is not portable to T-SQL.** The Cognos SQL's overall
   `count(distinct C9) over ()` (the "Count Distinct(JDE Parent)" footer) is **dropped from the query** and
   is instead a DAX measure on the visual (see §7). SQL Server does not support windowed `COUNT(DISTINCT)`.
4. **`NVL` → `ISNULL`**; **`SYSDATE` → `CAST(GETDATE() AS date)`** (report is "as of last refresh");
   **Julian CYYDDD → date** via `DATEADD(DAY,(x%1000)-1, DATEFROMPARTS(1900+(x/1000),1,1))`.
5. **No expired date literal.** The only date logic is `Branch` prompt's `IXEFFT > SYSDATE` (dynamic, fine).
   No hard-coded `DATE '2026-06-30'`-style ceiling anywhere. ✅
6. **Difference-filter partition.** The `summaryFilter` lists levels *(JDE Parent, Branch Plant)*, but the
   generated SQL partitions the total by **parent only** (`sum(C7) over (partition by C0)`). The port
   follows the **generated SQL** (`PARTITION BY [JDE Parent]`), since that is what produced the validated
   render. Noted as a deliberate fidelity choice.
7. **Trim JDE strings** (`LTRIM(RTRIM(...))`) on every item-number / branch key — JDE right-pads.

---

## 5. Page layout

- **Page name:** `Page1`. **Page header title:** `BOM Discrepancies JDE to WERCS` — bold, centered
  (Cognos style `tt`). Use a textbox or the visual title.
- **Prompt:** a single-select **slicer on `Branch Plant`**, sourced from the `Branch` query (§6). Cognos
  `selectValue parameter="Branch"`, `autoSubmit="true"`, **optional** (the JDE filter is `use="optional"`).
  **Default = nothing selected = all branches.** Place top-left, matching the Cognos dropdown.
- **Page footer:** Cognos prints date / page-number / time. Reproduce the repo-standard **`Last Refreshed`
  card** (see the project-wide decision); Cognos's page-number has no PBI analogue and is not reproduced.

---

## 6. The list visual (`List1`, query `Report`)

Build as a **flat table (PBIR `tableEx`)** — not a matrix. Rationale (consistent with report 03's decision):
the two numeric columns (`JDE Percent`, `WERCS Percent`) are display values, not aggregates; a matrix would
try to SUM them and would fight the three-level Cognos row-span grouping. Set **`summarizeBy: none` on
every column** (identifiers *and* the two numeric columns) so nothing silently aggregates.

### Columns — **visible**, in this exact order (Cognos `label=` → PBIR `displayName`):

| Order | `displayName` | Report column | Type / format | Notes |
|---|---|---|---|---|
| 1 | `JDE Parent` | `[JDE Parent]` | text | Cognos groups on this (row-span). |
| 2 | `JDE Raw` | `[JDE Raw]` | text | = component 2nd item number. |
| 3 | `JDE Percent` | `[JDE Percent]` | number `0.####` | right-aligned. e.g. `1`, `99`, `9.31`, `55.4802`, `0.113`. |
| 4 | `WERCS Percent` | `[WERCS Percent]` | number `0.####` | right-aligned; blank when no WERCS match. |
| 5 | `WERCS Raw` | `[WERCS Raw]` | text | blank when no WERCS match. |
| 6 | `WERCS Parent` | `[WERCS Parent]` | text | blank when no WERCS match. |

### Columns — **hidden** (present in the query, not shown; parity with Cognos `Conditional Style 1` =
`visibility:hidden;display:none` @ `1=1`):

- `Branch Plant` — used only for the slicer/grouping/filter. **Hide the column** in the table.
- `Difference` — used only for the `≠ 0` filter. The query already applies the filter (`ParentDiffTotal <> 0`),
  so `Difference` need not even be added to the table; if added, hide it.

> There is **no conditional formatting** in this report. `Conditional Style 1` is a *hide* mechanism (always
> `1=1 → hidden`), not a color rule. Do not record CF as a gap and do not build any color rules.

### Sort
Sort the table by **`JDE Parent` ascending, then `JDE Raw` ascending**. This reproduces the screenshot
exactly (parents `1%CAR934, 161107INT, 161107PX, 161183PX.S, 181139INT, 181139IX…`; components alphabetical
within each parent: `DMEA45, ESC5200, SH2O, SH2OF`). The Cognos `<listGroup>` sort on `JDE Percent` is a
group-ordering artifact that the component alpha order dominates; do not sort by `JDE Percent`.

### Grouping / row-span (disclosed cosmetic difference)
Cognos row-spans `JDE Parent` (shows it once per group) and paints a blue group-footer separator bar between
parents. A flat `tableEx` repeats `JDE Parent` on every row and has no separator bar. This is the same
disclosed trade-off accepted on reports 01/03 — faithful data, non-identical grouping chrome. Do **not** try
to force a matrix to regain the row-span; it re-introduces the numeric-aggregation hazard.

---

## 7. Footer / overall count

Cognos's overall footer prints `Count Distinct(JDE Parent)` labelled `Overall - Count Distinct` = the number
of distinct parent BOMs in discrepancy. Reproduce as a **card** (or a measure in the table's total):

```DAX
Overall Count Distinct = DISTINCTCOUNT ( Report[JDE Parent] )
```

Label it `Overall - Count Distinct`. (This replaces the un-portable windowed `COUNT(DISTINCT)` — flag #3.)

---

## 8. Expected data (from the screenshot — page 1 only, 20-row pagination)

Every visible row has JDE columns populated and **all WERCS columns blank** (JDE BOMs absent from WERCS):

| JDE Parent | components (JDE Raw : JDE Percent) |
|---|---|
| `1%CAR934` | CAR934 : 1 · SH2O : 99 |
| `161107INT` | DMEA45 : 9.31 · ESC5200 : 20 · SH2O : 68.69 · SH2OF : 2 |
| `161107PX` | DMEA45 : 9.31 · ESC5200 : 20 · SH2O : 68.69 · SH2OF : 2 |
| `161183PX.S` | D517.S : 4.29 · DIH2O.S : 38.57 · DP060.S : 57.14 |
| `181139INT` | BRIJS2 : 3.9548 · DEEA50 : 4.5198 · DIH2O : 55.4802 · EM221 : 2.2599 · GLUT50 : 0.113 · MD353D : 30.2825 · NEO2512 : 3.2768 · SODMET : 0.113 |
| `181139IX` | (same 8 components as 181139INT; row cut off at bottom of page 1) |

Per-parent JDE% sums to ~100 (a full formula), confirming the percent interpretation and the scaling in
flag #1. **Total row count is not knowable from the screenshot** (page 1 of N; the `Overall - Count Distinct`
value is off-screen). Establish the full count from a data run once WERCS is resolved.

### ✅ Final validation vs the complete Cognos export (2026-07-14)

Two full Cognos exports (data format + report format, both pulled 2026-07-14) settled everything:

- **At branch grain: all 5,019 Cognos rows present in PBI, 0 missing, 0 JDE-percent diffs.**
- Cognos footer `Overall - Count Distinct` = **982**; PBI = **984**. The two extra parents
  (`NYS2106`, `NYCS6202` — 8 rows) exist in live ODS but not in the frozen `DW_LEGACY`
  warehouse (the 3:14 PM Cognos run still lacked them). Disclosed: the rebuild is *current*.
- **18 rows where PBI shows WERCS values that Cognos renders blank** — the DW's
  `BILL_OF_MATERIAL_WERCS` matched literally nothing across the whole report (stale/empty feed);
  our live `T_PROD_COMP` read is *more correct*. Disclosed.
- Report-format export confirms layout parity: title, 6 columns in order, footer card semantics.
  The row-span + blue separator remains the known cosmetic difference (flat `tableEx`).

---

## 9. PBIR authoring notes (author in PBIR, like 02/03)

- **PBIR format is required.** `definition.pbir` with the split visual/page JSON, not the legacy `report.json`.
- `summarizeBy: none` on **every** column of `Report` (both numeric columns included) — a `sum` on any
  identifier corrupts a matrix and would mis-total the percents here.
- If any per-cell formatting is ever added, values-level CF selectors need `dataViewWildcard` — metadata-only
  selectors are silently dropped by PBIR. (Not needed here; no CF.)
- One `nativeQueryRef` per visual field — duplicate refs render-error.
- Add the `Last Refreshed` card to the page (repo standard).

---

## 10. Files in this folder

| File | Purpose |
|---|---|
| `BUILD.md` | this spec |
| `Report.m` | production Power Query for the list — **WERCS subquery is a marked placeholder** |
| `Report.commented.m` | commented master of the above |
| `Branch.m` | production Power Query for the `Branch` prompt (fully runnable) |
| `Branch.commented.m` | commented master of the above |
| `00_verify_tables.sql` | SSMS pre-flight: confirm F3002/F4101/F0006 + **discover the WERCS table** |

Per repo rule, `Report.m` / `Branch.m` ship comment-free; the `.commented.m` masters carry the narrative.

---

## 11. Open questions for the human

1. ~~**WERCS column mapping**~~ ✅ FULLY RESOLVED 2026-07-14 — `T_PROD_COMP` (`F_PRODUCT` /
   `F_COMPONENT_ID` / `F_PERCENT`), exact-equality join, no unit filter; see the §2 resolution
   block for the probe evidence and the chemical-rollup finding.
2. ~~**`IXQNTY` scaling**~~ ✅ ANSWERED 2026-07-14 — live F3002 dump confirms `/10000.0`
   (`997500 + 2500 → 100%`); final tie-out `DIH2O = 55.4802` at validation (flag #1).
3. ~~**Stock-type grain**~~ ✅ ANSWERED 2026-07-14 — **branch grain (`F4102.IBSTKT`)**, proven by
   the third validation pass: switching restored `1%CAR934` (in Cognos, was missing), removed the
   AUBA `.E` parents (`151165PX.E`/`161107PX.E`, provably absent from Cognos), and collapsed
   every parent to a single branch (0 multi-branch parents; the `DENSE_RANK` never fires).
   Final numbers: 4,985 rows / 983 parents / 18 WERCS matches.
4. **Row-span / blue separator** — confirm the flat-table cosmetic (repeated `JDE Parent`, no separator bar)
   is acceptable, as accepted on 01/03.
