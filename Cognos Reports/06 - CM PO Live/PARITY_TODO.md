# Parity TODO — 06 CM PO Live
_Source of truth: PBIP. Power BI page: `CM PO Live` in `CM Overview LIVE` (shared with reports 02-06)._

## Status — 2026-07-09

**The PBIP is updated. The PBIX is not.** `FINAL - for handover/Dashboard - CM Overview LIVE.pbix` was last
written **2026-07-08 14:07**; the PBIP edits landed **2026-07-09 12:30-12:37**. **Someone must open
`CM Overview LIVE.pbip` in Power BI Desktop, re-save, and republish before any user sees these changes.**

Implemented on 2026-07-09, affecting this page:

| Change | Where | Effect |
|---|---|---|
| `Last Refreshed` table + `Last Refreshed Label` measure + a `card` visual on this page (and all 7) | `Last Refreshed.tmdl`, `model.tmdl`, `report.json` | Closes 6.5, and closes the *surfacing* half of 6.4. |

**Three gaps specific to this page remain open and were NOT fixed** — re-verified against `report.json` on
2026-07-09, all three still present:
- **6.1** Both slicer titles still carry only `{show, text, bold}` with **no `fontColor`** key. They render in the
  theme's default dark text, not Cognos's red.
- **6.2** Both slicer titles still read `'Select the Region'` / `'Enter the Date Range'` — **no trailing colon**.
- **6.3** The `tableEx` still has no `objects.values` entry, so **`Next Status` is not right-aligned**.

**6.4 (the rolling 90-day window) is only half closed.** The `Last Refreshed` card now makes the as-of date
visible, which was the recommended mitigation's second half. The first half — **scheduling a daily refresh** —
is an operational task in the Power BI Service and has not been done. The window still freezes at refresh time;
see 6.4 below, which is unchanged and still accurate.

Verified after the edits: `report.json` re-parses; all `config` fields are still JSON-encoded strings; the model
loads (12 tables, 23 measures); this page still has **0** conditional-format markers, matching Cognos.

## Summary
The data layer, column set, column order, header labels, sort order, number/date formats and both prompts are faithful to Cognos, and there is no conditional formatting, grouping or subtotal in the Cognos source (sections 1-3 are genuinely N/A). Three real gaps remain **open**, all on this page and all already specified in `BUILD.md`: the two slicer titles are **not red** (pages 04 and 05 set `fontColor: #FF0000`; this page sets only `bold`), they are **missing their trailing colon**, and the `Next Status` column is **not right-aligned**. Separately, the hard-coded 90-day rolling floor in `CM_PO_Live.m` is evaluated at *refresh* time rather than at *view* time — a behaviour difference from Cognos worth calling out to Rohit. A `Last Refreshed` card now surfaces the as-of date on this page (6.5 done), which is why that difference is at least visible to the reader; scheduling the refresh remains outstanding.

Evidence: `Report XML.md`, `Generated SQL (Cognos - raw).sql`, `CM_PO_Live.m`, `BUILD.md`, `screenshots/Cognos - CM PO Live rendered (...).png`, `PBIP/CM Overview LIVE.Report/report.json` (section `CM PO Live`), `PBIP/CM Overview LIVE.SemanticModel/definition/tables/CM_PO_Live.tmdl`.

## 1. Conditional formatting
**None in Cognos — nothing to port.**

Verified independently: 0 occurrences of `namedConditionalStyles`, `advancedConditionalStyle`, `conditionalStyleRef`, `styleCase`, `conditionalRender` in `Report XML.md`. Every `listColumnTitle` carries the same static `font-weight:bold;color:red;…;border:1pt solid black`; every `listColumnBody` carries only alignment + border. The screenshot shows plain white rows.

Power BI side: `report.json` has 0 `FillRule` / `fillRule` / `Conditional` / `dataBars`. The `fontColor` hits are static literals. Confirmed.

## 2. Grouped lists rendered as flat tables
**None in Cognos — nothing to port.**

0 `<listGroup>`, 0 `<listGroupFooter>`, 0 `<crosstab>` in `Report XML.md`. The Cognos object is a flat `<list>` with 13 `<listColumn>`s. `tableEx` is the correct rebuild.

## 3. Subtotals / summary rows
**None in Cognos — nothing to port.** 0 `<summary>`, 0 `<aggregate>`, 0 `<listGroupFooter>`, 0 `<overallFooter>`.

Correctly reflected in Power BI: `objects.total[0].properties.totals = false` on the `tableEx`. No action.

## 4. Sort order
**Matches.**

| | Sort keys |
|---|---|
| Cognos (`<sortList><sortItem refDataItem="Promised Date" sortOrder="ascending"/></sortList>`) | `Promised Date` ▲ only, `nulls last` |
| Power BI (`prototypeQuery.OrderBy`) | `Promised Date` Direction 1 |

Single key, matching. Note this report sorts on **one** column, unlike 04 (three keys) and 05 (three keys) — do not "helpfully" add tiebreakers. The screenshot confirms a single ascending run: Jul 15 → Jul 25 → Jul 30 → Jul 31 → Aug 3 → … → Oct 23 2026 → Feb 3 2027 → Apr 1 2027, with no secondary ordering within Jul 30. The `.m` deliberately omits `ORDER BY` (illegal in the folded subquery); the visual carries it — already done. Cognos's `nulls last` is moot because the `>= today-90` floor already excludes null promised dates.

## 5. Prompts / parameters
**Both prompts are reproduced 1:1 and behave correctly. The only defects are in their *titles* — see 6.1 and 6.2. The filtering itself is right.**

| Cognos | Definition | Power BI |
|---|---|---|
| `Select the Region: ` | `<selectValue parameter="Select_Region" refQuery="Purchase Orders" multiSelect="false" required="false" autoSubmit="true">` over distinct `REGION` | Slicer on `CM_PO_Live.REGION`, `data.mode = 'Dropdown'`, `selection.singleSelect = true`, title `'Select the Region'` — **bold but no `fontColor`, no colon** |
| `Enter the Date Range:  Beginning … and End Date` | two `<selectDate parameter="1 - Start"/"2 - End" required="false" selectDateUI="editBox">` feeding the optional filter `[Promised Date] between ?1 - Start? and ?2 - End?` | Slicer on `CM_PO_Live.Promised Date`, `data.mode = 'Between'`, title `'Enter the Date Range'` — **bold but no `fontColor`, no colon** |

Binding is right: the Cognos date prompt filters `Promised Date` (not `Requested Date`), and so does the slicer. Both prompts are `required="false"`, so an unanswered prompt returns the full population — which is what an untouched slicer does. The screenshot corroborates: both date boxes read `Jul 1, 2026` yet rows span Jul 15 2026 → Apr 1 2027, i.e. the prompt was never submitted. `autoSubmit="true"` means the Cognos `Finish` button needs no analogue.

**Landing state matches.** `use="optional"` in Cognos means the filter applies *only* when the prompt is answered — an unanswered prompt shows all rows. Verified that neither Power BI slicer carries a baked-in default selection: on both slicer `visualContainer`s, `filters` is `"[]"`, `singleVisual.objects.general` is absent (no persisted filter expression), and `prototypeQuery.Where` is `null`. The page's `filters` array is `[]` and `report.json` has no report-level `filters` key. So the page lands unfiltered, exactly as Cognos does with both prompts unanswered.

One residual difference, not worth fixing: the region slicer is `selection.singleSelect = true`, matching Cognos's `multiSelect="false"`. Cognos's dropdown offers a blank entry to clear the selection; a Power BI single-select slicer requires Ctrl+click to deselect. Functionally equivalent, marginally less discoverable.

### 5.1 VERIFIED CORRECT — not a gap: the `use="prohibited"` region filter is a disabled DUPLICATE
_Recorded because this looks like a bug on a first read and will be re-raised at handover. **No action required. Do not remove or default the region slicer.**_

Report 06 is the only one of the three that contains a `use="prohibited"` filter, and it is `[REGION] in ?Select_Region?`. It is tempting to read that as "the region prompt is inert in Cognos, so our slicer over-filters". **It is not.** There are *two* copies of that filter, on two different queries:

| Query | Filter | `use=` | Effect |
|---|---|---|---|
| `Purchase Orders` (upstream child query) | `[REGION] in ?Select_Region?` | `optional` | **ACTIVE** when the prompt is answered |
| `PO Summary` (the query the list binds to, `<list refQuery="PO Summary">`) | `[REGION] in ?Select_Region?` | `prohibited` | disabled — redundant duplicate |

`PO Summary`'s dataItems are all `[Purchase Orders].[…]` and `[Item Branch].[…]`, i.e. `Purchase Orders` is a child query joined into it. Restricting `REGION` upstream restricts the list. So the Cognos region prompt **does** filter this report, and a Power BI slicer on `CM_PO_Live[REGION]` is correct behaviour, not over-filtering.

The conclusion is robust to the open question about what `prohibited` means: if it meant "active", both copies filter; if it means "disabled", the upstream `optional` copy still filters. Either reading gives an active prompt.

Report 04 has the identical architecture minus the duplicate — its `Sales Orders` child query carries the `optional` `[REGION] in ?Select_Region?`, and its list query `Sales Summary` has no region filter and no `REGION` dataItem at all. Report 04's region prompt is uncontroversially live, which is direct internal evidence for reading 06 the same way. The likeliest history is that Report Studio auto-copied the filter when `REGION` was dragged into `PO Summary`, and the author disabled the duplicate to avoid applying it twice.

**Evidence that `use="prohibited"` = "filter disabled"** (the reading was previously supported only by a `.m` comment in report 01). Across the ten-report corpus, `<detailFilter use="…">` takes exactly three values — `required`, `optional`, `prohibited` (report 02 uses all three) — which is Cognos's filter-usage enum, where `prohibited` is the XML token for the UI's "Disabled". Empirically, prohibited filters containing **literal constants that could only originate from the filter** do not appear in the Cognos-generated SQL:

- Report 02: prohibited `[2nd Item Number]='ML160PFP'` → `ML160PFP` occurs **0** times in `Generated SQL (Cognos - raw).sql`.
- Report 07: prohibited `[Bulk Item] in ('JS168.S', …)` → `JS168.S` occurs **0** times in its generated SQL.
- Report 03: prohibited `[AVAILABLE]>0` → `AVAILABLE` occurs **0** times in its generated SQL.

By contrast, report 05's *active* (default-`use`) whitelist renders in full: `trim(both from "F554101_ITEM_TAG"."IMBULK") in ('161017CX', …)`. Active filters reach the SQL; prohibited ones do not. These are static, non-parameterised predicates, so their absence cannot be explained by an unanswered prompt. This is in-repo evidence, independent of the report-01 author's comment; I have still not checked it against IBM's published schema.

## 6. Other parity gaps

| # | Item | Status | Evidence | Power BI fix |
|---|---|---|---|---|
| 6.1 | **Slicer titles are not red.** Cognos renders both prompt labels `font-weight:bold;color:red` (= `#FF0000`). Pages `CM Open Sales Orders` and `CM Inventory on Hand` both set `vcObjects.title[0].properties.fontColor` to `#FF0000`. **This page sets only `bold`** — the titles render in the theme's default dark text. | **MISSING** | `Report XML.md` `<textItem>` `<staticValue>Select the Region: </staticValue>` with `CSS value="font-weight:bold;color:red"`; screenshot; `BUILD.md` §4 "this **exact plaintext** (red, bold)"; `report.json` — the two `CM PO Live` slicers have `title.properties = {show, text, bold}` with no `fontColor` key | Add to each of the two slicers' `vcObjects.title[0].properties`: `"fontColor": {"solid": {"color": {"expr": {"Literal": {"Value": "'#FF0000'"}}}}}` — copy the exact block from the `CM Open Sales Orders` slicers. |
| 6.2 | **Slicer titles are missing the trailing colon.** Cognos: `Select the Region: ` and `Enter the Date Range:  Beginning`. Page 06: `'Select the Region'`, `'Enter the Date Range'`. Pages 04 and 05 have the colon. | **MISSING (cosmetic)** | `Report XML.md` `<staticValue>` values; `report.json` `title.properties.text` literals | Change the two `title.text` literals to `'Select the Region:'` and `'Enter the Date Range:'`. |
| 6.3 | **`Next Status` is not right-aligned.** Uniquely on this report, Cognos right-aligns the `Next Status` body cells alongside the three numeric columns. (On report 04 the same column is left-aligned — so this is a real, report-specific difference, not a template artefact.) `Next Status` is a `string` column in the TMDL, so Power BI left-aligns it by default and there is no per-column override in `report.json`. | **MISSING** | `Report XML.md` `listColumn[9]` `listColumnBody` `CSS value="text-align:right;border:1pt solid black"`; screenshot shows `400` right-aligned; `BUILD.md` §"Alignment": "the three numeric columns … **and Next Status** are `text-align:right`"; `report.json` has no `objects.values` on this visual | Add to the `tableEx` `singleVisual.objects`: `"values": [{"properties": {"alignment": {"expr": {"Literal": {"Value": "'Right'"}}}}, "selector": {"metadata": "CM_PO_Live.Next Status"}}]`. In the UI: select the table → Format → Values → Column-specific → `Next Status` → Alignment = Right. |
| 6.4 | **Rolling 90-day window freezes at refresh time.** Cognos re-evaluates `to_date(sysdate) - 90` on every run. `CM_PO_Live.m` folds it to `AND d.Promised_Date >= DATEADD(DAY,-90, CAST(GETDATE() AS date))`, so in an import model the window is fixed at the last refresh. A report left unrefreshed for a week silently shows a window ending a week ago. Reports 04 and 05 have no time-dependent predicate and are immune. | **BEHAVIOUR DIFFERENCE — half addressed** | `CM_PO_Live.m` line 276 / TMDL partition line 276; Cognos generated SQL `Promised_Date >= to_date(sysdate)-90`; `.m` header already concedes "report is 'as of last refresh'" | Preferred fix was: schedule a daily refresh **and** surface a `Data as of` card. **The card is done (2026-07-09) — the window is no longer *silently* stale, since the page now states its as-of timestamp.** Scheduling the daily refresh is **still outstanding** and is an operational task in the Power BI Service. Alternative (not taken): move the floor out of the query into a report-level filter or DAX so it re-evaluates at view time — but that changes the folded query and the row count, so it needs re-validation. Still recommend the first. |
| 6.5 | **Page footer** — Cognos `<pageFooter>` is a 25%/50%/25% table: run date (left), page number (centre), run time (right). | **DONE 2026-07-09** | `Report XML.md` `<pageFooter>` block | A `Last Refreshed` card is now on this page, reading `Last refreshed: <date> <time> EDT\|EST`. This matters more here than on 04/05 because of 6.4 — the as-of date is load-bearing on this page. The **page number** is not reproduced (no Power BI analogue). |
| 6.6 | **Title underline** — the blue `CM - PO Live` title renders underlined in Cognos (from the `tt` stylesheet class; no `text-decoration` appears in the XML). | **MISSING (cosmetic)** | screenshot; `<textItem>` `refStyle="tt"` + `CSS value="color:blue"` | Set `underline: true` on the textbox `textRun.textStyle`, or accept. |
| 6.7 | **Empty-state message** — Cognos `<noDataHandler>` renders `No Data Available`. | **MISSING (cosmetic)** | `<staticValue>No Data Available</staticValue>` | Low value. |
| 6.8 | Column header labels | **Done** | `columnProperties` in `report.json` renames `Branch Plant`→`Branch`, `Purchase Order Number`→`PO #`, `Line Number`→`Line #`, `2nd Item Number`→`Item`, `Primary Quantity`→`QTY`, `Open Quantity`→`Open QTY`, `Secondary Quantity`→`2nd QTY`. `Company`, `Bulk Item`, `Next Status`, `Requested Date`, `Promised Date`, `Vendor Name` need no rename. All 13 match the screenshot. | none |
| 6.9 | Number/date formats | **Done** | TMDL: `Primary Quantity` / `Open Quantity` / `Secondary Quantity` `formatString: #,0` (= `numberFormat decimalSize="0"`); `Requested Date` / `Promised Date` `formatString: MMM d, yyyy` (= `dateFormat dateStyle="medium"` with no `displayOrder`, i.e. month-first — screenshot `Jun 19, 2026`); `Purchase Order Number` `formatString: 0`, no thousands separator (screenshot `177205`) | none |
| 6.10 | Column order and count | **Done** | 13 Cognos `<listColumn>`s vs 13 `projections.Values`, same order | none |
| 6.11 | Header/grid styling | **Done** | `objects.columnHeaders` bold `#FF0000`; `objects.grid` 1pt `#000000` grid + outline; `stylePreset = 'None'` | none |

**Verified, do NOT "fix":**
- The `REGION` decode defaults to `'OTHER'` and omits `BPIP`, whereas report 04's decode defaults to `'Americas'` and includes `'BPIP'`. Both are verbatim from their own Cognos `Decode(...)` (`Report XML.md`, dataItem `REGION`). This looks like a copy-paste bug across the three `.m` files and is not one.
- Double-SUM (`Purchase_Orders5` sums `PDPQOR`/`PDUOPN`/`PDSQOR`, the outer query sums them again), the `Item_Branch6` fan-out on `(Branch_Plant, 2nd_Item)`, and the degenerate `LEFT OUTER JOIN … WHERE po.<key> = ib.<key>` (which behaves as an inner join) are all reproduced deliberately so the rebuild ties to the live Cognos numbers. Documented in `BUILD.md` "Known Cognos quirks".
- Bulk-item whitelist is identical: 75 values in the Cognos filter, 75 in the `.m`, symmetric difference empty (checked programmatically).
- `Open Quantity > 0` is applied pre-aggregation in both (`WHERE d.PDUOPN/10000.0 > 0`), matching the Cognos generated SQL.
- Date format is month-first here (`MMM d, yyyy`) and day-first on report 04 (`d MMM, yyyy`). Correct — Cognos report 04 sets `displayOrder="DMY"` on its `dateFormat`, this one does not. Already fixed per the brief; not re-reported.

## 7. Model-level defects found
**None.**

The brief warned about identifier columns carrying `summarizeBy: sum`. Independently checked: `grep -n "summarizeBy: sum"` across `PBIP/CM Overview LIVE.SemanticModel/definition/tables/` returns **zero hits**. In `CM_PO_Live.tmdl` all 14 columns — including `Purchase Order Number` (`int64`), `Line Number` (`double`), and the three quantity columns — are `summarizeBy: none`. Nothing latent to correct if these tables are ever put into a matrix.

One tidy-up rather than a defect: `CM_PO_Live.m` documents `REGION` as "carried as a hidden slicer column", but `CM_PO_Live.tmdl` sets no `isHidden` on it, so it shows in the Fields pane. Cognos does not display `REGION` on this report (it is a prompt source only), and the Power BI table correctly does not project it — only the model metadata disagrees with the comment.

## Open items checklist

- [x] 6.5 Add a page footer / "Data as of" indicator to replace the Cognos run-date + run-time footer — MED here (LOW on 04/05) — **DONE 2026-07-09.** `Last Refreshed` card added to this page and all 7. Page number not reproduced (no analogue).

Still open — **this page has more outstanding work than 04 or 05**:

- [ ] 6.1 Set `fontColor` `#FF0000` on both slicer titles (`Select the Region`, `Enter the Date Range`) to match Cognos and pages 04/05 — MED — ~5 min. **Confirmed still missing 2026-07-09**: both slicers' `title[0].properties` = `{show, text, bold}`, no `fontColor`.
- [ ] 6.3 Right-align the `Next Status` column in the table visual — MED — ~5 min. **Confirmed still missing 2026-07-09**: the `tableEx` `objects` has only `{total, columnHeaders, grid}` — no `values` entry.
- [ ] 6.4 Rolling-90-day behaviour — **half done.** The "Data as of" indicator is now surfaced (6.5), so the staleness is at least visible. **Still to do: schedule a daily refresh in the Power BI Service.** The alternative (move the floor to a view-time filter) changes the folded query and row count and would need re-validation; not recommended — MED — ~30 min for the schedule, or ~1 hr incl. re-validation if the floor is moved
- [ ] 6.2 Add the trailing colon to both slicer titles — LOW — ~2 min. **Confirmed still missing 2026-07-09**: titles read `'Select the Region'` and `'Enter the Date Range'`.
- [ ] 6.6 Underline the blue page title to match the Cognos `tt` style — LOW — ~5 min. Confirmed still absent 2026-07-09.
- [ ] 7.1 Set `isHidden` on `CM_PO_Live[REGION]` so the slicer-only column stops appearing in the Fields pane — LOW — ~2 min. Confirmed still absent 2026-07-09 (`CM_PO_Live.tmdl` line 126, no `isHidden`).
- [ ] 6.7 (optional) Reproduce the Cognos `No Data Available` empty-state message — LOW — ~10 min
- [ ] **Not a code task:** open `CM Overview LIVE.pbip` in Power BI Desktop, re-save and republish so the `Last Refreshed` card reaches users (see `## Status`).

**Reminder for whoever picks up 6.1 / 6.2 / 6.3:** do not "fix" the region slicer while you are in there. §5.1
explains why the `use="prohibited"` region filter is a disabled duplicate and the slicer is correct as built.
