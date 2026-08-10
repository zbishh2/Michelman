# Parity TODO — 04 CM Open Sales Orders Live
_Source of truth: PBIP. Power BI page: `CM Open Sales Orders` in `CM Overview LIVE` (shared with reports 02-06)._

## Status — 2026-07-09

**The PBIP is updated. The PBIX is not.** `FINAL - for handover/Dashboard - CM Overview LIVE.pbix` was last
written **2026-07-08 14:07**; the PBIP edits landed **2026-07-09 12:30-12:37**. **Someone must open
`CM Overview LIVE.pbip` in Power BI Desktop, re-save, and republish before any user sees these changes.**

Implemented on 2026-07-09, affecting this page:

| Change | Where | Effect |
|---|---|---|
| `Last Refreshed` table + `Last Refreshed Label` measure + a `card` visual on this page (and all 7) | `Last Refreshed.tmdl`, `model.tmdl`, `report.json` | Closes 6.1 — reproduces the Cognos footer's run date and run time. |

No other change was needed on this page: it had **no** conditional formatting, **no** grouped list, **no**
subtotal row and **no** model-level defect, and none was introduced. Verified after the edits: `report.json`
re-parses; all `config` fields are still JSON-encoded strings; the model loads (12 tables, 23 measures); this
page still has **0** conditional-format markers, matching Cognos.

The card shows `Last refreshed: <date> <time> EDT|EST`, computed from `DateTimeZone.FixedUtcNow()` with the US
Eastern DST rule applied — not `DateTime.LocalNow()`, which returns UTC in the Service but machine-local time on
Desktop and would therefore disagree between them. The Cognos footer's **page number** has no Power BI analogue
and is not reproduced.

## Summary
The data layer, column set, column order, header labels, sort order, number/date formats and both prompts are faithful to Cognos. The bulk-item whitelist (76 entries) and the `Next Status <> '999'` filter match the Cognos XML exactly, and every model column is `summarizeBy: none`. There is **no** conditional formatting, **no** grouped list and **no** subtotal row in the Cognos source, so sections 1-3 are genuinely N/A rather than "not done yet".

The Cognos page footer **is now reproduced** as a `Last Refreshed` card (6.1, done 2026-07-09). The remaining open items are cosmetic and shared with pages 05 and 06: the page title is not underlined, `REGION` is left visible in the model, and the `No Data Available` empty state is not reproduced.

Evidence: `Report XML.md`, `Generated SQL (Cognos - raw).sql`, `CM_Open_Sales_Orders.m`, `screenshots/Cognos - CM Open Sales Orders LIVE rendered (...).png`, `PBIP/CM Overview LIVE.Report/report.json` (section `CM Open Sales Orders`), `PBIP/CM Overview LIVE.SemanticModel/definition/tables/CM_Open_Sales_Orders.tmdl`.

## 1. Conditional formatting
**None in Cognos — nothing to port.**

Verified independently: `Report XML.md` contains 0 occurrences of `namedConditionalStyles`, `advancedConditionalStyle`, `conditionalStyleRef`, `styleCase` and `conditionalRender`. Every `listColumnBody` carries only static CSS (`text-align:*` + `border:1pt solid black`). The rendered screenshot shows plain white rows with no highlighting.

Power BI side: `report.json` contains 0 occurrences of `FillRule`, `fillRule`, `Conditional` and `dataBars`. The `fontColor` / `backColor` hits in that file are all static literals (red column headers, red slicer titles), not rules. This matches Cognos.

## 2. Grouped lists rendered as flat tables
**None in Cognos — nothing to port.**

`Report XML.md` contains 0 `<listGroup>`, 0 `<listGroupFooter>` and 0 `<crosstab>`. The Cognos object is a flat `<list>` with 16 `<listColumn>` children. The Power BI `tableEx` is therefore the correct visual type; a `pivotTable` would be a regression here.

## 3. Subtotals / summary rows
**None in Cognos — nothing to port.** 0 `<summary>`, 0 `<aggregate>`, 0 `<listGroupFooter>`, 0 `<overallFooter>` in the XML, and the screenshot shows no total row.

Correctly reflected in Power BI: the `tableEx` sets `objects.total[0].properties.totals = false`. No action.

## 4. Sort order
**Matches.**

| | Sort keys |
|---|---|
| Cognos (`<sortList>` on the list) | `Promised Ship Date` ▲, `Order Number` ▲, `Order Line` ▲ (all default ascending, `nulls last`) |
| Power BI (`prototypeQuery.OrderBy`) | `Promised Ship` Direction 1, `Order #` Direction 1, `Line #` Direction 1 |

Cognos's `nulls last` is reproduced by Power BI's blanks-last behaviour on ascending sorts. The `.m` deliberately omits `ORDER BY` (illegal inside the folded subquery) and pushes the sort to the visual — that is done, not outstanding.

## 5. Prompts / parameters
**Both prompts reproduced. No gaps.**

| Cognos | Definition | Power BI |
|---|---|---|
| `Select the Region:` | `<selectValue parameter="Select_Region" multiSelect="false" required="false" autoSubmit="true">` over distinct `REGION` | Slicer on `CM_Open_Sales_Orders.REGION`, `data.mode = 'Dropdown'`, `selection.singleSelect = true`, title `'Select the Region:'` bold `#FF0000` |
| `Enter the Date Range: Beginning … and End Date` | two `<selectDate parameter="1 - Start"/"2 - End" required="false" selectDateUI="editBox">` feeding the optional filter `[Promised Ship Date] between ?1 - Start? and ?2 - End?` | Slicer on `CM_Open_Sales_Orders.Promised Ship`, `data.mode = 'Between'`, title `'Enter the Date Range:'` bold `#FF0000` |

**Both Cognos prompts are reproduced 1:1, and this was checked, not assumed.** Report 04 contains zero `use="prohibited"` filters; both of its prompt filters sit on the `Sales Orders` child query as `use="optional"`, and both are genuinely active. The Power BI slicers bind the matching columns — `[REGION]` and `[Promised Ship]` (the column the Cognos filter names, not `Requested`).

**Landing state matches.** `use="optional"` in Cognos means the filter applies *only* when the prompt is answered — an unanswered prompt shows all rows. Verified that neither Power BI slicer carries a baked-in default selection: on both slicer `visualContainer`s, `filters` is `"[]"`, `singleVisual.objects.general` is absent (no persisted filter expression), and `prototypeQuery.Where` is `null`. The page's `filters` array is `[]` and `report.json` has no report-level `filters` key. So the page lands unfiltered, exactly as Cognos does with both prompts unanswered. The screenshot confirms the Cognos side (prompts show `Jul 1, 2026`/`Jul 1, 2026` yet rows span 1 Jul → 21 Jul, i.e. the filter was never applied).

The Cognos `Finish` button has no Power BI analogue and needs none (slicers auto-apply, matching `autoSubmit="true"`).

One residual difference, not worth fixing: the region slicer is `selection.singleSelect = true`, matching Cognos's `multiSelect="false"`. Cognos's dropdown offers a blank entry to clear the selection; a Power BI single-select slicer requires Ctrl+click to deselect. Functionally equivalent, marginally less discoverable.

## 6. Other parity gaps

| # | Item | Status | Evidence | Power BI fix |
|---|---|---|---|---|
| 6.1 | **Page footer** — Cognos `<pageFooter>` is a 25%/50%/25% table: run date (left), page number (centre), run time (right). Screenshot bottom: `Jul 1, 2026` … `1` … `6:32:32 PM`. | **DONE 2026-07-09** | `Report XML.md` `<pageFooter>` block | A `Last Refreshed` card is now on this page, reading `Last refreshed: <date> <time> EDT\|EST`. Run date + run time covered. The **page number** is not reproduced — it has no Power BI analogue. |
| 6.2 | **Title underline** — the blue title renders underlined in Cognos (from the `tt` default style class; there is no `text-decoration` in the XML, so it comes from the Cognos stylesheet). | **MISSING (cosmetic)** | screenshot; `<textItem>` with `refStyle="tt"` + `CSS value="color:blue"` | Set `underline: true` on the textbox `textRun.textStyle`, or accept the difference. |
| 6.3 | **Empty-state message** — Cognos `<noDataHandler>` renders `No Data Available` when the list is empty. | **MISSING (cosmetic)** | `Report XML.md` `<noDataHandler>` + `<staticValue>No Data Available</staticValue>` | Power BI shows a blank grid instead. Low value; skip unless Rohit asks. |
| 6.4 | Column header labels — Cognos shows duplicate `QTY`/`UOM` headers for the primary and secondary pairs. | **Done** | `columnProperties` in `report.json` renames `Primary Qty`→`QTY`, `Primary UOM`→`UOM`, `Secondary Qty`→`QTY`, `Secondary UOM`→`UOM` | none |
| 6.5 | Number/date formats | **Done** | TMDL: `Primary Qty` / `Secondary Qty` `formatString: #,0` (= Cognos `numberFormat decimalSize="0"` + right-align); `Order Date` / `Requested` / `Promised Ship` `formatString: d MMM, yyyy` (= Cognos `dateFormat dateStyle="medium" displayOrder="DMY"`); `Order #` `formatString: 0` (no thousands separator, matches `2629816` in the screenshot) | none |
| 6.6 | Column order and count | **Done** | 16 Cognos `<listColumn>`s vs 16 `projections.Values` in the same order | none |
| 6.7 | Header/grid styling | **Done** | `objects.columnHeaders` = bold `#FF0000`; `objects.grid` = 1pt `#000000` horizontal + vertical + outline; `stylePreset = 'None'` | none |

**Verified, do NOT "fix":**
- The `REGION` decode in `CM_Open_Sales_Orders.m` defaults to `'Americas'` and includes `'BPIP' → 'Americas'`. Reports 05 and 06 default to `'OTHER'` and have no `BPIP`. This asymmetry is **correct** — it is verbatim from each report's own Cognos `Decode(...)` expression (`Report XML.md`, dataItem `REGION`). It looks like a copy-paste bug and is not one.
- The double-SUM (`Sales_Orders6` sums, then the outer query sums again) and the `Item_Branch7` fan-out are reproduced deliberately so the rebuild ties to the live Cognos numbers. Documented in `BUILD.md` "Known Cognos quirks".
- The degenerate `LEFT OUTER JOIN … WHERE so6.<key> = ib7.<key>` (which behaves as an inner join) is verbatim Cognos.
- The bulk-item whitelist is byte-identical: 76 values in the Cognos filter, 76 in the `.m`, symmetric difference empty (checked programmatically).
- `Next Status not in ('999')` is present in the `.m` as `WHERE o.SDNXTR NOT IN ('999')`.

## 7. Model-level defects found
**None.**

The brief warned about identifier columns carrying `summarizeBy: sum`. Independently checked: `grep -n "summarizeBy: sum"` across `PBIP/CM Overview LIVE.SemanticModel/definition/tables/` returns **zero hits**. In `CM_Open_Sales_Orders.tmdl` all 17 columns — including `Order #` (`int64`), `Line #` (`double`), `Primary Qty` and `Secondary Qty` — are `summarizeBy: none`. Nothing latent to correct.

One tidy-up rather than a defect: `REGION` is a slicer-only column (it is not one of the 16 projected table columns, and Cognos does not display it on this report) but has no `isHidden` in the TMDL, so it appears in the Fields pane. The `.m` header comment already describes it as "carried as a non-visible column", so the code and the model disagree by omission.

## Open items checklist

- [x] 6.1 Add a page footer / "Data as of" indicator to replace the Cognos run-date + run-time footer — LOW — **DONE 2026-07-09.** `Last Refreshed` card added to this page and all 7. Page number not reproduced (no analogue).

Still open:

- [ ] 6.2 Underline the blue page title to match the Cognos `tt` style — LOW — ~5 min. Confirmed still absent 2026-07-09 (no `underline` on this page's textbox).
- [ ] 7.1 Set `isHidden` on `CM_Open_Sales_Orders[REGION]` so the slicer-only column stops appearing in the Fields pane — LOW — ~2 min. Confirmed still absent 2026-07-09 (`CM_Open_Sales_Orders.tmdl` line 150, no `isHidden`).
- [ ] 6.3 (optional) Reproduce the Cognos `No Data Available` empty-state message — LOW — ~10 min
- [ ] **Not a code task:** open `CM Overview LIVE.pbip` in Power BI Desktop, re-save and republish so the `Last Refreshed` card reaches users (see `## Status`).
