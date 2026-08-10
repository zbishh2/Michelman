# Report 01 — RM Staging at Shell Road 2026 (ODS)

**Cognos source:** Public Folders > Michelman Reporting > Production and Shipping > Cogan Excel AD HOC Reports > *DEMO - RM Staging at Shell Road 2026*
**Report header in Cognos:** "Raw Materials Needed in CINC"

> **OBJECTIVE:** Identify the materials that need to be transferred to **CINC** from **CIN2**.
> **SCOPE:** Parts list required within the next **2 business days**, and material is **NOT** a finished-good MPF.

The PBI page reproduces the two Cognos tables: a **summary shortage** table and a **work-order detail** table.

---

## Status — 2026-07-09

> **This document is the original build spec, updated in place.** Where a section once *prescribed* something, it now *records* it. The live open-items list is `PARITY_TODO.md` in this folder — read that first.

**Implemented in the PBIP** (`PBIP\RM Staging at Shell Road 2026 (ODS).pbip`):

- **Both report pages exist.** Page 1 "RM Staging at Shell Road" (Cognos `Materials Short`) and page 2 "Shortage Details". §7's old claim that page 2 was "NOT yet built" was already stale when written — it is built, with `Shortage_Detail.m` behind it. What is missing page 2 is the **PBIX**, not the PBIP.
- **Both grouped lists are now `pivotTable` visuals** with `steppedLayout: false`, per the design §3/§8 prescribed. The per-`Branch Plant` subtotal is on; the grand total is off (Cognos has no `<overallFooter>`).
- **All four Cognos sorts are applied:** `RM` asc (page-1 RM Requirements), `Work Order Start` asc (page-1 work orders), `Branch Plant` desc and `Lot Number` asc (page 2).
- Page 1's `RM Requirements` table **correctly stays a flat `tableEx`** — Cognos `List3` has no `<listGroups>` child. Only 2 of the 3 lists were ever grouped. Do not "fix" it into a matrix.
- A duplicate visual title was removed: page 1's work-order table had a copy-pasted `'Raw Material Requirements'` caption, so the heading rendered twice. Cognos gives that list **no caption at all**. (Cognos's own caption on the RM table is lowercase-r `"Raw Material requirements"`; ours is title-case. Cosmetic, deliberately left alone.)
- A **`Last Refreshed`** table + `Last Refreshed Label` measure + a `card` visual now sit on **both pages** — see "Last Refreshed card" below. This is an addition beyond Cognos parity, not a parity item.

**PBIP changes do not reach the PBIX.** The `.pbip` is a folder of text files; Power BI does not read them at runtime. `FINAL - for handover\DEMO - RM Staging at Shell Road 2026.pbix` still has the old flat tables and no page 2. **Someone must open the `.pbip` in Power BI Desktop, re-save, and publish.** Until that happens, none of the above is user-visible.

### Model trap worth stating generally: `summarizeBy` on Cognos grouping keys

`WorkOrder_Detail[WO Number]` and `Shortage_Detail[Short Qty]` were both set to **`summarizeBy: none`**. Both are Cognos `<listGroup>` **grouping keys**, not measures. Left at the Power BI default `sum`, a matrix would have **added work-order numbers together**, and would have **multiplied `Short Qty` by the lot count** (`Short Qty` is functionally dependent on `RM`, so summing it across an item's lot/location detail rows inflates it). Both were harmless while the visuals were flat tables — one row per group — which is exactly why the defect survived the first build. **Before converting any Cognos list to a Power BI matrix, set every grouping-key column to `summarizeBy: none` first.**

### Last Refreshed card

`Last Refreshed.m` computes one row via `DateTimeZone.FixedUtcNow()` plus an explicit US-Eastern DST rule (second Sunday in March → first Sunday in November), yielding an `EDT`/`EST` label. `DateTime.LocalNow()` is **deliberately avoided**: it returns UTC in the Power BI Service but machine-local time on Desktop, so the two would disagree. The stamp is refresh-**start**, not finish — Power Query's evaluation order across queries is not deterministic — which is why the label reads "Last refreshed", not "finished". Format `MMM d, yyyy h:mm:ss AM/PM` matches the Cognos page-footer stamp, which is month-first in every report regardless of what the table's own date columns use.

---

## 1. Queries (Power Query)

| Query | File | Feeds |
|---|---|---|
| `RM_Requirements` | `RM_Requirements.m` | Top table — "Raw Material requirements" |
| `WorkOrder_Detail` | `WorkOrder_Detail.m` | Bottom table — work orders driving the demand |

Both connect to `Sql.Database("ODSPROD","ODS")` and run native T-SQL against `PRODDTA` (folding on). Paste each into **Power BI Desktop → Get Data → Blank Query → Advanced Editor**. Set the server name to match your SSMS connection if it differs from `ODSPROD`.

### Column mapping (Cognos → PBI)
**Top table**

| Cognos column | Query column | JDE field |
|---|---|---|
| RM | `RM` | `F3111.WMCPIL` (component 2nd item) |
| QTY OH in CINC | `Qty On Hand CINC` | `AVG` of `F41021.LIPQOH/10000` across lot statuses |
| Total RM Needed | `Total RM Needed` | `SUM((F3111.WMUORG − F3111.WMTRQT)/10000)` |
| QTY Required from CIN2 | `Qty Required From CIN2` | `Total RM Needed − Qty On Hand` (or full need if no on-hand) |

**Bottom table**

| Cognos column | Query column | JDE field |
|---|---|---|
| Work Order Start | `Work Order Start` | `F4801.WASTRT` (Julian → date) |
| Raw Material | `Raw Material` | `F3111.WMCPIL` |
| WO # | `WO Number` | `F4801.WADOCO` |
| FG Item | `FG Item` | `F4801.WALITM` (parent / finished good) |

---

## 2. Data model / relationship

**Short-list filtering is done IN THE QUERY, not the report.** The Cognos report XML shows the bottom table (`Query1`) **inner-joins** the planned work orders to the short-material summary (`RM Shortage CINC`) — so it only lists WOs whose raw material is short. `WorkOrder_Detail.m` reproduces this by inner-joining the same shortage subquery in SQL. So the table already contains only short-material rows when it loads; no report-level filter needed.

> Why in SQL and not a Power Query merge to `RM_Requirements`? A query that both calls `Sql.Database` **and** references another query trips Power BI's **Formula Firewall** ("references other queries, so it may not directly access a data source"). Keeping the join in native SQL avoids that entirely.

Relationship (optional, for interactivity):
```
RM Requirements[RM]  1 ───► *  WorkOrder_Detail[Raw Material]   (single direction)
```
- Not required for correctness (the query is already filtered), but it lets clicking a material in the top table cross-highlight its work orders in the bottom table. Included in the PBIP.

---

## 3. Visuals

### Page title / objective (Text boxes)
- Title: **"Raw Materials Needed in CINC"** (red, bold) — matches Cognos.
- Subtitle objective/scope text (blue) — copy the OBJECTIVE/SCOPE block above.

### Visual A — "Raw Material requirements" (Table) — *built as specified*
- Visual type: **Table** (`tableEx`). **This one is correctly flat.** Cognos `List3` has no `<listGroups>` child, so there is nothing to group on. Leave it as a table.
- Fields in order: `RM`, `Qty On Hand CINC`, `Total RM Needed`, `Qty Required From CIN2`.
- Rename column headers to the Cognos labels: **RM**, **QTY OH in CINC**, **Total RM Needed**, **QTY Required from CIN2**.
- Format the three numeric columns: **whole number, thousands separator, 0 decimals**.
- Sort ascending by `RM`. **Applied 2026-07-09.**
- Header styling to match Cognos: red header text on the first column label group, blue on the metric labels (optional — cosmetic).
- This visual keeps its own `'Raw Material Requirements'` title (Cognos's caption, title-cased).

### Visual B — Work-order detail (Matrix) — *built 2026-07-09*
- Visual type: **Matrix** (`pivotTable`), grouped so the Cognos "date shown once" behaviour reproduces. Originally specified as "Table or Matrix"; the matrix is what shipped.
- Rows, in order: `Work Order Start`, `Raw Material`, `WO Number`, `FG Item`. **No Values** — there is no measure here, so all four fields sit on Rows, which reproduces Cognos's repeat-suppression without any aggregation. `steppedLayout: false`, so each level gets its own column.
- Rename headers: **Work Order Start**, **Raw Material**, **WO #**, **FG Item**.
- `Work Order Start`: format as **long date** (e.g. "Wednesday, 1 July 2026") to match Cognos.
- `WO Number`: format as whole number, **no thousands separator** (it's an ID), and `summarizeBy: none` — see the trap in the Status block. Its `prototypeQuery.Select` entry must read `WorkOrder_Detail.WO Number`, **not** `Sum(WorkOrder_Detail.WO Number)`.
- Sort by `Work Order Start` ascending. **Applied 2026-07-09.**
- **No visual title.** Cognos gives `List2` no caption. The copy-pasted `'Raw Material Requirements'` title that once rendered here has been removed (`vcObjects.title.show = false`).
- This visual is filtered to the short materials via the relationship above. (If you want it to ignore the summary and show all planned parts, remove the relationship or set the visual to not interact.)

---

## 4. Refresh / "as of" behavior
The window uses `CAST(GETDATE() AS date)` for `sysdate`, so the report is always **"as of the last refresh."** Schedule a daily refresh (early morning) so the 2-business-day look-ahead is current. There are no report parameters/prompts.

---

## 5. Known Cognos quirks (PARITY MODE — reproduced on purpose)

> **READ THIS BEFORE RECONCILING ANY NUMBER ON PAGE 1.** Two figures on this page are **wrong by any normal definition and deliberately left wrong**, because the point of the rebuild is to tie 1:1 to the live Cognos report. `Total RM Needed` **double-counts**, and `Qty On Hand CINC` uses **AVG across lot statuses, not SUM**. Anyone reconciling against JDE without knowing this will chase both as bugs. Do not "fix" them without a planner decision — the rebuild stops matching Cognos the moment you do.

These two behaviors are baked into the Cognos report. We **reproduce them** so the PBI numbers tie 1:1 to the live report. If/when the planners confirm they want them fixed, here are the corrected formulas.

### Quirk 1 — `Total RM Needed` double-counts when an item has 2 lot statuses
Cognos joins the planned demand to on-hand **per lot status**, then `SUM`s the open RM — so the need is multiplied by the number of qualifying lot statuses (`' '` and `'-'`). An item with stock in both statuses shows **2×** its real need.

**Corrected:** compute `OpenRM` once per component (don't let the on-hand join fan it out). In the query, pre-aggregate `Planned` to the component and join on-hand as a scalar:
```sql
-- corrected Total RM Needed = MAX(p.OpenRM)  (or compute OpenRM in a separate CTE and join 1:1)
```

### Quirk 2 — `QTY OH in CINC` uses AVG, not SUM
On-hand is **averaged** across lot statuses, so 100 (`' '`) + 50 (`'-'`) reports as **75**, not the true 150.

**Corrected:** replace `AVG(ioh.QtyOnHand)` with a per-component `SUM`:
```sql
-- corrected on-hand: SUM the lot-status quantities first, then join 1:1 to Planned
IOH_total AS (SELECT Component2nd, SUM(QtyOnHand) AS QtyOnHand FROM IOH GROUP BY Component2nd)
```

> To switch to corrected mode: build `IOH_total` (sum across statuses), join Planned (already 1 row per component) to it 1:1, and drop the `AVG`/`SUM(OpenRM)` fan-out. Everything else (filters, window, SHORT test) stays the same.

---

## 6. Validation checklist
- [ ] Refresh both queries — no errors; `RM_Requirements` returns the short materials, `WorkOrder_Detail` returns the planned parts.
- [ ] Open the live Cognos report the same day and compare the **RM list** and the four metric columns row-for-row (parity mode should match exactly).
- [ ] Confirm the business-day window: on a **Thursday/Friday** the look-ahead reaches into next week (Thu/Fri → +4 days); Sat → +3; otherwise +2.
- [ ] Spot-check one item that has stock in both `' '` and `'-'` lot statuses to confirm the double-count/AVG quirks reproduce (or are intentionally corrected).
- [ ] Confirm `WO Number` shows as a plain integer and `Work Order Start` as a long date.

---

## 7. Open items

> The live open-items list is `PARITY_TODO.md`. What remains there is LOW cosmetics (page name, `No Data Available` empty state, `SCOPE` casing), two questions for Rohit, and the PBIX regeneration.

- **Cognos query objects (confirmed from Report XML):** the visible page ("Materials Short") uses `RM Shortage CINC` (top table) and `Query1` (bottom table). `Summary Shortage`, `Summary`, `IOH CIN2`, `IOH All` feed the **second page** (§8).
- **Second page — "Shortage Details" — BUILT.** *(This bullet previously read "NOT yet built". That was already wrong.)* It exists in the PBIP as its own page, driven by `Shortage_Detail.m` (Cognos query `Summary Shortage` / `List5`): a full CIN2 **and** CINC on-hand breakdown for the short materials — one row per lot/location, columns `RM | Short Qty | RM in CIN2/CINC | Branch Plant | Status | Lot Number | Location | Qty On Hand`, grouped by material with a per-branch total. **The PBIX is what lacks this page**, because it predates the PBIP edits. See §8 and the Status block.
- IBPRP4 raw-material whitelist is hard-coded (`'RRC','REC','RCB','TOL','PKG','RBW'`) per Cognos. Confirm with planners whether this list should be maintained or derived.
- **Report 01 has four `use="prohibited"` (disabled) filters.** Counted directly in `Report XML.md`:

  | Query | Prohibited filter |
  |---|---|
  | `IOH CIN2` | `[2nd Item Number]='POLYMINP'` |
  | `IOH All` | `[2nd Item Number]='POLYMINP'` |
  | `IOH All` | `[Status] in (' ', '-')` |
  | `RM Shortage CINC` | `[OPEN RM]>[Quantity On Hand]` |

  All four are **legacy/manual exclusions, currently inactive**. Our `.m` files correctly skip all four. The `IOH All` status filter is the consequential one: because it is disabled, **page 2 includes all lot statuses**, while page 1's `IOH CINC`/`IOH CIN2` filter to `' '`/`'-'`. `Shortage_Detail.m` honours this explicitly. Do not "harmonise" the two pages. Noted in case any of the four is ever re-enabled.

---

## 8. Page 2 — "Shortage Details"  *(second report page — BUILT 2026-07-09)*

The Cognos report has a second page. It lists, for every short material, all on-hand inventory at **CIN2 and CINC** by lot/location — the "where do I pull it from" companion to page 1.

**Query:** `Shortage_Detail.m` (Cognos `Summary Shortage` / `List5`). Run `00_verify_tables_page2.sql` first (needs F41021 `LILOCN`/`LILOTN`).

**Page text (verbatim, for fidelity):**
- (blue, bold) `OBJECTIVE: Identify the materials that need to be transferred to CINC from CIN2 based on Work Order parts requested date needed by the (2nd) business day forward`
- (red, bold) `Full inventory on hand list of materials needed at CINC`

**Visual — Matrix** (`pivotTable`, `steppedLayout: false`), columns in Cognos order. *Built as specified below.*

| Column | Field | Notes |
|---|---|---|
| RM | `RM` | group / row header (red bold) |
| Short Qty | `Short Qty` | red bold header; whole number, 0 dec; **`summarizeBy: none`** — it is a grouping key, not a measure (see the Status block) |
| Item | `Item` | the on-hand item (blue) |
| Branch Plant | `Branch Plant` | blue; **sort descending** (so CINC then CIN2) — per-branch subtotal of Qty On Hand |
| Status | `Status` | blue |
| Lot Number | `Lot Number` | blue; sort ascending |
| Location | `Location` | blue |
| Qty On Hand | `Qty On Hand` | blue header; whole number, 0 dec; **branch subtotal on**. The only field in **Values**. |

- Grouping (Cognos `listGroups`): RM → Short Qty → Item → Branch Plant (with a **Total(Qty On Hand)** footer per branch) → Status. All five are matrix **Rows** levels, with `Lot Number` and `Location` beneath.
- **Applied 2026-07-09.** Row subtotals on, per-row-level, with `levelSubtotalEnabled` **only** on `Branch Plant`. Grand total **off** — Cognos has no `<overallFooter>`.
- Sorts applied: `RM` asc → `Branch Plant` desc → `Lot Number` asc. The descending branch sort is deliberate: `'CINC' > 'CIN2'`, so descending puts **CINC before CIN2**, which is the order planners expect. A default ascending sort silently reverses it.
- Header colors match page 1: red `#e40011`, blue `#001eff`; borders `1pt solid black`.

### Where the subtotal actually comes from — a query-layer audit will never find it

The per-branch subtotal Cognos renders is a bare **`<listFooter>` nested inside `listGroup[Branch Plant]`**. Its aggregate, `Total(Quantity On Hand)`, is **not a data item in any `<query>`**. It is a *layout-level extended aggregate*, enabled by `RS_CreateExtendedDataItems="true"` on the report root. If you go looking for it in the query definitions — which is the natural first move — you will conclude the report has no subtotal. It does. Cognos `Total()` = `SUM`.

### Accepted, disclosed geometric difference

Cognos's footer **merges the first 4 cells** (`colSpan=4`) for the `"<Branch Plant> - Total"` label and puts the number in the next cell. A Power BI matrix subtotal puts the label in the **row-header area** and the value under the `Qty On Hand` column. **The value lands in the semantically right place; the exact cell geometry cannot be reproduced** — Power BI has no cell merge. We accepted the Power BI rendering rather than mimicking the `colSpan`. This is a known, intentional difference, not a defect. Recorded so it is disclosed rather than discovered.

**Model:** `Shortage_Detail` is a 3rd table. No relationship required (it's self-contained and already filtered to short materials). It sits on a second report page named "Shortage Details".

**Parity note:** page 2's `Short Qty` uses the same shortage subquery as page 1, so the two pages agree on the short set and quantities.
