# Parity TODO — 01 - RM Staging at Shell Road 2026 (ODS)
_Audited: see git/file date. Source of truth: PBIP (the PBIX is missing page 2)._

## Status — 2026-07-09

The high-severity items in the checklist below have been **implemented in the PBIP** and verified against the files: both grouped lists are now `pivotTable` visuals with the correct row levels and stepped layout off; the per-`Branch Plant` subtotal is enabled on page 2 with the grand total left off; all four Cognos sorts are present; `WorkOrder_Detail[WO Number]` and `Shortage_Detail[Short Qty]` are both `summarizeBy: none`; and a `Last Refreshed` table plus card visual (DST-aware Eastern time) has been added to both pages. `report.json` re-parses as valid JSON, every `config` remains a JSON-encoded string, and the semantic model loads cleanly (6 tables, 1 measure, 2 relationships). **Critically: none of this reaches the PBIX.** PBIP edits are text-file edits; the published artefact is `FINAL - for handover\DEMO - RM Staging at Shell Road 2026.pbix`, which still has the old flat tables and no page 2. Someone must open `PBIP\RM Staging at Shell Road 2026 (ODS).pbip` in Power BI Desktop, re-save, and publish before any of this is visible to a user. Until that happens, treat the PBIX as unchanged.

A duplicate heading has also been fixed: the page-1 work-order matrix had been given a copy of the RM Requirements table's title, so **"Raw Material Requirements" rendered twice on page 1** where Cognos shows it once. This is visible in the Cognos-vs-PBI comparison screenshot. That visual's `vcObjects.title.show` is now `false` and the copied `text` property has been removed; the RM Requirements table keeps its own title (§6b).

Remaining open items are all LOW cosmetics plus the PBIX regeneration and two questions for Rohit. See the checklist at the bottom.

---

## Summary

_(Original assessment, retained as the evidence trail. Superseded where the Status block above says so.)_

The Power BI rebuild is **data-accurate but layout-flat**. Cognos renders two of its three lists as grouped lists (one on each page); both were rebuilt as flat `tableEx` visuals, so the "value printed once, spanning its rows" presentation is gone. The page-2 list additionally carries a **per-Branch-Plant subtotal footer** (`Total(Quantity On Hand)`) that has no Power BI equivalent — totals are explicitly switched off on all three tables. All four Cognos sort specifications are absent (`OrderBy: NONE` on every visual). Conditional formatting is genuinely **absent on both sides** — nothing to port.

The most serious item is that the page-2 grouped list is the report's centrepiece and is missing both its 5-level grouping and its subtotal. Converting it is blocked by a model defect: `Short Qty` and `WO Number` both have `summarizeBy: sum`, and both are grouping keys in Cognos, not measures.

Notably, `BUILD.md` **already prescribes** the correct design (matrix, subtotals, sorts) at lines 71–72, 77, 139–152 — the report.json simply never implemented it. This is an implementation gap, not a spec gap.

**Outcome (2026-07-09):** all of the above has been addressed in the PBIP. The model defects were fixed first, then both conversions and all four sorts landed. The grand total remains off on all three visuals, which is correct — see §3.

---

## Known limitations to read before filing a bug

Two numbers on page 1 are **wrong by any normal definition and deliberately left wrong**, because the point of this rebuild is to tie 1:1 to the live Cognos report:

- **`Total RM Needed` double-counts.** Cognos joins planned demand to on-hand *per lot status*, then `SUM`s the open RM. An item with stock in both the `' '` and `'-'` statuses reports **2× its real need**.
- **`Qty On Hand CINC` uses `AVG`, not `SUM`,** across lot statuses. 100 in `' '` plus 50 in `'-'` reports as **75**, not 150.

Both are reproduced on purpose. `BUILD.md` §5 ("Known Cognos quirks — PARITY MODE") documents them and gives the corrected SQL for whenever the planners decide they want the true numbers. Please do not "fix" these without that decision; the rebuild will stop matching Cognos the moment you do.

Also note: **`BUILD.md:123` is stale.** It states the second page, "Shortage Details", is "NOT yet built". It is built — it exists in the PBIP as section 1, with its own query (`Shortage_Detail.m`) and matrix visual. Ignore that line.

---

## 1. Conditional formatting

**None in Cognos — nothing to port.**

Verified independently, not assumed:

| Element searched | Occurrences in `Report XML.md` |
|---|---|
| `<namedConditionalStyles>` | 0 |
| `<advancedConditionalStyle>` | 0 |
| `<conditionalStyleRef>` | 0 |
| `<crosstab>` | 0 |

Power BI side is consistent: `report.json` contains **0** occurrences of `FillRule`, `fillRule`, `Conditional`, `backColor`, `dataBars`, or `gradient`. The 16 `fontColor` hits are all static `{"Literal": {"Value": "'#e40011'"}}` / `'#001eff'` values inside `objects.columnFormatting` and `objects.columnHeaders` — fixed red/blue header styling, **not** conditional rules. This matches the Cognos static `<CSS>` styling.

**Status: N/A on both sides. Confirms the lead's ground truth.**

---

## 2. Grouped lists rendered as flat tables — CONVERTED

Cognos has **3 lists**, of which **2 are grouped**. The third is legitimately flat — do not "fix" it.

| Cognos list (page) | `listGroup` field(s) — outer → inner | Subtotals? | PBI visual (now) | Blockers |
|---|---|---|---|---|
| `List3` — *Materials Short* (`refQuery="RM Shortage CINC"`) | **none** (no `<listGroups>` child) | No | `tableEx` id `0d09a783…` — **correct as-is, left alone** | None. Sort added (§4). |
| `List2` — *Materials Short* (`refQuery="Query1"`) | `Start Date` | No | `pivotTable` id `ec005f59…` — **converted** | Was `WorkOrder_Detail[WO Number] summarizeBy: sum` → fixed, see §7. |
| `List5` — *Shortage Details* (`refQuery="Summary Shortage"`) | `Component 2nd Item Number` → `SHORT QTY` → `2nd Item Number` → `Branch Plant` → `Status` (5 levels) | **Yes** — `<listFooter>` inside `listGroup[Branch Plant]` | `pivotTable` id `b7f3c9a1…` — **converted** | Was `Shortage_Detail[Short Qty] summarizeBy: sum` → fixed, see §7. |

Evidence for the grouping, from the parsed XML tree:

```
page[Shortage Details]/pageBody/contents/list[List5]/listGroups/
    listGroup[Component 2nd Item Number]
    listGroup[SHORT QTY]
    listGroup[2nd Item Number]
    listGroup[Branch Plant]
        listFooter/listRow/rowCell[colSpan=4] -> "Branch Plant" + "-" + "Total"
        listFooter/listRow/rowCell          -> dataItemValue[Total(Quantity On Hand)]
    listGroup[Status]
```

**Correction to ground truth:** the lead's list of 6 `listGroup` fields is right, but the distribution is **1 on page 1 (`Start Date`, in List2) and 5 on page 2 (List5)** — and page 1's *first* table (List3) is ungrouped, so only **2 of the 3 tables** needed converting, not all three.

**List5 — applied.** Now a `pivotTable`. Rows, in order: `RM`, `Short Qty`, `Item`, `Branch Plant`, `Status`, `Lot Number`, `Location`. Values: `Sum(Qty On Hand)`. `objects.rowHeaders.steppedLayout = false`, so each level gets its own column (Cognos's spanned-value look). Branch Plant subtotal on, everything else off (§3).

**List2 — applied.** Now a `pivotTable`. Rows: `Work Order Start`, `Raw Material`, `WO Number`, `FG Item`. No Values. Stepped layout off. Because there is no measure, all four fields sit on Rows — this reproduces Cognos's "date printed once" behaviour without any aggregation. The `prototypeQuery.Select` entry now reads `WorkOrder_Detail.WO Number`, no longer `Sum(WorkOrder_Detail.WO Number)`.

---

## 3. Subtotals / summary rows — ADDED

| Cognos element | Location | What it renders | PBI status |
|---|---|---|---|
| `<listFooter>` | inside `listGroup[Branch Plant]`, `List5`, page *Shortage Details* | A footer row per Branch Plant: label cell (`colSpan=4`) reading `"<Branch Plant> - Total"`, then a cell with `Total(Quantity On Hand)` | **PRESENT** as a per-level matrix subtotal |

There is **no** `<listGroupFooter>`, `<summary>`, or `<aggregate>` element anywhere in the report (counts: 0 / 0 / 0). The one summary row is the `<listFooter>` above. `Total(Quantity On Hand)` is **not** a data item in any `<query>` — it is a layout-level extended aggregate, enabled by `RS_CreateExtendedDataItems="true"` on the report root. Cognos `Total()` = SUM.

Power BI previously had totals explicitly disabled on **all three** tables. For List3 and List2 that is **correct and still the case** (Cognos has no footer on either). List5 was a real miss and has been fixed:

```
objects.subTotals = rowSubtotals: true, perRowLevel: true, columnSubtotals: false
                    levelSubtotalEnabled: true   on Shortage_Detail.Branch Plant
                    levelSubtotalEnabled: false  on RM, Short Qty, Item, Status, Lot Number
objects.total     = totals: false               (no grand total — Cognos has none)
```

**NEEDS REVIEW — accepted, disclosed cosmetic deviation.** The Cognos footer merges the first 4 columns for the `"CINC - Total"` label and places the number in the *next* cell. The Power BI matrix renders the subtotal label in the row-header area and the value under the `Qty On Hand` column. **The value lands in the semantically right place; the exact cell geometry cannot be reproduced.** We have accepted the Power BI rendering rather than mimicking the `colSpan`. This is recorded here as a known, intentional difference — not a defect. Rohit's confirmation is wanted, but no code change is proposed.

---

## 4. Sort order — ADDED

All four Cognos `<sortItem>` elements were **missing** in Power BI (`prototypeQuery.OrderBy` absent on every visual). All four are now present.

| # | Cognos sort location | Field | Direction | PBI status |
|---|---|---|---|---|
| 1 | `list[List3]/sortList` (list-level detail sort), page *Materials Short* | `Component 2nd Item Number` | ascending | **DONE** — `RM` asc on the `tableEx` |
| 2 | `list[List2]/listGroups/listGroup[Start Date]/sortList` | `Start Date` | ascending | **DONE** — `Work Order Start` asc |
| 3 | `list[List5]/listGroups/listGroup[2nd Item Number]/sortList` | `Lot Number` | ascending | **DONE** — `Lot Number` asc |
| 4 | `list[List5]/listGroups/listGroup[Branch Plant]/sortList` | `Branch Plant` | **descending** | **DONE** — `Branch Plant` desc (`Direction: 2`) |

Sort #4 is worth calling out: descending on `Branch Plant` puts **CINC before CIN2** (`'CINC' > 'CIN2'`). A default ascending sort would silently reverse the branch order the users expect. `BUILD.md:146` corroborates ("**sort descending** (so CINC then CIN2)").

List5's `OrderBy` is now `RM` asc → `Branch Plant` desc → `Lot Number` asc. One honest caveat on #3: Cognos scopes that sort *inside* the `2nd Item Number` group; Power BI expresses it as an ordered entry in the visual's flat `OrderBy` list, positioned after the levels it nests under. The rendered order is the same, but the mechanism is not a literal translation. No action; noted so nobody is surprised by the JSON.

---

## 5. Prompts / parameters

**None in Cognos — nothing to port.**

Verified: `<selectValue>` = 0, `<parameter>` = 0, `prompt(` macro = 0, and a regex sweep for `?paramName?` tokens returns no matches. The report is fully unparameterised; its date window is computed internally:

- `DAY OF WEEK` = `_day_of_week(to_date({sysdate}),1)`
- `DAYS FORWARD` = `Decode([DAY OF WEEK], 4,4, 5,4, 6,3, 2)`
- detail filter: `[Requested Date1] between to_date({sysdate}-7) and to_date({sysdate}+[DAYS FORWARD])`

This "next 2 business days" rolling window is baked into the M queries. **Status: N/A.**

---

## 6. Other parity gaps

| # | Gap | Evidence | Severity | Status |
|---|---|---|---|---|
| 6a | **Page 1 name mismatch.** Cognos page is named `Materials Short`; the PBI section `displayName` is `RM Staging at Shell Road`. Page 2 matches (`Shortage Details` both sides). | `page[@name='Materials Short']` vs `sections[0].displayName` | LOW | Open |
| 6b | **Duplicate title / wrong caption reuse.** Cognos prints a `staticValue` caption `"Raw Material requirements"` immediately before **List3** only; **List2 has no caption**. In PBI, *both* page-1 tables carried `vcObjects.title.text = 'Raw Material Requirements'`, so the heading rendered **twice** on page 1 and the work-order table was mislabelled. | `report.json` sections[0], both visuals | LOW–MED | **FIXED 2026-07-09** — see below |
| 6c | **"No Data Available" empty state.** Each Cognos list carries its own `<contents><textItem><staticValue>No Data Available</staticValue>` no-rows message — it is **per-list, not per-page**. Power BI renders an empty grid with no message. | 3× in XML, 0 in report.json | LOW | Open |
| 6d | **SCOPE text casing.** Cognos: `"…material is NOT finished good MPF."` PBI textbox: `"…material is not finished good MPF."` | `sections[0]` textbox `4935660d…` | LOW (nit) | Open |
| 6e | **Page-2 table title is a paraphrase.** Cognos body text reads `"Full inventory on hand list of materials needed at CINC"` (reproduced correctly in the PBI textbox); the table's own `vcObjects.title` adds a shortened `'Full Inventory On Hand at CINC'` that Cognos does not have. Harmless duplication. | `sections[1]` pivotTable `b7f3c9a1…` | LOW | Open — no action proposed |

**6b — fixed 2026-07-09.** The page-1 `pivotTable` (work-order detail, `ec005f59…`) now has `vcObjects.title.show = false` with the copied `text` property removed. Page 1's only captions are therefore the report header **"Raw Materials Needed in CINC"** and the List3 caption **"Raw Material Requirements"**, matching Cognos's structure. The `RM Requirements` `tableEx` keeps its own title.

> **Residual cosmetic difference, flagged and deliberately not changed:** Cognos's caption is lowercase-r — `"Raw Material requirements"` — while ours is title-case `"Raw Material Requirements"`. Trivial, and title-case is the better reading; recorded so the difference is disclosed rather than discovered.

**6c — implementation note.** The `No Data Available` string appears **3× in the Cognos XML**, and the distribution matters: **twice on page `Materials Short`** (once inside each of List3 and List2) and once on page `Shortage Details` (List5). It is a **per-list empty state, not a page-level one**. Anyone implementing it therefore needs *three* independently-controlled elements — one bound to each visual's own row count — not a single page-level message. That is the main reason this item is still open: the Power BI workaround (a card or textbox per visual with a `HASONEVALUE`/`COUNTROWS`-style visibility rule) costs more than the cosmetic gain, and it should be a conscious decision rather than a default.

**Headers / footers: N/A in Cognos.** `<pageHeader>` = 0 and `<pageFooter>` = 0, and there is **no run-date/time stamp** anywhere in the Cognos report.

**Addition beyond Cognos parity (2026-07-09):** a `Last Refreshed` table has been added to the model — one row, computed in M via `DateTimeZone.FixedUtcNow()` with a DST-aware US-Eastern offset (second Sunday in March → first Sunday in November), yielding an `EDT`/`EST` label. It exposes a `Last Refreshed Label` measure, registered in `model.tmdl`, surfaced by a `card` visual on **both** pages. Cognos does not have this; it was added because an import-mode Power BI report gives the reader no other cue as to how stale the numbers are. Flagging it explicitly so it is not mistaken for a parity item.

**Verified correct — no action.** Cognos disables two filters via `use="prohibited"` on query `IOH All` (`[Status] in (' ','-')` and `[2nd Item Number]='POLYMINP'`), meaning page 2 includes **all** lot statuses while page 1's `IOH CINC`/`IOH CIN2` filter to `' '`/`'-'`. `Shortage_Detail.m:15-16` explicitly honours this ("Cognos's status filter here is DISABLED / use=\"prohibited\""). The rebuild got this subtle point right; calling it out so nobody "fixes" it later.

---

## 7. Model-level defects found — FIXED

Both defects below have been corrected in the TMDL. The "Problem" column describes what *was* wrong and why it mattered; it is retained as the rationale.

| Table | Column | dataType | summarizeBy (was → now) | Problem | Outcome |
|---|---|---|---|---|---|
| `WorkOrder_Detail` | `WO Number` | `int64` | **`sum` → `none`** | Identifier. Was projected as `Sum(WorkOrder_Detail.WO Number)` in the visual. Invisible in a flat table (one WO per row), but grouped into a matrix Power BI would have **added work-order numbers together**. | Fixed. Column is `summarizeBy: none`; the visual's `prototypeQuery.Select` no longer wraps it in `Sum()`. |
| `Shortage_Detail` | `Short Qty` | `double` | **`sum` → `none`** | Genuine number, **but in Cognos it is a `listGroup` key, not an aggregate**. Was projected as `Sum(Shortage_Detail.Short Qty)`. `Short Qty` is functionally dependent on `RM`, so summing it across the lot/location detail rows under one `RM` **multiplies it by the lot count**. Harmless then only because each flat row was its own group. | Fixed. Column is `summarizeBy: none` and now sits in matrix **Rows** as the 2nd grouping level, so it can never be dropped into Values by accident. |

Scanned all three source tables. No other identifier column carried `summarizeBy: sum`:

- `RM Requirements`: `RM` (string, none); `Qty On Hand CINC`, `Total RM Needed`, `Qty Required From CIN2` (double, sum) — all three are true measures. **OK.**
- `Shortage_Detail`: `RM`, `Item`, `Branch Plant`, `Status`, `Lot Number`, `Location` (string, none) — **OK**. `Qty On Hand` (double, sum) — true measure, correctly the only thing in Values. **OK.**
- `WorkOrder_Detail`: `Work Order Start` (dateTime, none), `Raw Material`, `FG Item` (string, none) — **OK**.

`WO Number` was the defect the lead flagged, and it was the **only** string/identifier-style column with `sum`. Confirmed.

---

## Open items checklist

- [x] Convert `List5` (page *Shortage Details*) from `tableEx` to `pivotTable` with 5 row levels `RM → Short Qty → Item → Branch Plant → Status`, plus `Lot Number`/`Location` detail; stepped layout off — **HIGH** — 1–2 h — DONE 2026-07-09
- [x] Add per-`Branch Plant` subtotal of `Qty On Hand` to `List5`; grand total stays off — **HIGH** — 30 min — DONE 2026-07-09
- [x] Set `WorkOrder_Detail[WO Number].summarizeBy = none` **before** any matrix conversion — **HIGH** — 5 min — DONE 2026-07-09
- [x] Move `Shortage_Detail[Short Qty]` from Values to Rows; set `summarizeBy: none` — **HIGH** — 15 min — DONE 2026-07-09
- [x] Convert `List2` (page *Materials Short*) from `tableEx` to `pivotTable` grouped on `Work Order Start` — **MED** — 45 min — DONE 2026-07-09
- [x] Add sort: `Branch Plant` **descending** on `List5` (CINC before CIN2) — **MED** — 10 min — DONE 2026-07-09
- [x] Add sort: `Lot Number` ascending nested inside the `2nd Item Number` level of `List5` — **MED** — 15 min — DONE 2026-07-09
- [x] Add sort: `Component 2nd Item Number` ascending on `List3` — **MED** — 5 min — DONE 2026-07-09
- [x] Add sort: `Work Order Start` ascending on `List2` — **MED** — 5 min — DONE 2026-07-09
- [x] Fix mislabelled title on the page-1 work-order table (duplicated `'Raw Material Requirements'`; Cognos gives List2 no caption) — **LOW–MED** — 10 min — DONE 2026-07-09
- [ ] Rename PBI page 1 `RM Staging at Shell Road` → `Materials Short` to match Cognos, **or** confirm with Rohit that the friendlier name is wanted — **LOW** — 5 min
- [ ] Decide whether to reproduce the `"No Data Available"` empty-state message. Power BI has no native equivalent, and Cognos's is **per-list** (2 elements on page 1, 1 on page 2), so this needs a card/textbox *per visual* with a row-count-driven visibility rule — not one page-level message — **LOW** — 30 min
- [ ] Fix `SCOPE` casing `not` → `NOT` in the page-1 textbox — **LOW** — 2 min
- [ ] **NEEDS REVIEW:** confirm with Rohit that a Power BI matrix subtotal row (label in row-header area, value under `Qty On Hand`) is an acceptable stand-in for Cognos's `colSpan=4` merged `"CINC - Total"` footer cell. Implemented and accepted as a disclosed difference (§3); we are asking for acknowledgement, not a change — **LOW** — discussion
- [ ] **NEEDS REVIEW:** confirm the innermost `listGroup[Status]` earns its keep as a matrix row level. It **was included** in Rows for faithfulness to Cognos, but with `Lot Number`/`Location` beneath it the visible effect is only value de-duplication. A judgement call the user may revisit; removing it is a one-line change — **LOW** — discussion
- [ ] **Regenerate the PBIX from the PBIP.** The PBIP is now correct; `FINAL - for handover\DEMO - RM Staging at Shell Road 2026.pbix` is **not** — it predates every change above and is still missing page 2. Open `PBIP\RM Staging at Shell Road 2026 (ODS).pbip` in Power BI Desktop, save, and publish. **Nothing above is user-visible until this is done.** — **HIGH** — 15 min
