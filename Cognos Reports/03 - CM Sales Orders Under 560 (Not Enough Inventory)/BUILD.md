# Report 03 — CM Sales Orders < 560 (Not Enough Inventory to Ship)

**Cognos source:** Public Folders > Michelman Reporting > Production and Shipping > Contract Manufacturing Orders > *Dashboard - CM Overview LIVE* (embedded panel).
**Report name (Cognos):** `CM (Brent Planner 3 December 2024) - Sales Orders < 560 (Problem: Not Enough inventory to Ship)`
**Page rendered in the panel:** `Not Shipping` (list `List1`, query `Not Shipping`).

> **PURPOSE:** Show Brent's contract-manufacturing sales-order lines for the **next 21 days** (Next Status 525–550, pre-560/pre-ship) whose item **does not have enough available inventory to ship**, with the on-hand inventory and open work orders for that item alongside — so a planner can see, per item, "what's ordered vs what's on hand vs what's being made."
> **SCOPE:** Plants `CINC / CIN2 / CIN4`, Line Type `S`, item on Brent's CM whitelist, no lot yet assigned, Promised Ship ≤ today + 21. An item is shown **only if** its total ordered qty exceeds its total available (or nothing is available) — the "not enough inventory" gate.

This is **page 2 of the shared "CM Overview LIVE" PBIP** (report 02 is page 1). Build it as the second page of that PBIP. It is the most complex panel: a **master-detail** list — sales orders (master) with inventory + work-order detail nested per item.

This is the report the user calls **"the Brent planner page"** — the only report in the repo with **three** header colours, and the one named in `Excel Validation\CM (Brent Planner 3 December 2024) - Sales Orders _ 560 (...).xlsx`. When someone describes "a pivot table with three joined tables and colour-coded headers", they mean this page, not report 02.

---

## Status — 2026-07-10 — the page is now ONE grouped-grid `tableEx` (owner-directed)

> The owner asked for the Cognos grouped-list render back. The page no longer ships as four flat
> tables: a new combined table **`SO560_Grouped`** (see `SO560_Grouped.m` — the fan-out, the
> row-span suppression flags, the gate, and the inline `<item> - Total` rows all in one folding
> T-SQL query) drives a **single `tableEx`** that reproduces the Cognos grid, including all colour
> rules and the red/blue/green source headers. The §4 "Option A / Option B" discussion and the
> 2026-07-09 matrix rejection below are retained as history — the matrix is still impossible; this
> route sidesteps it. Full details: `PARITY_TODO.md` "Status — 2026-07-10". The old four-table
> layout is archived at `Archive\SO-under-560-pre-grouped-grid-2026-07-10\`; its four model tables
> remain in the model pending validation of the new grid.

## Status — 2026-07-09

> **This document is the original build spec, updated in place.** The live open-items list is `PARITY_TODO.md` in this folder — read that first.

**The `SO under 560` page stays as four flat cross-filtered `tableEx` visuals + the `Item` bridge + the `[Show Item] = 1` gate. That is a DECISION with a rationale, not an outstanding approximation.** §4 below offers "Option A / Option B" as if the choice were open; it is not. The matrix conversion (§4's Option B) was evaluated in full and **deliberately not made**. See "The matrix decision" immediately below — it is the first thing a reviewer will ask about.

Also implemented in the PBIP on 2026-07-09:

- **`Inventory Lot Count` fixed.** It was `COUNTROWS('Inventory_Availability')`, a row count. Cognos's footer cell is `Count Distinct(AVAILABLE)` — a distinct count of the **`AVAILABLE` values**. Now `DISTINCTCOUNT('Inventory_Availability'[AVAIL])`. The two coincide only while every inventory row for an item holds a distinct quantity; two lots holding the same quantity would make Cognos print `1` and Power BI print `2`. (Counting distinct *quantities* is almost certainly a Cognos authoring accident — the neighbouring cells count distinct orders and distinct WO numbers — but we ship Cognos's behaviour, per the parity-first rule, and raise the correction separately. See `PARITY_TODO.md` §8-1.)
- **`SO Cell Color` received an `ISBLANK` guard** on its red branch. **Be precise about this one: it is latent, not live.** `SO_Not_Shipping.m`'s `WHERE` already excludes null-promised-ship rows in SQL (`NULL <= GETDATE()+21` is unknown), so no row can currently trigger it and **no rendered cell changed**. The guard is defence-in-depth for whoever loosens that filter. It aligns the code with report 02, where the identical pattern *was* live and *was* a real bug. **Do not present this as a fixed defect on report 03.**
- **The colour-coded headers ARE reproduced** — 11 red / 8 blue / 8 green, encoding the three joined sources (§3). This was briefly suspected as a gap. It is not one. Do not raise it.
- A **`Last Refreshed`** table + `Last Refreshed Label` measure + a `card` visual now sit on this page and all 7. See "Last Refreshed card" below.

**PBIP changes do not reach the PBIX.** `FINAL - for handover\Dashboard - CM Overview LIVE.pbix` was last written 2026-07-08; the PBIP edits landed 2026-07-09. **Someone must open `CM Overview LIVE.pbip` in Power BI Desktop, re-save, and republish.** Until then nothing above is user-visible.

### The matrix decision — why this page is four flat tables

Cognos renders `List1` as **one** grouped list: 28 `<listGroup>` entries, a per-item `<listFooter>` producing inline `<item> - Total` subtotal rows, and `visibility:hidden` row-span suppression. Converting the SO block to a `pivotTable` looks like the obvious parity fix. It was examined and rejected, for five verified reasons:

1. **A matrix would destroy all 9 conditional-format rules.** Every conditionally-formatted column — `Order Number`, `Order Line`, `Promised Ship Date`, `Customer Name`, `Next Status`, `Quantity`, `Primary Quantity Ordered`, `Lot Number (Orders)` (the 8 SO cells) and `WO Status` — is **also** a `<listGroup>` field. Power BI binds `objects.values[].properties.backColor…expr.Measure` **only to fields in `Values`, never to row headers.** Moving those fields into a matrix's `Rows` silently drops their colour. There is no workaround. The colours are the entire point of the report — the on-page NOTES describe them — so a conversion that removes them is strictly worse than no conversion.
2. **It is structurally impossible regardless.** Sales-order lines, inventory lots and work orders are three **sibling grains** hanging off an item, not a hierarchy. A matrix `Rows` list is strictly hierarchical, so nesting the three **cross-joins** them (each SO line × each lot × each WO). Cognos escapes this only because its query is one flat join and the layout merely blanks repeated cells.
3. **Cognos's row-span is faked, and the fake cannot be rebuilt.** It is `visibility:hidden` driven by `Order Count > 1` and `Lot Number Count > 1`, both `running-total(count(...))` data items. **Power BI has no row-ordinal concept inside a visual and no cell merge.**
4. **The subtotal shape does not survive.** Cognos emits exactly **one** `<listFooter>`, at the item level (group #1, `2nd Item Number (Orders)`), and **zero** `<overallFooter>`. A Power BI matrix subtotals at *every* row level.
5. **The footer label cannot be produced.** Its first cell concatenates `<item>`, `" - "`, `"Total"`. A matrix subtotal row label is just `Total`.

**Verified counts** (against `Report XML.md`): **28** `<listGroup>` vs **27** `<listColumnTitle>`. The extra group is `WO Number Count`, a `running-total(count([WO Number]))` data item that drives visibility and **never renders as a column** — it is not a missing column. `<listFooter>` = 1, `<overallFooter>` = 0, `<crosstab>` = 0, `<masterDetailLink>` = 0. Separately, all **32** columns across the four rebuilt tables (`SO_Not_Shipping` 12, `Inventory_Availability` 9, `WorkOrder_Detail` 10, `Item` 1) are already `summarizeBy: none`, so the silent-aggregation hazard that afflicted report 01 cannot occur here. That was checked and ruled out; it is **not** what drove the decision.

**What the decision costs, stated plainly for the handover — two real things:**
1. The per-item subtotals sit in a **detached fifth table** ("Per-Item Totals") rather than inline underneath each item's rows.
2. Seeing which inventory lots belong to a given SO line is **one click** — cross-filter through the `Item` bridge — rather than **zero** (reading across a row-spanned grid).

Neither is recoverable. The matrix alternative would not have recovered them either; it would have cost the colours on top. Power BI has no row-span and no native master-detail, and three cross-filtered tables on a bridge dimension is the standard idiom for this shape. **Say this to the reviewer up front rather than letting them find it.**

### Last Refreshed card

`Last Refreshed.m` computes one row via `DateTimeZone.FixedUtcNow()` plus an explicit US-Eastern DST rule (second Sunday in March → first Sunday in November), yielding an `EDT`/`EST` label. `DateTime.LocalNow()` is **deliberately avoided**: it returns UTC in the Power BI Service but machine-local time on Desktop, so the two would disagree. The stamp is refresh-**start**, not finish — Power Query's evaluation order across queries is not deterministic — which is why the label reads "Last refreshed", not "finished". Format `MMM d, yyyy h:mm:ss AM/PM` matches the Cognos page-footer stamp, which is month-first in every report regardless of what the table's own date columns use.

---

## 0. On-page header text (VERBATIM — reproduce exactly)

Stack these as text boxes above the table, in this order:

1. **Title** (blue `#0000FF`, bold, ~14pt):
   `CM (Brent Planner 3 December 2024) - Sales Orders < 560 (Problem: Not Enough Inventory to Ship)`
2. *(blank line)*
3. **(bold)** `PURPOSE: Report shows Brent's planner number for next 21 days that do not have available inventory to ship`
4. *(blank line)*
5. **(bold)** `NOTES: `
6. **(bold)** `1. Sales Orders at status 530 or 535 OR Work Orders at status 90 are color coded YELLOW`
7. **(bold)** `2. Sales Orders with promised ship date of today or prior are color coded RED`
8. **Hyperlink** (blue, underlined): text = `\\kaylee\shared\OPS-PROD\Schedule\Shipment Date Change Log - Change History File.xlsm`, link target = the same UNC path.

---

## 1. Queries (Power Query)

| Query | File | Feeds |
|---|---|---|
| `SO_Not_Shipping` | `SO_Not_Shipping.m` | LEFT block — the **sales-order master list** (Cognos "Open Orders") |
| `Inventory_Availability` | `Inventory_Availability.m` | MIDDLE block — **on-hand inventory** for the item (Cognos "Inventory On Hand") |
| `WorkOrder_Detail` | `WorkOrder_Detail.m` | RIGHT block — **open work orders** for the item (Cognos "Work Orders") |

All three connect to `Sql.Database("ODSPROD","ODS")` and run native T-SQL against `PRODDTA` (folding on), following the canonical `edw_model/JDE_Orders/Orders.m` and reports 01/02: `Value.NativeQuery(Source, "<T-SQL>", null, [EnableFolding=true])`, inline Julian `DATEADD/DATEFROMPARTS` decode, `LTRIM(RTRIM(...))` trims, `x/10000.0` scaling, trailing `Table.TransformColumnTypes`. Paste each into **Power BI Desktop → Get Data → Blank Query → Advanced Editor**. Set the server name if it differs from `ODSPROD`.

### How the 3 raw Cognos SQL blocks map to the .m files

| Raw SQL block | Cognos query | Built as |
|---|---|---|
| Block A (C0..C23 pivot, window fns) | `Open Orders` | `SO_Not_Shipping.m` |
| Block B (flat F4102×F41021×F554101×F4101) | `Inventory On Hand` | `Inventory_Availability.m` |
| Block C (F4801×… with window count/sum) | `Work Orders` | `WorkOrder_Detail.m` |

> **Important — the join is done in Cognos, not SQL.** There are only 3 generated SQL statements. Cognos then stitches them in its engine via two more query objects that have **no SQL of their own**:
> - **`Sales Inventory`** = `Inventory On Hand` (0:N) ⟕ `Open Orders` (1:N) **on 2nd Item Number** → Open Orders is the required "1" side, inventory is optional detail.
> - **`Not Shipping`** = `Sales Inventory` (0:N) ⟕ `Work Orders` (0:N) **on 2nd Item Number**, then `WHERE [2nd Item Number (Orders)] <> null` (keeps SO-driven rows).
>
> We reproduce that stitch in **Power BI** (relationships + the gate below), not in SQL — so each `.m` stays a single-source folding query (no cross-query Formula-Firewall trap).

---

## 2. Data model — the master-detail (3 tables joined on **Item**)

**The join key is the trimmed JDE 2nd item number (`LITM`)** — NOT the bulk item. It is `SDLITM` (sales order) = `IBLITM` (inventory item-branch) = `WALITM` (work order), each trimmed. This is the value shown in the report ("U501-OP", "U701-OP"). Confirmed from the Cognos join filters `[Inventory On Hand].[2nd Item Number] = [Open Orders].[2nd Item Number]` and `[Sales Inventory].[2nd Item Number (Orders)] = [Work Orders].[2nd Item Number]`.

`Item` is **not unique** in any of the three tables (many order lines / many lots / many WOs per item), so relate them through a small **`Item` bridge** table on the "1" side:

**Bridge table** (new query or DAX calc table — SO items only, since the gate only ever shows SO items):
```DAX
Item = DISTINCT ( SO_Not_Shipping[Item] )
```

**Relationships** (all **single-direction**, `Item` is the "1" side, 1 → *):
```
Item[Item]  1 ──► *  SO_Not_Shipping[Item]        (single direction)
Item[Item]  1 ──► *  Inventory_Availability[Item]  (single direction)
Item[Item]  1 ──► *  WorkOrder_Detail[Item]        (single direction)
```
Filtering `Item[Item]` (or grouping a matrix on it) then scopes all three blocks to the same item — mirroring the Cognos master-detail. Inventory/WO are intentionally **not** whitelist-filtered in SQL (Cognos leaves them wide open); the relationship to the SO items does the filtering, so only items that actually appear in a sales order pull inventory/WO rows.

### The "Not Enough Inventory" gate (Cognos `summaryFilter` — REQUIRED)

The panel's whole point. Cognos keeps an item only when:
> `[Primary Quantity Ordered per 2nd Item Number] > [AVAILABLE per 2nd Item Number]` **OR** `[AVAILABLE per 2nd Item Number] = 0` **OR** `[AVAILABLE per 2nd Item Number] = null`

Because ordered-qty and available live in **different tables**, reproduce this with DAX measures + a visual-level filter:
```DAX
Qty Ordered Per Item = SUM ( SO_Not_Shipping[Primary Qty] )
Available Per Item    = SUM ( Inventory_Availability[AVAIL] )   -- status-gated AVAIL, see §5

Show Item =
VAR ord   = [Qty Ordered Per Item]
VAR avail = [Available Per Item]
RETURN
    IF ( ISBLANK ( ord ), 0,                       -- no order line for this item → not shown
         IF ( ord > avail || avail = 0 || ISBLANK ( avail ), 1, 0 ) )
```
Add **`Show Item = 1`** as a filter on the table/matrix (through the `Item` context). Example: U701-OP ordered 18,000 > available 8,100 → shown; U501-OP available 0 → shown. An item fully covered by available stock is hidden. `[Qty Ordered Per Item]` can also read the carried window column `SO_Not_Shipping[Qty Ordered Per Item]`; the measure form is preferred so it respects the current filter/slicer context.

---

## 3. Column layout (LEFT → RIGHT, exact Cognos labels & header colors)

One wide row per item group. Header colors are literal from the XML: **SO block = red `#FF0000`, Inventory block = blue `#0000FF`, WO block = green `#008000`.** Every header + body cell has a `1pt solid black` border (thin grid).

> **The three header colours ARE reproduced — verified, not a gap.** 11 red / 8 blue / 8 green, exactly matching the Cognos tally, applied per-visual via `objects.columnHeaders[].properties.fontColor` as a `Literal` (Cognos's styling is static, carrying no `<conditionalStyleRef>`). Because each Cognos block maps to exactly one Power BI table, per-visual colouring is behaviourally identical to Cognos's per-column colouring: **a user can still tell which source a column came from.** This was briefly suspected as a parity miss. It is not. Do not raise it. (The colour tally is also this report's fingerprint — report 02's 41 `<listColumnTitle>` elements are *all* red; report 01 is red+blue; 04-10 are red-only.)

| # | Cognos label | Header color | Query column | JDE source | Format |
|---|---|---|---|---|---|
| 1 | Plant | red | `SO_Not_Shipping[Plant]` | `F4211.SDMCU` | text |
| 2 | Item | red | `SO_Not_Shipping[Item]` | `F4211.SDLITM` (2nd item) | text |
| 3 | Order Date | red | `SO_Not_Shipping[Order Date]` | `F4211.SDTRDJ` (Julian→date) | medium date |
| 4 | Order # | red | `SO_Not_Shipping[Order#]` | `F4211.SDDOCO` | int, **no** thousands sep |
| 5 | Line # | red | `SO_Not_Shipping[Line#]` | `F4211.SDLNID / 1000` | number |
| 6 | Promised Ship | red | `SO_Not_Shipping[Promised Ship]` | `F4211.SDPDDJ` (Julian→date) | medium date |
| 7 | Customer | red | `SO_Not_Shipping[Customer]` | `F0101.ABALPH` via `SDSHAN` (ship-to) | text |
| 8 | Next Status | red | `SO_Not_Shipping[Next Status]` | `F4211.SDNXTR` | text |
| 9 | Qty | red | `SO_Not_Shipping[Qty]` | `F4211.SDUORG / 10000` | `#,0` |
| 10 | Qty | red | `SO_Not_Shipping[Primary Qty]` | `F4211.SDPQOR / 10000` | `#,0` |
| 11 | Lot# | red | `SO_Not_Shipping[Lot#]` | `F4211.SDLOTN` (blank by filter) | text |
| 12 | Plant | blue | `Inventory_Availability[Plant]` | `F4102.IBMCU` | text |
| 13 | Item | blue | `Inventory_Availability[Item]` | `F4102.IBLITM` | text *(Cognos renders white — it repeats the SO item; see note)* |
| 14 | On Hand | blue | `Inventory_Availability[On Hand]` | `F41021.LIPQOH / 10000` | `#,0` |
| 15 | Commit | blue | `Inventory_Availability[Commit]` | `F41021.LIHCOM / 10000` | `#,0` |
| 16 | AVAIL | blue | `Inventory_Availability[AVAIL]` | status-gated `(LIPQOH−LIHCOM)/10000` (§5) | `#,0` |
| 17 | Location | blue | `Inventory_Availability[Location]` | `F41021.LILOCN` | text |
| 18 | Lot# | blue | `Inventory_Availability[Lot#]` | `F41021.LILOTN` | text |
| 19 | Status | blue | `Inventory_Availability[Status]` | `F41021.LILOTS` | text |
| 20 | Item | green | `WorkOrder_Detail[Item]` | `F4801.WALITM` | text *(Cognos renders white)* |
| 21 | Plant | green | `WorkOrder_Detail[Plant]` | `F4801.WAMMCU` | text |
| 22 | WO # | green | `WorkOrder_Detail[WO#]` | `F4801.WADOCO` | int, **no** thousands sep |
| 23 | Start | green | `WorkOrder_Detail[Start]` | `F4801.WASTRT` (Julian→date) | medium date |
| 24 | Requested | green | `WorkOrder_Detail[Requested]` | `F4801.WADRQJ` (Julian→date) | medium date |
| 25 | Qty | green | `WorkOrder_Detail[Qty]` | `F4801.WAUORG / 10000` | `#,0` |
| 26 | Lot# | green | `WorkOrder_Detail[Lot#]` | `F4801.WALOTN` | text |
| 27 | Status | green | `WorkOrder_Detail[Status]` | `F4801.WASRST` | text |

- **Dates** = `dateStyle="medium"` → `Jul 21, 2026` / `Apr 23, 2026`.
- **Numbers** = `groupDelimiter=","`, no decimals in the rendered report → `#,0`.
- Columns 13 & 20 (the inventory/WO **Item**) are given **white font** in Cognos so the repeated item value is invisible (the SO item already shows it). Optional cosmetic; you can simply drop these two Item columns in PBI (the group already identifies the item) or keep them white.

`Bulk` (`F554101.IMBULK`) is carried by the inventory & WO queries (Cognos selects it) but is **not** placed in the rendered list. Leave it out of the visual; it's available if planners want it.

---

## 4. Visual approach — reproducing the master-detail + subtotals

> **SUPERSEDED 2026-07-09 — neither option below was adopted.** The page ships as **four flat cross-filtered `tableEx` visuals** (SO / Inventory / Work Orders / Per-Item Totals) joined through the `Item` bridge, all four carrying the shared `SO_Not_Shipping[Show Item] = 1` visual-level filter. Option B's matrix was evaluated and **rejected** — it would destroy all 9 conditional-format rules, and a matrix cannot nest three sibling grains without cross-joining them. Option A's merged table was not built either. The full reasoning is in the **Status block** at the top of this file, and in `PARITY_TODO.md` §2 and §4.
>
> Both options are retained below **as the evidence trail** — they record what was considered. Read them as history, not as instructions. **Do not re-raise the matrix conversion as a gap.**

Cognos renders `List1` as one wide list **grouped on `2nd Item Number (Orders)`**, sorted by item, with a per-item **footer** ("`<item> - Total`") and **row-spanning** (SO cells shown once, inventory/WO listed on their own rows). Two ways to do this in PBI — pick per how faithful the look must be:

### Option A (*originally* recommended for fidelity; NOT BUILT) — one merged "Not Shipping" table + a Table visual
Reproduce the Cognos join in Power Query and drive a single Table visual. After the 3 queries load, add a 4th query:
```
Not Shipping =
  SO_Not_Shipping
  |> merge (left outer) with Inventory_Availability on [Item]  → expand inventory cols
  |> merge (left outer) with WorkOrder_Detail      on [Item]  → expand WO cols
```
This fans each SO line out by (inventory lots × work orders) for that item — exactly what Cognos does before hiding duplicates. Then:
- One **Table** visual with the 27 columns in §3 order.
- **Per-item subtotals:** group the table by `Item` and show a group total row, or (simpler) show the subtotal values via the measures in §4.1 on a matrix (below).
- This gives the closest match to the rendered row-spanned block. Downside: the merged table is wider/denser and duplicates SO cells across an item's inventory/WO rows (Cognos hides those with `visibility:hidden`; in PBI either accept the repeats or blank them with a measure).

### Option B (NOT BUILT — the matrix half was rejected) — keep the 3 tables, use a Matrix (or 3 aligned Table visuals)
- A **Matrix** with `Item[Item]` (bridge) on Rows reproduces the item grouping and gives free **subtotal rows**. Put the SO fields as values; because a matrix can't align three independent detail lists in one grid, place **Inventory_Availability** and **WorkOrder_Detail** as two additional **Table** visuals to the right, all filtered by the same `Item` context (click an item → its inventory + WOs highlight/scope). This keeps the model clean (3 tables + bridge) at the cost of the exact row-spanned single-grid look.
- Use this if planners are fine with "grouped by item" rather than the pixel-exact Cognos grid.

> **What actually shipped is Option B's *table* half without its matrix.** The three cross-filtered `tableEx` visuals + `Item` bridge + `Show Item` gate are exactly as described here; the SO block was **kept as a flat `tableEx`, not converted to a matrix**. Two failure modes were identified for anyone who revisits the idea: (a) the `backColor` value selectors are dropped the moment a coloured field moves into `Rows`, and (b) once `Item` moves into `Rows` its header is governed by a `rowHeaders` object, not `columnHeaders`, so the red header colour is silently lost unless `objects.rowHeaders[].properties.fontColor` is also set. Start from those, not from scratch.
>
> The subtotal cells make the case on their own: cells 1–2 of the Cognos footer (`Count Distinct(Order Number)`, `Primary Quantity Ordered per 2nd Item Number`) could return inline under a matrix, but cells 3–6 span the Inventory and WO tables and can **never** rejoin a single matrix. The Per-Item Totals table would have to remain anyway, for *most* of the footer. Converting would split one coherent totals row across two places **and** destroy the SO block's 8 colour rules. Keeping all seven footer cells together was the better trade.

### 4.1 Per-item subtotal ("… - Total") — the footer values
The Cognos footer row shows these five aggregates per item (from the group `listFooter`). Reproduce as measures (they light up on the matrix subtotal row, or on the merged-table group total):
```DAX
SO Lines (Order Count)   = DISTINCTCOUNT ( SO_Not_Shipping[Order#] )       -- e.g. 1
SO Qty Total             = SUM ( SO_Not_Shipping[Primary Qty] )            -- e.g. 18,450 / 18,000
Inventory Lot Count      = DISTINCTCOUNT ( Inventory_Availability[AVAIL] ) -- e.g. 0 / 2   (FIXED 2026-07-09)
Available Total          = SUM ( Inventory_Availability[AVAIL] )           -- e.g. 8,100
WO Count                 = DISTINCTCOUNT ( WorkOrder_Detail[WO#] )         -- e.g. 0
WO Qty Total             = SUM ( WorkOrder_Detail[Qty] )
```
(Cognos labels these `Count Distinct(Order Number)`, `Primary Quantity Ordered per 2nd Item Number`, `Count Distinct(AVAILABLE)`, `AVAILABLE per 2nd Item Number`, `Count Distinct(WO Number)`, `Quantity Requested per 2nd Item Number`.) These are the window `COUNT(...) OVER (...)` / `SUM(...) OVER (...)` aggregates in the raw SQL, re-expressed as PBI aggregations so we don't carry the Cognos list-plumbing window columns.

> **`Inventory Lot Count` — fixed 2026-07-09.** It shipped as `COUNTROWS ( Inventory_Availability )`, described above as "row-count as the practical equivalent of Cognos's distinct-AVAILABLE count". It is not equivalent. Cognos's footer cell is `Count Distinct(AVAILABLE)` — a distinct count of the **`AVAILABLE` values**, not of the rows. The two agree only while every inventory row for an item holds a distinct quantity (true in the validation screenshot: U701-OP's lots hold 450 and 7,650, so both formulas give `2`). **Two lots holding the same quantity would make Cognos print `1` and Power BI print `2`.** Now `DISTINCTCOUNT ( Inventory_Availability[AVAIL] )`.
>
> Counting distinct *quantities* is almost certainly a Cognos authoring accident — the surrounding footer cells count distinct *orders* and distinct *WO numbers*, so the author plainly meant distinct **lots**. We implemented **Cognos's behaviour, not the presumed intent**, per this project's parity-first rule; corrections get proposed separately rather than smuggled in. **Open question for the report owner, not a code task:** if two lots ever hold the same quantity, this under-counts by one. If they want lots, it is a one-line change to `DISTINCTCOUNT('Inventory_Availability'[Lot#])` — and it must then be documented as a deliberate divergence from Cognos.

### 4.2 Sort
The `.m` files intentionally omit `ORDER BY` (illegal inside the folded subquery — the bug that hit reports 04/06). Set the sort in the visual:
**Item ▲, then Order # ▲, then Line # ▲** (SO block); within an item, inventory by **Location ▲ / Lot# ▲**, work orders by **Lot# ▲**. (Cognos `sortList`: `2nd Item Number` → `Order Number` → `Order Line` → `Location` → `Lot Number`.)

---

## 5. Conditional formatting (VERBATIM from the XML `<namedConditionalStyles>`)

> **Conditional formatting was never missing from this report.** All three colour rules below are implemented and live in `report.json` as **9** dynamic markers (8 on the SO block + 1 on `WO Status`), driven by DAX colour measures bound to `backColor`, on exactly the columns Cognos styles, with the same red-over-yellow precedence. If any note anywhere implies CF is outstanding here, it is wrong.
>
> **Why a grep finds nothing.** This repo uses Power BI's *format-by-field-value* form — `objects.values[].properties.backColor.solid.color.expr.Measure` pointing at a DAX measure that returns a hex string — **not** rules-based `FillRule`. And `config` in `report.json` is a **JSON-encoded string**, so a search for a quoted `"backColor"` returns zero hits even though the markers are there. You must parse `config` before searching it. That mistake was made once and corrected; do not repeat it.

Five named styles. **Three are colour rules** (`Flag non 540`, `Flag Today or Past`, `WO Status 90`) and **two are visibility** (row-span) helpers (`Order Count > 1`, `Lot Number Count > 0`). *(This line previously said "two colour, three visibility" — it had the split backwards.)*

### (a) YELLOW — Sales-order status  (`Flag non 540`)
- **Rule (exact):** `Next Status` **contains** `525` **OR** `530` **OR** `535`. → i.e. `SO_Not_Shipping[Next Status] IN ("525","530","535")`.
- **Style:** `background-color:yellow` → **`#FFFF00`** (text unchanged).
- **Applied to:** the **SO block body cells** (columns 4–11: Order#, Line#, Promised Ship, Customer, Next Status, Qty, Primary Qty, Lot#). Plant / Item / Order Date (cols 1–3) carry **no** conditional style.
- ⚠ **Discrepancy to flag:** the on-page NOTE says *"status 530 or 535"*, but the actual rule **also flags 525**. Reproduce the XML rule (525/530/535); mention the note wording to the planners.

### (b) RED — Promised ship today or prior  (`Flag Today or Past`)
- **Rule (exact):** `SO_Not_Shipping[Promised Ship] <= today()` (today = refresh date).
- **Style:** Cognos predefined conditional style **`pd_5`** = the strongest **RED** band → **`#FF0000`** (per the on-page NOTE "color coded RED").
- **Applied to:** the same SO block body cells (columns 4–11).
- **Precedence:** listed **after** the yellow rule on every SO cell → **RED wins** when a line is both (e.g. status 530 *and* promised ≤ today). Gate the yellow so it doesn't fire on red rows.

### (c) YELLOW — Work order at status 90  (`WO Status 90`)
- **Rule (exact):** `WorkOrder_Detail[Status] = "90"`.
- **Style:** `background-color:yellow` → **`#FFFF00`**.
- **Applied to:** the **WO Status** cell only (column 27).

### (d)/(e) Row-span suppression — NOT colors (`Order Count > 1`, `Lot Number Count > 0`)
- `Order Count > 1` → `visibility:hidden` when the item's running order count > 1; `Lot Number Count > 0` → `visibility:hidden` when the running lot count > 1. These **hide repeated** inventory/WO cells on the 2nd+ physical row of an item (the Cognos master-detail row-span). In PBI this is handled by matrix grouping (Option B) or by blanking duplicates in the merged table (Option A) — no color involved. Do not reproduce them as fills.

### DAX for the color rules (Table/Matrix → Cell elements → Background color → format by field value)
```DAX
-- SO block cells (cols 4–11): red wins over yellow
SO Cell Color =
VAR isPastDue = SELECTEDVALUE ( SO_Not_Shipping[Promised Ship] ) <= TODAY ()
VAR isFlagSts = SELECTEDVALUE ( SO_Not_Shipping[Next Status] ) IN { "525", "530", "535" }
RETURN
    IF ( isPastDue, "#FF0000", IF ( isFlagSts, "#FFFF00", BLANK () ) )

-- WO Status cell (col 27)
WO Status Color =
    IF ( SELECTEDVALUE ( WorkOrder_Detail[Status] ) = "90", "#FFFF00", BLANK () )
```
**Color reference:** yellow `#FFFF00`, red `#FF0000`, white `#FFFFFF`. Title/labels blue `#0000FF`. Header text: SO red `#FF0000`, inventory blue `#0000FF`, WO green `#008000`. Grid border `1pt solid black`.

> **`SO Cell Color` was `ISBLANK`-guarded on 2026-07-09 — and this one is LATENT, not live.** As written above, `SELECTEDVALUE(...[Promised Ship]) <= TODAY()` is **TRUE** when the value is `BLANK()`, because DAX coerces blank to `1899-12-30`; Cognos evaluates `NULL <= today()` as *unknown* and applies no style. **But no row can currently reach it:** `SO_Not_Shipping.m`'s `WHERE` compares that same nullable expression to `GETDATE()+21`, and `NULL <= x` is unknown in SQL, so null-promised-ship rows never survive the query. **The guard changed no rendered cell.** As shipped:
> ```dax
> VAR prm = SELECTEDVALUE ( 'SO_Not_Shipping'[Promised Ship] )
> VAR isPastDue = NOT ISBLANK ( prm ) && prm <= TODAY ()
> ```
> It is defence-in-depth against a future `.m` edit that relaxes that `WHERE`, and it aligns this report with report 02, where the identical pattern *was* reachable and *was* a real bug. **Do not describe this as a fixed defect on report 03.**

---

## 6. Known Cognos quirks (PARITY MODE — reproduced or deliberately dropped)

1. **Vestigial business-day logic.** `Open Orders` and `Work Orders` each compute `DAY_OF_WEEK` / `WEEKDAY` / `CALC_DAYS_FORWARD` (Thu/Fri→4, Sat→3, else 2 for SO; 5/5/4/3 for WO), but **no filter references them**. The real look-ahead is a **flat** `sysdate+21` (SO promised ship) and `sysdate+31` (WO requested). Unlike report 01 (where the day-of-week window is live), here it's dead code → **omitted** from the `.m` files. If planners later want a business-day window, port report 01's `(((DATEDIFF(DAY,'2003-01-06', d)%7)+7)%7)+1` form.
2. **`trim` on numerics.** Cognos wraps numeric expressions in `trim(both from x/10000)` — a no-op quirk. In T-SQL we just divide (`x/10000.0`) and drop the trim.
3. **Status-gated AVAIL.** The `AVAIL` column is **not** raw `On Hand − Commit`; Cognos's `AVAILABLE` counts on-hand only for **blank-status** (approved) lots, else 0 (§5-context). Reproduced in `Inventory_Availability.m`. The raw SQL block B *also* selected a plain `LIPQOH/10000 − LIHCOM/10000`, but the report's visible AVAIL and the per-item Available total both use the gated value — so we output the gated one.
4. **`AVAILABLE CHECK` row filter.** Cognos hides only blank-status lots that are fully hard-committed (available ≤ 0); everything else shows. Reproduced as `LTRIM(RTRIM(LILOTS)) <> '' OR (LIPQOH−LIHCOM)/10000.0 > 0`.
5. **Window count/sum plumbing.** Block A's outer `count()/sum() OVER (partition by C0..C19)` and block C's outer window are Cognos **list running-totals** for the footer. We keep only the meaningful **per-item `SUM`** (`Qty Ordered Per Item`, `Qty Requested Per Item`) and rebuild the footer counts as the §4.1 measures.
6. **Whitelist lists `UNYTEC201-FD` twice** — kept verbatim (harmless duplicate in an `IN` list).
7. **Extra joins.** `Open Orders` also inner-joins Sold-To (F0101 via SDAN8) + Order Company (F0010 via SDKCOO=CCCO) and left-joins CSR (F42140). Sold-To + Company are 1:1 non-filtering and are kept for exact row-set parity (columns unused); the CSR left join is dropped (unused, cannot change the row set).

---

## 7. Refresh / "as of" behavior
Both look-ahead windows use `CAST(GETDATE() AS date)` for Oracle `sysdate` (SO `+21`, WO `+31`), and the RED rule uses `today()`, so the panel is **"as of the last refresh."** Schedule a daily refresh (early morning). No report parameters/prompts.

---

## 8. Validation checklist
- [ ] Refresh all three queries — no errors; `SO_Not_Shipping` returns CINC/CIN2/CIN4 lines at status 525–550 for the next 21 days, `Inventory_Availability` and `WorkOrder_Detail` return CINC/CIN2/CIN4 stock/WOs.
- [ ] Open the live Cognos panel the same day; confirm the **item groups** match (the screenshot shows **U501-OP** and **U701-OP** groups).
- [ ] **U501-OP:** 1 SO line (Order 2681222, Apr 23 2026, Promised Jul 21 2026, AGY Aiken, status 540, Primary Qty 18,450), **no** inventory rows, footer `Available Total = 0`, `WO Count = 0` → item shows because available = 0.
- [ ] **U701-OP:** 1 SO line (Order 2695060, Johns Manville, Primary Qty 18,000), **2** inventory lots (450 @ F11 lot 4582014, 7,650 @ F42 lot H01260500084D, both blank status), footer `Available Total = 8,100`, `WO Count = 0` → item shows because 18,000 > 8,100.
- [ ] Tie the **AVAIL math**: for each blank-status lot, AVAIL = On Hand − Commit; non-blank lots show AVAIL 0; `Available Total` per item = Σ AVAIL.
- [ ] Confirm the **gate**: only items with `Qty Ordered Per Item > Available Per Item` (or Available = 0) appear.
- [ ] **Color rules:** a line at status 525/530/535 → SO cells **yellow**; Promised Ship ≤ today → SO cells **red** (red wins if both); a WO at status 90 → its **Status** cell **yellow**.
- [ ] Dates render **medium** (`Jul 21, 2026`); quantities `#,0`; `Order #` / `WO #` show **no** thousands separator.
- [ ] Sort = Item ▲, Order # ▲, Line # ▲.

---

## 9. Open items / assumptions

> The live open-items list is `PARITY_TODO.md`. The matrix conversion and the colour-coded headers are **closed there as decisions/non-issues** — do not re-raise either. What remains is the `Count Distinct(AVAILABLE)` owner question, resolving Cognos's `pd_5` red from the server stylesheet, some LOW cosmetics, and the PBIX regeneration.

- **The four-flat-tables layout is a decision, not an approximation.** See the Status block. The cost — detached subtotals, one click instead of zero to see an SO line's lots — is real, unavoidable, and must be disclosed at handover.
- **Item join key = trimmed 2nd item number (`SDLITM`=`IBLITM`=`WALITM`)**, confirmed from the Cognos join filters. It is the item shown in the report (e.g. `U701-OP`), **not** the bulk item (`IMBULK`, which is carried but unshown).
- **Not-enough-inventory gate is a cross-table comparison** (`Qty Ordered Per Item > Available Per Item`), so it lives in DAX + a visual filter (§2), not in any single `.m`. This is the one piece that cannot fold into one query.
- **NOTE vs rule mismatch on yellow — STILL WORTH CONFIRMING WITH PLANNERS.** The on-page NOTE says *"Sales Orders at status 530 or 535"*; the actual `Flag non 540` rule **also flags 525**. The XML is the authority and the DAX follows it (`IN { "525", "530", "535" }`), so the Cognos NOTES text is stale — and the rebuild copies that text faithfully, meaning the *text* and the *behaviour* disagree in Power BI exactly as they do in Cognos. Correct call; be ready to explain it.
- **`Inventory Lot Count` counts distinct `AVAILABLE` values, matching Cognos** — which almost certainly meant distinct *lots*. Owner decision, not a code task. See §4.1.
- **`pd_5` = red.** The RED rule uses Cognos's predefined `pd_5` conditional-palette style; per the on-page NOTE this is red `#FF0000`. If the live panel shows a different red shade, adjust the hex.
- **Inventory & WO are not whitelist-filtered** (Cognos leaves them open; the join filters). If the two detail tables are too large, you *could* add the same item whitelist to them, but the relationship + gate already restricts what displays.
- **Line# uses `SDLNID/1000.0`** (float, so sub-lines survive), matching report 02. Switch to integer `/1000` if planners want whole line numbers only.
- **No `00_verify_tables.sql`** for this report (per instruction). ODS mirrors JDE; all tables (F4211, F0101, F0010, F42140, F4102, F41021, F4101, F554101, F4801) are the standard PRODDTA set used by reports 01/02.
- **Two SO quantity columns:** `Qty` = `SDUORG/10000` (units, e.g. 41) and `Qty` = `SDPQOR/10000` (primary quantity, e.g. 18,450). Both labelled "Qty" in Cognos; optionally rename to `Qty (Units)` / `Primary Qty` for clarity or leave as-is to match.
