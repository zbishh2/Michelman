# Cognos source collection — Report 17

- **Migration tracker Report ID: 137** ("Migration Report Status - Remaining Reports_7_13_26.xlsx", Reports Detail row 30 + "Orders within Goal and Stretch" tab)
- **Report name:** Report - Orders within Goal and Stretch
- **Cognos path:** Public Folders > Michelman Reporting > Customer Service
- **Prior owner:** Lilly (LillySc) — handed to Zack 2026-07-14.
- **Tracker status at handover:** 90%, BUT — **"My original validation never passed due to the historical data returning the wrong values; therefore, I did not proceed with it"**. Code was sent and issues discussed with the team. This is the highest-risk of the three handover reports: the core historical-data logic is known-broken or known-mistrusted.
- **DECISION (Zack, 2026-07-14): full from-scratch rebuild through our standard pipeline.** Lilly's SQL below is REFERENCE ONLY. The build derives from the Cognos original (XML + generated SQL) — which matters doubly here, since her reinterpretation is the thing that never validated.

## Collected so far (extracted from the migration workbook, tab "Orders within Goal and Stretch")

| File | What it is |
|---|---|
| `Goal and Stretch rewrite (Lilly 2026-07-10).sql` | Lilly's T-SQL (from her 7/10/26 email) — full parameterized query |

## Query anatomy (from the rewrite — verify at intake)

- **Source: `PRODDTA.F42199` sales-order LEDGER** (`SL*` prefix — proven correct on this instance by report 12). Statuses: rows at Next Status **525** (pick confirm) and **540** (ship).
- **Date540** = MIN(Updated_Date) of 540 rows per order line; **Date525** = MAX(Updated_Date) of 525 rows *at or before* Date540. Metric = business days between (weekend-adjust both dates, then `DATEDIFF(DAY)-2×DATEDIFF(WEEK)` — spot-check this business-day formula, it's a known-fragile idiom).
- **Goal** flag: RAME ≤1 day; REUR/RASI ≤2 (via F0006 `MCRP02` company-level-2). **Stretch** ≤1. Plus >48H / <72H / >72H buckets.
- Excludes order types S5/ST; ledger filtered `SLTRDJ` (order date Julian) between @Start/@End params.
- Enrichment: F0006 (branch → MCRP02/MCRP03 Business Group), F0101 sold-to/ship-to names, F42140 CSR.
- Params: @Company, @BusinessGroup, @Customer, @BulkItem, @CSR (CSV STRING_SPLIT), @OrderStartDate/@OrderEndDate → natural PQ parameters / slicers.
- `SLUPMJ` (Updated_Date) is **date-only** — ties within a day are invisible; likely implicated in the "historical data wrong values" failure. Get specifics of the failed validation from Lilly/team before trusting any of this logic.

## Intake checklist (still needed)

0. [x] Prompt page screenshot → `Intake\Prompt page.png` (captured 2026-07-15). Six prompts: Company Name / Business Group Description / Customer Name / Bulk Item / CSR Name dropdowns + REQUIRED Order Start Date + Order End Date pickers (default = today). Maps 1:1 to Lilly's 7 `@` params — her parameterization mirrors the original's prompt set.
1. [x] Rendered report page → `Intake\Report page June run (2026-07-16 10-10).png` (render clock 10:10:48, screenshot ~10:13 per Zack; June 2026 run, all dropdowns blank). Layout = ONE flat list, no grouping. Columns L→R: Company Code, Company Name, Branch Plant, Freight Handling Code, Order Number, Ordered Quantity, 2nd Item Number, Sold To Customer Code/Name, Ship To Customer Code/Name, Customer Segmentation (code + description), Order Date, Confirmation Date, Shipped Date, Requested Date, Goal, Stretch, >48h, <72h, >72h. Dates render M/D/YY. Goal "1" values render blue (drill-through or CF — confirm in XML). On-page re-prompt toolbar = 4 dropdowns + Finish (no CSR dropdown on-page, unlike prompt page). NOTE: this is page 1 only (20-row panel pagination); rows include Shipped-Date-blank lines that still carry bucket flags (540 comes from ledger, not ship date) — good decode evidence.
2. [x] Full Cognos report specification XML → `Intake\XML.txt` (captured 2026-07-16 10:04; report/12.0 schema, complete root-to-close, model = Data Warehouse/DW_LEGACY).
3. [x] Cognos generated SQL for every query object → `Intake\Queries.txt` (2026-07-16 10:04). All 6 tree nodes: Company/Business Group/Customer/Bulk Item prompt queries (each ×2, matching the paired query-result nodes), CSR, and the main Sales Ledger/Orders query. Note: Report Studio required the two date prompts satisfied before generating SQL — dates land as `:PQ1`/`:PQ2` binds, not literals, so no expired-date-ceiling risk from the capture itself.
4. [x] Output export → `Intake\Cognos export June run (2026-07-16).xlsx` (from ~10:13 run, same capture as the report-page PNG). ONE sheet `Page1_1`: header + **997 detail rows** + `Overall - Total` list footer + a page-footer artifact row (run date serial 46219 = 2026-07-16, page "1", time 0.42417 = 10:10:48). **Totals row = the row-count/flag targets: Total Order Lines 997, Goal 706, Stretch 645, >48h 187, <72h 810, >72h 117** (187+810=997 ✓ complementary at the <3/>2 boundary). Sorted by Order Number as STRING (26001037 < 2733006). **Prompt range CONFIRMED by Zack: Jun 1 → Jun 30, 2026** (both 12:00 AM). Sheet anatomy: rows 1–2 blank/title, row 3 header, rows 4–1000 = 997 detail rows, then `Overall - Total`, then page-footer artifacts.

## THIRD finding: displayed Order Date ≠ filtered order date (2026-07-16) — RESOLVED same day

**RESOLUTION (intake agent, BUILD.md §6.2 + §4.1):** the displayed "Order Date" column is the **earliest-525 date** and "Confirmation Date" is the **earliest-540 date** — Cognos `label=` overrides rename the two ledger dates to business-friendly-but-inverted labels (the true ordered date isn't displayed at all). So the 4 "July" rows are simply June-ORDERED lines whose first 525 event happened in July — the June order-date filters worked correctly on both sides. The entry-timestamp hypothesis below is superseded; kept for the record. This label inversion is also the likeliest source of Lilly's wrong interval (she measured Order→525 believing the labels). Ported verbatim per parity; disclose to the business.

XML filters are unambiguous — Orders query: `[Time Order Date].[Date] between ?FromDate? and ?ToDate?`; both ledger queries: `[Sales Order Ledger].[Ordered Date] between ?FromDate? and ?ToDate?`. Yet the confirmed Jun 1–30 run contains **4 rows (3 orders) with July displayed Order Dates**: 26001182 ×2 lines (OD Jul 9 11:54 AM, conf Jul 16 10:07 AM — 3 min before the report ran), 2727528 (OD Jul 2, conf Jul 7), 2742995 (OD Jul 14, conf Jul 14). Since these passed BOTH June filters, the displayed `ORDER_ACTIVITY_MEASURE.ORDERED_DATE` (a datetime) must be a different fact than the filter's `[Time Order Date]` dimension date — working hypothesis: displayed = order **entry timestamp**, filter = JDE **order date** (SLTRDJ/SDTRDJ), which diverge when an order is entered later than its (backdated) order date, or when the order date is revised. Implications: (a) rebuild must filter and display per Cognos, not per intuition — filter on JDE order date, display the entry-timestamp-like column; (b) probe: in F4211/F42199, compare SDTRDJ vs entry date+time candidates on these 3 orders to pin the lineage; (c) this "orders outside my date range" behavior is a plausible contributor to the report's historical mistrust.

## SECOND smoking gun (2026-07-16, from the export)

**The Cognos 525/540 dates are DATETIMES, not dates.** Excel serials carry time fractions: Order Date 46174.336 (Jun 1 08:04), Confirmation Date 46174.4548 (Jun 1 10:54). DW_LEGACY `ORDER_LINE_LAST_UPDATED` evidently combines JDE date + time (F42199: `SLUPMJ` + `SLTDAY`), so Cognos' MIN-window picks the first 525/540 by **timestamp** and same-day multi-status sequences are fully ordered. Lilly's rewrite used `SLUPMJ` date-only → ties invisible. Combined with divergence #1 (first-vs-last 525), these are the two prime suspects for her "historical data returning the wrong values". **Rebuild requirement: reconstruct datetime as SLUPMJ + SLTDAY in the F42199 native query.** (Shipped/Requested dates are date-only integers in the export — only the ledger-derived and ordered dates carry time.)
5. [ ] The story of the failed validation: which values were wrong, vs what truth?
6. [x] Prompts/parameters confirmed against generated SQL; no hard-coded date ceiling found in the main query (unlike reports 08/10).

## First-pass divergence found (2026-07-16, pre-intake-agent)

**Cognos vs Lilly's rewrite disagree on which ledger rows define the window.** Cognos generated SQL takes, per (order, line): the **FIRST 525 row** (`MIN(ORDER_LINE_LAST_UPDATED)` window, filtered `C5=C9`) and the **FIRST 540 row** (same construct). Lilly's T-SQL takes `MIN(540)` but then `MAX(525 at-or-before Date540)` — the *last* 525 before ship, not the first. Any line confirmed more than once gives different 525 dates ⇒ different business-day counts ⇒ prime suspect for her "historical data returning the wrong values". Also confirmed: Cognos ledger filter is `ORDERED_DATE between :PQ1 and :PQ2` with `NEXT_STATUS = '525'/'540'`; Goal/Stretch CASE is RAME≤1, REUR≤2, RASI≤2 → Goal; c10≤1 → Stretch; buckets >2 / <3 / >3 business days.
