# Report 09 — Ivan FC 2023  (BUILD)

Cognos report name: **`1 - Ivan FC 2023`**. Standalone → its own single-page-per-tab PBIP
(5 pages). Rebuild target: reproduce the Cognos report as closely as possible (parity-now).

**Structural twin of report 07 — Ivan SK 2023.** Same SELECT / JOIN / GROUP BY / UOM conversions /
REGION decodes on every page; the two differ **only in WHERE-clause filter literals**. Report 07 was
produced by cloning this report and swapping in SK's literals.

---

## Status — 2026-07-09

> **This report is clean.** No data-layer defects, no HIGH-severity findings, no missing visuals.
> The live open-items list is in `PARITY_TODO.md` in this folder; everything remaining there is
> cosmetic. This section records what changed and what a reviewer must not mistake for a bug.

### PBIP changes do NOT reach the PBIX

`FINAL - for handover\1 - Ivan FC 2023.pbix` was inspected on 2026-07-09: it contains **no
`Last Refreshed` table and no `card` visual**. Someone must open `PBIP\1 - Ivan FC 2023.pbip` in
Power BI Desktop and **re-save / publish**. Until then **nothing below is user-visible.**

### What landed in the PBIP

- **`Last Refreshed` table + `Last Refreshed Label` measure + a `card` visual on every page (5 of 5).**
  The M uses `DateTimeZone.FixedUtcNow()` with explicit US DST handling (switch to `-4`/EDT at the
  2nd Sunday of March 07:00 UTC, back to `-5`/EST at the 1st Sunday of November 06:00 UTC).
  `DateTime.LocalNow()` is **deliberately avoided**: it returns UTC in the Power BI Service but
  *local* time on Desktop, so a Desktop-authored stamp would jump 4–5 hours on publish.
  The stamp is refresh-**start**, not refresh-finish — Power Query does not guarantee the order in
  which queries evaluate, so it fires at some point *during* the refresh. The label therefore reads
  "Last refreshed", never "finished". Format `MMM d, yyyy h:mm:ss AM/PM`, matching the Cognos
  page-footer run-date stamp.

  Worth knowing: **this report already displayed a refresh timestamp before the card was added.**
  `Work_Orders[DATE]` is Cognos's `current_timestamp` → `GETDATE()`, it **is** a displayed column
  (column 22 of 22 on the **Work Order** page, with its own bold-red header), and its
  `formatString: General Date` is **correct** — it is the one date-ish column in the report with no
  `<dataFormat>` element, so Cognos renders it raw with time. It is not a hidden technical column,
  and it was not changed. The card generalises that stamp to all five pages.

- **Date formats corrected to `d MMM, yyyy`** (from `dd MMM yyyy`), matching Cognos
  `<dateFormat dateStyle="medium" displayOrder="DMY"/>`. The tables below are corrected accordingly.
  Two things to note: it is **`displayOrder`, not `dateStyle`, that makes the date day-first**; and
  the old `dd MMM yyyy` was wrong **twice over** — a leading-zero day, *and* a missing comma.

### Checked and cleared — Cognos defines neither of these anywhere in 07–10

Two of Rohit's escalations on other reports were about exactly these, so record the result:

- **Conditional formatting: none.** `advancedConditionalStyle`, `conditionalStyleRefs`,
  `conditionalStyleRef`, `styleCase` and `reportCondition` are all **0** in `Report XML.md`.
  The static styling that *does* exist (red bold headers, 1pt black borders) **is** ported.
- **Grouping: none.** `<listGroup>` = 0, `<listGroupFooter>` = 0, `<crosstab>` = 0. All five Cognos
  visuals are plain `<list>` elements.

The five flat `tableEx` visuals are therefore the **correct** rebuild, not a shortcut or an
omission. Converting any of them to a matrix would be a regression.

Also clear: **zero `summarizeBy: sum` columns.** All 86 columns across the five tables are
`summarizeBy: none`, and every visual projection is a raw grouped `Column` reference with **zero**
`Aggregation` nodes. The matrix-corruption trap that affected report 01 **cannot occur here.**

### The three known Oracle→T-SQL defects for this report family

| Defect | Status here | Evidence |
|---|---|---|
| (a) Oracle `trim()=''` is NULL, not ported → `Inventory_HP` returns 0 rows | **FIXED** | `Inventory_HP.m:71` carries **both** the `IS NULL` and the `= ''` arm |
| (b) Cognos render-DISTINCT missing → `Work_Orders` over-counts | **FIXED** | `Work_Orders.m:67` `SELECT DISTINCT` (also `Safety_Stock_HP.m:36`, `Sales_Order_Summary.m:96`) |
| (c) F4211-only sales history decays as lines purge to F42119 | **N/A — does not apply, and adding it would be a bug** | This report has no sales-*history* page. `Sales Order Summary` reads **open** orders from F4211, filtered `SDNXTR NOT IN ('570','580','620','999')` at `Sales_Order_Summary.m:160`. Purged lines are out of scope *by construction*. `Generated SQL (Cognos - raw).sql` has **0** `F42119` references, and so does every `.m` here. |

Defect (c) applies to reports **08 and 10** (which do have a Sales History page), not to 07/09.

### ⚠ THE `use="prohibited"` TRAP — a false bug was raised and retracted on exactly this

Three queries (`Inventory`, `Inventory - New`, `Safety Stock - New`) each carry a **second**
`[Bulk Item] in (...)` filter marked `use="prohibited"` — a disabled leftover. It does **not**
survive into the generated SQL, so it is correctly **not** applied. In this report it is a **stale
subset of this report's own active list** (25 literals / 15 distinct, against the active 31/18); it
omits `ME90640.S`, `ME92040.S` and `MG7140.S`.

**The trap:** the prohibited list and the active list **share their leading literals**. Grepping the
`.m` for a handful of item codes therefore *cannot tell the two lists apart*, and will make the
active list look like it is "over-filtering". **Compare item COUNTS, not membership.**
Set-differencing the active Cognos lists against the `.m` `IN (...)` lists gives an exact match
(**18/18 distinct on all four queries**) with **zero prohibited-only items leaked**.

Had the stale filter been ANDed in, those three pages would silently drop the three newest bulk items.

*(In report 07 the prohibited filter is instead **this** report's FC whitelist — strong evidence that
the SK report was cloned from this one inside Cognos. Harmless in both, since prohibited filters are
correctly ignored in both.)*

### Hard-coded date literal — stale, not breaking

The Work Orders page carries `Start Date >= 2025-11-01` (report 07's twin uses `2026-03-01`), copied
verbatim from Cognos. Unlike the **forecast** reports 08/10 — whose frozen *upper* bound has made
Cognos return zero rows since 2026-07-01 — this is a **lower** bound, so it does not break anything.
It does silently **widen** the history window's meaning as time passes: what was "the last ~8 months"
when it was written is a lengthening window today. Cognos has the same landmine. Someone should
decide whether this is an intentional anchor date or an unmaintained literal.

### `PRODCTL.F0005`

`Sales_Order_Summary.m` reads `PRODCTL.F0005` for the country UDC decode — a **different schema from
`PRODDTA`**, so `PRODDTA` grants alone are **insufficient**. Unlike reports 08/10, this report *does*
name it, both in the `.m` `SOURCE:` header (`Sales_Order_Summary.m:17-18`) and under Shared
conventions below. It is still missing from the handover's required-grants list.

### Remaining gaps: cosmetic only

Cognos **left**-aligns numeric-ID and date columns (`Customer Code`, `Global Parent`, `Order Number`,
`WO Number`, and all 7 date columns); Power BI right-aligns `int64` / `dateTime` by default. And
Cognos's `<noDataHandler>` "No Data Available" empty-state message has **no Power BI equivalent** on
a `tableEx`. Neither blocks handover. See `PARITY_TODO.md` items 6.1 and 6.2.

**One asymmetry that favours this report:** report 07's `Sales Orders` sub-query filter names 12
branch plants while its `Item Information` filter names 6, so 07 silently drops 6 plants at the join.
This report's two filters agree at 6 plants, so it has no such trap. **If anyone "harmonises" the two
reports, do not copy SK's 12-plant list into this one.**

---

## Shared conventions (all 5 pages)
- **Source:** `Sql.Database("ODSPROD","ODS")` → `Value.NativeQuery(..., [EnableFolding=true])`.
  Business tables in **`PRODDTA`**; the country UDC decode on page 3 uses **`PRODCTL.F0005`**.
- **Header style:** EVERY column header is **bold red** — CSS `font-weight:bold;color:red` on a
  `1pt solid black` border; body cells also `1pt solid black`. Apply red bold column headers +
  thin black gridlines to every table visual.
- **Number columns** (`numberFormat decimalSize="0"`) → format **`#,0`** (whole number, thousands
  sep). **ID numerics** (WO Number, Order Number, Customer Code, Global Parent) have NO number
  format in Cognos → format **`0`** (no thousands separator).
- **Date columns** (`dateFormat dateStyle="medium" displayOrder="DMY"`) → format **`d MMM, yyyy`**
  (e.g. `9 Jul, 2026`). It is **`displayOrder`, not `dateStyle`**, that makes the date day-first.
  *(Corrected 2026-07-09 from `dd MMM yyyy`, which was wrong twice: leading-zero day, missing comma.)*
  Page-1 `NOW` (label "Date") and page-2 `DATE` are "as of now" stamps (`GETDATE()`). Page-2 `DATE`
  keeps `formatString: General Date` — it is Cognos's raw `current_timestamp` with no `<dataFormat>`,
  so date+time is the faithful rendering. Do not "fix" it to a date-only format.
- **Sort:** Cognos `order by` was stripped from every query (illegal inside PBI's folded
  `SELECT * FROM (<q>)`). **Set the sort in each visual** using the keys listed per page.
- **Whitelist:** the long `Bulk Item IN (...)` list (**31 literals, 18 distinct** — Cognos's own list
  repeats items) is kept **verbatim** in each `.m`. Do not deduplicate; duplicates are harmless
  inside `IN (…)` and removing them would diverge from the source. The Report XML also carries a
  second `use="prohibited"` Bulk-Item filter (25 literals / 15 distinct) on three queries — it did
  **NOT** survive into the generated SQL, so it is **not** applied (we match the generated SQL, the
  source of truth for what ran).
  **⚠ The two lists share their leading literals — grepping the `.m` for a few item codes cannot
  distinguish them. Compare COUNTS.** See the trap note under Status.
- **Julian dates:** `PRODDTA.JUL2DATE(col)` (guarded `col>0`) →
  `CASE WHEN col>0 THEN DATEADD(DAY,(col%1000)-1,DATEFROMPARTS(1900+(col/1000),1,1)) END`.
- **REGION decodes differ per query** — see each page. Page 1 & 2 default `'ERROR'`; pages 4 & 5
  have NO Oracle default (even-arg `decode`) → `ELSE NULL`.

| # | Page name | Query object | `.m` file | Table (suggested) | Cols | Rows (xlsx, excl header) |
|---|---|---|---|---|---|---|
| 1 | Inventory | Inventory | `Inventory.m` | `Inventory` | 16 | **85** |
| 2 | Work Order | Work Orders | `Work_Orders.m` | `Work_Orders` | 22 | **413** |
| 3 | Sales Orders | Sales Order Summary | `Sales_Order_Summary.m` | `Sales_Order_Summary` | 29 | **22** |
| 4 | Inventory HP | Inventory - New | `Inventory_HP.m` | `Inventory_HP` | 11 | **243** |
| 5 | Safety Stock HP | Safety Stock - New | `Safety_Stock_HP.m` | `Safety_Stock_HP` | 9 | **140** |

Validation source: `Ivan Reports/Ivan FC 2023.xlsx` (one sheet per page). Row counts above are the
targets. No slicers/prompts/on-page plaintext exist in this report (pure list pages).

---

## Page 1 — Inventory  (`Inventory.m`, 16 cols)
Grain: lot/location. Flat `SELECT + GROUP BY` over F4102/F554101/F41021/F4101.
Filter: Branch in (SHAN,MUM3,SING,SNG4,AUBA,AUB2); on-hand>0; Bulk in whitelist.

Rendered columns (left→right) with type / format / display label:
| # | Column | Type | Format | Label shown |
|---|---|---|---|---|
| 1 | REGION | text | — | **Site** |
| 2 | Branch Plant | text | — | Branch Plant |
| 3 | Global Bulk Item | text | — | Global Bulk Item |
| 4 | Bulk Item | text | — | Bulk Item |
| 5 | 2nd Item Number | text | — | 2nd Item Number |
| 6 | Stock Type | text | — | Stock Type |
| 7 | Lot Number | text | — | Lot Number |
| 8 | Location | text | — | Location |
| 9 | Status | text | — | Status |
| 10 | Quantity On Hand | number | `#,0` | Quantity On Hand |
| 11 | Hard Commit | number | `#,0` | Hard Commit |
| 12 | Primary UOM | text | — | Primary UOM |
| 13 | Master Planning Family | text | — | **MPF** |
| 14 | NOW | date | `d MMM, yyyy` | **Date** |
| 15 | OH KG | number | `#,0` | OH KG |
| 16 | OH LB | number | `#,0` | OH LB |

Sort keys (visual): **Global Bulk Item ↑, Bulk Item ↑, 2nd Item Number ↑**.
REGION decode: SING/SNG4→Singapore, MUM3→India, SHAN→China, AUBA/AUB2→Aubange,
CINC/CIN2/CIN4→Americas, **ELSE 'ERROR'**.

**Parity quirks (faithful; "correct" form noted):**
- `OH KG` / `OH LB` re-express the same on-hand SUM in one unit — KG→as-is, LB↔×0.453593 / ÷0.453593,
  EA→×20 (KG) / ×44 (LB), **ELSE sentinel `100000`**. (*Correct:* the EA multipliers and the `100000`
  fallback are per-item hacks; a real model would drop unknown UOMs, not emit 100000.)
- `MIN(IMUOM1)` inside the CASE while `GROUP BY IMUOM1` — MIN over the group == the group's single
  UOM. Cognos emitted its aggregate wrapper; kept.

No conditional formatting on this page.

---

## Page 2 — Work Order  (`Work_Orders.m`, 22 cols)  ⚠ the fan-out
**Two-level query** kept exactly as Cognos emitted: inner `FO` = flat SELECT over 5 tables
(F4801/F3111/F554101/F4101/F4102) with **window aggregates** over a big PARTITION (the WO×component
grain) and **no GROUP BY**; outer applies **`WHERE FO.QtyRequested > 0`** (Cognos' `WHERE T0.C20>0`).
The fan-out returns one row per source (WO-line × part) row — **413 rows** — reproduced faithfully.

**Cn→business mapping** (raw SQL used opaque `T0.Cn`; decoded via the XML dataItem order + the detail
filters, verified vs the xlsx):
- `[Quantity Requested]` = `AVG(WAUORG/10000) OVER P`  ← the `>0` filter is on this column.
- `[Quantity Completed]` = `AVG(WASOQS/10000) OVER P`
- `[Issued Quantity]` = `SUM(WMTRQT/10000) OVER P`  ·  `[Ordered Quantity]` = `SUM(WMUORG/10000) OVER P`
- (Cognos emitted sum+count pairs to build the two averages; `AVG() OVER` is identical and legal.)

Row-level filters: Component 2nd item in (BRIJS2.E, BRIJS20.E, BRIJS2.S, BRIJS20.S); Issued+Ordered>0;
Start Date ≥ 2025-11-01; 2nd Item `NOT LIKE '%-%'`; WAUOM in (LB,KG); WASRST not in (MM).

Rendered columns:
| # | Column | Type | Format | Source |
|---|---|---|---|---|
| 1 | REGION | text | — | decode(WAMMCU) |
| 2 | STATE | text | — | derived (see below) |
| 3 | Branch Plant | text | — | WAMMCU |
| 4 | WO Number | number | `0` | WADOCO |
| 5 | Global Bulk Item | text | — | IMGBLK |
| 6 | Bulk Item | text | — | IMBULK |
| 7 | 2nd Item Number | text | — | WALITM |
| 8 | WO Status | text | — | WASRST |
| 9 | Start Date | date | `d MMM, yyyy` | WASTRT |
| 10 | Completed Date | date | `d MMM, yyyy` | WASTRX |
| 11 | Quantity Requested | number | `#,0` | AVG(WAUORG) |
| 12 | Quantity Completed | number | `#,0` | AVG(WASOQS) |
| 13 | Component 2nd Item Number | text | — | WMCPIL |
| 14 | Component UOM | text | — | WMUM |
| 15 | REQUEST KG | number | `#,0` | derived |
| 16 | COMPLETE KG | number | `#,0` | derived |
| 17 | P7 ISSUED KG | number | `#,0` | derived |
| 18 | P7 ORDERED KG | number | `#,0` | derived |
| 19 | P7 ISSUED LB | number | `#,0` | derived |
| 20 | P7 ORDERED LB | number | `#,0` | derived |
| 21 | P7 REMAINING | number | `#,0` | derived |
| 22 | DATE | datetime | — | GETDATE() |

Sort keys (visual): **REGION ↑, Start Date ↑, Completed Date ↑**.
REGION decode (this page): SING→Singapore, CINC→Americas, AUBA→Aubange, CIN2→Americas, **ELSE 'ERROR'**.

**Derived columns** (Cognos-render formulas re-computed in SQL so the table has all 22 typed columns):
- `STATE` = `'OPEN'` when `Quantity Completed = 0` AND `WO Status in ('20','30','90')` AND
  `[P7 ISSUED KG] = 0`, else `'COMPLETE'`.
- `REQUEST KG` / `COMPLETE KG` = if `WAUOM='LB'` → qty×0.453593 else qty (on Req / Comp resp.).
- `P7 ISSUED/ORDERED KG` = if `Component UOM='LB'` → qty×0.453593 else qty.
- `P7 ISSUED/ORDERED LB` = if `Component UOM='KG'` → qty÷0.453593 else qty.
- `P7 REMAINING` = `P7 ORDERED LB − P7 ISSUED LB` (inlined).

**Parity quirks:** the double window-aggregate fan-out and the AVG-based Quantity Requested/Completed
are Cognos artifacts. (*Correct:* a clean model would `GROUP BY` the WO/component grain once and
`SUM` the parts, not fan out then AVG.) No conditional formatting.

---

## Page 3 — Sales Orders  (`Sales_Order_Summary.m`, 29 cols)
Raw was a **5-CTE `WITH` chain** → rewritten as **nested derived tables** (no leading WITH, folds):
`Item_Information8 (II)`, `F4211_Open_Sales_Orders (os)`, `F4211_F0006_join_to_F42140 (f0006j)`,
`F42140__CSR (csr)`, `Sales_Orders7 (SO7)`. Final = **`II LEFT OUTER JOIN SO7`** on Branch_Plant +
2nd Item, then `GROUP BY` + KG/LB CASE. Country name from **`PRODCTL.F0005`** (`DRSY='00  '`,`DRRT='CN'`).
`os` open-order filters: SDLNTY='S', SDPQOR>0, SDNXTR not in (570,580,620,999), SDMCU in the 6 branches.

Rendered columns:
| # | Column | Type | Format | Label |
|---|---|---|---|---|
| 1 | Order Company | text | — | Order Company |
| 2 | Customer Code | Int64 | `0` | Customer Code |
| 3 | Customer Name | text | — | Customer Name |
| 4 | Customer Segmentation | text | — | **Segmentation** |
| 5 | Global Parent | Int64 | `0` | Global Parent |
| 6 | Country Name | text | — | Country Name |
| 7 | Branch Plant | text | — | Branch Plant |
| 8 | Order Number | Int64 | `0` | Order Number |
| 9 | Hold Orders Code | text | — | Hold Orders Code |
| 10 | Global Bulk Item | text | — | Global Bulk Item |
| 11 | Bulk Item | text | — | Bulk Item |
| 12 | 2nd Item Number | text | — | 2nd Item Number |
| 13 | Next Status | text | — | Next Status |
| 14 | Last Status | text | — | Last Status |
| 15 | ORDER KGs | number | `#,0` | ORDER KGs |
| 16 | ORDER LBs | number | `#,0` | ORDER LBs |
| 17 | Primary Quantity Ordered | number | `#,0` | **Prim QTY** |
| 18 | Primary UOM | text | — | **UOM** |
| 19 | Secondary Quantity Ordered | number | `#,0` | **2nd QTY** |
| 20 | Secondary UOM | text | — | **UOM2** |
| 21 | Order Date | date | `d MMM, yyyy` | Order Date |
| 22 | Requested Date | date | `d MMM, yyyy` | Requested Date |
| 23 | Promised Ship Date | date | `d MMM, yyyy` | Promised Ship Date |
| 24 | Scheduled Pick Date | date | `d MMM, yyyy` | Scheduled Pick Date |
| 25 | CSR Name | text | — | CSR Name |
| 26 | TM Name | text | — | TM Name |
| 27 | Customer PO | text | — | Customer PO |
| 28 | Master Planning Family | text | — | **MPF** |
| 29 | Stock Type | text | — | Stock Type |

Sort keys (visual): **Order Company ↑, Global Bulk Item ↑, Bulk Item ↑, Scheduled Pick Date ↑**.

**Parity quirks:**
- `ORDER KGs`/`ORDER LBs`: `MIN(Primary_UOM)` inside CASE while `GROUP BY Primary_UOM`; EA×20 (KG) /
  ×44 (LB); **ELSE sentinel `1000000`**.
- **Scheduled Pick Date == Promised Ship Date** (both = SDPDDJ; Cognos aliased the same column twice).
  The `.m` emits the same value in both output columns.
- Final `WHERE SO7.Branch_Plant=II.Branch_Plant AND SO7.2nd_Item=II.2nd_Item` turns the LEFT JOIN into
  an inner join (Cognos quirk — kept). `CMRTYPE = ISNULL(trim(MCRP01),'-')+'GTM'` and
  `TM Name = ISNULL(sales-rep name,'Unassigned')` reproduced verbatim.

No conditional formatting.

---

## Page 4 — Inventory HP  (`Inventory_HP.m`, 11 cols)
Grain: lot/location. Same 4 tables as page 1 but the **"available lots" variant**: Status IS NULL or
in (T,B,Q,H); Branch in (AUBA,AUB2,SING,SNG4,SHAN,MUM3); Bulk in whitelist.

Rendered columns: **REGION, Branch Plant, Global Bulk Item, Bulk Item, 2nd Item Number, Location,
Lot Number, Status, Primary UOM, Quantity On Hand(`#,0`), LB(`#,0`)** — text except the last two numbers.
Sort keys (visual): **Global Bulk Item ↑, Bulk Item ↑, 2nd Item Number ↑**.
REGION decode (this page): CINC/CIN2/CIN4→Americas, AUBA/AUB2→EMEA, SING/SNG4→PacRim, MUM3→India,
SHAN→China, **ELSE NULL** (no Oracle default).
Parity: `LB` = LB→as-is, KG→÷0.453593, EA→×40, **ELSE 0**; `MIN(IMUOM1)` inside CASE while GROUP BY
IMUOM1. No conditional formatting.

---

## Page 5 — Safety Stock HP  (`Safety_Stock_HP.m`, 9 cols)
`SELECT DISTINCT` (no aggregation) over F4102/F554101/F4101; item-branch grain (`IBSAFE`).
Branch in (AUBA,AUB2,SING,SNG4,SHAN,MUM3); Bulk in whitelist.

Rendered columns: **REGION, Branch Plant, Global Bulk Item, Bulk Item, 2nd Item Number, Primary UOM,
Safety Stock(`#,0`), LB Safety Stock(`#,0`), REGION** — text except the two numbers.
> **REGION appears TWICE** (columns 1 and 9; col 9 right-aligned). The `.m` produces ONE `[REGION]`
> column — **place the `[REGION]` field twice in the table visual** (do not duplicate it in the model).
Sort key (visual): **REGION ↑**.
REGION decode: same as page 4 (…→Americas/EMEA/PacRim/India/China, **ELSE NULL**).
Parity: `LB Safety Stock` uses **IMUOM1 directly** (no MIN — no GROUP BY): LB→as-is, KG→÷0.453593,
EA→×40, **ELSE 0**. No conditional formatting.

---

## Validation checklist (tie to the live Cognos panel / xlsx)
- [ ] Server = ODSPROD; refresh succeeds (all 5 native queries fold, no "Incorrect syntax near 'WITH'"
      / no ORDER-BY error).
- [ ] Row counts: Inventory **85**, Work Order **413**, Sales Orders **22**, Inventory HP **243**,
      Safety Stock HP **140**.
- [ ] Column order & count per page match the tables above (16 / 22 / 29 / 11 / 9).
- [ ] Headers render **bold red** with thin black gridlines on every page.
- [ ] Number cols `#,0`; ID numerics `0` (no comma); dates **`d MMM, yyyy`**; page-2 `DATE` stays
      `General Date`.
- [ ] Display labels applied: p1 Site/MPF/Date; p3 Segmentation/Prim QTY/UOM/2nd QTY/UOM2/MPF.
- [ ] Sort keys set per page (see each section).
- [ ] Page-2 spot check (from xlsx): a KG-component row has `P7 ISSUED LB = P7 ISSUED KG / 0.453593`
      and `P7 REMAINING = P7 ORDERED LB − P7 ISSUED LB`; STATE='OPEN' only when QtyCompleted=0 &
      WO Status∈(20,30,90) & P7 ISSUED KG=0.
- [ ] Page-5: REGION shown in both column 1 and column 9.
- [ ] **Open `PBIP\1 - Ivan FC 2023.pbip` in Power BI Desktop, re-save, publish** — otherwise the
      `Last Refreshed` card is invisible to users (see Status).
- [ ] Confirm `PRODCTL.F0005` is granted, not just `PRODDTA` — the page-3 country decode needs it.

## Self-check (intake)
All 5 `.m`: **paren-balanced** (Inventory 58/58, Work_Orders 139/139, Sales_Order_Summary 101/101,
Inventory_HP 51/51, Safety_Stock_HP 18/18), **no `WITH`**, **no `ORDER BY`**, `[bracket]`-aliases
balanced, string literals balanced. SQL uses `[bracket]` identifiers only (no embedded `"`), so the
M string needs no escaping.

---

## SEE ALSO

`PARITY_TODO.md` in this folder carries the live, prioritised open-items list, the
twin-divergence analysis against report 07, and the "faithful-but-surprising" items to brief
Rohit on — chiefly that **`Scheduled Pick Date` is identical to `Promised Ship Date`** (Cognos
aliases the same physical column `SDPDDJ` twice; `SDPPDJ` never appears), that **`Safety Stock HP`
shows `REGION` twice**, and that the **UOM sentinel values** differ per page (`100000` / `1000000` /
`0`) because Cognos's own authoring is inconsistent. All three are correct. This file records *how
the thing was built and why*; that file records *what is still owed*.
