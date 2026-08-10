# Report 06 — CM PO Live

**Cognos source:** Public Folders > Michelman Reporting > Production and Shipping > Contract Manufacturing Orders > *Dashboard - CM Overview LIVE* — panel 5 ("CM PO Live").
**Report name (XML `reportName`):** `CM - PO Live`

> **This is page 5 of the shared 5-page "CM Overview LIVE" PBIP** (panels 02–06). You author this intake `.m` + `BUILD.md`; the builder agent assembles the visual on page 5. Do **not** touch the PBIP.

A single flat table of open contract-manufacturing purchase-order lines whose promised date is within the last 90 days, restricted to a fixed whitelist of "Bulk Items", sorted by promised date. Two optional prompts (a promised-date range and a single region) narrow it.

---

## Status — 2026-07-09

> **This document is the original build spec, updated in place.** The live open-items list is `PARITY_TODO.md` in this folder — read that first. This page has more outstanding cosmetics than 04 or 05 (slicer titles not red, missing trailing colons, `Next Status` not right-aligned).

**The data layer is clean.** Column set, column order, header labels, sort order, number/date formats and both prompts are faithful to Cognos; there is no conditional formatting, grouping or subtotal in the Cognos source. Every model column is `summarizeBy: none`.

- **Date formats corrected 2026-07-09.** `Requested Date` and `Promised Date` are `formatString: MMM d, yyyy` — **month-first** (`Jun 19, 2026`). Cognos drives day/month order with **`displayOrder="DMY"` on the `<dateFormat>` element, *not* `dateStyle`**; this report's `<dateFormat>` carries **no** `displayOrder`, so it is month-first. Report 04's does, so its dates are day-first (`1 Jul 2026`). The asymmetry is verbatim from each report's own XML and is **not** a copy-paste bug.
- **A `Last Refreshed` table + `Last Refreshed Label` measure + a `card` visual** now sit on this page and all 7. See below. **This card matters more here than on 04/05** — the as-of date is load-bearing, because of the rolling window described next.

**Prompts map 1:1 to slicers — verified, not assumed.** Both Cognos prompts are `use="optional"`, so the filter applies **only when the prompt is answered**; an unanswered prompt shows all rows. Neither Power BI slicer carries a baked-in default selection, so the page lands unfiltered exactly as Cognos does. The date prompt binds `Promised Date` (not `Requested Date`), and so does the slicer.

**PBIP changes do not reach the PBIX.** `FINAL - for handover\Dashboard - CM Overview LIVE.pbix` was last written 2026-07-08; the PBIP edits landed 2026-07-09. **Someone must open `CM Overview LIVE.pbip` in Power BI Desktop, re-save, and republish.** Until then nothing above is user-visible.

### VERIFIED CORRECT — not a gap: the `use="prohibited"` region filter is a disabled DUPLICATE

_Recorded because it looks like a bug on first read. **It was raised and retracted once already. Do not re-raise it at handover, and do not remove or default the region slicer.**_

Report 06 is the only one of 04/05/06 that contains a `use="prohibited"` filter, and it is `[REGION] in ?Select_Region?`. It is tempting to read that as "the region prompt is inert in Cognos, so our slicer over-filters." **It is not.** There are **two copies of that filter, on two different queries:**

| Query | Filter | `use=` | Effect |
|---|---|---|---|
| `Purchase Orders` (upstream child query) | `[REGION] in ?Select_Region?` | `optional` | **ACTIVE** when the prompt is answered |
| `PO Summary` (the query the list binds to, `<list refQuery="PO Summary">`) | `[REGION] in ?Select_Region?` | `prohibited` | disabled — a redundant duplicate |

`PO Summary`'s dataItems are all `[Purchase Orders].[…]` and `[Item Branch].[…]` — `Purchase Orders` is a child query joined into it, so restricting `REGION` upstream restricts the list. **The Cognos region prompt does filter this report, and a Power BI slicer on `CM_PO_Live[REGION]` is correct behaviour, not over-filtering.** The conclusion is robust either way: if `prohibited` meant "active", both copies filter; if it means "disabled", the upstream `optional` copy still filters.

Report 04 has the identical architecture minus the duplicate, and its region prompt is uncontroversially live — direct internal evidence for reading 06 the same way. The likeliest history is that Report Studio auto-copied the filter when `REGION` was dragged into `PO Summary`, and the author disabled the duplicate to avoid applying it twice. **General lesson: a `prohibited` filter frequently sits beside an active `optional` twin — never judge one in isolation.** (Report 02 has the same shape on its `Owner` prompt.)

### Behaviour difference: the 90-day floor evaluates at REFRESH time, not view time

Cognos re-evaluates `to_date(sysdate) - 90` on **every run**. `CM_PO_Live.m` folds it to `AND d.Promised_Date >= DATEADD(DAY, -90, CAST(GETDATE() AS date))`, so in an **import** model the window is **fixed at the last refresh**. A report left unrefreshed for a week silently shows a window ending a week ago. Reports 04 and 05 have no time-dependent predicate and are immune.

The `Last Refreshed` card means the staleness is at least **visible** — the page now states its own as-of timestamp. **Scheduling a daily refresh in the Power BI Service is still outstanding**, and is the recommended fix. The alternative — moving the floor out of the query into a report-level filter or DAX so it re-evaluates at view time — changes the folded query and the row count, so it would need re-validation. Not recommended.

### Last Refreshed card

`Last Refreshed.m` computes one row via `DateTimeZone.FixedUtcNow()` plus an explicit US-Eastern DST rule (second Sunday in March → first Sunday in November), yielding an `EDT`/`EST` label. `DateTime.LocalNow()` is **deliberately avoided**: it returns UTC in the Power BI Service but machine-local time on Desktop, so the two would disagree. The stamp is refresh-**start**, not finish — Power Query's evaluation order across queries is not deterministic — which is why the label reads "Last refreshed", not "finished". Format `MMM d, yyyy h:mm:ss AM/PM` matches the Cognos page-footer stamp, which is month-first in every report regardless of what the table's own date columns use. The card covers the Cognos footer's run date and run time; the **page number** has no Power BI analogue and is not reproduced.

---

## 1. Query (Power Query)

| Query | File | Feeds |
|---|---|---|
| `CM_PO_Live` | `CM_PO_Live.m` | The one table on the page (Cognos list `List1`, query object `PO Summary`) |

Connects to `Sql.Database("ODSPROD","ODS")` and runs native T-SQL against `PRODDTA` (folding on). Paste into **Power BI Desktop → Get Data → Blank Query → Advanced Editor**. Set the server name to match your SSMS connection if it differs from `ODSPROD`.

The Cognos report has 3 query objects that matter (`Item Branch`, `Purchase Orders`, and their join `PO Summary`); `Query1`/`Query2` are empty stubs. All three are folded into the single `CM_PO_Live.m` as nested derived tables — no CTEs (a leading `WITH` breaks folding). The tiny `REGION` distinct-list query (Statement 1 in the raw SQL) is **not** rebuilt as its own query — see §4.

---

## 2. Cognos → PBI column mapping

Rendered left → right (from `List1` `listColumns`). The header label is the dataItem's `label` if present, else its name (all confirmed from the XML).

| # | On-page header | Query column | JDE field / derivation |
|---|---|---|---|
| 1 | **Company** | `Company` | `F4311.PDKCOO` |
| 2 | **Branch** | `Branch Plant` | `trim(F4311.PDMCU)` |
| 3 | **PO #** | `Purchase Order Number` | `F4311.PDDOCO` |
| 4 | **Line #** | `Line Number` | `F4311.PDLNID / 1000` |
| 5 | **Bulk Item** | `Bulk Item` | `trim(F554101.IMBULK)` (via F4102⋈F4101⋈F554101) |
| 6 | **Item** | `2nd Item Number` | `trim(F4311.PDLITM)` |
| 7 | **QTY** | `Primary Quantity` | `SUM(F4311.PDPQOR / 10000)` |
| 8 | **Open QTY** | `Open Quantity` | `SUM(F4311.PDUOPN / 10000)` |
| 9 | **2nd QTY** | `Secondary Quantity` | `SUM(F4311.PDSQOR / 10000)` |
| 10 | **Next Status** | `Next Status` | `F4311.PDNXTR` (screenshot shows `400`) |
| 11 | **Requested Date** | `Requested Date` | `F4311.PDDRQJ` (Julian → date) |
| 12 | **Promised Date** | `Promised Date` | `F4311.PDPDDJ` (Julian → date) |
| 13 | **Vendor Name** | `Vendor Name` | `trim(F0101.ABALPH)` via `PDAN8 = ABAN8` |

Put the columns in the table visual in **exactly this order**, and set each header's display name to the bold on-page label above (the query column names differ slightly — e.g. query `2nd Item Number` displays as **Item**, `Primary Quantity` as **QTY**).

`REGION` is an extra column on the query — **do not add it to the table**; it drives the region slicer only (§4).

---

## 3. Visual fidelity

Everything below is pulled from the Cognos Report XML for this panel.

### Page title (Text box)
- **`CM - PO Live`** — **blue**. XML: page-header `textItem` with `CSS value="color:blue"`. Blue = CSS named `blue` = **`#0000FF`**. (Report-01 used `#001eff`; this panel's XML uses plain `blue` — match `#0000FF`.)

### Table
- Visual type: **Table**.
- **Column headers: red, bold.** XML: every `listColumnTitle` has `CSS value="font-weight:bold;color:red;...;border:1pt solid black"`. Red = CSS named `red` = **`#FF0000`** (not report-01's `#e40011` — this panel uses plain `red`). Header text left-aligned.
- **Cell borders:** `1pt solid black` on every title and body cell (`border-collapse:collapse`). Apply a thin black gridline/border to the table if matching the boxed look.
- **Alignment:** the three numeric columns (**QTY**, **Open QTY**, **2nd QTY**) and **Next Status** are `text-align:right`; all others `text-align:left`.
- **No row-level conditional formatting.** Confirmed — there are no `conditionalStyles`/`styleReference` rules or data-bar/color-by-value on any column; the only colors are the static red headers and blue title.

### Number format
- **QTY / Open QTY / 2nd QTY:** whole number, **0 decimals**. XML: `numberFormat decimalSize="0"` on all three. Use `#,0` (thousands separator, 0 decimals) per house convention.

### Date format
- **Requested Date / Promised Date:** XML `dateFormat dateStyle="medium"` with **no `displayOrder`** → medium date, **month-first**, e.g. **`Jul 1, 2026`**. Shipped as `formatString: MMM d, yyyy` (corrected 2026-07-09). Type is `date` (no time). Report 04's dates are day-first (`1 Jul 2026`) because its `<dateFormat>` carries `displayOrder="DMY"` — **that attribute, not `dateStyle`, is what sets the order.** The difference between the two reports is verbatim from their XML; do not harmonise them.

### Sort
- **Promised Date ascending.** XML: `sortList → sortItem refDataItem="Promised Date" sortOrder="ascending"` (and `rp_sort="a"` on that column). The `.m` intentionally **omits `ORDER BY`** (an ORDER BY inside the folded subquery is illegal in SQL Server — PBI wraps the query as `SELECT * FROM (<query>)`), so **set the sort in the visual**: Promised Date ascending. PBI table sorting puts blanks last, matching Cognos's nulls-last.

---

## 4. Prompts → slicers

The page top has a Cognos prompt table with this **exact plaintext** (red, bold), then a Finish button:

```
Enter the Date Range:  Beginning  [ date box: 1 - Start ]     and End Date  [ date box: 2 - End ]
Select the Region:  [ dropdown: Select_Region ]   [ Finish ]
```

Reproduce the labels as-is if you want fidelity; otherwise use native slicers:

### Region slicer — **Select the Region**
- Cognos `selectValue parameter="Select_Region"`, `multiSelect="false"` (single-select), sourced from the distinct `REGION` list.
- **Build:** a **single-select slicer on `CM_PO_Live[REGION]`.** REGION is already a column on the table (decode of Branch Plant), so its slicer values are the same set Cognos listed (Americas / Aubange / Shanghai / Singapore / Mumbai / OTHER). No separate region query or relationship needed.
- The Cognos filter is **optional** (`use="optional"` on the live `Purchase Orders` query; the copy on `PO Summary` is `use="prohibited"` = disabled) → default = no region selected = **all regions**. Set the slicer to allow "no selection = show all" (single-select but not forced).
- **The `prohibited` copy is a disabled duplicate of the active `optional` one, and the slicer is correct as built.** This reads like a bug and has already been raised and retracted once. Full explanation in the Status block above ("VERIFIED CORRECT — not a gap") and in `PARITY_TODO.md` §5.1. **Do not remove or default the region slicer.**

### Promised-date range slicer — **Enter the Date Range**
- **It DOES filter, but optionally.** The `Purchase Orders` query carries `detailFilter use="optional"`: `[Promised Date] between ?1 - Start? and ?2 - End?`. Because it's optional and no values were supplied when the SQL was captured, the Generated SQL shows only the **hard** floor `Promised Date >= to_date(sysdate)-90` and no BETWEEN — that hard floor is already in the `.m` and always applies.
- **Build:** add a **Between slicer on `CM_PO_Live[Promised Date]`.** Left empty it shows everything from today-90 forward (the base population); when the user picks a start/end it narrows within that. Do **not** hard-code the range into the query.

> Net: the `.m` reproduces the always-on population (open qty > 0, promised date ≥ today−90, bulk-item whitelist). The two prompts become optional slicers layered on top; neither changes the base query.

---

## 5. Refresh / "as of" behavior
The 90-day floor uses `CAST(GETDATE() AS date)` for `sysdate`, so the table is always **"as of the last refresh."** Schedule a daily refresh so the rolling 90-day promised-date window stays current. No hard report parameters (both prompts are optional slicers).

> **This is a real behaviour difference from Cognos, not just an operational note.** Cognos re-evaluates `to_date(sysdate) - 90` on every run; the folded `.m` fixes the window at **refresh** time. Left unrefreshed for a week, the report silently shows a window ending a week ago. The `Last Refreshed` card makes that visible; **scheduling the daily refresh is still outstanding.** See the Status block.

---

## 6. Parity notes (reproduced on purpose — numbers tie to the live panel)

1. **Double-SUM (group nesting).** Cognos aggregates the quantities in `Purchase_Orders5` (`SUM(PDPQOR/10000)`, etc.) and then `SUM`s them again in `PO Summary`. Reproduced as nested derived tables with an inner and outer `SUM`. At one-PO-line grain this is a no-op; it only matters together with quirk #2.
2. **Item-Branch fan-out.** `Item_Branch6` is `DISTINCT` on (Branch_Plant, **Global Bulk Item**, Bulk Item, 2nd Item), but the join to the PO lines is on **(Branch_Plant, 2nd Item)** only and the final `GROUP BY` keeps **Bulk Item** (not Global Bulk Item). So an item/branch tagged with one Bulk Item under **more than one Global Bulk Item** duplicates that PO line's quantity within a single Bulk Item row — the outer `SUM` then adds the copies. Kept verbatim so totals match Cognos; flag to planners if the quantities look inflated for a specific item.
3. **Degenerate LEFT JOIN.** Cognos writes `LEFT OUTER JOIN` but then repeats the join keys in the `WHERE` (`Purchase_Orders5.Branch_Plant = Item_Branch6.Branch_Plant`, etc.), which drops the unmatched left rows — i.e. it behaves as an **inner join**. Reproduced verbatim (LEFT JOIN + the WHERE predicates).
4. **`nulls last`** on the promised-date sort: the `.m` omits `ORDER BY` (illegal in the folded subquery), so this is handled by the **visual's** Promised Date ascending sort (PBI puts blanks last). In practice the ≥ today−90 floor already excludes null promised dates, so it rarely matters.

Corrected forms (if planners ever want them): join `Item_Branch6` on Bulk Item too (or pre-collapse it to one row per Branch/2nd-Item/Bulk-Item), and drop the outer `SUM`, to remove the fan-out double count.

---

## 7. Validation checklist
- [ ] Refresh `CM_PO_Live` — no errors; rows return with `Next Status` values like **400** (matches the screenshot).
- [ ] Open the live "CM PO Live" panel the same day; compare the table row-for-row: **Company / Branch / PO # / Line # / Bulk Item / Item / QTY / Open QTY / 2nd QTY / Next Status / Requested Date / Promised Date / Vendor Name**.
- [ ] Confirm sort: **Promised Date ascending** (earliest at top).
- [ ] Confirm every visible PO line has **Open QTY > 0** and **Promised Date ≥ today − 90**.
- [ ] Confirm every visible **Bulk Item** is in the whitelist (75 codes; see the `IN (...)` list in `CM_PO_Live.m`).
- [ ] Pick a region in the **Select the Region** slicer → the table narrows to that region only; clear it → all regions return.
- [ ] Set a **Promised Date** range → the table narrows within the 90-day window; clear it → base population returns.
- [ ] Formatting: QTY/Open QTY/2nd QTY show as whole numbers with thousands separators; dates show medium style (e.g. `Jul 1, 2026`); headers red/bold, title blue.

---

## 8. Open items / ambiguities

> The live open-items list is `PARITY_TODO.md`. **This page has more outstanding work than 04 or 05:** both slicer titles lack `fontColor: #FF0000` and their trailing colons, `Next Status` is not right-aligned, and the daily refresh is unscheduled. Plus the usual LOW cosmetics and the PBIX regeneration.

- **The `use="prohibited"` region filter is a disabled duplicate — VERIFIED CORRECT, not a gap.** Do not re-raise it; do not remove or default the region slicer. See the Status block and `PARITY_TODO.md` §5.1.
- **The 90-day rolling floor evaluates at refresh time, not view time** — a real behaviour difference from Cognos. See §5 and the Status block.
- **Date-range prompt:** confirmed it filters **Promised Date** (optional BETWEEN), not Requested Date — built as an optional Promised Date range slicer.
- **REGION as a column:** added to the main query (decode of Branch Plant) rather than a separate query, so the region slicer needs no extra table/relationship. If the team prefers REGION kept off the model, drop it from the final `SELECT`, the outer `GROUP BY`, and the `Typed` step, and instead build the slicer from a standalone distinct-REGION query (Statement 1 in the raw SQL).
- **`Reference 2` (PDVR02), `Reporting Code 3` (PDPDP3), `Last Status` (PDLTTR), `PO Type` (PDDCTO), `Vendor Code`:** selected/grouped inside Cognos `Purchase_Orders5` but never displayed. Kept in the derived table's GROUP BY for faithful grain; not surfaced as output columns. Harmless at PO-line grain.
- **Bulk-item whitelist** is hard-coded (75 codes) exactly as the Cognos `PO Summary` filter. Confirm with planners whether it should be maintained here or externalized.
