# Report 02 — Shell and Kemper - 530 Report

**Cognos source:** Public Folders > Michelman Reporting > Production and Shipping > Contract Manufacturing Orders > *Dashboard - CM Overview LIVE* (embedded panel).
**Report name (Cognos):** `Shell and Kemper - 530 Report`
**Page rendered in the dashboard panel:** `Main Report - 530` (list `List2`, query `Main w Routing 530`).

> **OBJECTIVE:** Show every open Contract-Manufacturing sales-order line sitting at **Next Status 530** (company `00010`), with its owner/planner, so planners can work their queue. A red **"Number of Errors"** counter flags lines whose planner does not map to a known owner.
> **SCOPE:** Company `00010`, Next Status **= 530**, item present (2nd item not null). One row per order line × bulk item × planner × work center.

This is **page 1 of the shared "CM Overview LIVE" PBIP** (see `_PROGRESS.md`). Build it as the first page of that PBIP.

---

## Status — 2026-07-09

> **This document is the original build spec, updated in place.** The live open-items list is `PARITY_TODO.md` in this folder — read that first.

**Implemented in the PBIP** (`02 - Shell and Kemper 530 Report\CM Overview LIVE (shared PBIP)\PBIP\`), which now has **7 pages**:

- **`Main Report - All` — BUILT.** §1 and §9 previously recorded it as *not built / out of scope*; that was a deliberate scope call at the time and it has since been superseded. It is bound to a new table `Shell_Kemper_All`, implementing Cognos's `Main w Routing` query: it **keeps** `SDNXTR IN ('525','530','535','540','545','550')` and **drops** `mb.Next_Status = '530'`. 20 columns (no `Planner` column), **40** dynamic conditional-format markers (20 `backColor` + 20 `fontColor`), its own `Select the Planner` slicer and its own error card.
- **`Planner Responsibilities` — BUILT**, as a literal Power Query `#table`. Verified: that Cognos page has **no `refQuery` and zero `<query>` elements** — it is a static `<table>` of `<textItem>` static values. There is no database round-trip, so it cannot drift.
- **The `Requested Cell Color` DAX bug is fixed** — see below. This was the one live, user-visible defect in report 02.
- A **`Last Refreshed`** table + `Last Refreshed Label` measure + a `card` visual now sit on all 7 pages. See "Last Refreshed card" below.

**PBIP changes do not reach the PBIX.** `FINAL - for handover\Dashboard - CM Overview LIVE.pbix` was last written 2026-07-08; the PBIP edits landed 2026-07-09. **Someone must open `CM Overview LIVE.pbip` in Power BI Desktop, re-save, and republish.** Until then the live report still has only five pages and still yellows the null-`Requested` rows described below.

### Fixed: `Requested Cell Color` painted yellow on NULL Requested dates

`Shell_Kemper_530.m` derives `Requested` from `CASE WHEN so.SDDRQJ > 0 THEN … END`, which is **NULL** when the JDE Julian date is `0`, and the query's `WHERE` never filters those rows out — so null `Requested` dates reach the visual. **In DAX, `BLANK()` coerces to `1899-12-30`, so `BLANK() < <any date>` evaluates TRUE** and every one of those rows painted its `Requested` cell yellow. **Cognos evaluates `NULL < [Promised Ship Date]` as *unknown* and applies no style.**

Now guarded with `NOT ISBLANK(...) && NOT ISBLANK(...)` on both dates, with the ERROR/red branch still tested first so red-over-yellow precedence is unchanged (§5b).

**State this as what it is: a general DAX/SQL three-valued-logic mismatch.** SQL's `NULL` comparisons are *unknown* and suppress the predicate; DAX's `BLANK()` silently coerces to zero or to `1899-12-30` and the comparison returns TRUE. Any Cognos condition of the form `[nullable] < [x]` or `[nullable] <= [x]` ported straight to DAX will fire on the nulls. Report 03 carries the same pattern (guarded there as defence-in-depth, though it is latent, not live).

### Last Refreshed card

`Last Refreshed.m` computes one row via `DateTimeZone.FixedUtcNow()` plus an explicit US-Eastern DST rule (second Sunday in March → first Sunday in November), yielding an `EDT`/`EST` label. `DateTime.LocalNow()` is **deliberately avoided**: it returns UTC in the Power BI Service but machine-local time on Desktop, so the two would disagree. The stamp is refresh-**start**, not finish — Power Query's evaluation order across queries is not deterministic — which is why the label reads "Last refreshed", not "finished". Format `MMM d, yyyy h:mm:ss AM/PM` matches the Cognos page-footer stamp, which is month-first in every report regardless of what the table's own date columns use. This covers the Cognos footer's run date and run time; the **page number** has no Power BI analogue and is not reproduced.

---

## 0. On-page plaintext (verbatim, for fidelity)

- **Page header title** (blue, bold, large): `Shell and Kemper - 530 Report`
- **Prompt label** (bold): `Select the Planner `  → dropdown (see slicer below)
- **Counter label** (bold, black): `    Number of Errors = ` immediately followed by the count value `N` (the value cell turns **red with white text** when `N > 0`).
- **Empty-state text:** `No Data Available`

---

## 1. Queries (Power Query)

| Query | File | Feeds |
|---|---|---|
| `Shell_Kemper_530` | `Shell_Kemper_530.m` | The visible **530 detail list** (main deliverable) |
| `Number_of_Errors` | `Number_of_Errors.m` | The **"Number of Errors = N"** scalar *(optional — a DAX measure is recommended instead, see §4)* |

Both connect to `Sql.Database("ODSPROD","ODS")` and run native T-SQL against `PRODDTA` (folding on), following the repo's canonical JDE/ODS query `edw_model/JDE_Orders/Orders.m` and report 01: same `Value.NativeQuery(Source, "<T-SQL>", null, [EnableFolding=true])` shape, inline Julian `DATEADD/DATEFROMPARTS` decode, `LTRIM(RTRIM(...))` trims, `SDLNID/1000.0` line scaling, and a trailing `Table.TransformColumnTypes`. Paste each into **Power BI Desktop → Get Data → Blank Query → Advanced Editor**. Set the server name to match your SSMS connection if it differs from `ODSPROD`. (ODS mirrors JDE, so table reachability is a given — no pre-flight check needed. Note the schema convention: business tables live in `PRODDTA`; the UDC master `F0005` lives in `PRODCTL` — not used by this query.)

### The 4 Cognos generated-SQL blocks → what we built

| Cognos block | What it is | Built as |
|---|---|---|
| Block 1 | error **COUNT**, `Next_Status='530'` | `Number_of_Errors.m` (or DAX measure) |
| **Block 2** | **DETAIL list**, `Next_Status='530'` | **`Shell_Kemper_530.m`** ← the panel |
| Block 3 | error COUNT, no `='530'` filter (all 525–550) | **BUILT 2026-07-09** — the error card on page `Main Report - All` |
| Block 4 | DETAIL list, no `='530'` filter | **BUILT 2026-07-09** — `Shell_Kemper_All` on page `Main Report - All` |

> Blocks 3 & 4 were originally scoped out ("*not built — feeds Cognos page `Main Report - All`, which is not in the dashboard panel*"). That call was reversed. `Shell_Kemper_All.m` is `Shell_Kemper_530.m` with the `AND mb.Next_Status = '530'` predicate removed; the `WHERE so.SDNXTR IN ('525','530','535','540','545','550')` filter is retained, exactly reproducing Cognos's `Main w Routing` query.

Cognos also has a 3rd page `Planner Responsibilities` (a **static** "Planner Segregation of Duties" reference matrix — no query). **BUILT 2026-07-09** as a literal Power Query `#table` (`Planner_Responsibilities.tmdl`), rendered as a `tableEx`. That Cognos page has **no `refQuery`** at all and zero `<query>` elements — just a static `<table>` of `<textItem>` values — so a literal table is the faithful rebuild, and it makes no database round-trip and cannot drift.

---

## 2. Cognos → PBI column mapping (visible list, left → right)

Header labels are the Cognos `label=` attributes from the list; query columns are the `Shell_Kemper_530.m` output names (already the Cognos labels).

| # | Cognos label | Query column | JDE source |
|---|---|---|---|
| 1 | Promised Ship | `Promised Ship` | `F4211.SDPDDJ` (Julian → date) |
| 2 | Requested | `Requested` | `F4211.SDDRQJ` (Julian → date) |
| 3 | Plant | `Plant` | `F4211.SDMCU` (trimmed) |
| 4 | Ship To | `Ship To` | `F0101.ABALPH` via `SDSHAN` |
| 5 | CS | `CS` | `F0101.ABAC06` (Customer Segmentation) via `SDSHAN` |
| 6 | Order# | `Order#` | `F4211.SDDOCO` |
| 7 | Line# | `Line#` | `F4211.SDLNID / 1000` |
| 8 | Bulk | `Bulk` | `F554101.IMBULK` via item master `IMITM` |
| 9 | Item | `Item` | `F4211.SDLITM` (2nd item, trimmed) |
| 10 | Description | `Description` | decode: `NEWITEMFG`/`NEWITEMPKG` → `SDDSC1`, else `' '` |
| 11 | Owner | `Owner` | planner-number → name decode (`F4102.IBANPL`), else `ERROR` |
| 12 | Planner | `Planner` | raw `F4102.IBANPL` |
| 13 | Status | `Status` | `F4211.SDNXTR` (= `530`) |
| 14 | Qty | `Primary Qty` | `AVG` of `F4211.SDPQOR/10000` (see quirk §6) |
| 15 | UOM | `Primary UOM` | `F4211.SDUOM1` |
| 16 | Qty | `Secondary Qty` | `AVG` of `F4211.SDSQOR/10000` (see quirk §6) |
| 17 | UOM | `Secondary UOM` | `F4211.SDUOM2` |
| 18 | Order Date | `Order Date` | `F4211.SDTRDJ` (Julian → date) |
| 19 | CSR Name | `CSR Name` | `F0101.ABALPH` via `F42140` (`CMRTYPE='CSR'`, `CMSLSM→ABAN8`) |
| 20 | Work Ctr | `Work Ctr` | `Routing13.Work_Center` (`F3312.CWMCU`) |
| 21 | MPF | `MPF` | `F4211.SDPRP4` |

> Two columns are both labelled **Qty** and two both **UOM** in Cognos (primary then secondary). In the PBI table, keep the field order above; optionally rename the visible headers to `Primary Qty / Primary UOM / Secondary Qty / Secondary UOM` for clarity, or leave as `Qty / UOM / Qty / UOM` to match Cognos exactly.

The planner → owner decode (identical in the detail and the count):

| Planner # | Owner | | Planner # | Owner |
|---|---|---|---|---|
| 324363 | Eric | | 316775 | Lance |
| 20444 | Eric | | 334927 | Tammy |
| 20445 | Lance | | 290808 | David Kramer |
| 291740 | Mark Tilley | | 335951 | Lance |
| 328907 | Lance | | 300021 | Tammy |
| 333530 | Lance | | 324287 | Brent |
| *(any other)* | **ERROR** | | | |

---

## 3. Visuals

### Page header (Text box)
- Title **"Shell and Kemper - 530 Report"** — **blue**, bold (Cognos page-header style is `color:blue`). *(Note: unlike report 01's red title, this panel's title is blue.)*

### Visual A — the 530 detail (Table)
- Visual type: **Table**.
- Fields in the order of the §2 table (Promised Ship … MPF).
- **Number format:** `Primary Qty` and `Secondary Qty` → whole number, **0 decimals**, right-aligned (Cognos `numberFormat decimalSize="0"`).
- **Date format:** `Promised Ship`, `Requested`, `Order Date` → medium date (Cognos `dateStyle="medium"`, e.g. `Jul 1, 2026`).
- `Order#`, `Planner` → whole number, **no thousands separator** (IDs).
- Header styling to match Cognos: column titles **bold, red text, 1pt solid black border**; body cells **1pt solid black border** (thin grid). Red header hex `#FF0000`.
- **Sort:** `Bulk` ▲, then `Promised Ship` ▲, then `Order#` ▲, then `Line#` ▲, then `Owner` ▲ (all ascending). *The `.m` intentionally omits `ORDER BY` — an ORDER BY inside the folded subquery is illegal in SQL Server — so set this sort in the visual.* Cognos sorts NULLs last; PBI table sorting puts blanks last on ascending, which matches.

### Visual B — "Number of Errors" counter
Two options — **the DAX measure (§4) is recommended.**
- Render as a **Card** (or a text box + card) reading `Number of Errors = N`.
- Apply conditional formatting so the value goes **red background / white text when N > 0** (Cognos `FLAG ERROR in HEADER 530`). See §5.

### Slicer — "Select the Planner"
- Cognos prompt `?Owner1?` is an **optional single-select** dropdown filtering `[NEW OWNER]=?Owner1?`.
- Build a **Slicer** on `Shell_Kemper_530[Owner]`, style **Dropdown**, **single-select**.
- Options present in Cognos: `Brent, Eric, Lance, Tammy, Mark Tilley, David Kramer, ERROR` (these are exactly the distinct `Owner` values, so the slicer populates itself).
- Default = **no selection** (shows all owners). The Cognos label placeholder shown when nothing is picked is the parameter name `Owner1`; there is no pre-selected planner.

> **The `Owner` slicer binding is correct — verified, do not "fix".** Cognos carries **two** filters for this prompt: an active `use="optional"` `[NEW OWNER]=?Owner1?`, and a **`use="prohibited"` (disabled) legacy** `decode([Planner],...)=?Owner1?`. Seeing only the prohibited one invites the conclusion that the prompt is inert and our slicer over-filters. It is not. **A `prohibited` filter frequently sits beside an active `optional` twin — never judge one in isolation.** (Report 06 has the same shape; see its `PARITY_TODO.md` §5.1.) Note also that the prompt filters `NEW OWNER`, the *decoded owner name*, not the numeric `Planner` column, despite the "Select the Planner" label. The rebuild binds `Owner`. Correct.

---

## 4. "Number of Errors" — recommended DAX measure

Rather than load `Number_of_Errors.m`, add a measure on the detail table so the counter ties 1:1 to the red rows:

```DAX
Number of Errors =
CALCULATE (
    COUNTROWS ( 'Shell_Kemper_530' ),
    'Shell_Kemper_530'[Owner] = "ERROR"
)
```

- This counts the visible 530 rows owned by `ERROR`. With the `DISTINCT`-Routing13 rewrite, it equals the value `Number_of_Errors.m` returns and equals Cognos's `total([FLAG ERROR])`.
- It also respects the "Select the Planner" slicer (if a planner is chosen, the counter reflects that filter) — matching Cognos, where the counter query and the list share the `Owner1` prompt.
- If you prefer a fully static scalar independent of the page (or a standalone card that ignores slicers), load `Number_of_Errors.m` instead and show its single `Number of Errors` value.

### ⚠ The counter reads **16**; Cognos's card reads **1,299**. STILL AN OPEN DECISION FOR THE USER.

`VALIDATE_error_count.sql` (this folder) settles the mechanism. Cognos's **card** value is computed from the *un-collapsed* `Routing13` join with **no outer `GROUP BY`**, so every ERROR order line is counted once per matching routing row (work-centre × period × capacity). That fan-out is what produces `1,299`. Cognos's **list**, on the very same page, shows the true figure: **16** ERROR rows out of 57. **The card and the list disagree inside Cognos.** The bullet above is correct about the *detail* query, whose `GROUP BY` collapses `Routing13` to a distinct work-centre per line — the two statements were never in conflict; they describe different objects.

Our measure counts the visible ERROR rows, so it ties to Cognos's **list** (16), not to Cognos's **card** (1,299).

- **Recommendation: 16.** `1,299` is a fan-out artefact of Cognos's own un-grouped COUNT query.
- **This is a deliberate correction of a Cognos defect, not a parity miss** — and therefore a decision that belongs to the user, not to the rebuild. It has not been ratified.
- **Disclose it before anyone compares the two reports side by side.** Seeing `16` where Cognos says `1,299` is the single most likely false alarm in report 02.

---

## 5. Visual fidelity — conditional formatting (exact rules from the Report XML)

> **Conditional formatting was never missing from this report.** All rules below are implemented and live in `report.json`: **42** dynamic markers across the 21 columns of the `530 Report` page, plus **40** on `Main Report - All`. If any note anywhere implies CF is outstanding here, it is wrong.
>
> **Why a grep finds nothing.** This repo uses Power BI's *format-by-field-value* form — `objects.values[].properties.backColor.solid.color.expr.Measure` pointing at a DAX measure that returns a hex string — **not** rules-based `FillRule`. And `config` in `report.json` is a **JSON-encoded string**, so a search for a quoted `"backColor"` returns zero hits even though the markers are there. You must parse `config` before searching it. That mistake was made once and corrected; do not repeat it.

Three named conditional styles apply to the `530 Report` page; the Cognos XML defines **five** in total (`<namedConditionalStyles>`), the other two (`FLAG ERROR ALL`, `FLAG ERROR in HEADER`) belonging to `Main Report - All`. All five are referenced; none are dead. Reproduce all three below.

### (a) Red row highlight — `Flag ERROR`
- **Rule:** `[NEW OWNER] = 'ERROR'` (i.e. `Shell_Kemper_530[Owner] = "ERROR"`).
- **Style:** `background-color:red; color:white` → **red fill `#FF0000`, white text `#FFFFFF`**.
- **Applied to:** **every** body cell of the row (all 21 columns carry this conditional style), so the whole row turns red.
- **PBI:** add a background-color rule (and a font-color rule) on every column, driven by a measure:
  ```DAX
  Is Error Row = IF ( SELECTEDVALUE ( 'Shell_Kemper_530'[Owner] ) = "ERROR", 1, 0 )
  ```
  Table → each column → Cell elements → **Background color** = `#FF0000` when `Is Error Row = 1`; **Font color** = `#FFFFFF` when `Is Error Row = 1`. (Format-by field-value works too since `Owner` is on the row.)

### (b) Yellow cell highlight on the **Requested** column — `Flag 530 - Request Date Sooner`
- **Rule (confirmed exact):** `[Requested Date] < [Promised Ship Date]`.
- **Style:** `background-color:yellow` → **yellow fill `#FFFF00`** (text unchanged).
- **Applied to:** the **Requested** column body cell **only** (not the whole row). *Note the Requested column also carries the `Flag ERROR` red rule; red (error) takes precedence over yellow because both set the background — in Cognos the ERROR style is listed after the yellow style. In PBI, gate the yellow so it does not fire on error rows (see below).*
- **PBI:** background-color rule on the `Requested` column only:
  ```DAX
  Requested Flag =
  VAR req = SELECTEDVALUE ( 'Shell_Kemper_530'[Requested] )
  VAR prom = SELECTEDVALUE ( 'Shell_Kemper_530'[Promised Ship] )
  RETURN
      IF ( 'Shell_Kemper_530'[Owner]... )  -- see note
  ```
  Simplest: color `Requested` **yellow `#FFFF00`** when `Requested < Promised Ship` **AND** `Owner <> "ERROR"` (so red wins on error rows), e.g.:
  ```DAX
  Requested Cell Color =
  IF (
      SELECTEDVALUE ( 'Shell_Kemper_530'[Owner] ) = "ERROR", "#FF0000",
      IF (
          SELECTEDVALUE ( 'Shell_Kemper_530'[Requested] )
              < SELECTEDVALUE ( 'Shell_Kemper_530'[Promised Ship] ),
          "#FFFF00", BLANK ()
      )
  )
  ```
  Use this as the **Background color → format by field value** for the `Requested` column.

  > **⚠ The form above shipped and was WRONG.** It yellows every row whose `Requested` date is NULL, because DAX coerces `BLANK()` to `1899-12-30`, making `BLANK() < <date>` **TRUE**. Cognos evaluates `NULL < [Promised Ship Date]` as *unknown* and applies no style. **Fixed 2026-07-09** — as shipped in `Shell_Kemper_530.tmdl`:
  > ```DAX
  > Requested Cell Color =
  > IF ( SELECTEDVALUE('Shell_Kemper_530'[Owner]) = "ERROR", "#FF0000",
  > IF ( NOT ISBLANK(SELECTEDVALUE('Shell_Kemper_530'[Requested]))
  >   && NOT ISBLANK(SELECTEDVALUE('Shell_Kemper_530'[Promised Ship]))
  >   && SELECTEDVALUE('Shell_Kemper_530'[Requested]) < SELECTEDVALUE('Shell_Kemper_530'[Promised Ship]), "#FFFF00" ) )
  > ```
  > Red-over-yellow precedence is preserved (ERROR is still tested first). This is a **general DAX/SQL semantic mismatch**, not a typo — see the Status block.

### (c) Red "Number of Errors" counter — `FLAG ERROR in HEADER 530`
- **Rule:** `[COUNT ERROR] > 0` (i.e. `[Number of Errors] > 0`).
- **Style:** `background-color:red; color:white`.
- **PBI:** conditional format the Card's value: background `#FF0000`, font `#FFFFFF` when `[Number of Errors] > 0`.

**Color reference:** red `#FF0000`, white `#FFFFFF`, yellow `#FFFF00`. Grid border `1pt solid black`. Title/labels blue `#0000FF`. *(These are the literal CSS values in this report — note they differ from report 01's `#e40011` / `#001eff`.)*

---

## 6. Known Cognos quirks (PARITY MODE — reproduced on purpose)

### Quirk 1 — quantities use `AVG`, not `SUM`
The final Cognos step computes `average([Primary Quantity Ordered])` and `average([Secondary Quantity Ordered])` (see the `Main w Routing 530` selection). `Shell_Kemper_530.m` reproduces this with `AVG(...)`.

- **Effect here:** the final `GROUP BY` is at the order-line grain (each group is a single line × bulk × planner × work center), and the `MAIN8`/`Main_w_Bulk12` steps already `SUM`med the quantities to that grain. So the values being averaged within a group are identical repeats, and `AVG` returns that same value — it ties to the live report. The quirk only bites if a future change makes a final group span multiple distinct line quantities.
- **Corrected form (when planners confirm):** replace the two `AVG(...)` with `SUM(...)` in `Shell_Kemper_530.m`. Everything else (joins, filters, grouping) stays the same.

### Quirk 2 — `FULL OUTER JOIN` to Routing that behaves like a left join
Cognos `FULL OUTER JOIN`s `Main w Bulk` to `Routing` on `Bulk Item = 2nd Item Number`, then filters `WHERE [2nd Item Number] <> null`, which discards the routing-only side. We keep the `FULL OUTER JOIN` (valid in SQL Server) for faithfulness; the net effect is that order lines with no matching work center still appear (`Work Ctr` blank), and work centers with no order line are dropped.

### Note — Routing13 reduced to `DISTINCT`
Cognos's `Routing13` is a heavily grouped subquery, but the only column consumed downstream is `Work_Center`, and the final `GROUP BY` collapses on `Work_Center` (not on the routing dates Cognos grouped by). `Shell_Kemper_530.m` therefore builds Routing13 as `SELECT DISTINCT (Item_Branch, 2nd item, Work_Center)` — result-equivalent after the collapse and fold-friendly. If you later need the routing dates/quantities, expand it back to the full grouped form.

---

## 7. Refresh / "as of" behavior
`Routing13`'s period-end-date window uses `CAST(GETDATE() AS date)` for Oracle `sysdate` (`> today + 31 days`), so the report is **"as of the last refresh."** Schedule a daily refresh. The only prompt is the optional **Owner** slicer; there are no date parameters.

---

## 8. Validation checklist
- [ ] Refresh `Shell_Kemper_530` — no errors; rows come back at `Status = 530` only.
- [ ] Open the live Cognos `Shell and Kemper - 530 Report` (530 panel) the same day and compare **row count** and **`Number of Errors = N`** to the PBI page (parity mode should match).
- [ ] Spot-check that **ERROR** rows render **whole-row red / white text**, and that a row with `Requested < Promised Ship` shows the **Requested** cell **yellow** (except on error rows, where red wins).
- [ ] Confirm the **Owner** slicer filters the list (and, if using the DAX measure, the counter) to the chosen planner.
- [ ] Confirm sort = Bulk ▲, Promised Ship ▲, Order# ▲, Line# ▲, Owner ▲.
- [ ] Confirm `Primary/Secondary Qty` show 0 decimals and `Order#`/`Planner` show no thousands separator.

---

## 9. Open items / assumptions

> The live open-items list is `PARITY_TODO.md`. What remains there is LOW cosmetics (`Line#` `formatString`, `No Data Available` empty state, the dead `Is Error Row` measure), the `Number of Errors` disclosure, and the PBIX regeneration.

- ~~**Blocks 3 & 4 (the un-filtered "All" variant) are not built.**~~ **BUILT 2026-07-09** as page `Main Report - All` on table `Shell_Kemper_All` — 20 columns, 40 conditional-format markers, its own planner slicer and error card. See the Status block and §1.
- ~~**`Planner Responsibilities`** (page 3) … Not built.~~ **BUILT 2026-07-09** as a literal `#table`. The Cognos page has **no `refQuery`** and zero `<query>` elements — it is a static `<table>` of `<textItem>` values, so there is no database round-trip and it cannot drift.
- **`Number of Errors` = 16, not 1,299 — open decision.** See §4. Recommendation stands at 16; needs the user's ratification and must be disclosed at handover.
- **`Line#` uses `SDLNID / 1000.0`** (float division, matching Oracle) so sub-lines like `1.5` survive. If planners want whole line numbers only, switch to integer `/1000`.
- **Planner decode compares numeric `IBANPL` to string literals** (`'324363'` etc.); SQL Server implicitly converts to numeric (matching Oracle `decode`). No leading-zero planners appear in the list, so this is safe.
- **Owner slicer default:** Cognos leaves it unselected (`use="optional"`); assumed the same here (show all). Confirm with the planners whether a specific planner should be the landing default.
