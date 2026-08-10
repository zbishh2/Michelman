# Parity TODO — 09 - Ivan FC 2023
_Source of truth: PBIP. Structural twin of `07 - Ivan SK 2023`._

## Status — 2026-07-09

**A "last refreshed" timestamp was added to this report's `PBIP\`. It is in the PBIP only — it is not in
the PBIX.** `FINAL - for handover\1 - Ivan FC 2023.pbix` was opened and inspected on 2026-07-09: it
contains no `Last Refreshed` table and no `card` visual. Someone must open
`PBIP\1 - Ivan FC 2023.pbip` in Power BI Desktop and re-save / publish before any user sees this. Nothing
else in this document changed state; every other item below is still open.

What shipped into the PBIP (each row checked against the file, not taken on report):

| Change | Location | Verified |
|---|---|---|
| `Last Refreshed` table — a single-row `#table` computing US Eastern time from `DateTimeZone.FixedUtcNow()` | `…SemanticModel/definition/tables/Last Refreshed.tmdl` | Yes |
| Columns `Last Refreshed` (`formatString: MMM d, yyyy h:mm:ss AM/PM`) and `Time Zone` (`EDT` / `EST`) | same file | Yes |
| Measure `Last Refreshed Label` | same file | Yes |
| Registered in the model — `ref table 'Last Refreshed'` plus an entry in `PBI_QueryOrder` | `…SemanticModel/definition/model.tmdl` | Yes |
| A `card` visual bound to that measure on **every page — 5 of 5** (`x=8, y=4, 300×34`, sitting above the table at `y=46`; no overlap) | `…Report/report.json` | Yes |
| Model still loads | MCP `ConnectFolder` → 7 tables, 1 measure, 0 relationships | Yes |
| `report.json` re-parses and all 31 nested `config` / `filters` / `query` payloads are still JSON-encoded strings | `…Report/report.json` | Yes |

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
- **The stamp renders month-first (`Jul 9, 2026 3:04:12 PM`) while every data date column in this report
  renders day-first (`9 Jul, 2026`, per Cognos `dateStyle="medium" displayOrder="DMY"`).** The month-first
  choice was made to match Cognos's rendered page-footer run-date. That footer does not appear in
  `Report XML.md` — Cognos generates it at render time — so the justification could not be confirmed from
  anything in this repo. Cosmetic; change the column's `formatString` if a reviewer objects to the
  inconsistency.

Related and worth knowing: `Work_Orders[DATE]` is Cognos's `current_timestamp` (`GETDATE()`) column, it is
Cognos column 22 of 22 on the **Work Order** page, and it keeps `formatString: General Date`. This report
therefore already displayed a refresh timestamp on one page before the card was added; the card
generalises that to all five. See item 7.2 — `General Date` there is correct and was not changed.

**Not changed, deliberately:** date formats were already corrected repo-wide to `d MMM, yyyy` before this
build, and `Work_Orders[DATE]` keeps `General Date`. Neither is new work.

## Summary
The Power BI rebuild is a faithful reproduction of the Cognos report. All five Cognos `<list>` visuals are correctly rebuilt as flat `tableEx` tables with matching column count, **column order**, and **sort keys**; Cognos has no conditional formatting, no grouping, no subtotals and no prompts, so sections 1, 2, 3 and 5 are genuinely N/A rather than missed work.

Both known model-level defects for this report family (the Oracle `trim()=''` → NULL port, and the missing render-DISTINCT) **are already fixed here**, and the third (F42119 sales-history decay) does not apply to this report at all. Two items in the briefed ground truth are wrong and are corrected in section 7: there are **no** `summarizeBy: sum` columns anywhere, and the `Work_Orders.DATE` column **is** a rendered Cognos column whose `General Date` format is correct.

The only real remaining gaps are cosmetic: **cell text alignment** (Cognos left-aligns numeric-ID and date columns; Power BI right-aligns them by default) and the missing **"No Data Available"** empty-state message. Nothing here blocks handover.

Since this audit was written, a per-page "last refreshed" card has been added to the PBIP — see the Status
block above. That is additive, not a Cognos parity item; Cognos has no such element in the report
definition.

## 1. Conditional formatting
**None in Cognos — nothing to port.**

Verified independently: `Report XML.md` contains 0 occurrences of `advancedConditionalStyle`, `conditionalStyleRefs`, `conditionalStyleRef`, `styleCase` and `reportCondition`. Correspondingly `report.json` contains no `objects.values[]` entries and no `FillRule` / `Conditional` markers. This matches the briefed ground truth.

**Do not confuse with static styling, which does exist and *is* ported.** Every list column title in Cognos carries `CSS value="font-weight:bold;color:red;text-align:left;border:1pt solid black"` and every body cell carries `border:1pt solid black`. This is unconditional formatting, and the rebuild reproduces it:

| Cognos static style | Power BI equivalent (`report.json`) | Status |
|---|---|---|
| Header `color:red` | `objects.columnHeaders[0].properties.fontColor` = `'#FF0000'` | Ported |
| Header `font-weight:bold` | `objects.columnHeaders[0].properties.bold` = `true` | Ported |
| Cell `border:1pt solid black` | `objects.grid[0]`: `gridVertical`/`gridHorizontal` = `true`, both colors `'#000000'`, both weights `1L`, `outlineColor` `'#000000'`, `outlineWeight` `1L` | Ported |

Present and identical on all 5 pages.

## 2. Grouped lists rendered as flat tables
**None in Cognos — nothing to port.**

`Report XML.md` contains 0 `<listGroup>`, 0 `<listGroupFooter>` and 0 `<crosstab>`. All five visuals are plain `<list>` elements, so a flat `tableEx` is the correct Power BI target — a `pivotTable` (matrix) would be *wrong* here.

| Cognos list | `refQuery` | Power BI page | Visual type | Verdict |
|---|---|---|---|---|
| `List1` | Inventory | Inventory | `tableEx` | Correct |
| `List4` | Work Orders | Work Order | `tableEx` | Correct |
| `List3` | Sales Order Summary | Sales Orders | `tableEx` | Correct |
| `List5` | Inventory - New | Inventory HP | `tableEx` | Correct |
| `List2` | Safety Stock - New | Safety Stock HP | `tableEx` | Correct |

## 3. Subtotals / summary rows
**None in Cognos — nothing to port.** No `<listGroupFooter>`, `<listFooter>`, `<overallFooter>` or `<listColumnFooter>` anywhere in the XML.

Power BI correctly suppresses the totals row: every page has `objects.total[0].properties.totals.expr.Literal.Value = "false"`. Verified on all 5 pages.

Note on `aggregate="total"`: the Cognos *queries* mark some data items `aggregate="total"` (e.g. `Inventory.Quantity On Hand`, `Work Orders.Issued Quantity`). This is Cognos's query-level auto-aggregation, which produces the row grain — **not** a rendered subtotal row. The rebuild reproduces it as `GROUP BY` / `SELECT DISTINCT` in the `.m` (see section 7), which is the correct translation.

## 4. Sort order
**Match — all five lists.** Cognos `<sortList>` sits on the layout `<list>` element (not on the query), and no `<sortItem>` carries a sort-order attribute, so all keys are ascending. Power BI `prototypeQuery.OrderBy` uses `Direction: 1` (ascending) throughout.

| Page | Cognos `<sortList>` keys | Power BI `OrderBy` | Verdict |
|---|---|---|---|
| Inventory | Global Bulk Item, Bulk Item, 2nd Item Number | same, all ASC | Match |
| Work Order | REGION, Start Date, Completed Date | same, all ASC | Match |
| Sales Orders | Order Company, Global Bulk Item, Bulk Item, Scheduled Pick Date | same, all ASC | Match |
| Inventory HP | Global Bulk Item, Bulk Item, 2nd Item Number | same, all ASC | Match |
| Safety Stock HP | REGION | same, ASC | Match |

**NEEDS REVIEW (LOW):** Cognos's generated SQL sorts `asc nulls last` (see `Generated SQL (Cognos - raw).sql`), whereas Power BI's ascending sort places blanks **first**. In practice the sort keys are all `LTRIM(RTRIM(...))` expressions that yield `''` (empty string, not NULL) and both engines sort `''` first, so this is very likely a non-issue. Worth one spot-check on a page whose sort key can be genuinely NULL before dismissing.

## 5. Prompts / parameters
**None in Cognos — nothing to port.** 0 `promptPage`, 0 `<parameter`, 0 `selectValue`, 0 `selectDate`, 0 `?p_` references. All filtering is hardcoded into the queries.

Correspondingly Power BI has no slicers, no report-level filters (`filters: None`), and empty `filters: []` on every page and every visual. Consistent and correct.

## 6. Other parity gaps

| # | Gap | Evidence | Severity | Power BI fix |
|---|---|---|---|---|
| 6.1 | **Cell alignment differs on numeric-ID and date columns.** Cognos left-aligns `Customer Code`, `Global Parent`, `Order Number`, `WO Number` and *all* date columns (`NOW`, `Start Date`, `Completed Date`, `Order Date`, `Requested Date`, `Promised Ship Date`, `Scheduled Pick Date`). In Power BI these are `int64` / `dateTime`, which right-align by default. | Cognos `listColumnBody` CSS `text-align:left` on those columns; TMDL shows `dataType: int64` / `dateTime`. `report.json` has no `objects.values[]` alignment entries. | LOW (cosmetic, but visible side-by-side) | Add per-column `objects.values[]` entries with `selector.metadata` = the column's queryRef and `properties.alignment` = `Literal "'Left'"`. 11 columns across 3 pages. |
| 6.2 | **`noDataHandler` empty-state message not reproduced.** Each Cognos list renders the text **"No Data Available"** when its query returns no rows; a Power BI `tableEx` renders an empty grid with headers only. | `<noDataHandler>` present on all 5 Cognos lists; no equivalent in `report.json`. | LOW | No native `tableEx` equivalent. Either accept, or overlay a card/textbox whose visibility is driven by a `COUNTROWS(...) = 0` measure. |
| 6.3 | **Auto date/time hierarchy is enabled** — not a Cognos feature; adds a hidden date table per date column and bloats the model. | `model.tmdl`: `annotation __PBI_TimeIntelligenceEnabled = 1` and `ref table DateTableTemplate_13e223e7-...`. | LOW | Power BI Desktop → Options → Current File → Data Load → uncheck "Auto date/time". |
| 6.4 | **Hardcoded Work Orders start date `2025-11-01`.** Faithful to Cognos, but it is a literal that silently ages. | Cognos `Work Orders` detailFilter `[Start Date]>=2025-11-01`; `Work_Orders.m` renders `>= '2025-11-01'`. | LOW (informational) | None — parity is correct. Flag to the business as a maintenance item, since Cognos had the same landmine. |

**Not gaps** (checked and dismissed): number formats — all 21 Cognos numeric columns are `<numberFormat decimalSize="0"/>` and all map to TMDL `formatString: #,0`. Date formats are `d MMM, yyyy` per prior fix. Column order matches Cognos exactly on all 5 pages (16 / 22 / 29 / 11 / 9 columns). `horizontalPagination="true"` on the Cognos lists has no Power BI analogue and needs none.

## 7. Model-level defects found
**No new defects. All applicable known defects are already fixed.** Two briefed assumptions are incorrect and are corrected below.

| Known defect | Status in this report | Evidence |
|---|---|---|
| (a) Oracle `trim()=''` is NULL, not ported → `Inventory_HP` returns 0 rows | **FIXED** | `Inventory_HP.m:71` — `WHERE (loc.LILOTS IS NULL OR LTRIM(RTRIM(loc.LILOTS)) = '' OR LTRIM(RTRIM(loc.LILOTS)) IN ('T','B','Q','H'))`. Carries both the `IS NULL` and the `= ''` arm, matching Cognos `[Status] = null or [Status] in ('T','B','Q','H')`. |
| (b) Cognos render-DISTINCT missing → `Work_Orders` over-counts | **FIXED** | `Work_Orders.m:67` `SELECT DISTINCT`. Also present where needed in `Safety_Stock_HP.m:36` and `Sales_Order_Summary.m:96` (Item Information CTE) plus the outer `GROUP BY`. |
| (c) F4211-only sales history decays as lines purge to F42119 | **N/A — does not apply** | Neither the Cognos SQL nor the `.m` touches sales *history*. `Generated SQL (Cognos - raw).sql` has 0 `F42119` references. The `Sales Order Summary` query reads **open** orders from `F4211` filtered `SDNXTR NOT IN ('570','580','620','999')`, so purged lines are out of scope by construction. Adding an F42119 union here would be a bug, not a fix. |

### Corrections to the briefed ground truth

**7.1 — `summarizeBy: sum` on identifier columns: NOT PRESENT.** All **86** columns across the five tables are `summarizeBy: none` (`grep -c "summarizeBy:"` → 86, all `none`); `isHidden` appears 0 times. `WO Number`, `Order Number`, `Customer Code` and `Global Parent` are `int64` with `formatString: 0` and `summarizeBy: none`. Nothing to fix. Additionally, every visual projection is a raw grouped `Column` reference — `prototypeQuery.Select` contains **zero** `Aggregation` nodes on all 5 pages — so no column is being summed even implicitly.

**7.2 — `Work_Orders.DATE` IS displayed, and `General Date` is the correct format.** It is Cognos column **22 of 22** on the Work Order list (`<dataItemValue refDataItem="DATE"/>`), right-aligned, and it is projected as the 22nd column in `report.json`. Its Cognos expression is `current_timestamp` (a full timestamp, not a date), and it is the one date-ish column in the whole report with **no** `<dataFormat>` element — Cognos renders it raw with time. Power BI's `formatString: General Date` (date + time) is therefore the *faithful* rendering. **No change required, and it was not changed.** This is not a technical/lineage column. Because `current_timestamp` evaluates at query time, this column is itself a refresh timestamp — the Work Order page has always carried one.

### Faithful-but-surprising items (explain to Rohit; do not "fix")
These will each look like a bug to a reviewer. All were verified against Cognos and are correct.

- **`Safety Stock HP` shows `REGION` twice** (columns 1 and 9). Cognos's `List2` genuinely has two `REGION` columns — the 9th is even right-aligned, as if the original author pasted it into a measure slot. Power BI reproduces this as `Safety_Stock_HP.REGION` and `Safety_Stock_HP.REGION 2`; the `2` suffix is Power BI's alias for a second projection of the same column (`prototypeQuery.Select[8]` has `NativeReferenceName: "REGION"`, `Property: "REGION"`). It is **not** a dangling reference. Recommend asking the business whether to drop it — but dropping it is a deliberate divergence, not a fix.
- **`Scheduled Pick Date` is identical to `Promised Ship Date`.** Cognos's own generated SQL aliases the *same* physical column `T0.C18` (JDE `SDPDDJ`) as both `Promised_Ship_Date` and `Scheduled_Pick_Date`; `SDPPDJ` never appears. `Sales_Order_Summary.m` emits `SO7.Promised_Ship_Date` twice, which is exact.
- **`REGION` decodes differ per page, by design.** Inventory / Work Order use `Singapore / India / China / Aubange / Americas` with an `ELSE 'ERROR'`; Inventory HP / Safety Stock HP use `Americas / EMEA / PacRim / India / China` with **no** `ELSE` (so NULL is possible). Work Order's decode covers only 4 branch plants (`SING`, `CINC`, `AUBA`, `CIN2`) and the Work Orders query has **no branch-plant filter**, so `'ERROR'` can legitimately appear on that page. All four variants are reproduced verbatim in the `.m` files.
- **UOM sentinel values.** Unknown UOM emits `100000` on Inventory (`OH KG` / `OH LB`), `1000000` on Sales Orders (`ORDER KGs` / `ORDER LBs`), and `0` on the HP pages. The differing magnitudes are Cognos authoring inconsistencies, reproduced verbatim.
- **Disabled Cognos filters correctly excluded.** Three queries (`Inventory`, `Inventory - New`, `Safety Stock - New`) each carry a second `[Bulk Item] in (...)` filter marked `use="prohibited"` — here it is a stale 15-item subset of this report's own 18-item active list (it omits `ME90640.S`, `ME92040.S`, `MG7140.S`). Set-differencing the active Cognos lists against the `.m` `IN (...)` lists gives an exact match (18/18 on all three queries) with **zero** prohibited-only items leaked. Had the stale filter been ANDed in, those three pages would silently drop the three newest bulk items.

Note: unlike its twin, this report's `Sales Orders` branch-plant filter is the same 6 APAC/EMEA plants as `Item Information`, so it has no "extra plants silently dropped by the join" quirk. See section 8.

## 8. Twin divergence (07 vs 09)
**Verdict: no structural divergence. The two rebuilds are consistent, and both carry every fix.**

- **`report.json`: byte-for-byte identical** after decoding the embedded `config` strings and normalizing key order — including page names, page GUIDs, visual types, projection order, `OrderBy`, `objects` and `vcObjects`. Diff is empty.
- **TMDL: identical in structure.** Same 5 tables, same 86 columns, same names, `dataType`, `formatString`, `summarizeBy: none`, and no `isHidden`. The only differences are the SQL filter literals inside the `.m` partitions and their accompanying comments — which is exactly what should differ.
- **Both defect fixes present in both twins**, at the same line numbers: the NULL/`''` guard at `Inventory_HP.m:71` and `SELECT DISTINCT` at `Work_Orders.m:67`. **No asymmetry — no HIGH finding.**

Observation on the *Cognos source* (not a rebuild defect): in this report the `use="prohibited"` filter is a stale subset of its own active whitelist, whereas in 07 the prohibited filter is *this* report's FC whitelist. That asymmetry is strong evidence the SK report was cloned from this FC report inside Cognos. It has no effect on either rebuild, since prohibited filters are correctly ignored in both.

The genuine, intended content differences between the twins (all faithfully carried through): FC reuses one 31-literal / 18-distinct bulk-item list across Inventory, Sales Order Summary, Inventory HP and Safety Stock HP, where SK has three distinct lists (99 / 13 / 21 entries); FC's Inventory and Sales Orders branch lists are both the 6 APAC/EMEA plants, where SK's are 9 and 12 respectively; FC's Work Orders component filter is the `BRIJS*` family with `Start Date >= 2025-11-01`, SK's is the `PR*` family with `>= 2026-03-01`.

**One asymmetry worth knowing, and it favours this report:** because SK's `Sales Orders` sub-query filter (12 plants) is wider than its `Item Information` filter (6 plants), SK's Sales Orders page silently drops 6 plants at the join. This report's two filters agree at 6 plants, so it has no such trap. Nothing to fix here — but if anyone "harmonises" the two reports, do not copy SK's 12-plant list into this one.

### Re-checked after the 2026-07-09 refresh-stamp build
**No functional asymmetry introduced.** Both twins received the same `Last Refreshed` table, the same
`Last Refreshed Label` measure, the same `model.tmdl` registration, and a card visual on all five pages
with identical geometry (`x=8, y=4, w=300, h=34, z=4000`). Both models load via MCP `ConnectFolder`
(7 tables, 1 measure, 0 relationships each).

One cosmetic difference exists and is worth recording so nobody chases it: after stripping `lineageTag`
GUIDs, this report's `Last Refreshed.tmdl` carries `annotation SummarizationSetBy = Automatic` on both
columns and 07's does not. That annotation is Power BI Desktop bookkeeping with no semantic effect — same
data types, same `summarizeBy: none`, same `formatString`. It will normalise itself the first time each
file is re-saved from Desktop.

## Open items checklist
- [x] Add a visible "last refreshed" timestamp to every page — **DONE 2026-07-09** — PBIP only; the PBIX still needs a Power BI Desktop re-save before users see it (see Status)
- [ ] 6.1 Left-align `Customer Code`, `Global Parent`, `Order Number`, `WO Number` + the 7 date columns to match Cognos — LOW — ~30 min
- [ ] 6.2 Decide whether to reproduce the "No Data Available" empty state — LOW — ~15 min (or accept)
- [ ] 6.3 Disable auto date/time to drop the `DateTableTemplate` — LOW — ~5 min
- [ ] 4.x Spot-check `nulls last` vs Power BI blanks-first on a sort key that can be NULL — LOW / NEEDS REVIEW — ~15 min
- [ ] 7.x Confirm with the business that the duplicated `REGION` column on Safety Stock HP should be kept — LOW — ask, don't change
- [ ] 8.x Brief Rohit on the four "faithful-but-surprising" items above — MED (handover risk, not a code defect) — ~20 min

**No HIGH severity items. No MISSING conditional formatting. No MISSING matrix visuals. No model defects.**
