# Parity TODO — 02 Shell and Kemper 530 Report
_Source of truth: PBIP. Power BI pages: `530 Report`, `Main Report - All`, `Planner Responsibilities` in `CM Overview LIVE` (shared with reports 02-06)._

## Status — 2026-07-09

**The PBIP is updated. The PBIX is not.** Everything ticked below is implemented in the PBIP source at
`02 - Shell and Kemper 530 Report/CM Overview LIVE (shared PBIP)/PBIP/`. Power BI does not read those files
at runtime — `FINAL - for handover/Dashboard - CM Overview LIVE.pbix` was last written **2026-07-08 14:07**,
whereas the PBIP edits landed **2026-07-09 12:30-12:37**. **Someone must open `CM Overview LIVE.pbip` in
Power BI Desktop, re-save, and republish before any user sees these changes.** Until then the live report
still contains the yellow-on-null-Requested bug described in §8-1 and still has only five pages.

Implemented in the PBIP on 2026-07-09:

| Change | Where | Effect |
|---|---|---|
| `Requested Cell Color` ISBLANK-guarded on both dates | `Shell_Kemper_530.tmdl` | Fixes a **live** bug (§8-1). Red-over-yellow precedence preserved. |
| Page `Main Report - All` built, bound to new table `Shell_Kemper_All` | `report.json`, `Shell_Kemper_All.tmdl` | Closes §7-1. 20 columns, 40 conditional-format markers, own planner slicer and error card. |
| Page `Planner Responsibilities` built as a literal `#table` | `report.json`, `Planner_Responsibilities.tmdl` | Closes §7-2. |
| `Last Refreshed` table + `Last Refreshed Label` measure + a `card` visual on all 7 pages | `Last Refreshed.tmdl`, `model.tmdl`, `report.json` | Partially closes §7-4 (run timestamp; page number has no analogue). |

Post-edit verification performed: `report.json` re-parses as JSON; every `config` field is still a JSON-encoded
string; the semantic model loads with **12 tables and 23 measures**; the `530 Report` page still carries its
original **42** conditional-format markers across 21 columns (untouched).

**`BUILD.md` line 38 is now superseded.** It records `Main Report - All` as *"not built — feeds Cognos page
`Main Report - All`, which is not in the dashboard panel"*. That was a deliberate scope call at the time; the
page has since been built. `BUILD.md` has not been amended (it is the original build spec, kept as-is).

## Summary
The rebuilt pages are at **full structural parity**. Contrary to the briefing, **all conditional-format rules are implemented** in `report.json`, driven by DAX colour measures rather than `FillRule` expressions. Report 02 has **0 `<listGroup>` and 0 `<crosstab>`**, so the flat `tableEx` is the *correct* rebuild, not a miss. The two previously un-rebuilt Cognos pages (`Main Report - All`, `Planner Responsibilities`) **are now built**, and the **real DAX defect** that painted spurious yellow on rows with a null Requested date **is fixed**. What remains is cosmetic (see the checklist) plus one disclosure obligation about the `Number of Errors` figure (§7-7).

## 1. Conditional formatting

Cognos defines **5** named styles in `<namedConditionalStyles>` (all `advancedConditionalStyle`). All 5 are referenced; **none are dead**.

| Cognos style name | Condition (HTML-unescaped) | Background / font | Applied to column(s) | PBI status | Implementation |
|---|---|---|---|---|---|
| `Flag ERROR` | `[Main w Routing 530].[NEW OWNER]='ERROR'` | bg `red`, font `white` | **All 21** `<listColumnBody>` cells of the list on page `Main Report - 530` (query `Main w Routing 530`) | **PRESENT** | `objects.values[].backColor` = measure `Shell_Kemper_530[Row Background Color]` and `.fontColor` = `[Row Font Color]`, one selector per column, all 21 covered |
| `Flag 530 - Request Date Sooner` | `([Main w Routing 530].[Requested Date]<[Main w Routing 530].[Promised Ship Date])` | bg `yellow` | `Requested Date` `<listColumnBody>` **only** | **PRESENT** | `backColor` on `Shell_Kemper_530.Requested` = measure `[Requested Cell Color]` |
| `FLAG ERROR in HEADER 530` | `[Main w Routing 530].[COUNT ERROR]>0` | bg `red`, font `white` | pageHeader `<textItem>` cell `"    Number of Errors = "` + `<dataItemValue refDataItem="COUNT ERROR"/>`, page `Main Report - 530` | **PRESENT** | Card visual `d3be0b1cebb2b411fd6b`: `singleVisual.vcObjects.background.color` = `[Error Card BG]`; `objects.labels[].color` and `objects.categoryLabels[].color` = `[Error Card Font]` |
| `FLAG ERROR ALL` | `[Main w Routing].[NEW OWNER]='ERROR'` | bg `red`, font `white` | All 20 `<listColumnBody>` cells of the list on page **`Main Report - All`** (query `Main w Routing`) | **PRESENT** — DONE 2026-07-09 | Host page now built. `objects.values[].backColor` = `Shell_Kemper_All[Row Background Color]`, `.fontColor` = `[Row Font Color]`, one selector per column, all 20 covered (**40** markers) |
| `FLAG ERROR in HEADER` | `[Main w Routing].[COUNT ERROR]>0` | bg `red`, font `white` | pageHeader `"Number of Errors = "` cell on page **`Main Report - All`** | **PRESENT** — DONE 2026-07-09 | Card visual on `Main Report - All`: background = `Shell_Kemper_All[Error Card BG]`, label colours = `[Error Card Font]` |

**Precedence.** The `Requested Date` column carries **two** `<conditionalStyleRef>` entries, in document order `Flag 530 - Request Date Sooner` then `Flag ERROR`. Cognos applies them in order, so red (ERROR) overwrites yellow. The screenshot confirms it: rows such as `Jul 9, 2026 / Jul 1, 2026` (owner `ERROR`, requested earlier than promised) render the Requested cell **red**, not yellow. The DAX honours this by testing ERROR first. **As shipped 2026-07-09** (both dates now ISBLANK-guarded per §8-1; precedence unchanged):
```dax
Requested Cell Color =
IF ( SELECTEDVALUE('Shell_Kemper_530'[Owner]) = "ERROR", "#FF0000",
IF ( NOT ISBLANK(SELECTEDVALUE('Shell_Kemper_530'[Requested]))
  && NOT ISBLANK(SELECTEDVALUE('Shell_Kemper_530'[Promised Ship]))
  && SELECTEDVALUE('Shell_Kemper_530'[Requested]) < SELECTEDVALUE('Shell_Kemper_530'[Promised Ship]), "#FFFF00" ) )
```
Correct. No action.

**Defined-but-unreferenced styles:** none. All 5 appear in a `<conditionalStyleRef refConditionalStyle="…"/>` (44 refs total).

**Colours in the screenshot but absent from the XML:** none. Screenshot shows red + yellow only; XML defines exactly red (`background-color:red;color:white`) and yellow (`background-color:yellow`). Reconciled.

> **Correction to the briefing.** The claim "*ZERO conditional-format markers exist in any report.json*" is **wrong** for this page. The rebuild uses the *field-value* conditional-formatting form — `backColor.solid.color.expr.Measure` pointing at a DAX measure that returns a hex string — not `FillRule` / `Conditional`. A grep for `FillRule` or `Conditional` finds nothing; a grep for `backColor` finds 21 column selectors on this page alone.

## 2. Grouped lists rendered as flat tables

**N/A — nothing to fix.**

| Cognos list | `listGroup` field(s) | Subtotals? | Current PBI visual | Required PBI visual | Blockers |
|---|---|---|---|---|---|
| `List2` (query `Main w Routing 530`), page `Main Report - 530` | **none** (0 `<listGroup>` in the whole report) | no (`0` `<listGroupFooter>`, `0` `<summary>`, `0` `<aggregate>`) | `tableEx` `e75d597687f8d4c45253` | `tableEx` — already correct | none |

Report 02 contains **0** `<listGroup>`, **0** `<crosstab>`, **0** `<listGroupFooter>`. It is a flat, sorted, ungrouped list. A `pivotTable` here would be a regression. Confirms the briefing's ground truth.

## 3. Subtotals / summary rows
**N/A.** No `<listFooter>`, `<listGroupFooter>`, `<summary>` or `<aggregate>` anywhere in the XML. The PBI `tableEx` correspondingly sets `objects.total[].totals = false`. Correct.

The only aggregate in the report is the scalar `COUNT ERROR` = `total([FLAG ERROR])` where `FLAG ERROR = If ([NEW OWNER]='ERROR') Then (1) Else (0)` — rendered in the page header, rebuilt as the card. Covered in §1.

## 4. Master-detail structure
**N/A.** `0` `<masterDetailLink>`, `0` `<masterDetailLinks>`, `0` `<listPageBody>`. The three-way join (`Main` × `Bulk` × `Routing13`) happens inside the *query*, not the layout.

## 5. Sort order
**PRESENT — exact match.**

Cognos `<sortList>` on the list: `Bulk Item`, `Promised Ship Date`, `Order Number`, `Order Line`, `NEW OWNER` (all `sortOrder=""` → ascending).

PBI `prototypeQuery.OrderBy` on `tableEx e75d597687f8d4c45253`: `Bulk`, `Promised Ship`, `Order#`, `Line#`, `Owner`, every entry `Direction: 1` (ascending). Same five fields, same order. No action.

## 6. Prompts / parameters
**PRESENT — behaviourally equivalent.**

- Cognos: `<selectValue multiSelect="false" range="false" required="false" autoSubmit="true" refQuery="Main w Routing" parameter="Owner1">`, feeding `<filterExpression>[NEW OWNER]=?Owner1?</filterExpression>`. Label `Select the Planner `.
- PBI: slicer `e86d6e57ed2356803fc9`, title `Select the Planner`, field `Shell_Kemper_530.Owner`, `data.mode = 'Dropdown'`, `selection.singleSelect = true`.

`multiSelect="false"` ↔ `singleSelect: true`; `required="false"` ↔ an unselected PBI slicer applies no filter. Match. Note the prompt filters `NEW OWNER` (the decoded owner name: `Lance`, `Tammy`, `David Kramer`, `Eric`, `Mark Tilley`, `Brent`, `ERROR`), **not** the numeric `Planner` column — despite the "Select the Planner" label. The rebuild binds `Owner`, which is correct.

## 7. Other parity gaps

1. **`Main Report - All` page — BUILT 2026-07-09.** Cognos `<page name="Main Report - All">`, title `Shell and Kemper - All Sales Orders`, its own list over query `Main w Routing` (**20** `<listColumn>`, i.e. no `Planner` column), no `Next Status = '530'` filter (so statuses `525`–`550`), its own `Select the Planner` prompt and its own `Number of Errors` counter. Carries `FLAG ERROR ALL` + `FLAG ERROR in HEADER`.

   Now present in `report.json` as page `Main Report - All`. Pages are: `530 Report`, **`Main Report - All`**, **`Planner Responsibilities`**, `SO under 560`, `CM Open Sales Orders`, `CM Inventory on Hand`, `CM PO Live` (**7**). It is bound to a new table `Shell_Kemper_All`, which is `Shell_Kemper_530.m` with the `AND mb.Next_Status = '530'` predicate removed — the `WHERE so.SDNXTR IN ('525','530','535','540','545','550')` filter is retained, exactly reproducing Cognos's `Main w Routing` query. Verified: `Shell_Kemper_All.tmdl` contains the `SDNXTR IN (...)` line and contains **no** `Next_Status = '530'` line; the page's `tableEx` projects **20** columns from `Shell_Kemper_All` and carries **40** measure-driven conditional-format markers (20 `backColor` + 20 `fontColor`); the page has its own `Select the Planner` slicer and its own error card.

   `BUILD.md` line 38 ("*not built — … not in the dashboard panel*") is **superseded** and has not been amended.
2. **`Planner Responsibilities` page — BUILT 2026-07-09.** Cognos `<page name="Planner Responsibilities">`, title `Planner Segregation of Duties`, is a static reference matrix. Verified: the page contains **0 `<query>`** elements and **0 `refQuery`** attributes — it is a static `<table>` of `<textItem>` values, not a data-bound list.

   Rebuilt as table `Planner_Responsibilities`, a literal Power Query `#table` (no database round-trip, cannot drift), rendered as a `tableEx` with 7 visible columns (`Planner` + the six duty columns; a hidden `Ord` column carries the authored row order via `sortByColumn`). Four planner rows — `Lance`, `Eric`, `Travis`, `Mark Tilley` — transcribed against the page's 23 `<staticValue>` elements. Both surrounding Cognos textItems are reproduced as textboxes: the title `Planner Segregation of Duties` and the footnote `Report can be found at the following: Michelman Reporting > Planning > Critical Report - Live JDE Data Americas`. `BUILD.md` line 41 (out of scope) is superseded.
3. **`noDataHandler` not reproduced** — 4 `noDataHandler` elements in the XML render the static text `No Data Available` when a list returns nothing. PBI `tableEx` shows an empty grid. Cosmetic. **Still open.**
4. **`<pageFooter>` — partially reproduced 2026-07-09.** The Cognos footer is run date (left) / page number (centre) / run time (right). A `Last Refreshed` card is now on **all 7 pages**, showing `Last refreshed: <date> <time> EDT|EST` — this covers the run date and run time. The **page number has no Power BI analogue** and is not reproduced; that is by nature, not an omission.

   Implementation note: `Last Refreshed.m` uses `DateTimeZone.FixedUtcNow()` and derives the US Eastern offset from the DST rule (2nd Sunday of March → 1st Sunday of November), rather than `DateTime.LocalNow()`, which returns UTC in the Power BI Service but machine-local time on Desktop and so would disagree between them.
5. **`Line#` has no `formatString`** in `Shell_Kemper_530.tmdl` (`dataType: double`). Cognos renders `1`, `2`, `3`. Low risk of a `1.00`-style render depending on the source values. Everything else has a format: dates `MMM d, yyyy`, quantities `#,0`, `Order#`/`Planner` `0` — all matching Cognos `dateStyle="medium"` / `groupDelimiter=","` / `decimalSize="0"`.
6. **Header styling matches** — title textbox is `#0000FF` bold 20px (Cognos page-header `color:blue`); `columnHeaders.fontColor = '#FF0000'` bold (Cognos red header row). Confirmed against the screenshot.
7. **`Number of Errors` magnitude — RESOLVED, but must be DISCLOSED.** The apparent tension between `BUILD.md` line 128 and the fan-out analysis is not a contradiction; the two statements are about different objects.

   `VALIDATE_error_count.sql` (in this folder) settles it: Cognos's **card** value (`1,299`) is computed from the *un-collapsed* `Routing13` join with no outer `GROUP BY`, so every ERROR order-line is counted once per matching routing row (work-centre × period × capacity). Cognos's **list** on the same page shows the true figure, **16** ERROR rows out of 57. The card and the list disagree *inside Cognos*. `BUILD.md` line 128 is correct about the detail query, whose `GROUP BY` collapses `Routing13` to distinct work-centre per line.

   The Power BI measure `Number of Errors` counts the visible ERROR rows, so it ties to Cognos's **list** (16), not to Cognos's **card** (1,299). **This is a deliberate correction of a Cognos defect, not a parity miss.**

   **Action for handover: tell Rohit before he compares the two numbers.** He will open both reports side by side, see `16` where Cognos says `1,299`, and reasonably conclude the rebuild is broken. This is the single most likely false alarm in report 02.

## 8. Model-level defects found

1. **`Requested Cell Color` fired yellow on NULL Requested dates — FIXED 2026-07-09.** `Shell_Kemper_530.m` line 134 derives `Requested` as `(CASE WHEN so.SDDRQJ > 0 THEN … END)` → **NULL** when the JDE Julian date is `0`, and the query's `WHERE` (lines 152-153, 217-218) never filters it out, so null Requested dates reach the visual. In DAX, `BLANK() < <date>` coerces the blank to `1899-12-30` and evaluates **TRUE**, so those rows got a yellow Requested cell. Cognos evaluates `NULL < [Promised Ship Date]` as unknown and applies **no** style. This was a reachable, user-visible divergence — **the one live bug found in report 02.**

   Both dates are now `ISBLANK`-guarded in `Shell_Kemper_530.tmdl`, with the ERROR/red branch still tested first so the red-over-yellow precedence is unchanged. Verified in the TMDL. **Note this fix is in the PBIP only — the live PBIX still yellows those rows** until it is re-saved and republished (see `## Status`).
2. **`summarizeBy` audit — clean.** All 21 columns of `Shell_Kemper_530` are `summarizeBy: none`, including the identifier columns `Order#` (int64), `Line#` (double) and `Planner` (int64). No silent-aggregation hazard; a future matrix conversion on this table is safe. (Same result for `SO_Not_Shipping`, `WorkOrder_Detail`, `Inventory_Availability`, `Item`.)
3. **`Is Error Row` is dead.** Defined in `Shell_Kemper_530.tmdl` line 195, referenced 0 times in `report.json` (`BUILD.md` §5(a) proposed it; the build instead used the direct `Row Background Color` / `Row Font Color` measures). Harmless; remove or leave.

## Open items checklist

- [x] `Requested Cell Color` yellows rows whose `Requested` date is NULL (BLANK < date is TRUE in DAX) — **HIGH** — **DONE 2026-07-09** (§8-1; both dates ISBLANK-guarded, precedence preserved)
- [x] Confirm the `Number of Errors` value against `VALIDATE_error_count.sql` before claiming parity — **HIGH** — **DONE 2026-07-09.** Resolved: Cognos's card (1,299) is a routing fan-out artefact; Cognos's own list shows 16. The PBI measure ties to the list. `BUILD.md` line 128 and the fan-out analysis were never actually in conflict. **Carries a disclosure obligation — see §7-7.**
- [x] Cognos page `Main Report - All` (20-col list, statuses 525–550, `FLAG ERROR ALL` + `FLAG ERROR in HEADER`) has no PBI page — **MED** — **DONE 2026-07-09.** Built on table `Shell_Kemper_All`; 20 columns, 40 CF markers, own slicer + error card.
- [x] Cognos page `Planner Responsibilities` (static SoD matrix) has no PBI page — **MED** — **DONE 2026-07-09.** Built as a literal `#table` (the Cognos page has no `<query>`); title and footnote textboxes reproduced.
- [x] `<pageFooter>` not reproduced — **LOW** — **DONE 2026-07-09** for the run date + run time (`Last Refreshed` card on all 7 pages). The page number is not reproduced and has no Power BI analogue.

Still open:

- [ ] `Line#` has no `formatString` in `Shell_Kemper_530.tmdl` (`dataType: double`) — **LOW** — 5 min. Confirmed still absent 2026-07-09.
- [ ] `No Data Available` empty-state text not reproduced — **LOW** — 15 min
- [ ] Dead measure `Is Error Row` (`Shell_Kemper_530.tmdl` line 195; 0 references in `report.json`, confirmed 2026-07-09) — **LOW** — 2 min. Harmless.
- [ ] **Not a code task:** disclose the `Number of Errors` 16-vs-1,299 divergence to Rohit at handover (§7-7).
- [ ] **Not a code task:** open `CM Overview LIVE.pbip` in Power BI Desktop, re-save and republish so the PBIP fixes above reach users (see `## Status`).

---

### Verdict on the "pivot table with 3 joined tables, conditional formatting on the Requested column" claim

**The user is describing two different reports in one sentence.** Taking it apart against the evidence:

- *"conditional formatting on the Requested column"* → **report 02, confirmed.** `Flag 530 - Request Date Sooner` is applied to exactly one column body, `Requested Date`, and to nothing else. It is the only single-column conditional style in either report.
- *"a pivot table with 3 joined tables"* → **not report 02.** Report 02's XML has **0 `<listGroup>`, 0 `<crosstab>`, 0 `<listGroupFooter>`, 0 `<masterDetailLink>`**, and the live screenshot shows a flat, ungrouped list. This phrase describes **report 03**, whose Cognos title is literally *"CM (**Brent Planner** 3 December 2024) - Sales Orders < 560"*, and which renders three joined blocks (sales order + inventory availability + work orders) as one list grouped on item with `<item> - Total` subtotal rows. The words "Brent planner page" settle it — that is report 03's name, not report 02's.

  **Independently confirmed by header colour.** The user recalled the page as "blue red green on the table headers". Report 03 is the only report in the repo with three header colours — its 27 `<listColumnTitle>` elements are 11 `color:red` (sales orders) / 8 `color:blue` (inventory) / 8 `color:green` (work orders), one group per joined source. **Report 02's 41 `<listColumnTitle>` elements are *all* `color:red`.** Report 01 is red+blue; 04-10 are red-only. The colour tally is a unique fingerprint and it does not point at report 02.

Report 02's join of three tables happens in the **query** (`Main` ⋈ `Bulk` ⋈ `Routing13`, a `FULL OUTER JOIN` in `Shell_Kemper_530.m`), which may be what prompted "3 joined tables" — but that is invisible in the layout and does not make the visual a pivot table.

**Conclusion: the `530 Report` page's flat `tableEx` needs no conversion.** The grouping/matrix concern is real, but it belongs entirely to report 03 — where it was examined and **deliberately not actioned**, for reasons recorded in `03 - CM Sales Orders Under 560 (Not Enough Inventory)/PARITY_TODO.md` §2.
