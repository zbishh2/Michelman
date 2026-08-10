# Prep — JDE Sales Order session w/ Greg Kohls (5/20, 10am)

Greg = JDE data expert, brought in to explain the JDE Sales Order process and
tables. Goal of this session: lock the **Orders denominator** for Complaint %
(`(Orders − Complaints) / Orders`). See `Dashboard Requirements/COMPLAINTS_REQUIREMENTS.md`.

---

## The reframe (walk in with this)

The denominator probably already exists. The SSAS `Sales` fact is sourced from
EDW views that are straight pulls of JDE Sales Order files:

```
JDE F4211 (Sales Order Detail)    → EDW BIQL.TbSales_Detail   ┐
JDE F42119 (Sales Order History)  → EDW BIQL.TbSales_History  ┘ → SSAS [Sales] → PBI
                                                    (partitioned by GL Date)
```

So this is **not** "help me find the order data." It's **"the Sales fact has
the orders — help me define which rows count as an order for this KPI, and
confirm the column logic."** That's a tighter, faster conversation and it
keeps the work as report-level DAX (no new EDW views unless a gap appears).

The Sales fact already carries every column the open questions hinge on
(verified in `ssasprod.bim`):

| Question | Column(s) in `Sales` |
|---|---|
| Cancelled orders | `Cancelled_Flag` (int), `QuantityCanceledScrapped`, `Order Exclude` |
| Order types in scope | `Order Type` / `Order Type Desc`, `Document Type`, `Filter - Active Order Types` |
| Freight / non-product lines | `Line Type`, `Exclude Freight Line Types` |
| Region split (10/20/30) | `Order Company` / `Order Company Desc`, `Document Company` |
| Open vs closed | `Open Order Flag`, `Status Code Last/Next`, `Hold Orders Code` |
| Order identity / grain | `Order Num`, `Order Suffix`, `Line Num`, `Shipment Num` |
| Date candidates | `GL Date` (active rel), `Actual Ship Date`, `Order Date`, `Invoice Date`, `Promised/Requested` dates |

## How I can model (the access mental model)

Two separate activities — don't conflate them:

1. **Explore / validate** → SSMS, write SQL against **ODS** and **EDW** (Greg
   OK'd SQL; Dave's recommended order: ODS dev → EDW dev → SSAS dev). Also
   Tabular Editor 3 / the local `ssasprod.bim` for reading existing measures.
   This is where the denominator definition gets proven. Excel exports OK.
2. **Build the deliverable** → Power BI **Live Connect** to ssasprod, report-
   level DAX measures. No import. No model edits (ssasdev included — read-only
   by instruction).

Net: validate the order count in SQL against `BIQL.TbSales_Detail`, then
express the locked definition as a DAX distinct-count measure on `Sales`.

## Questions for Greg (JDE specifics)

**Order universe / grain**
1. In F4211/F42119, what defines one "order" for a complaint-rate denominator
   — order header (`Order Num`+`Order Suffix`), order line, or shipment?
   (Complaints are counted as distinct CaseNumber, so denominator grain
   should be a comparable "order" unit — likely distinct `Order Num`.)
2. `Order Suffix` — when does an order get multiple suffixes, and should they
   count as one order or several?

**Order types & line types**
3. Which `Order Type` values are real customer sales orders vs.
   quotes/samples/credits/transfers? What's the canonical "active sales
   order" set? (Does `Filter - Active Order Types` already encode this?)
4. `Line Type` — which values are product vs. freight/charge/text lines?
   (`Exclude Freight Line Types` — what does it flag, and what's the value
   that means "exclude"?)

**Cancelled / excluded / held**
5. `Cancelled_Flag` vs `Order Exclude` vs `QuantityCanceledScrapped > 0` —
   which is the right way to drop cancelled orders? Do any of these
   double-count?
6. Should held orders (`Hold Orders Code`) or fully-backordered orders be
   excluded from the denominator?

**Intercompany**
7. How are intercompany orders identified in JDE — a specific `Order Type`,
   a company relationship, or a sold-to range? (Meeting flagged we must
   exclude them.)

**Company → region**
8. Confirm `Order Company` = 10 / 20 / 30 maps to Americas / Asia / Europe.
   Which code is which? Any other companies in the data? Does this align with
   the Salesforce `Location` regions (Kemper/Shell=Americas, Aubange=Europe,
   Singapore=Asia)?

**Date**
9. Jessica's assumption: month bucket = `Actual Ship Date`, straight calendar
   match. Confirm. (Note: SSAS Sales' *active* date relationship is `GL Date`,
   not Actual Ship Date — so a ship-date measure needs `USERELATIONSHIP`.
   Worth knowing if Greg expects ship-date.)
10. Orders with no Actual Ship Date (not yet shipped) — in or out of the
    denominator for a given month?

## SQL probes to run (SSMS → EDW dev, schema BIQL)

These resolve the OTIF mystery (filters returned 0) and pre-answer several
questions above. Run against `BIQL.TbSales_Detail` (current) — column names
match the SSAS `sourceColumn`s, so bracket the ones with spaces.

```sql
-- Distinct values that drive the scope filters
SELECT [Filter - Active Order Types], COUNT(*) AS Rows
FROM BIQL.TbSales_Detail GROUP BY [Filter - Active Order Types];

SELECT [Exclude Freight Line Types], COUNT(*) AS Rows
FROM BIQL.TbSales_Detail GROUP BY [Exclude Freight Line Types];

SELECT [Order Exclude], COUNT(*) AS Rows
FROM BIQL.TbSales_Detail GROUP BY [Order Exclude];

SELECT Cancelled_Flag, COUNT(*) AS Rows
FROM BIQL.TbSales_Detail GROUP BY Cancelled_Flag;

-- Order type / line type catalogs
SELECT [Order Type],[Order Type Desc], COUNT(*) AS Rows
FROM BIQL.TbSales_Detail GROUP BY [Order Type],[Order Type Desc] ORDER BY Rows DESC;

SELECT [Line Type], COUNT(*) AS Rows
FROM BIQL.TbSales_Detail GROUP BY [Line Type] ORDER BY Rows DESC;

-- Region split sanity
SELECT [Order Company],[Order Company Desc], COUNT(*) AS Rows,
       COUNT(DISTINCT [Order Num]) AS DistinctOrders
FROM BIQL.TbSales_Detail GROUP BY [Order Company],[Order Company Desc] ORDER BY Rows DESC;

-- Candidate denominator: distinct orders by ship month, last 12 months
SELECT YEAR([Actual Ship Date]) AS Yr, MONTH([Actual Ship Date]) AS Mo,
       COUNT(DISTINCT [Order Num]) AS DistinctOrders,
       COUNT(*) AS Lines
FROM BIQL.TbSales_Detail
WHERE [Actual Ship Date] >= DATEADD(MONTH,-12,GETDATE())
GROUP BY YEAR([Actual Ship Date]), MONTH([Actual Ship Date])
ORDER BY Yr, Mo;
```

(If `TbSales_Detail` is current-period only, repeat the month query against
`BIQL.TbSales_History` and UNION for a full trend.)

## Outcomes to leave the meeting with

- A one-sentence written definition of "an order" for the denominator
  (table, grain, included Order Types, excluded flags, intercompany rule).
- Confirmed company-code → region mapping.
- Confirmed date field + handling of unshipped orders.
- Whether the existing `Sales` fact is sufficient or a new EDW view is needed
  (if needed → that becomes a tech spec for Dave/Rohit, not a Zack DDL).
- Then update `COMPLAINTS_REQUIREMENTS.md` Q1–Q8 + JDE section with answers.
