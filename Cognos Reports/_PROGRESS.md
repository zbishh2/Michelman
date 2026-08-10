# Cognos → Power BI rebuild — program status

18 numbered reports. This file is current state; each report folder's `BUILD.md` carries the build
spec and its validation log.

Folder contract: `BUILD.md`, `PARITY_TODO.md` (gap list, wins over `BUILD.md` on conflict),
`COLLECTION_NOTES.md`, `Intake/`, `<Name>.m` + `<Name>.commented.m`, `00_verify_tables.sql`,
`PBIP/`, `PROBE/`.

PBIP is both source of truth and publish artifact — Zack publishes PBIPs directly. The PBIX files
in `FINAL - for handover/` are legacy snapshots.

---

## Standing decisions

- **Source:** `Sql.Database("ODSPROD","ODS")` + `Value.NativeQuery(…, [EnableFolding=true])`,
  schema `PRODDTA`. UDC master `F0005` lives in `PRODCTL` — read by four queries and named in no
  `.m` `SOURCE:` header, so `PRODDTA` grants alone are insufficient; it belongs on the handover's
  required-grants list.
- **Parity now.** Reproduce Cognos exactly so numbers tie 1:1; document the corrected formula in
  `BUILD.md`. The one deliberate exception is report 02's error count.
- **New reports route SSAS → EDW → ODS**, preferring an SSAS live connection where a perspective
  covers it. Delivered reports stay on EDW/ODS — no retrofits.
- **Date-format parity is exact, per report.** Cognos rendering is driven by `displayOrder` on
  `<dateFormat>`, not `dateStyle`: `medium` → `MMM d, yyyy`; `medium` + `displayOrder="DMY"` →
  `d MMM, yyyy`; `long` + `DMY` + `showWeekday` → `dddd, d MMMM, yyyy`. Day-first: 04, 07–10.
  Month-first: 02, 03, 06. Weekday+long: 01. No date columns: 05.
- **`Last Refreshed` card on every page.** Single-row `#table`, Eastern time from
  `DateTimeZone.FixedUtcNow()` with explicit US DST handling — `DateTime.LocalNow()` returns UTC in
  the Service but machine-local on Desktop. It stamps refresh *start*; Power Query does not
  guarantee query evaluation order.
- **Conditional formatting is present, not missing.** Reports 02 and 03 are the only Cognos
  originals defining any, and both implement it via DAX colour measures bound to `backColor`. This
  repo uses format-by-field-value, not rules-based `FillRule`, and `config` is a JSON-encoded
  string — a quoted `"backColor"` grep cannot match. Do not record CF as a gap.
- **`summarizeBy: none` everywhere**, identifiers included, so matrix conversions carry no silent
  aggregation hazard.
- **`No Data Available` empty states are unreproduced.** Cognos's `<noDataHandler>` is per-list, not
  per-page; Power BI has no native equivalent. Conscious omission.
- `_tools/new-report-pbip.ps1` stamps a clean PBIP. Builders sharing one PBIP run **serially** —
  they all edit `model.tmdl` and `report.json`, and concurrent edits clobber each other.

## Report-out workbook standard

Template = `08 - SK Forecast.xlsx`. Sheets: **Notes**, then aligned `[Cognos | Compare | PBI]`
blocks, then an **RS** tab. The middle Compare block is per-column `EXACT()` computed live off the
two data blocks — never hardcoded TRUE/FALSE. Deliverable-only; no process narrative.

---

## Reports

**01 — RM Staging at Shell Road 2026 (ODS)** · ODS/PRODDTA · done. Two pages; both grouped Cognos
lists are `pivotTable` matrices (`steppedLayout:false`), per-`Branch Plant` subtotal on, grand
total off. `WorkOrder_Detail[WO Number]` and `Shortage_Detail[Short Qty]` are Cognos grouping keys
and must stay `summarizeBy: none`. *Open:* the missing RM Staging pages are blocked on a Cognos
re-export.

**02–06 — CM Overview LIVE** · ODS/PRODDTA · done. Five reports are seven pages of **one shared
PBIP** at `02 - Shell and Kemper 530 Report\CM Overview LIVE (shared PBIP)`; folders 03–06 hold
intake only, no PBIP of their own.

- **02 Shell and Kemper 530** — pages `530 Report`, `Main Report - All`, `Planner
  Responsibilities` (a literal `#table`; the Cognos page has no `<query>`). `Number of Errors`
  reads **16**, ties to Cognos's own red-row list; Cognos's card reads 1,299, a fan-out artifact of
  a COUNT query that omits the detail `GROUP BY`. Rohit is told the number before he compares.
- **03 CM Sales Orders < 560** — page `SO under 560`. Four cross-filtered flat tables + an `Item`
  bridge + a `[Show Item]=1` gate. The four-table shape is a **decision, not a gap**: a matrix
  would destroy all 9 CF rules (Power BI binds a measure-driven `backColor` only to fields in
  Values), and SO lines / lots / work orders are sibling grains that cross-join under a hierarchy.
  Subtotals sit in a detached fifth table. `Inventory Lot Count` = `DISTINCTCOUNT([AVAIL])`, which
  is Cognos's `Count Distinct(AVAILABLE)` — it counts distinct *quantities*; the author likely meant
  lots. This is the Brent planner page.
- **04 CM Open Sales Orders Live** — 16 cols + Region slicer + optional Promised-Ship range slicer.
  TM Name via F0006→F42140→F0101 with an `'Unassigned'` fallback. Double-SUM fan-out kept.
- **05 CM Inventory on Hand** — 9 cols, LB↔KG at 0.453593. `REGION` is a displayed column here,
  unlike 04/06 — do not hide it.
- **06 CM PO Live** — 13 cols + Region slicer + optional Promised-Date range slicer. Its rolling
  90-day floor freezes at refresh time (Cognos re-evaluates `sysdate-90` per run), so the shared
  PBIP wants a **daily Service refresh** — still unscheduled. The `use="prohibited"` region filter
  is a disabled duplicate; the slicer is correct, do not "fix" it.

**07 — Ivan SK 2023 / 09 — Ivan FC 2023** · ODS/PRODDTA (JDE Live Data pkg) · done. Standalone
5-page PBIPs: Inventory, Work Order, Sales Orders, Inventory HP, Safety Stock HP; five independent
tables, no relationships. 07 is a structural clone of 09 differing only in filter literals (SK item
whitelist + Americas branches CINC/CIN2/CIN4). 09's Sales Orders and Item Information branch
filters agree at 6 plants — **do not copy 07's 12-plant list into it**. Faithful oddities: 07's
`Safety Stock HP` shows `REGION` twice, and its `Scheduled Pick Date` ≡ `Promised Ship Date`
because Cognos aliases `SDPDDJ` twice. `Sales Order Summary` is a 5-CTE chain rewritten as nested
derived tables; `Work Orders` keeps the window-function fan-out (`AVG(WAUORG) OVER` =
`[Quantity Requested]`).

**08 — Ivan SK 2023 Forecast / 10 — Ivan FC 2023 Forecast** · ODS/PRODDTA · done. The Cognos
originals target the Data Warehouse pkg / `DW_LEGACY`, which we have no connection to, so both are
rebuilt on ODS. Two pages each. Sales History reads `F4211` ∪ `F42119` (both legs use `SD*` column
names on this instance; the JDE-standard `SH*` prefix does not exist here) and is validated.
*Open:* the **Forecast pages are unvalidatable** — the Cognos source itself returns zero rows —
and each `Forecast.m` carries 12 `-- TODO verify` markers that one ODSPROD session closes for both
twins; `MFFQT` and its `/10000` scaling carry every quantity, so if `MFFQT` is stored whole every
forecast quantity is 10,000× too small. `Revenue Business Unit` is a placeholder copy of `Branch
Plant` and needs a real source or removal (business decision). Page naming differs between the
twins (`Forecast (This Month)` on 10, `Forecast` on 08) — apply symmetrically or revert.

**11 — BOM WERCS Integrity Check** · ODS/PRODDTA · published, full-export validated. WERCS table is
`BILL_OF_MATERIAL_WERCS` (`F_PRODUCT`/`F_COMPONENT_ID`/`F_PERCENT`, exact-equality join, no unit
filter); JDE side is `F3002` + `F4101` + `F0006` with prefix **`IX*`** (not `IB*`, which is F4102)
and `/10000.0` scaling. **WERCS is a chemical rollup** keyed by CAS with raw materials decomposed,
so most JDE BOMs never match and blank WERCS cells are normal. Flat `tableEx`, 6 visible columns,
no CF.

**12 — Americas Open Purchase Orders** · ODS/PRODDTA · **open**. Three independent pages/tables:
`PO.m` (F4311), `Sales_Orders_Static.m` (F4211 ∪ F42119 + F0101/F4102/F554101),
`Sales_Ledger.m` (F42199 + F4211). Rebuilt for DAX ownership so Rohit can validate.
*Needs a jumpbox refresh + a fresh tight capture.* Column facts worth keeping: F42199 prefix is
`SL*`; Date Created is `SLUPMJ` (`SLADDJ` is actual ship date); F4311 has no `PDRCDJ`, so Receipt
Date is `MAX(F43121.PRRCDJ)` per line; `SDASN` is a price adjustment schedule, not a rep address
number — CSR is `F42140.CMRTYPE = 'CSR'`, TM is `CMRTYPE LIKE '%TM'`, and both names come from
`F0111.WWMLNM`. Page-1 dates are month-first, pages 2–3 day-first, verbatim per page.

**13 — Ivan LIVE Global Inventory Excel** · ODS/PRODDTA · done, round-2 validated on a ~5-minute
capture pair. Six pages / six tables. Inventory Summary is rendered twice by Cognos (full +
distinct subset) → two tables, do not merge. All filters are `sysdate`-relative, so exact page ties
are impossible by design. Residual, not a rebuild defect: 38 case-only text diffs where both sides
read the same JDE columns — an ODS change-capture gap on UPDATEs that affects every ODS-sourced
report and belongs with the ODS owner.

**14 — Ivan Global Inventory Excel, Select Date** · EDW · **sign-off only**. Validation is
complete. Date UX is a disconnected `Select Date` slicer with all date logic in measures. Source is
`dbo.FactInventorySnapshot_History` (the `_Filtered` view's pruned spine loses daily dates older
than ~2 months), with a CompanySKey=2 +1-day interval shift, FX via
`BIQL.DimCurrencyExchangeRatesUSDDaily`, carrier-borrow for `ItemCostSKey = -1`, and KG/LB
constants for KG/LB-primary rows. *After sign-off:* delete the frozen SQL tables, the `AsOfDate`
param, and the tie-out measures.

**15 — Open Orders Live – Data** · ODS/PRODDTA · done, accepted. One `Open Orders` page + a
multi-select CSR Name slicer (replacing five hard-coded per-CSR pages, whose names had gone stale).
Reproduced verbatim: CSR join is effectively inner, so CSR-less orders appear on no page, and
>1-CSR-per-customer fan-out double-counts Qty/Weight.

**16 — LTL Report Over 20k lbs** · ODS/PRODDTA · done, accepted. Cognos's grouped list becomes a
matrix. Its `- Total` footers are **averages** (a `Average()` re-wrap), kept as averages by
decision. 23 hard-coded carrier exclusions ported verbatim. The Cognos `<burst>` distribution
plumbing is not ported; the CSR slicer replaces it. Disclosed: Power BI cannot render Cognos's
`<value> - Total` subtotal wording.

**17 — Orders within Goal and Stretch** · ODS/PRODDTA · publish-ready. One table `Orders_GS` =
F4211 ∪ F42119 order master joined to earliest-525 / earliest-540 `#temp` extracts plus a
business-day metric; multi-statement batch, `EnableFolding=false`, MIN-window `GROUP BY` (no
`OUTER APPLY` / `ROW_NUMBER` — those hang). Ledger event = `SLUPMJ` + `SLTDAY`. Ported verbatim:
Ship-To columns show sold-to, and the "Order Date"=525 / "Confirmation Date"=540 label inversion.
This report ships lightly commented, unlike the rest.
*Open:* **reconfirm the `#csr` `CMCO` predicate with Rohit before applying it.** As stated
(`CMCO <> '00000'`) it blanks all CSR — every 'CSR' row is `CMCO = '00000'` — so the inverse is the
likely intent. The event-pick rule is a legacy-DW nightly-batch artifact and is not reproducible;
~3.7% of rows flag deltas, pending a Dave decision.

**18 — Singapore Warehouse Inv 2025** · EDW · done, turned in at 1:1 parity. Same
`dbo.FactInventorySnapshot_History` route as 14, with USD carrier-borrow for `ItemCostSKey = -1`
lots. The export is a dated snapshot history across Singapore / Americas / Aubange plus a
cross-region Lot Status sheet, despite the "Singapore" title.

---

## Cognos source defects, reproduced deliberately

Defects in the Cognos originals, not in the rebuild. Each looks like our bug at handover.

| Report | Defect | Our behaviour |
|---|---|---|
| 08, 10 | Expired date ceiling: the forecast filter's lower bound is computed from `sysdate` but the upper bound is a hard-coded literal, so the source returns zero rows. | `Forecast.m` uses a dynamic ceiling. The Forecast pages therefore cannot be reconciled against Cognos. |
| 02 | `Number of Errors` counts each ERROR line once per un-collapsed `Routing13` row. The card disagrees with its own list, inside Cognos. | We ship the correct 16. |
| 01 | `Total RM Needed` double-counts — planned demand joins on-hand per lot status, then SUMs. | Reproduced. Corrected SQL in `01\BUILD.md` §5. Do not fix without a planner decision. |
| 01 | `Qty On Hand CINC` uses `AVG` across lot statuses, not `SUM`. | Reproduced. Corrected SQL in `01\BUILD.md` §5. |
| 03 | `Count Distinct(AVAILABLE)` counts distinct quantities where sibling footers count orders; on-report NOTES say "530 or 535" while the XML flags 525, 530, 535; a style named `Lot Number Count > 0` tests `> 1`. | We ship Cognos's behaviour. Divergences are proposed separately, never smuggled in. |
| 08, 10 | The KG/LB fallback literals are physically inverted. Fires only when the stored `CONVERSION_FACTOR` is 0. | Our `CASE` is physically correct. |
| 07, 09 | Sales-history **lower** bounds are hard-coded literals — stale, not breaking. | Reproduced verbatim; flagged to the business as a maintenance landmine Cognos already had. |

---

## Handover items for Rohit

`Query Exports for Rohit\` holds the native T-SQL each report actually runs, one folder per report,
with a `_README.txt` and the original Cognos-generated Oracle SQL as `_Reference - ….sql`.
Outstanding: the RM Staging pages blocked on a Cognos re-export.

## Per-report intake checklist

1. Cognos screenshots — remembering list panels paginate at **20 rows**, so a screenshot is page 1.
2. Native SQL for every query object (Generated SQL popup).
3. Confirm source tables are reachable in the chosen connection.
4. Note prompts, parameters and dynamic-date logic — and check every date literal for an expired
   ceiling.
