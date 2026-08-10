# Parity TODO — 03 CM Sales Orders Under 560 (Not Enough Inventory)
_Source of truth: PBIP. Power BI page: `SO under 560` in `CM Overview LIVE` (shared with reports 02-06)._

## Status — 2026-07-10 — GROUPED GRID REBUILT (owner-directed; supersedes the four-table layout)

**The report owner asked for the Cognos grouped-list look back** ("create this pivot table in the visual",
with the conditional formatting). The 2026-07-09 *matrix* rejection below still stands — a `pivotTable`
remains impossible for the reasons in §2 — but the page no longer ships as four flat tables either. What
shipped instead is **Option A from BUILD.md §4, upgraded**: the Cognos stitch was rebuilt in SQL and one
`tableEx` renders the whole grouped grid, byte-faithful to the Cognos render.

| Piece | What it is |
|---|---|
| `SO560_Grouped` (new model table) | One native T-SQL query: SO ⟕ Inventory ⟕ WO fan-out on trimmed 2nd item number, window-function suppression flags (`_SuppSO/_SuppInv/_SuppWO` = Cognos's `visibility:hidden` running-count rules), the not-enough-inventory gate in `WHERE`/`HAVING`, and the per-item **`<item> - Total` footer rows as real `UNION ALL` rows** (`_IsTotal = 1`). `_Sort` = ordering key (kept in the model but NOT projected — see render notes below). Commented master: `SO560_Grouped.m` in this folder; comment-free copy in the TMDL partition. |
| New visual `362a8a6e742b7e5dcb69` | Single `tableEx`, 27 display columns in exact Cognos order, sorted by the visible key columns (`Item`, `Order#`, `Line#`, `Location`, `Inv Lot#`, `Inv Plant`, `WO#`) — a hidden `_Sort` projection was tried first and its sort is silently ignored by the renderer. Duplicate Cognos headers (`Plant`/`Item`/`Qty`/`Lot#`/`Status`) via projection `displayName` overrides (trailing-space uniquified). Header colours per column via `columnFormatting` (`styleHeader`, 11 red / 8 blue / 8 green). All CF via 8 new colour measures (`Grid BG/FG *`): yellow 525/530/535, red promised ≤ today (red wins), WO-90 yellow, suppressed repeats white-on-white (Cognos's own trick), total rows blue `#82A9D6` + white font. |
| Removed | The four `tableEx` visuals (SO / Inventory / WO / Per-Item Totals). Backup: `Archive\SO-under-560-pre-grouped-grid-2026-07-10\`. The four model tables + `Item` bridge + their measures are **still in the model** (unused by this page now) — keep until the new grid is validated, then decide whether to drop them (they cost three extra ODS queries per refresh). |

**Known deliberate divergences from Cognos in the new grid:** total row is not bold (PBI cell CF cannot
set bold per row); the footer band is flat `#82A9D6` instead of Cognos's `#C7D9ED→#6595CD` gradient;
`Order Date` deliberately repeats on continuation rows (matches the reference screenshot render, which
contradicts the XML's group list — the render wins). `Inventory Lot Count` quirk (§8-1) is preserved
(`COUNT(DISTINCT AVAIL)` in the totals branch).

**Render validated 2026-07-10 12:57 in Desktop** — yellow 525 row (the 8 SO cells only), blue `- Total`
bands with white font, row-span suppression (incl. the Order-Date-repeats quirk), 3-colour duplicate headers,
correct sort. Bring-up fixes worth knowing: (1) the `wa2` totals-branch WO aggregate was missing its
`GROUP BY`; (2) hand-authored PBIR `objects.values` CF selectors must carry
`"data":[{"dataViewWildcard":{"matchingOption":1}}]` alongside `metadata` — metadata-only is silently
ignored; (3) sortDefinition on a hidden projection is ignored — the grid sorts by visible columns and the
`" - Total"` Item suffix places footer rows; (4) Desktop 2.146 bumps `definition.pbir` to
`definitionProperties/2.0.0`, which older Desktops refuse — keep one Desktop version on this file.

**Still open:** numbers tie-out against the live Cognos panel (BUILD.md §8 checklist), the old-tables
cleanup decision below, and re-exporting the handover PBIX — it predates ALL of this.

## Status — 2026-07-09

**The PBIP is updated. The PBIX is not.** `FINAL - for handover/Dashboard - CM Overview LIVE.pbix` was last
written **2026-07-08 14:07**; the PBIP edits landed **2026-07-09 12:30-12:37**. **Someone must open
`CM Overview LIVE.pbip` in Power BI Desktop, re-save, and republish before any user sees these changes.**

Implemented on 2026-07-09:

| Change | Where | Effect |
|---|---|---|
| `Inventory Lot Count` → `DISTINCTCOUNT('Inventory_Availability'[AVAIL])` (was `COUNTROWS`) | `Inventory_Availability.tmdl` | Closes §8-1. Now literally matches Cognos's `Count Distinct(AVAILABLE)`. |
| `SO Cell Color` red branch `ISBLANK`-guarded (`VAR prm` + `NOT ISBLANK(prm) && prm <= TODAY()`) | `SO_Not_Shipping.tmdl` | Closes §8-2. **Behaviour-neutral** — see below. |
| `Last Refreshed` card added to this page (and all 7) | `report.json`, `Last Refreshed.tmdl` | Reproduces the Cognos footer run timestamp. |

**On the `SO Cell Color` guard, precisely:** this was **latent, not live**. `SO_Not_Shipping.m`'s `WHERE` clause
already excludes null-promised-ship rows in SQL (`NULL <= GETDATE()+21` is unknown, so those rows never reach
the model). The guard changes no rendered cell today. It was added as defence-in-depth because the identical
pattern **was** live in report 02, where the query does not filter the nulls out. Do not present this as a bug fix.

**The matrix conversion (§2) was examined and deliberately NOT done.** It is a decision with rationale, not an
outstanding task. See §2 — it is now recorded there in full, because it is the first thing a reviewer will ask about.

Post-edit verification: `report.json` re-parses; all `config` fields remain JSON-encoded strings; the model loads
(12 tables, 23 measures); this page still carries its **9** conditional-format markers (8 on the SO block + 1 on `WO Status`).

## Summary
**Conditional formatting is complete and faithful** — all three colour rules are implemented as DAX colour measures wired to `backColor`, on exactly the columns Cognos styles, with the same red-over-yellow precedence. **The colour-coded headers that distinguish the three joined sources are also present** (see §7.1) — the rebuild reproduces all three colours exactly, at table granularity. The **measure-semantics defect** (`Inventory Lot Count` counting rows where Cognos counts distinct `AVAILABLE` values) **is fixed**.

The remaining structural difference is that Cognos renders **one** grouped list (28 `<listGroup>` entries, a per-item `<listFooter>` producing inline `<item> - Total` subtotal rows, and `visibility:hidden` row-span suppression), whereas the rebuild is **four cross-filtered `tableEx` visuals** with the subtotals in a fifth table. This looks like the "grouped/matrix visual rebuilt as a flat table" pattern Rohit has flagged elsewhere, **but here it is a considered choice, not an oversight** — a `pivotTable` would destroy all 9 conditional-format rules and cannot represent three sibling grains anyway. §2 sets out the reasoning, the alternative that was rejected, and what the choice costs.

Of the four gap classes anticipated for this report: **one was already closed** (conditional formatting §1), **one is a false alarm** (colour-coded headers §7.1), **one is fixed** (`Inventory Lot Count`, §8-1), and **one is a deliberate, disclosed design decision** (grouping/subtotals, §2 and §3).

## 1. Conditional formatting

Cognos defines **5** named styles: **3** `advancedConditionalStyle` + **1** `stringsConditionalStyle` + **1** more `advancedConditionalStyle`. **3 are colour rules, 2 are visibility (row-span) helpers.** All 5 are referenced (41 `<conditionalStyleRef>`); **none are dead**.

| Cognos style name | Condition (HTML-unescaped) | Background / font | Applied to column(s) | PBI status | Implementation |
|---|---|---|---|---|---|
| `Flag non 540` (`stringsConditionalStyle`, driver `<conditionalDataItem refDataItem="Next Status" refQuery="Not Shipping"/>`) | 3 × `<stringCriteria operator="contains">` on `styleValue` **`525`**, **`535`**, **`530`** | bg `yellow` | 8 SO-block cells: `Order Number`, `Order Line`, `Promised Ship Date`, `Customer Name`, `Next Status`, `Quantity`, `Primary Quantity Ordered`, `Lot Number (Orders)` | **PRESENT** | `objects.values[].backColor` = `SO_Not_Shipping[SO Cell Color]`, on exactly those 8 columns of `tableEx 0e7af36c267f4df092f4` |
| `Flag Today or Past` | `[Not Shipping].[Promised Ship Date]<=today()` | `<defaultStyle refStyle="pd_5"/>` → **red** (see NEEDS REVIEW below) | the **same 8** SO-block cells | **PRESENT** | same measure `[SO Cell Color]`, red branch |
| `WO Status 90` | `[Not Shipping].[WO Status] = '90'` | bg `yellow` | `WO Status` **only** (1 ref) | **PRESENT** | `backColor` on `WorkOrder_Detail.Status` = `[WO Status Color]` in `tableEx 5512e7237bf04fab8d86` |
| `Order Count > 1` | `[Not Shipping].[Order Count] > 1` | `visibility:hidden` | 16 cells: all 8 Inventory-block + all 8 WO-block columns | **N/A by design** — see §4 | superseded by the 3-table split |
| `Lot Number Count > 0` *(name says `> 0`, condition says `> 1`)* | `[Not Shipping].[Lot Number Count] > 1` | `visibility:hidden` | 8 WO-block columns: `2nd Item Number (WO)`, `Branch Plant (WO)`, `WO Number`, `Start Date`, `Requested Date`, `Quantity Requested`, `Lot Number (WO)`, `WO Status` | **N/A by design** — see §4 | superseded by the 3-table split |

**Precedence — correct.** Each of the 8 SO-block columns carries two `<conditionalStyleRef>` entries in document order `Flag non 540` (yellow) then `Flag Today or Past` (red); Cognos applies them in order, so red wins. The DAX tests red first:
```dax
SO Cell Color =
VAR isPastDue = SELECTEDVALUE ( 'SO_Not_Shipping'[Promised Ship] ) <= TODAY ()
VAR isFlagSts = SELECTEDVALUE ( 'SO_Not_Shipping'[Next Status] ) IN { "525", "530", "535" }
RETURN IF ( isPastDue, "#FF0000", IF ( isFlagSts, "#FFFF00", BLANK () ) )
```
Same precedence, same 8 columns, same status set. No action.

**Colour seen in the screenshot but absent from the XML — investigated.** The screenshot's on-report NOTES read `2. Sales Orders with promised ship date of today or prior are color coded RED`, but the XML never states a colour for `Flag Today or Past`: its `<styleCase>` carries `<defaultStyles><defaultStyle refStyle="pd_5"/></defaultStyles>` instead of a `<CSS value="…"/>`. `pd_5` occurs **exactly once** in the whole document (the reference itself) and the report has **no `<classes>` / `<classStyles>` block**, so the class is defined outside this spec — in the Cognos global stylesheet or theme. **NEEDS REVIEW:** the rebuild's `#FF0000` is inferred from the on-report NOTES text plus the filename, which is good evidence but is not the actual `pd_5` definition. If Rohit wants byte-exact colour, pull `pd_5` from the Cognos server stylesheet. (The three styles that *do* carry `<CSS>` use literal `yellow` / `red` / `white`, which the rebuild renders as `#FFFF00` / `#FF0000` / `#FFFFFF`.)

**Two discrepancies inside Cognos itself, worth pre-empting before Rohit finds them:**
1. `Flag non 540` matches **`525`, `530`, `535`** — but the report's own NOTES text says only *"Sales Orders at status 530 or 535"*. The **XML is the authority and the DAX follows the XML** (`IN { "525", "530", "535" }`). The Cognos NOTES text is stale. Correct call; just be ready to explain it.
2. The style named `Lot Number Count > 0` tests `> 1`. Cognos naming bug, faithfully irrelevant to the rebuild.

**Non-defect note (LOW):** Cognos uses `operator="contains"` for the three status matches; the DAX uses exact `IN {…}`. `Next Status` is a fixed 3-character JDE code, so the two agree on all real data. Flagging only because `contains` would also match a hypothetical `5251`.

> **Correction to the briefing.** "*ZERO conditional-format markers exist in any report.json*" is **wrong**. The rebuild uses field-value conditional formatting — `backColor.solid.color.expr.Measure` → a DAX measure returning a hex string — not `FillRule` / `Conditional`. Also, the single `<conditionalDataItem>` in this report is **not** conditional *content*: it is the `<stringsConditionalStyle>`'s driver column (`Next Status`), i.e. the field whose string value the three `<stringCriteria>` test.

## 2. Grouped lists rendered as flat tables

## DECISION (2026-07-09): the matrix conversion was evaluated and deliberately NOT made. This section is the rationale, not a task.

The analysis below was written *before* the decision and proposed converting the SO block to a `pivotTable`
("Option B"). **That recommendation was not adopted.** It is retained verbatim as the evidence trail; the
decision and its reasoning follow immediately, and they supersede it. Three independent reasons:

**1. A matrix would destroy all 9 conditional-format rules.** Every coloured column — `Order Number`,
`Order Line`, `Promised Ship Date`, `Customer Name`, `Next Status`, `Quantity`, `Primary Quantity Ordered`,
`Lot Number (Orders)` (the 8 SO cells) and `WO Status` — is *also* a `<listGroup>` field in Cognos. Power BI
binds `objects.values[].properties.backColor…expr.Measure` **only to fields in `Values`, never to row headers.**
Moving those fields into a matrix's `Rows` therefore silently drops their colour. There is no workaround: the
colours are the entire point of the report (the on-report NOTES describe them), so a conversion that removes
them is strictly worse than no conversion. The pre-decision analysis flagged this as "the step most likely to
silently drop the CF" — on inspection it is not a risk to be managed, it is a certainty.

**2. It is structurally impossible regardless.** Sales-order lines, inventory lots and work orders are three
**sibling grains** hanging off an item, not a hierarchy. A matrix `Rows` list is strictly hierarchical, so
nesting the three cross-joins them (each SO line × each lot × each WO). Cognos escapes this only because its
query is *one flat join* and the layout merely blanks repeated cells via `visibility:hidden` driven by
`running-total(count())` data items. **Power BI has no row-ordinal concept inside a visual and no cell merge**,
so the illusion cannot be reconstructed. Verified: the two `visibility:hidden` styles (`Order Count > 1`,
`Lot Number Count > 1`) exist precisely to do this blanking.

**3. The subtotal shape does not survive either.** Cognos emits **one** `<listFooter>`, at the item level
(group #1, `2nd Item Number (Orders)`), and **zero** `<overallFooter>` — verified by direct count. A Power BI
matrix subtotals at *every* row level. And the footer's label is `<item> - Total`, a string a matrix row header
cannot produce.

**Supporting counts, all verified against `Report XML.md` on 2026-07-09:** 28 `<listGroup>` elements inside
1 `<listGroups>` container, versus 27 `<listColumnTitle>`. The extra group is **`WO Number Count`**, a
`running-total(count([WO Number]))` data item that drives `visibility` and never renders as a column — it is
not a missing column. `<listFooter>` = 1, `<overallFooter>` = 0, `<crosstab>` = 0, `<masterDetailLink>` = 0.
Separately, all **32** columns across the four rebuilt tables (`SO_Not_Shipping` 12, `Inventory_Availability` 9,
`WorkOrder_Detail` 10, `Item` 1) are `summarizeBy: none`, so the silent-aggregation corruption that afflicted
report 01 **cannot** occur here. That hazard was checked and ruled out; it is not what drove the decision.

**What we keep instead.** Four cross-filtered `tableEx` visuals + the `Item` bridge dimension + the shared
`SO_Not_Shipping[Show Item] = 1` visual-level filter (verified present on all four visuals). This preserves:
- all **three header colours** (11 red / 8 blue / 8 green — they encode which of the three joined sources each
  column came from; see §7.1),
- all **9 conditional-format rules** (verified: 8 `backColor` markers on the SO `tableEx`, 1 on `WorkOrder_Detail.Status`),
- correct subtotal **values** (§3).

**What it costs, stated plainly for the handover.** Two things, both real:
1. The per-item subtotals sit in a **detached fifth table** rather than inline underneath each item's rows.
2. Seeing which inventory lots belong to a given SO line is **one click** (cross-filter on the item) rather than
   zero (reading across a row-spanned grid).

Power BI has no row-span and no native master-detail. Three cross-filtered tables on a bridge dimension is the
standard idiom for this shape. Say this to Rohit up front rather than letting him find it.

---

_Everything below this line is the original pre-decision analysis, preserved as evidence. Its "Recommended fix"
was **not** implemented, for the reasons above._

| Cognos list | `listGroup` field(s) | Subtotals? | Current PBI visual | Required PBI visual | Blockers |
|---|---|---|---|---|---|
| `List1` (query `Not Shipping`), page `Not Shipping` | **28** `<listGroup>` inside one `<listGroups>`. Only `2nd Item Number (Orders)` is a *real* group (non-self-closing, owns the `<listFooter>`). The other **27** are self-closing repeat-suppression groups: `Branch Plant (Orders)`, `Order Number`, `Order Line`, `Order Date`, `Promised Ship Date`, `Customer Name`, `Next Status`, `Quantity`, `Primary Quantity Ordered`, `Lot Number (Orders)`, `2nd Item Number (Inv)`, `Branch Plant (Inv)`, `Lot Number (Inv)`, `Quantity On Hand`, `Hard Commit`, `AVAILABLE`, `Location`, `Inventory Status`, `2nd Item Number (WO)`, `WO Number`, `WO Number Count`, `Start Date`, `Requested Date`, `Quantity Requested`, `Lot Number (WO)`, `WO Status`, `Branch Plant (WO)` | **Yes** — one `<listFooter>`, on the `2nd Item Number (Orders)` group. No grand total. | **4 × flat `tableEx`**: `0e7af36c267f4df092f4` (SO), `6d0cb4c1987a44c78cb6` (Inventory), `5512e7237bf04fab8d86` (WO), `c4202c90c5c741a58651` (Per-Item Totals) | **`pivotTable`** with `Item[Item]` in `Rows`, stepped layout **off**, row subtotals **on** — for the SO block at minimum | A matrix cannot align three independent detail lists (SO / Inventory / WO) side by side in one grid. Power BI has no row-span. See §4 for the honest options. |

**Recommended fix (Option B, lowest risk).** — _NOT ADOPTED; superseded by the DECISION above._ Convert the **SO block** (`0e7af36c267f4df092f4`) from `tableEx` to `pivotTable`:
- `Rows` = `Item[Item]` (the bridge — **not** `SO_Not_Shipping[Item]`, so the group scopes all three tables).
- `Values` = the remaining 10 fields.
- `objects.stepped[].properties.stepped = false` (Cognos indents nothing).
- `objects.subTotals[].properties.rowSubtotals = true` → gives the inline `<item> - Total` row back.
- Re-attach `backColor` = `[SO Cell Color]` per value selector (matrix `values` selectors survive the conversion; **verify** — this is the step most likely to silently drop the CF).
- Set `objects.rowHeaders[].properties.fontColor = '#FF0000'` bold. Once `Item` moves into `Rows` its header is governed by `rowHeaders`, not `columnHeaders`, so the red header colour is silently lost otherwise (§7.1).
- Keep Inventory / WO / Totals as `tableEx` to the right, all four already share the `Show Item = 1` filter and the `Item` relationship, so clicking an item cross-filters them.

This restores per-item grouping **and** inline subtotals for the master block, which is what a reviewer looking for "the Cognos matrix" will check first. Full pixel parity (one wide row-spanned grid) requires Option A below and is materially more work.

**Safe to convert:** every column on all four tables is `summarizeBy: none`, including the identifiers `Order#` (int64), `Line#` (double), `WO#` (int64). No column will silently aggregate when moved into a matrix. (Checked `SO_Not_Shipping`, `Inventory_Availability`, `WorkOrder_Detail`, `Item`.)

## 3. Subtotals / summary rows

Cognos has exactly **one** `<listFooter>`, on the `2nd Item Number (Orders)` group — rendering the blue `U501-OP - Total` / `U701-OP - Total` rows visible in the screenshot. **No grand total** (`0` `<overallFooter>`), and all four PBI tables correctly set `objects.total[].totals = false`.

The footer's 8 `<rowCell>`s, in order, and their PBI counterparts:

| # | Cognos footer cell | PBI measure (`c4202c90c5c741a58651`) | Status |
|---|---|---|---|
| 0 | `<2nd Item Number (Orders)>` + `" - "` + `"Total"` | `Item[Item]` (row label) | label text `" - Total"` not reproduced — cosmetic |
| 1 | `Count Distinct(Order Number)` | `SO Lines (Order Count)` = `DISTINCTCOUNT(SO_Not_Shipping[Order#])` | **match** (name is misleading — it counts distinct *orders*, not lines) |
| 2 | `Primary Quantity Ordered per 2nd Item Number` (colSpan 5) | `SO Qty Total` = `SUM(SO_Not_Shipping[Primary Qty])` | **match** |
| 3 | `Count Distinct(AVAILABLE)` | `Inventory Lot Count` = `DISTINCTCOUNT(Inventory_Availability[AVAIL])` | **match** — fixed 2026-07-09, §8-1 |
| 4 | `AVAILABLE per 2nd Item Number` (colSpan 2) | `Available Total` = `SUM(Inventory_Availability[AVAIL])` | **match** |
| 5 | `Count Distinct(WO Number)` (colSpan 3) | `WO Count` = `DISTINCTCOUNT(WorkOrder_Detail[WO#])` | **match** |
| 6 | `Quantity Requested per 2nd Item Number` | `WO Qty Total` = `SUM(WorkOrder_Detail[Qty])` | **match** |
| 7 | *(empty, colSpan 2)* | — | n/a |

So the subtotal **values** all exist and are correct (cell 3 fixed 2026-07-09) — they are simply in a **detached fifth visual** rather than as a footer row under each item group.

**Why the footer stays detached.** Converting the SO block to a matrix (§2) would put cells 1 and 2 back inline, but cells 3–6 span the Inventory and WO tables and can never re-join a single matrix — so the Per-Item Totals table would have to remain anyway, for *most* of the footer. The conversion would therefore split one coherent totals row across two places while destroying the SO block's 8 conditional-format rules. **Decision: keep all seven footer cells together in the Per-Item Totals table.** The values are right; only their position differs from Cognos. Disclose the position.

## 4. Master-detail structure

**Cognos does not use a master-detail feature here.** `0` `<masterDetailLink>`, `0` `<masterDetailLinks>`, `0` `<listPageBody>`. (Correction to the briefing.) The three-block appearance comes from **one flat query** (`Not Shipping` = `Sales Inventory` ⋈ `Work Orders` on 2nd item number, per `<filterExpression>[Sales Inventory].[2nd Item Number (Orders)] = [Work Orders].[2nd Item Number]`) rendered as a single grouped list, where repeated master cells are blanked with `visibility:hidden`:

- `Order Count > 1` hides the 16 Inventory+WO cells on the 2nd and later SO lines of an item.
- `Lot Number Count > 1` hides the 8 WO cells on the 2nd and later inventory lots of an item.

Together these produce the row-span illusion in the screenshot (U701-OP's two inventory lots share one SO row).

**What the rebuild did instead:** an `Item` bridge dimension (`Item.tmdl`, an import table = `SELECT DISTINCT` item over the SO query's own `FROM`/`WHERE`) with three 1→* single-direction relationships `Item[Item] → {SO_Not_Shipping, Inventory_Availability, WorkOrder_Detail}[Item]`, three side-by-side tables, and a shared visual-level filter `SO_Not_Shipping[Show Item] = 1` on all four visuals.

**Is it acceptable?** **Yes, with disclosure — and it is now the recorded decision (§2).** Power BI genuinely has no row-span and no native master-detail; three related tables filtered by a common bridge is the standard idiom, it keeps the model clean, and `Show Item` faithfully reproduces the Cognos `<summaryFilter>`:
```
Cognos: [Primary Quantity Ordered per 2nd Item Number] > [AVAILABLE per 2nd Item Number]
         or [AVAILABLE per 2nd Item Number]=0 or [AVAILABLE per 2nd Item Number]=null
DAX:    IF ( ISBLANK(ord), 0, IF ( ord > avail || avail = 0 || ISBLANK(avail), 1, 0 ) )
```
What is **lost**: the reader can no longer see, in one grid, that *this* SO row's inventory is *these* two lots. The three tables cross-filter on click, but nothing is grouped until you click. This is the accepted cost of the §2 decision, and it is unavoidable — the matrix alternative would not have recovered it either (a matrix cannot nest sibling grains without cross-joining them). **State this trade-off explicitly in the handover rather than letting Rohit discover it.**

## 5. Sort order
**PRESENT — the composite Cognos sort is correctly distributed across the three tables.**

Cognos `<sortList>` on the list: `2nd Item Number (Orders)`, `2nd Item Number (Inv)`, `2nd Item Number (WO)`, `Order Number`, `Order Line`, `Location`, `Lot Number (Inv)`, `Lot Number (Orders)`, `Lot Number (WO)` (plus a group-level sort on `2nd Item Number (Orders)`). All ascending.

| PBI visual | `prototypeQuery.OrderBy` (all `Direction: 1` = ascending) | Verdict |
|---|---|---|
| SO `0e7af36c267f4df092f4` | `Item[Item]`, `Order#`, `Line#` | match |
| Inventory `6d0cb4c1987a44c78cb6` | `Item[Item]`, `Location`, `Lot#` | match |
| WO `5512e7237bf04fab8d86` | `Item[Item]`, `Lot#` | match |
| Totals `c4202c90c5c741a58651` | `Item[Item]` | match |

No action.

## 6. Prompts / parameters
**N/A.** `0` `<selectValue>`, `0` `parameter=` in the XML. This report is unprompted — the item whitelist, branch plants, statuses and the 21-day horizon are all hard-coded `<detailFilter>`s. The rebuilt `.m` files hard-code the same values.

Data-layer filters spot-checked and matching:

| Cognos `<filterExpression>` | `SO_Not_Shipping.m` |
|---|---|
| `[Next Status] in ('525','530','535','536','537','540','545','550')` | line 76 `so.SDNXTR IN ('525','530','535','536','537','540','545','550')` |
| `[Line Type]='S'` | line 77 `so.SDLNTY = 'S'` |
| `[Branch Plant] in ('CINC','CIN2','CIN4')` | `LTRIM(RTRIM(so.SDMCU)) IN ('CINC','CIN2','CIN4')` |
| `[Promised Ship Date]<={sysdate}+21` | lines 93-95 `… <= DATEADD(DAY, 21, CAST(GETDATE() AS date))` |
| `trim([Lot Number]) is null or trim(…) = ' '` | `(so.SDLOTN IS NULL OR LTRIM(RTRIM(so.SDLOTN)) = '')` |

## 7. Other parity gaps

### 7.1 Colour-coded headers — the three joined sources (**VERIFIED PRESENT, not a gap**)

Report 03 is the only report in the repo whose `<listColumnTitle>` styles use three header colours, and they do encode the three joined sources. Verified by walking all 27 `<listColumn>` elements and pairing each `<listColumnTitle>`'s `<CSS value="…color:…">` with its `<listColumnBody>`'s `<dataItemValue refDataItem="…"/>`:

| Header colour | Cols | Source block | `<dataItem>`s (in render order) | `Not Shipping` query expression |
|---|---|---|---|---|
| **red** (`font-weight:bold;color:red`) | 1–11 | Sales orders (Cognos query `Open Orders`) | `Branch Plant (Orders)`, `2nd Item Number (Orders)`, `Order Date`, `Order Number`, `Order Line`, `Promised Ship Date`, `Customer Name`, `Next Status`, `Quantity`, `Primary Quantity Ordered`, `Lot Number (Orders)` | `[Sales Inventory].[…(Orders)]` |
| **blue** (`font-weight:bold;color:blue`) | 12–19 | Inventory availability (Cognos query `Inventory On Hand`) | `Branch Plant (Inv)`, `2nd Item Number (Inv)`, `Quantity On Hand`, `Hard Commit`, `AVAILABLE`, `Location`, `Lot Number (Inv)`, `Inventory Status` | `[Sales Inventory].[…(Inv)]` |
| **green** (`color:green;font-weight:bold`) | 20–27 | Work orders (Cognos query `Work Orders`) | `2nd Item Number (WO)`, `Branch Plant (WO)`, `WO Number`, `Start Date`, `Requested Date`, `Quantity Requested`, `Lot Number (WO)`, `WO Status` | `[Work Orders].[…]` |

Tally: **11 red / 8 blue / 8 green**, matching the briefing exactly. (Red and blue both resolve through the `Sales Inventory` query, which is `Inventory On Hand` (0:N) ⟕ `Open Orders` (1:N) on 2nd item number; the `(Orders)` / `(Inv)` data-item suffixes are what separate them. Green comes straight from `Work Orders`.) The `<listColumnTitle>` styles carry no `<conditionalStyleRef>` — the colours are **static**, so this is a styling feature, entirely independent of the conditional formatting in §1. Treating them as separate findings is right.

**The rebuild preserves all three colours**, applied per-visual via `objects.columnHeaders[].properties.fontColor` (a `Literal`, matching Cognos's static styling):

| PBI visual | Columns | `columnHeaders.fontColor` | Cognos block |
|---|---|---|---|
| `0e7af36c267f4df092f4` "Sales Orders < 560 (Not Enough Inventory)" | 11 | `'#FF0000'` bold | red / SO ✓ |
| `6d0cb4c1987a44c78cb6` "Inventory On Hand" | 8 | `'#0000FF'` bold | blue / Inventory ✓ |
| `5512e7237bf04fab8d86` "Work Orders" | 8 | `'#008000'` bold | green / WO ✓ |
| `c4202c90c5c741a58651` "Per-Item Totals" | 7 | `'#000000'` bold | *(no Cognos counterpart — the footer row has no headers)* |

11 / 8 / 8 columns, red / blue / green, one-to-one with the Cognos blocks. **A user can still tell which source a column came from.** Because each Cognos block maps to exactly one PBI table, per-visual colouring is behaviourally identical to Cognos's per-column colouring; nothing is lost.

> **Correction to the briefing.** "*our flat `tableEx` rebuild has no colour-coded headers, so a user can no longer tell which source a column came from*" is **not correct**. The colours are in `report.json` and match. The evidence that identified this page (three header colours, unique in the repo) is sound — report 02 has 41 `<listColumnTitle>` elements, **all** `color:red` — but the parity conclusion drawn from it does not hold. Do not raise this with Rohit as a miss.

**A risk that the §2 decision retires.** Converting the SO block from `tableEx` to `pivotTable` would move `Item` from a value column into `Rows`, where its header is governed by a **`rowHeaders`** object, not `columnHeaders` — so the item column's header would silently lose its red unless `objects.rowHeaders[].properties.fontColor = '#FF0000'` were also set. This was the *second* thing the matrix conversion could silently drop (the first being the `backColor` value selectors, §2). **Since the conversion was not made, neither hazard applies.** Both are recorded here so that anyone who revisits the matrix idea starts from the known failure modes rather than rediscovering them.

### 7.2 Remaining items

1. **Column order: `Item` and `Plant` are swapped** in two tables. Cognos SO block renders `Plant | Item | Order Date | …` and the Inventory block renders `Plant | Item | On Hand | …` (confirmed in the screenshot header row). PBI puts `Item[Item]` first in both `0e7af36c267f4df092f4` and `6d0cb4c1987a44c78cb6`. The WO block matches (`Item | Plant | WO # | …`). Cosmetic, but it is the first thing a side-by-side comparison shows.
2. **Duplicate `Qty` header renamed.** Cognos's SO block has **two** adjacent columns both labelled `Qty` (`Quantity` = 41, `Primary Quantity Ordered` = 18,450). PBI names them `Qty` and `Primary Qty`. An improvement, but it *is* a visible label difference.
3. **`" - Total"` label text.** Cognos's footer row reads `U501-OP - Total`; the PBI Per-Item Totals table just shows `U501-OP`. Trivial (a calculated column or a matrix row-label format).
4. **Inventory/WO `Item` columns are white-on-white in Cognos** (per `BUILD.md` line 132, so the repeated item is invisible). PBI shows them normally as the first column. Deliberate and better; note it.
5. **Header colours and grid match exactly.** SO `columnHeaders.fontColor = '#FF0000'`, Inventory `'#0000FF'`, WO `'#008000'`, Totals `'#000000'`, all bold; every table has `outlineColor`/`gridHorizontalColor`/`gridVerticalColor` `= '#000000'` weight `1` — matching the Cognos `border:1pt solid black` on every cell. Verified against the screenshot.
6. **Header text block reproduced verbatim**, including the title, `PURPOSE:`, both numbered `NOTES:` lines, and the UNC hyperlink `\\kaylee\shared\OPS-PROD\Schedule\Shipment Date Change Log - Change History File.xlsm` (textbox `b4976550a49546708f30`, `textRuns[].url`). Note the NOTES text carries the stale "530 or 535" wording discussed in §1 — the rebuild copied Cognos faithfully, so the *text* and the *behaviour* disagree in Power BI exactly as they do in Cognos.
7. **`BUILD.md` §5 line 179 is wrong**: it says "*Five named styles. Two are color rules, three are visibility*". It is **three** colour rules (`Flag non 540`, `Flag Today or Past`, `WO Status 90`) and **two** visibility rules (`Order Count > 1`, `Lot Number Count > 0`). Fix before handover — Rohit will read this file.

## 8. Model-level defects found

1. **`Inventory Lot Count` did not implement `Count Distinct(AVAILABLE)` — FIXED 2026-07-09.** The Cognos footer cell is `<dataItemValue refDataItem="Count Distinct(AVAILABLE)"/>` — a distinct count of the **`AVAILABLE` values**. `Inventory_Availability.tmdl` line 89 previously defined `Inventory Lot Count = COUNTROWS('Inventory_Availability')` — a **row count**. These coincide only while every inventory row for an item has a distinct `AVAIL` quantity (true in the screenshot: U701-OP has lots `F11`=450 and `F42`=7,650 → both give `2`). Two lots holding the same quantity would make Cognos print `1` and Power BI print `2`.

   **Shipped:** `Inventory Lot Count = DISTINCTCOUNT ( 'Inventory_Availability'[AVAIL] )`. Verified in the TMDL.

   **Which reading this chose, and why it is still worth raising.** Counting distinct `AVAILABLE` *values* is probably a Cognos authoring accident — the surrounding footer cells count distinct *orders* and distinct *WO numbers*, so the author's intent was plainly distinct **lots** (`DISTINCTCOUNT('Inventory_Availability'[Lot#])`). We deliberately implemented the **Cognos behaviour, not the presumed intent**, consistent with this project's parity-first rule: the rebuild reproduces what Cognos does, and any correction is proposed separately rather than smuggled in. So the measure now ties to Cognos exactly, *including where Cognos is arguably wrong*.

   **Open, and it is a question for the report owner, not a code task:** if two lots ever hold the same quantity, this column under-counts the lots. Ask whether the intended figure is distinct lots. If yes, the one-line change is `DISTINCTCOUNT('Inventory_Availability'[Lot#])` — and it must be documented as a deliberate divergence from Cognos.
2. **`SO Cell Color` would paint red on a NULL `Promised Ship` — GUARDED 2026-07-09. Was latent, never live.** `SELECTEDVALUE(…[Promised Ship]) <= TODAY()` is **TRUE** when the value is `BLANK()` (DAX coerces blank to `1899-12-30`), whereas Cognos evaluates `NULL <= today()` as unknown and applies no style. `SO_Not_Shipping.m` derives `Promised Ship` as `(CASE WHEN so.SDPDDJ > 0 THEN … END)` (NULL-able), **but** the same query's `WHERE` (lines 93-95) compares that expression to `GETDATE()+21`, and `NULL <= x` is unknown, so null-promised-ship rows never survive the query.

   The guard is now in place (verified in `SO_Not_Shipping.tmdl`):
   ```dax
   VAR prm = SELECTEDVALUE ( 'SO_Not_Shipping'[Promised Ship] )
   VAR isPastDue = NOT ISBLANK ( prm ) && prm <= TODAY ()
   ```
   **This changed no rendered cell.** It is defence-in-depth against a future `.m` edit that relaxes the `WHERE`, and it aligns the code with report 02, where the same pattern *was* live and *was* a real bug. **Do not describe this to Rohit as a fixed defect on report 03** — it was never reachable here.
3. **`summarizeBy` audit — clean.** All columns on `SO_Not_Shipping` (12), `Inventory_Availability` (9), `WorkOrder_Detail` (10) and `Item` (1) are `summarizeBy: none`, identifiers included. The §2 matrix conversion carries no silent-aggregation risk.
4. **`Qty Ordered Per Item` (column) vs `Qty Ordered Per Item (m)` (measure)** both exist on `SO_Not_Shipping`; only the measure is used (by `Show Item`). The carried window column is dead weight. Harmless.

## Open items checklist

**Closed as a decision, not as work:**
- [x] ~~SO block is a flat `tableEx`; convert to `pivotTable` on `Item[Item]`~~ — **DECIDED 2026-07-09: NOT DOING.** A matrix would destroy all 9 conditional-format rules (every coloured column is also a `<listGroup>` field, and Power BI binds `backColor` only to `Values`, never to row headers); the three blocks are sibling grains, not a hierarchy, so a matrix `Rows` list cross-joins them; and Cognos's single item-level `<listFooter>` cannot be reproduced by a matrix that subtotals at every level. Full reasoning in §2. **Do not re-raise as a gap.**
- [x] ~~Colour-coded headers distinguishing the 3 joined sources~~ — **VERIFIED PRESENT** (11 red / 8 blue / 8 green, §7.1). No work. Do not report as a gap.
- [x] Master-detail is emulated by 3 cross-filtered tables + `Item` bridge, not a single row-spanned grid; write the trade-off into the handover doc explicitly — **DONE 2026-07-09** (§2 "What it costs", §4).

**Done:**
- [x] `Inventory Lot Count = COUNTROWS()` ≠ Cognos `Count Distinct(AVAILABLE)` — **DONE 2026-07-09.** Now `DISTINCTCOUNT('Inventory_Availability'[AVAIL])`, matching Cognos exactly. See §8-1 for the residual owner question below.
- [x] `SO Cell Color` red branch is not BLANK-guarded — **DONE 2026-07-09.** Behaviour-neutral: the `.m`'s `WHERE` already excludes null-promised-ship rows. Defence-in-depth only; **not** a bug fix on this report.

**Still open:**
- [ ] **Owner decision (not a code task):** Cognos's `Count Distinct(AVAILABLE)` counts distinct *quantities*, almost certainly meaning distinct *lots*. We ship Cognos's behaviour. If two lots ever hold the same quantity the count is low by one. Ask the report owner; if they want lots, change to `DISTINCTCOUNT('Inventory_Availability'[Lot#])` and document it as a deliberate divergence — **MED** — a decision + 5 min
- [ ] Resolve Cognos class `pd_5` (the red for `Flag Today or Past`) from the server stylesheet to confirm `#FF0000` — **MED** — 30 min (needs Cognos admin access)
- [ ] `BUILD.md` §5 line 179 states the colour/visibility rule split backwards — it says "*Two are color rules, three are visibility*"; it is **3 colour** (`Flag non 540`, `Flag Today or Past`, `WO Status 90`) and **2 visibility** (`Order Count > 1`, `Lot Number Count > 0`). Confirmed still wrong 2026-07-09. Rohit will read that file — **MED** — 5 min
- [ ] `Item` / `Plant` column order swapped vs Cognos in the SO and Inventory tables (PBI projects `Item.Item` first; Cognos renders `Plant | Item`). The WO table matches. Confirmed still swapped 2026-07-09 — **LOW** — 10 min
- [ ] Per-Item Totals rows show `U501-OP`, Cognos shows `U501-OP - Total` — **LOW** — 15 min
- [ ] `Flag non 540` uses Cognos `contains` vs DAX exact `IN` (equivalent on real 3-char status codes) — **LOW** — no action, note only
- [ ] Dead carried column `SO_Not_Shipping[Qty Ordered Per Item]` (the measure `Qty Ordered Per Item (m)` is what `Show Item` uses). Confirmed still present 2026-07-09 — **LOW** — 2 min
- [ ] **Not a code task:** open `CM Overview LIVE.pbip` in Power BI Desktop, re-save and republish so the two DAX fixes above reach users (see `## Status`).
