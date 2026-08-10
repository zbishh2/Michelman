# Report 04 — CM Open Sales Orders LIVE

**Cognos source:** Public Folders > Michelman Reporting > Production and Shipping > Contract Manufacturing Orders > *Dashboard - CM Overview LIVE* (embedded panel).
**Report name (Cognos):** `CM - Open Sales Orders Live`
**Page rendered in the dashboard panel:** `Page1` (list `List1`, query `Sales Summary`).

> **OBJECTIVE:** Show every open Contract-Manufacturing sales-order line for the whitelisted bulk items, across both companies, so the CM team can see the live open-order book. One row per order line × (branch, 2nd item) after the bulk-item whitelist join.
> **SCOPE:** All companies (`00010` **and** `00020` both appear — there is **no** company filter, unlike report 02). Next Status **≠ 999** (open orders). Bulk item ∈ the CM whitelist. Optional user prompts narrow by **Promised Ship date range** and **Region**.

This is **page 3 of the shared "CM Overview LIVE" PBIP** (see `_PROGRESS.md`). Build it as the third page of that PBIP. Author only the `.m` + this `BUILD.md`; do **not** touch the PBIP.

---

## Status — 2026-07-09

> **This document is the original build spec, updated in place.** The live open-items list is `PARITY_TODO.md` in this folder — read that first.

**This page is clean.** Cognos has no conditional formatting, no grouped list and no subtotal row here, so those sections are genuinely N/A rather than "not done yet". Every model column is `summarizeBy: none`. Two changes are worth recording:

- **Date formats corrected 2026-07-09.** `Order Date`, `Requested` and `Promised Ship` are `formatString: d MMM, yyyy` — **day-first** (`1 Jul 2026`). Cognos drives this with **`displayOrder="DMY"` on the `<dateFormat>` element, *not* `dateStyle`**. `dateStyle="medium"` only selects the medium form; the day/month order is a separate attribute. Report 06's dates are month-first (`MMM d, yyyy`) because its `<dateFormat>` carries no `displayOrder` — the asymmetry is verbatim from each report's own XML and is **not** a copy-paste bug. Report 05 has no date columns at all.
- **A `Last Refreshed` table + `Last Refreshed Label` measure + a `card` visual** now sit on this page and all 7. See below.

**Prompts map 1:1 to slicers — verified, not assumed.** Both Cognos prompts are `use="optional"`, which means the filter applies **only when the prompt is answered**; an unanswered prompt shows all rows. Neither Power BI slicer carries a baked-in default selection, so the page lands unfiltered exactly as Cognos does. Report 04 contains **zero** `use="prohibited"` filters.

**PBIP changes do not reach the PBIX.** `FINAL - for handover\Dashboard - CM Overview LIVE.pbix` was last written 2026-07-08; the PBIP edits landed 2026-07-09. **Someone must open `CM Overview LIVE.pbip` in Power BI Desktop, re-save, and republish.** Until then nothing above is user-visible.

### Last Refreshed card

`Last Refreshed.m` computes one row via `DateTimeZone.FixedUtcNow()` plus an explicit US-Eastern DST rule (second Sunday in March → first Sunday in November), yielding an `EDT`/`EST` label. `DateTime.LocalNow()` is **deliberately avoided**: it returns UTC in the Power BI Service but machine-local time on Desktop, so the two would disagree. The stamp is refresh-**start**, not finish — Power Query's evaluation order across queries is not deterministic — which is why the label reads "Last refreshed", not "finished". Format `MMM d, yyyy h:mm:ss AM/PM` matches the Cognos page-footer stamp, **which is month-first in every report regardless of what the table's own date columns use** — so this card reads `Jul 9, 2026` even though this page's data columns read `9 Jul 2026`. That is correct, not an inconsistency. The card covers the Cognos footer's run date and run time; the **page number** has no Power BI analogue and is not reproduced.

---

## 0. On-page plaintext (verbatim, for fidelity)

- **Page header title** (blue, bold, large): `CM - Open Sales Orders LIVE`
- **Prompt line 1** (bold, **red** text): `Enter the Date Range:  Beginning ` → date edit box, then `    and End Date` → date edit box.
- **Prompt line 2** (bold, **red** text): `Select the Region: ` → single-select value dropdown, then a **`Finish`** prompt button.
- **Empty-state text:** `No Data Available`

> Note the prompt labels in this report are **red** (`font-weight:bold;color:red`), while the page title is **blue**.

---

## 1. Queries (Power Query)

| Query | File | Feeds |
|---|---|---|
| `CM_Open_Sales_Orders` | `CM_Open_Sales_Orders.m` | The visible **CM Open Sales Orders detail list** (main deliverable) + the `REGION` slicer column |

Connects to `Sql.Database("ODSPROD","ODS")` and runs native T-SQL against `PRODDTA` (folding on), following the repo's canonical JDE/ODS query `edw_model/JDE_Orders/Orders.m` and reports 01/02: same `Value.NativeQuery(Source, "<T-SQL>", null, [EnableFolding=true])` shape, inline Julian `DATEADD/DATEFROMPARTS` decode, `LTRIM(RTRIM(...))` trims, `SDLNID/1000.0` line scaling, and a trailing `Table.TransformColumnTypes`. Paste into **Power BI Desktop → Get Data → Blank Query → Advanced Editor**. Set the server name to match your SSMS connection if it differs from `ODSPROD`.

### The 2 Cognos generated-SQL blocks → what we built

| Cognos block | What it is | Built as |
|---|---|---|
| Block 1 | `SELECT DISTINCT ... REGION` from F4211 (branch decode), `SDNXTR NOT IN ('999')` | *the **"Select the Region"** prompt pick-list* — **not** built as a separate query; `REGION` is carried as a column on `CM_Open_Sales_Orders` and the slicer populates itself from it (see §3) |
| **Block 2** | **the main open-SO detail list** (Item_Branch7 ⋈ Sales_Orders6, whitelist) | **`CM_Open_Sales_Orders.m`** ← the panel |

The Cognos report also defines an empty `Query1` (no selection) — unused, ignore.

---

## 2. Cognos → PBI column mapping (visible list, left → right)

Header labels are the Cognos `label=` attributes from the `Sales Summary` list; query columns are the `CM_Open_Sales_Orders.m` output names.

| # | Cognos label | Query column | JDE source |
|---|---|---|---|
| 1 | Company | `Company` | `F4211.SDKCOO` |
| 2 | Branch | `Branch` | `F4211.SDMCU` (trimmed) |
| 3 | Order # | `Order #` | `F4211.SDDOCO` |
| 4 | Line # | `Line #` | `F4211.SDLNID / 1000` |
| 5 | Customer PO | `Customer PO` | `F4211.SDVR01` (trimmed) |
| 6 | Order Date | `Order Date` | `F4211.SDTRDJ` (Julian → date) |
| 7 | Requested | `Requested` | `F4211.SDDRQJ` (Julian → date) |
| 8 | Promised Ship | `Promised Ship` | `F4211.SDPDDJ` (Julian → date) |
| 9 | Item | `Item` | `F4211.SDLITM` (2nd item, trimmed) |
| 10 | Next Status | `Next Status` | `F4211.SDNXTR` (≠ 999) |
| 11 | QTY | `Primary Qty` | `SUM` of `F4211.SDPQOR/10000` (see quirk §6 double-sum) |
| 12 | UOM | `Primary UOM` | `F4211.SDUOM1` |
| 13 | QTY | `Secondary Qty` | `SUM` of `F4211.SDSQOR/10000` (see quirk §6) |
| 14 | UOM | `Secondary UOM` | `F4211.SDUOM2` |
| 15 | Customer Name | `Customer Name` | `F0101.ABALPH` (ship-to) via `SDSHAN` |
| 16 | TM Name | `TM Name` | `F0101.ABALPH` (sales rep) via the F0006/F42140 chain — see §5 |
| — | *(not shown)* | `REGION` | branch-plant decode; **slicer only**, not a visible column |

> Two columns are both labelled **QTY** and two both **UOM** in Cognos (Primary then Secondary). Keep the field order above. Optionally rename the visible headers to `QTY / UOM / QTY / UOM` (Cognos-exact) or `Primary Qty / Primary UOM / Secondary Qty / Secondary UOM` (clearer). Report 02 used the clearer names; either is fine.

### TM Name resolution (the F0006 → F42140 chain — reproduce carefully)

Cognos derives the Territory-Manager name through a synthetic sales-rep type:

1. **`fj` (Cognos `F4211_F0006_join_to_F42140`)** = `F4211 LEFT JOIN F0006 ON SDEMCU = MCMCU`, producing per SO line:
   `CMRTYPE = ISNULL(LTRIM(RTRIM(F0006.MCRP01)),'-') + 'GTM'` (i.e. the branch's `MCRP01` category code + the literal `GTM`; when F0006 is missing it becomes `-GTM`). Keyed on `(SDKCOO, SDDOCO, SDDCTO, SDLNID)` + `SDSHAN`.
2. **Sales_Orders6** then `LEFT JOIN (F42140 sales_rep INNER JOIN F0101 rep-name ON CMSLSM = ABAN8)` on `fj.SDSHAN = F42140.CMAN8 AND fj.CMRTYPE = F42140.CMRTYPE`.
3. **`TM_Name = ISNULL(F0101_Sales_Rep.ABALPH, 'Unassigned')`** (trimmed). When no sales rep matches, the name is **`Unassigned`**.

> **Faithful translation of the `decode`:** Cognos `decode(ABALPH, NULL, 'Unassigned', ABALPH)` matches **only true NULL**, so the T-SQL is `ISNULL(ABALPH,'Unassigned')` — **not** `ISNULL(NULLIF(...),'Unassigned')` (which would wrongly turn an empty-string name into 'Unassigned'). The `.m` uses plain `ISNULL`.

---

## 3. Visuals

### Page header (Text box)
- Title **"CM - Open Sales Orders LIVE"** — **blue** `#0000FF`, bold (Cognos page-header style `color:blue`).

### Visual A — the CM open-SO detail (Table)
- Visual type: **Table**.
- Fields in the order of the §2 table (Company … TM Name). **Do not** add `REGION` as a visible column (it is not in the Cognos list; it exists only to drive the slicer).
- **Number format:** `Primary Qty` and `Secondary Qty` → whole number, **0 decimals**, right-aligned (Cognos `numberFormat decimalSize="0"`, cell `text-align:right`).
- **Date format:** `Order Date`, `Requested`, `Promised Ship` → medium date, **day-month-year** order (Cognos `dateStyle="medium" displayOrder="DMY"`, e.g. `1 Jul 2026`). Shipped as `formatString: d MMM, yyyy` (corrected 2026-07-09). **It is `displayOrder="DMY"` that makes this day-first, not `dateStyle`** — see the Status block.
- `Order #` → whole number, **no thousands separator** (ID). `Line #` → 1–3 decimals (sub-lines like `1.5` survive the `/1000.0`); Cognos shows the raw scaled value.
- Header styling to match Cognos: column titles **bold, red text `#FF0000`, 1pt solid black border**; body cells **1pt solid black border** (thin grid). All cells `text-align:left` except the two QTY columns (`text-align:right`).
- **Sort:** `Promised Ship` ▲, then `Order #` ▲, then `Line #` ▲ (all ascending — Cognos `sortList` + `rp_sort a.1/a.2/a.3`). *The `.m` intentionally omits `ORDER BY` (illegal inside the folded subquery), so set this sort in the visual.* Cognos sorts NULLs last; PBI puts blanks last on ascending, which matches.

### Slicer — "Select the Region"
- Cognos prompt `?Select_Region?` is an **optional single-select** value dropdown (`autoSubmit="true"`) filtering `[REGION] in ?Select_Region?`.
- Build a **Slicer** on `CM_Open_Sales_Orders[REGION]`, style **Dropdown**, **single-select**.
- Options are exactly the distinct `REGION` values, so the slicer self-populates: `Americas, Aubange, Shanghai, Singapore, Mumbai`. Sorted ascending (Cognos `sortItem`).
- Default = **no selection** (shows all regions).

### Slicer / filter — "Enter the Date Range" (Promised Ship)
- Cognos has an **optional** detail filter `[Promised Ship Date] between ?1 - Start? and ?2 - End?` on the Sales Orders query. It is `use="optional"`, which is why it is **absent from the unfilled Generated SQL** — but it **does filter** when the user enters dates.
- **Reproduce as a `Between` (range) slicer on `CM_Open_Sales_Orders[Promised Ship]`.** Default = full range (no restriction), matching the empty prompt. This gives the "Beginning / and End Date" behavior.

> Both prompts are `required="false"` and `use="optional"` — the filter applies **only when the prompt is answered**, so the report renders fully with neither set (all open whitelisted lines, both companies). The slicers only narrow. **Verified 2026-07-09:** both slicers map 1:1 to their Cognos prompts, neither carries a default selection, and the page lands unfiltered. Report 04 has **zero** `use="prohibited"` filters.

---

## 4. Visual fidelity — conditional formatting

**There are NO conditional styles in this report.** The Cognos XML has **no** `<namedConditionalStyles>` and **no** per-cell conditional CSS — every body cell is plain (`text-align` + `1pt solid black border` only), matching the screenshot (plain white rows). So:

- **No** red/yellow/error highlighting to build (unlike report 02).
- The only styling is: blue title, red bold column headers, thin black grid, right-aligned 0-decimal quantities, medium DMY dates.

**Color reference:** title blue `#0000FF`; column headers red `#FF0000`; prompt labels red `#FF0000`; grid border `1pt solid black`.

---

## 5. Known Cognos quirks (PARITY MODE — reproduced on purpose)

### Quirk 1 — double SUM of the quantities
Cognos SUMs the quantities twice: once in `Sales_Orders6` (to the order-line grain) and again in the final `Sales Summary` step. `CM_Open_Sales_Orders.m` reproduces both `SUM`s.

- **Effect:** `Item_Branch7` is `DISTINCT` on `(Branch_Plant, Global_Bulk_Item, Bulk_Item, C_2nd_Item_Number)`. If one `(branch, 2nd item)` maps to multiple whitelisted `Bulk_Item`/`Global_Bulk_Item` rows, the `LEFT JOIN` fans the SO line into several copies and the **final SUM adds them** — inflating the quantity for that line. This is faithful to the live Cognos number; keep it for parity. If planners later want de-duplicated quantities, collapse `Item_Branch7` to `DISTINCT (Branch_Plant, Bulk_Item, C_2nd_Item_Number)` or drop `Global_Bulk_Item`, and/or replace the outer `SUM` with `MAX`.

### Quirk 2 — LEFT OUTER JOIN forced to an inner join
Cognos writes `Item_Branch7 LEFT OUTER JOIN Sales_Orders6 ... WHERE Sales_Orders6.Branch_Plant = Item_Branch7.Branch_Plant AND Sales_Orders6.C_2nd_Item_Number = Item_Branch7.C_2nd_Item_Number`. The `WHERE` on the right-side (nullable) columns discards unmatched `Item_Branch7` rows, so the LEFT JOIN behaves like an **INNER** join. We keep the LEFT JOIN + WHERE verbatim (valid in SQL Server) for faithfulness; net effect = only order lines whose `(branch, 2nd item)` sits in a whitelisted item-branch survive.

### Quirk 3 — synthetic `CMRTYPE` (always ends in `GTM`)
The `fj` CTE's `CASE WHEN ISNULL(trim(MCRP01),'-') IS NULL THEN NULL ELSE ... + 'GTM' END` can never hit the `NULL` branch (the `ISNULL(...,'-')` guarantees a non-null value), so `CMRTYPE` is always `<MCRP01 or '->' + 'GTM'`. Reproduced exactly as Cognos wrote it. When F0006 doesn't match `SDEMCU`, `MCRP01` is NULL → `CMRTYPE = '-GTM'`.

### Quirk 4 — no company / no date / no status='xxx' filter baked in
Unlike report 02 (company `00010`, status `530`), this panel's only baked filter is `SDNXTR NOT IN ('999')`. Company and Promised-Ship-date narrowing are done by the optional prompts (slicers), not in the query.

---

## 6. Refresh / "as of" behavior
The query has no `sysdate`/`GETDATE()` dependency and no baked date filter — it returns the full open-order book as of the last data refresh. Schedule a daily refresh. The two prompts (Region, Promised-Ship date range) are optional PBI slicers with no pre-selected default.

---

## 7. Validation checklist
- [ ] Refresh `CM_Open_Sales_Orders` — no errors; rows come back for **both** companies `00010` and `00020`, `Next Status ≠ 999`.
- [ ] Open the live Cognos `CM - Open Sales Orders LIVE` panel the same day (no prompts entered) and compare **row count** and a few line **quantities** to the PBI page (parity mode should match, including the double-sum inflation on multi-bulk items).
- [ ] Confirm the **Region** dropdown shows `Americas, Aubange, Shanghai, Singapore, Mumbai` and filters the list; default = all.
- [ ] Confirm the **Promised Ship** range slicer narrows the list and defaults to the full range.
- [ ] Confirm sort = Promised Ship ▲, Order # ▲, Line # ▲.
- [ ] Confirm `Primary/Secondary Qty` show 0 decimals right-aligned, dates render medium DMY (`1 Jul 2026`), `Order #` has no thousands separator.
- [ ] Spot-check a line with no sales rep shows `TM Name = Unassigned`.
- [ ] Confirm column headers are **red bold**, title is **blue**, grid is thin black, and there is **no** row/cell highlighting.

---

## 8. Open items / assumptions

> The live open-items list is `PARITY_TODO.md`. What remains there is LOW cosmetics (un-underlined title, `isHidden` on `REGION`, `No Data Available` empty state) and the PBIX regeneration. No HIGH or MED items.

- **`REGION` added as a hidden column** (not in the Cognos visible list) to drive the Region slicer. It is the branch-plant `decode` with default **`Americas`** (not 'OTHER'). Added to the final `SELECT`/`GROUP BY`; because it is functionally determined by `Branch_Plant` (already grouped), it does not change row counts. Alternative: build a separate one-column `REGION` query from Block 1 and a disconnected slicer — but the in-table column is simpler and filters the list directly. Chosen the in-table column.
- **Date-range prompt confirmed to filter.** The XML shows an optional `[Promised Ship Date] between ?1 - Start? and ?2 - End?` detail filter (absent from the unfilled Generated SQL only because it is optional). Reproduced as a `Between` range slicer on `Promised Ship`.
- **Double-sum reproduced** for parity (quirk 1) — may inflate quantities on items mapping to multiple bulk codes. Corrected forms documented above.
- **`Line #` uses `SDLNID / 1000.0`** (float, matching Oracle `/1000`) so sub-lines survive.
- **No conditional formatting** exists in this report (confirmed against the XML) — plain rows.
- **Both companies appear** — no company filter (differs from report 02).
