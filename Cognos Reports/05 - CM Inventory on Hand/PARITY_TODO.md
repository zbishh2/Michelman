# Parity TODO — 05 CM Inventory on Hand
_Source of truth: PBIP. Power BI page: `CM Inventory on Hand` in `CM Overview LIVE` (shared with reports 02-06)._

## Status — 2026-07-09

**The PBIP is updated. The PBIX is not.** `FINAL - for handover/Dashboard - CM Overview LIVE.pbix` was last
written **2026-07-08 14:07**; the PBIP edits landed **2026-07-09 12:30-12:37**. **Someone must open
`CM Overview LIVE.pbip` in Power BI Desktop, re-save, and republish before any user sees these changes.**

Implemented on 2026-07-09, affecting this page:

| Change | Where | Effect |
|---|---|---|
| `Last Refreshed` table + `Last Refreshed Label` measure + a `card` visual on this page (and all 7) | `Last Refreshed.tmdl`, `model.tmdl`, `report.json` | Closes 6.1 — reproduces the Cognos footer's run date and run time. |

No other change was needed on this page, and none was made. It had no conditional formatting, no grouped list,
no subtotal row and no model-level defect. Verified after the edits: `report.json` re-parses; all `config` fields
are still JSON-encoded strings; the model loads (12 tables, 23 measures); this page still has **0**
conditional-format markers, matching Cognos.

The card shows `Last refreshed: <date> <time> EDT|EST`, computed from `DateTimeZone.FixedUtcNow()` with the US
Eastern DST rule applied — not `DateTime.LocalNow()`, which returns UTC in the Service but machine-local time on
Desktop and would therefore disagree between them. The Cognos footer's **page number** has no Power BI analogue
and is not reproduced.

Note this page has **no time-dependent predicate** in its query, so (unlike report 06) the refresh timestamp is
informational rather than load-bearing.

## Summary
This page is **clean**. All nine columns, their labels, their left-to-right order, the three-level sort, the number formats, the single region prompt and the entire data layer match Cognos. The Cognos source has no conditional formatting, no grouping, no crosstab and no subtotals, so sections 1-3 are genuinely N/A. The missing page footer **is now closed** (6.1, `Last Refreshed` card). The two remaining open items are cosmetic and shared with pages 04 and 06 (un-underlined title, no empty-state message); there is nothing report-specific to fix and no model-level defect.

Evidence: `Report XML.md`, `Generated SQL (Cognos - raw).sql`, `CM_Inventory_on_Hand.m`, `screenshots/Cognos - CM Inventory on Hand rendered (...).png`, `PBIP/CM Overview LIVE.Report/report.json` (section `CM Inventory on Hand`), `PBIP/CM Overview LIVE.SemanticModel/definition/tables/CM_Inventory_on_Hand.tmdl`.

## 1. Conditional formatting
**None in Cognos — nothing to port.**

Verified independently: 0 occurrences of `namedConditionalStyles`, `advancedConditionalStyle`, `conditionalStyleRef`, `styleCase`, `conditionalRender` in `Report XML.md`. Every `listColumnTitle` carries the same static `font-weight:bold;color:red;text-align:left;border:1pt solid black`; every `listColumnBody` carries only `text-align:*` + border. The screenshot shows a plain boxed grid.

Power BI side: `report.json` has 0 `FillRule` / `fillRule` / `Conditional` / `dataBars`. Confirmed — the brief's claim holds.

## 2. Grouped lists rendered as flat tables
**None in Cognos — nothing to port.**

0 `<listGroup>`, 0 `<listGroupFooter>`, 0 `<crosstab>` in `Report XML.md`. The Cognos object is a flat `<list>` with 9 `<listColumn>`s. `tableEx` is the correct rebuild; a matrix would be wrong.

Worth stating explicitly because it is easy to misread: the Cognos list *is* implicitly aggregated (the `Quantity On Hand` and `Hard Commit` dataItems carry `aggregate="total"`, so Cognos groups by the displayed columns and sums). That is **aggregation, not grouping** — it produces one flat row per key, not a hierarchy. The generated Cognos SQL confirms it: a single `GROUP BY trim(IBMCU), trim(IMBULK), trim(IBLITM), trim(LILOTS), IMUOM1, <region decode>` with no rollup. `CM_Inventory_on_Hand.m` reproduces that `GROUP BY` verbatim, so the Power BI table receives pre-aggregated rows and needs no visual-level grouping.

## 3. Subtotals / summary rows
**None in Cognos — nothing to port.** 0 `<summary>`, 0 `<aggregate>`, 0 `<listGroupFooter>`, 0 `<overallFooter>`; the screenshot ends at the last data row.

Correctly reflected in Power BI: `objects.total[0].properties.totals = false` on the `tableEx`. No action.

## 4. Sort order
**Matches.**

| | Sort keys |
|---|---|
| Cognos (`<sortList>` on the list; also the trailing `order by` in the generated SQL) | `REGION` ▲, `Bulk Item` ▲, `2nd Item Number` ▲ (each `asc nulls last`) |
| Power BI (`prototypeQuery.OrderBy`) | `REGION` Direction 1, `Bulk Item` Direction 1, `2nd Item Number` Direction 1 |

The screenshot corroborates: `161190PX` → `ABEX2525` → `DPE3500` → `HP1432AT` → `HP1632` → `HP401` → `MDU20` → `U101` → `U2022` → `U502` (string ascending), with `2nd Item Number` breaking ties. The `.m` deliberately drops `ORDER BY` (illegal in the folded subquery) and the visual carries the sort — already done.

## 5. Prompts / parameters
**The one Cognos prompt is reproduced. No gaps.**

| Cognos | Definition | Power BI |
|---|---|---|
| `Select the Region:` | `<selectValue parameter="Select_Region" refQuery="Inventory" multiSelect="false" required="false" autoSubmit="true">` over distinct `REGION`, sorted by `REGION` | Slicer on `CM_Inventory_on_Hand.REGION`, `data.mode = 'Dropdown'`, `selection.singleSelect = true`, title `'Select the Region:'` bold `#FF0000` |

Unlike reports 04 and 06 there is **no** date prompt here — `Report XML.md` contains zero `<selectDate>` elements and the report has no date columns (the only `<dateFormat/>` in the file is the bare one inside `<pageFooter>`, which formats the run date, not data). The Power BI page correctly has a single slicer. This is N/A, not a miss.

**The prompt is reproduced 1:1, and this was checked, not assumed.** Report 05 contains zero `use="prohibited"` filters; its single prompt filter `[REGION] in ?Select_Region?` sits on the `Inventory` query as `use="optional"` and is genuinely active. The Power BI slicer binds the matching column.

**Landing state matches.** `use="optional"` in Cognos means the filter applies *only* when the prompt is answered — an unanswered prompt shows all rows. Verified that the Power BI slicer carries no baked-in default selection: its `visualContainer.filters` is `"[]"`, `singleVisual.objects.general` is absent (no persisted filter expression), and `prototypeQuery.Where` is `null`. The page's `filters` array is `[]` and `report.json` has no report-level `filters` key. So the page lands unfiltered, showing all regions, exactly as Cognos does with the prompt unanswered.

`autoSubmit="true"` means there is no `Finish` button to reproduce (the screenshot confirms none).

One residual difference, not worth fixing: the slicer is `selection.singleSelect = true`, matching Cognos's `multiSelect="false"`. Cognos's dropdown offers a blank entry to clear the selection; a Power BI single-select slicer requires Ctrl+click to deselect. Functionally equivalent, marginally less discoverable.

## 6. Other parity gaps

| # | Item | Status | Evidence | Power BI fix |
|---|---|---|---|---|
| 6.1 | **Page footer** — Cognos `<pageFooter>` is a 25%/50%/25% table: run date (left), page number (centre), run time (right). Screenshot bottom: `Jul 1, 2026` … `1` … `6:36:00 PM`. | **DONE 2026-07-09** | `Report XML.md` `<pageFooter>` block | A `Last Refreshed` card is now on this page, reading `Last refreshed: <date> <time> EDT\|EST`. Run date + run time covered. The **page number** is not reproduced — it has no Power BI analogue. |
| 6.2 | **Title underline** — the blue `CM - Inventory on Hand` title renders underlined in Cognos (from the `tt` stylesheet class; there is no `text-decoration` anywhere in the XML). | **MISSING (cosmetic)** | screenshot; `<textItem>` `refStyle="tt"` + `CSS value="color:blue"` | Set `underline: true` on the textbox `textRun.textStyle`, or accept. |
| 6.3 | **Empty-state message** — Cognos `<noDataHandler>` renders `No Data Available`. | **MISSING (cosmetic)** | `<staticValue>No Data Available</staticValue>` | Power BI renders a blank grid. Low value. |
| 6.4 | Column labels | **Done** | Cognos header text = the dataItem `label` where present (`KG/EA On Hand`→`KG/EA OH`, `LB/EA On Hand`→`LB/EA OH`) else the name. The TMDL column names already *are* the Cognos header strings, so no `columnProperties` rename is needed. All 9 match the screenshot. | none |
| 6.5 | Number formats | **Done** | TMDL `KG/EA OH`, `LB/EA OH`, `Hard Commit` all `formatString: #,0` = Cognos `numberFormat decimalSize="0"` + `text-align:right`. Screenshot: `23,047` / `50,810` / `36,800`. Power BI right-aligns numeric columns by default, matching the Cognos CSS. | none |
| 6.6 | Column order and count | **Done** | 9 Cognos `<listColumn>`s vs 9 `projections.Values`, same order: REGION, Branch Plant, Bulk Item, 2nd Item Number, Status, KG/EA OH, LB/EA OH, Hard Commit, Primary UOM | none |
| 6.7 | Header/grid styling | **Done** | `objects.columnHeaders` bold `#FF0000`; `objects.grid` 1pt `#000000` grid + outline; `stylePreset = 'None'` | none |

**Verified, do NOT "fix":**
- `REGION` here is **both** the slicer source **and** the first displayed column (Cognos displays it; reports 04 and 06 do not). So leaving it visible and unhidden in `CM_Inventory_on_Hand.tmdl` is correct — this is the one table where `isHidden` on `REGION` would be a regression.
- The `REGION` decode defaults to `'OTHER'` and omits `BPIP`, whereas report 04's decode defaults to `'Americas'` and includes `BPIP`. Both are verbatim from their own Cognos `Decode(...)`. Do not harmonise them.
- `MIN(im.IMUOM1)` inside the `CASE` while grouping on `IMUOM1` is Cognos's own aggregate wrapper, reproduced verbatim. Because the group key *is* `IMUOM1`, `MIN()` over the group returns that group's single UOM — functionally a no-op.
- `Hard Commit` is deliberately **not** UOM-converted, while `KG/EA OH` and `LB/EA OH` are. Screenshot row `DPE3500-T2`: `KG/EA OH 25,038`, `LB/EA OH 55,200`, `Hard Commit 36,800` — the hard-commit figure is the raw `LIHCOM` sum. Matches the Cognos expression.
- The `Quantity On Hand > 0` filter is applied **before** aggregation. Confirmed against the raw Cognos SQL: `where "F41021_Item_Location"."LIPQOH"/10000>0 and trim(...IMBULK) in (...)` — a `WHERE`, not a `HAVING`. The `.m` uses `WHERE loc.LIPQOH/10000.0 > 0`, matching.
- Bulk-item whitelist is identical: 120 literals (89 distinct — Cognos's own list contains duplicates) on both sides, symmetric difference empty (checked programmatically). The duplicates were copied verbatim and are harmless.
- The Oracle→T-SQL `trim()` difference (Oracle `trim()` of an all-blank string yields `NULL`, T-SQL `LTRIM(RTRIM())` yields `''`) affects the `Status` column here, but this report never compares `Status` to `''` or `NULL`, never filters on it, and does not sort by it — it only groups by it, and grouping is unaffected. Both render as an empty cell (screenshot rows with blank `Status`). Not the report-07 `Inventory_HP` bug; no action.

## 7. Model-level defects found
**None.**

The brief warned about identifier columns carrying `summarizeBy: sum`. Independently checked: `grep -n "summarizeBy: sum"` across `PBIP/CM Overview LIVE.SemanticModel/definition/tables/` returns **zero hits**. In `CM_Inventory_on_Hand.tmdl` all nine columns are `summarizeBy: none`. There are no measures on this table and no relationships touching it (`relationships.tmdl` only links `SO_Not_Shipping` / `Inventory_Availability` / `WorkOrder_Detail` to `Item`), so nothing can implicitly aggregate.

## Open items checklist

- [x] 6.1 Add a page footer / "Data as of" indicator to replace the Cognos run-date + run-time footer — LOW — **DONE 2026-07-09.** `Last Refreshed` card added to this page and all 7. Page number not reproduced (no analogue).

Still open:

- [ ] 6.2 Underline the blue page title to match the Cognos `tt` style — LOW — ~5 min. Confirmed still absent 2026-07-09 (no `underline` on this page's textbox).
- [ ] 6.3 (optional) Reproduce the Cognos `No Data Available` empty-state message — LOW — ~10 min
- [ ] **Not a code task:** open `CM Overview LIVE.pbip` in Power BI Desktop, re-save and republish so the `Last Refreshed` card reaches users (see `## Status`).

_No HIGH or MED items. Nothing report-specific outstanding._

**Do not** set `isHidden` on `CM_Inventory_on_Hand[REGION]`. Pages 04 and 06 carry that tidy-up because `REGION`
is slicer-only there. Here it is **both** the slicer source **and** the first displayed column, so hiding it
would be a regression. See "Verified, do NOT 'fix'" above.
