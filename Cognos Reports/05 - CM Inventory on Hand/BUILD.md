# Report 05 — CM Inventory on Hand

**Cognos source:** Public Folders > Michelman Reporting > Production and Shipping > Contract Manufacturing Orders > *Dashboard - CM Overview LIVE* — panel 4 ("CM Inventory on Hand").
**Report name (XML `reportName`):** `CM - Inventory on Hand`

> **This is page 4 of the shared 5-page "CM Overview LIVE" PBIP** (panels 02–06). You author this intake `.m` + `BUILD.md`; the builder agent assembles the visual on page 4. Do **not** touch the PBIP.

A single flat table of on-hand contract-manufacturing inventory (on-hand qty > 0), restricted to a fixed whitelist of "Bulk Items", one row per Branch / Bulk Item / 2nd Item / Lot Status / Primary UOM, sorted REGION ▸ Bulk Item ▸ 2nd Item Number. One optional prompt (a single region) narrows it.

---

## Status — 2026-07-09

> **This document is the original build spec, updated in place.** The live open-items list is `PARITY_TODO.md` in this folder — read that first.

**This page is clean.** All nine columns, their labels, their left-to-right order, the three-level sort, the number formats, the single region prompt and the entire data layer match Cognos. The Cognos source has no conditional formatting, no grouping, no crosstab and no subtotals — those sections are genuinely N/A, not "not done yet". Every model column is `summarizeBy: none`. There is no model-level defect and nothing report-specific outstanding.

- **Date formats: N/A.** This report has **no date columns** (the only `<dateFormat/>` in its XML is the bare one inside `<pageFooter>`, which formats the run date, not data). Reports 04 and 06 both had their date formats corrected on 2026-07-09; there was nothing here to correct.
- **A `Last Refreshed` table + `Last Refreshed Label` measure + a `card` visual** now sit on this page and all 7. See below. Note this page's query has **no time-dependent predicate**, so the refresh timestamp is informational rather than load-bearing (unlike report 06's rolling 90-day window).

**The prompt maps 1:1 to a slicer — verified, not assumed.** Cognos's `[REGION] in ?Select_Region?` is `use="optional"`, which means the filter applies **only when the prompt is answered**; an unanswered prompt shows all rows. The Power BI slicer carries no baked-in default selection, so the page lands unfiltered exactly as Cognos does. Report 05 contains **zero** `use="prohibited"` filters.

**PBIP changes do not reach the PBIX.** `FINAL - for handover\Dashboard - CM Overview LIVE.pbix` was last written 2026-07-08; the PBIP edits landed 2026-07-09. **Someone must open `CM Overview LIVE.pbip` in Power BI Desktop, re-save, and republish.** Until then nothing above is user-visible.

### Last Refreshed card

`Last Refreshed.m` computes one row via `DateTimeZone.FixedUtcNow()` plus an explicit US-Eastern DST rule (second Sunday in March → first Sunday in November), yielding an `EDT`/`EST` label. `DateTime.LocalNow()` is **deliberately avoided**: it returns UTC in the Power BI Service but machine-local time on Desktop, so the two would disagree. The stamp is refresh-**start**, not finish — Power Query's evaluation order across queries is not deterministic — which is why the label reads "Last refreshed", not "finished". Format `MMM d, yyyy h:mm:ss AM/PM` matches the Cognos page-footer stamp, which is month-first in every report regardless of what the table's own date columns use. The card covers the Cognos footer's run date and run time; the **page number** has no Power BI analogue and is not reproduced.

---

## 1. Query (Power Query)

| Query | File | Feeds |
|---|---|---|
| `CM_Inventory_on_Hand` | `CM_Inventory_on_Hand.m` | The one table on the page (Cognos list `List1`, query object `Inventory`) |

Connects to `Sql.Database("ODSPROD","ODS")` and runs native T-SQL against `PRODDTA` (folding on). Paste into **Power BI Desktop → Get Data → Blank Query → Advanced Editor**. Set the server name to match your SSMS connection if it differs from `ODSPROD`.

The Cognos report has one real query object (`Inventory`) plus an empty `Query1` stub. `Inventory` is a single flat SELECT + GROUP BY over four PRODDTA tables — it folds directly into `CM_Inventory_on_Hand.m` as-is (**no CTEs, no derived tables needed**). The tiny `REGION` distinct-list query (Statement 1 in the raw SQL) is **not** rebuilt as its own query — REGION is carried on this table and drives the slicer (see §4).

---

## 2. Cognos → PBI column mapping

Rendered left → right (from `List1` `listColumns`). The header label is the dataItem's `label` if present, else its name (all confirmed from the XML).

| # | On-page header | Query column | JDE field / derivation |
|---|---|---|---|
| 1 | **REGION** | `REGION` | `CASE trim(F4102.IBMCU) …` (decode; default **'OTHER'**) — also drives the slicer |
| 2 | **Branch Plant** | `Branch Plant` | `trim(F4102.IBMCU)` |
| 3 | **Bulk Item** | `Bulk Item` | `trim(F554101.IMBULK)` |
| 4 | **2nd Item Number** | `2nd Item Number` | `trim(F4102.IBLITM)` |
| 5 | **Status** | `Status` | `trim(F41021.LILOTS)` (lot status — `P`, `A`, blank) |
| 6 | **KG/EA OH** | `KG/EA OH` | on-hand SUM re-expressed in **KG** (see §6.1) — XML `dataItem label="KG/EA OH"` |
| 7 | **LB/EA OH** | `LB/EA OH` | on-hand SUM re-expressed in **LB** (see §6.1) — XML `dataItem label="LB/EA OH"` |
| 8 | **Hard Commit** | `Hard Commit` | `SUM(F41021.LIHCOM / 10000)` |
| 9 | **Primary UOM** | `Primary UOM` | `F4101.IMUOM1` |

Put the columns in the table visual in **exactly this order** and set each header's display name to the bold on-page label above. (The `.m` already names the query columns identically to the on-page labels, so no per-column renaming is needed — just confirm.)

Joins (all inner): `F4102.IBITM = F4101.IMITM`, `F4101.IMITM = F554101.IMITM`, and `F4102.IBITM = F41021.LIITM AND F4102.IBMCU = F41021.LIMCU`. Filter: `F41021.LIPQOH/10000 > 0` **and** `trim(F554101.IMBULK)` in the Bulk-Item whitelist.

Unlike report 06 (where REGION was hidden), here **REGION is a visible column** (column 1) *and* the slicer field.

---

## 3. Visual fidelity

Everything below is pulled from the Cognos Report XML for this panel.

### Page title (page-header text box)
- **`CM - Inventory on Hand`** — **blue**. XML: page-header `textItem` with `CSS value="color:blue"`. Blue = CSS named `blue` = **`#0000FF`**.

### Table
- Visual type: **Table**.
- **Column headers: red, bold, left-aligned.** XML: every `listColumnTitle` has `CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"`. Red = CSS named `red` = **`#FF0000`**.
- **Cell borders:** `1pt solid black` on every title and body cell (`border-collapse:collapse`). Apply a thin black gridline/border to the table for the boxed look.
- **Alignment:** the three numeric columns (**KG/EA OH**, **LB/EA OH**, **Hard Commit**) are `text-align:right`; all others (REGION, Branch Plant, Bulk Item, 2nd Item Number, Status, Primary UOM) are `text-align:left`.
- **No row-level conditional formatting.** Confirmed — there are **no** `conditionalStyles` / `styleReference` rules and no data-bar / color-by-value on any column. The only colors are the static red headers and blue title. (The screenshot shows a plain boxed grid, matching.)

### Number format
- **KG/EA OH / LB/EA OH / Hard Commit:** whole number, **0 decimals**. XML: `numberFormat decimalSize="0"` on all three body cells. Use **`#,0`** (thousands separator, 0 decimals) per house convention — matches the screenshot (thousands-separated integers).
- All other columns are text — no number format.

### Sort
- **REGION asc, then Bulk Item asc, then 2nd Item Number asc.** XML: `list → sortList` = `REGION`, `Bulk Item`, `2nd Item Number` (and `rp_sort` `a.1/a.2/a.3` on those columns). The `.m` intentionally **omits `ORDER BY`** (an ORDER BY inside the folded subquery is illegal in SQL Server — PBI wraps the query as `SELECT * FROM (<query>)`; this is the bug that bit report 06), so **set this 3-level sort in the visual**: primary REGION ▲, secondary Bulk Item ▲, tertiary 2nd Item Number ▲.

---

## 4. Prompt → slicer

The page top has a small Cognos prompt table with this **exact plaintext** (red, bold), then an auto-submit dropdown:

```
Select the Region:  [ dropdown: Select_Region ]
```

(XML: `textItem staticValue "Select the Region: "` with `CSS "font-weight:bold;color:red"`, then a `selectValue parameter="Select_Region"`.)

### Region slicer — **Select the Region**
- Cognos `selectValue parameter="Select_Region"`, `multiSelect="false"` (single-select), `required="false"`, `autoSubmit="true"`, sourced from the distinct `REGION` list, sorted by REGION.
- **Build:** a **single-select slicer on `CM_Inventory_on_Hand[REGION]`.** REGION is already a column on the table (decode of Branch Plant), so its slicer values are the same set Cognos listed (Americas / Aubange / Shanghai / Singapore / Mumbai / **OTHER**). No separate region query or relationship needed.
- The Cognos filter is **optional** (`detailFilter use="optional"`: `[REGION] in ?Select_Region?`) → the filter applies **only when the prompt is answered**, so default = no region selected = **all regions**. Set the slicer to allow "no selection = show all" (single-select, not forced). **Verified 2026-07-09:** the slicer maps 1:1, carries no default selection, and the page lands unfiltered. Report 05 has **zero** `use="prohibited"` filters.

> Net: the `.m` reproduces the always-on population (on-hand qty > 0, bulk-item whitelist). The single region prompt becomes an optional slicer layered on top; it does not change the base query.

---

## 5. Refresh / "as of" behavior
The query has **no date logic** (no Julian, no sysdate) — it is a straight snapshot of current on-hand inventory. The table is "as of the last refresh." Schedule a daily refresh so on-hand / hard-commit stay current. No hard report parameters (the region prompt is an optional slicer).

---

## 6. Parity notes (reproduced on purpose — numbers tie to the live panel)

1. **UOM conversion (KG/EA OH & LB/EA OH).** Both columns re-express the **same** on-hand SUM in a single unit, using the group's Primary UOM:
   - **KG/EA OH** = `LB → SUM(LIPQOH/10000)*0.453593` (LB→KG); `KG → SUM(LIPQOH/10000)`; **any other UOM → SUM(LIPQOH/10000) unconverted** (ELSE branch).
   - **LB/EA OH** = `KG → SUM(LIPQOH/10000)/0.453593` (KG→LB); `LB → SUM(LIPQOH/10000)`; **any other UOM → SUM(LIPQOH/10000) unconverted** (ELSE branch).
   - So for a non-LB/non-KG UOM (e.g. `EA`, `GA`), **both** columns show the raw on-hand number unchanged — that is Cognos's behavior, kept verbatim. `0.453593` is the lb→kg factor.
2. **`MIN(IMUOM1)` idiom.** The UOM test inside each CASE is `MIN(F4101.IMUOM1)`, while the query `GROUP BY`s `IMUOM1`. Because the group is on `IMUOM1`, `MIN()` over the group is just the group's single UOM value — the `MIN()` is Cognos's aggregate wrapper (a fact-vs-attribute mixing artifact), not real logic. Kept verbatim. The **Primary UOM** output column selects the bare grouped `IMUOM1` (the same value), so the two never disagree.
3. **Bulk-Item whitelist duplicates.** The `IN (...)` list is two concatenated Cognos lists and contains duplicate codes (e.g. `APT10`, `DMAEMA`, `U101`, `MD4020`, `HP1632`, `WD40`, `EMA3065`, `DPE3500`, `191245PX`, …). Duplicates are harmless in a SQL `IN`, so they are **kept verbatim** to match the Cognos filter byte-for-byte. ~130 entries as written, ~110 distinct.
4. **`ORDER BY` dropped.** The Cognos SQL ends `order by REGION, Bulk_Item, C_2nd_Item_Number` (each `asc nulls last`). Omitted from the `.m` (illegal in the folded subquery); handled by the **visual's** 3-level sort (§3). PBI table sorting puts blanks last, matching Cognos's `nulls last`.

---

## 7. Validation checklist
- [ ] Refresh `CM_Inventory_on_Hand` — no errors; rows return with `Status` values like **P / A / (blank)** and `Primary UOM` like **KG / LB / EA**.
- [ ] Open the live "CM Inventory on Hand" panel the same day; compare the table row-for-row: **REGION / Branch Plant / Bulk Item / 2nd Item Number / Status / KG/EA OH / LB/EA OH / Hard Commit / Primary UOM**.
- [ ] Confirm sort: **REGION ▲, Bulk Item ▲, 2nd Item Number ▲** (3 levels).
- [ ] Spot-check a **KG** row: KG/EA OH == on-hand, LB/EA OH == on-hand ÷ 0.453593. Spot-check an **LB** row: LB/EA OH == on-hand, KG/EA OH == on-hand × 0.453593.
- [ ] Confirm every visible **Bulk Item** is in the whitelist and every row has on-hand qty > 0.
- [ ] Pick a region in the **Select the Region** slicer → the table narrows to that region only; clear it → all regions return.
- [ ] Formatting: KG/EA OH / LB/EA OH / Hard Commit show as whole numbers with thousands separators (`#,0`, right-aligned); headers red/bold with thin black borders; title blue.

---

## 8. Open items / ambiguities

> The live open-items list is `PARITY_TODO.md`. What remains there is two LOW cosmetics (un-underlined title, `No Data Available` empty state) and the PBIX regeneration. **No HIGH or MED items; nothing report-specific outstanding.** Note in particular: **do not** set `isHidden` on `CM_Inventory_on_Hand[REGION]`. Pages 04 and 06 carry that tidy-up because `REGION` is slicer-only there; here it is **both** the slicer source **and** the first displayed column, so hiding it would be a regression.

- **REGION as a displayed column AND slicer field:** in this report REGION is both column 1 of the table and the slicer source (decode of Branch Plant). If the team ever wants REGION kept off the model, they'd instead need a standalone distinct-REGION query (Statement 1 in the raw SQL) — but here it must stay, because it is a visible column.
- **`Location`, `Lot Number`, `Global Bulk Item`, `Business Unit`:** these dataItems exist in the Cognos `Inventory` query `selection` but are **not** in the rendered `listColumns` and **not** in the Generated SQL's SELECT/GROUP BY — so they are not surfaced. Not built. (`Status` = lot **status** LILOTS is rendered; lot **number** is not.)
- **Bulk-Item whitelist** is hard-coded (~130 entries, duplicates kept) exactly as the Cognos `Inventory` filter. Confirm with planners whether it should be maintained here or externalized. It is the **same** whitelist as report 06.
