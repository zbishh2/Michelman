# Raw Material Margin — formulas for cube-measure review

Report 22 "CM – Information 2020 – Future", Shipments page. The Cognos report carries
**Raw Material Margin USD** and **Raw Material Margin EUR** per sales line. The Power BI rebuild
does not carry them (Dave Bubash: the report consumers do not need them yet). This note hands the
definitions to Dave, Greg and Rohit so the margin can be added to `BIQLTabular` as measures once
they validate a cost basis. Everything below is per sales-order line; the report sums over lines.

## 1. What Cognos computes (legacy DW_LEGACY warehouse, Oracle)

From the report's native SQL (`Intake\Native SQL (filed 2026-08-19).txt`, query `Shipments_2`),
simplified — every term is `ORDER_ACTIVITY_MEASURES` unless marked:

```
Net_local    = ORDER_NET_AMOUNT                              -- transaction currency
               (when ORDER_NET_AMOUNT = 0 and QTY_BACKORDERED > 0:
                ORDERED_QTY in pricing UOM × ORDER_NET_PRICE)  -- back-ordered line re-priced
               / EXCHANGE_RATE, rounded to 2 dp

Margin_local = Net_local            × SALES_FACTOR
             - A1_COST              × SALES_FACTOR
             - PRICE_ORDER_SUMMARY.DELV_FREIGHT × SALES_FACTOR
             - PRICE_ORDER_SUMMARY.WAREHOUSE    × SALES_FACTOR
             - PRICE_ORDER_SUMMARY.ADD_FREIGHT  × SALES_FACTOR

Raw Material Margin USD = Margin_local × rate(LOCAL_CURRENCY_CODE → USD, rate type M)
Raw Material Margin EUR = Margin_local × rate(LOCAL_CURRENCY_CODE → EUR, rate type M)
```

- `SALES_FACTOR` is the ±1 sign (credits negative).
- The rate is `FIN_CURRENCY_CONVERSION`, rate type **M** (monthly), effective on the line's
  **GL date** (order date when the line is unposted).
- `A1_COST` is the warehouse's per-line "A1" cost; by the JDE naming it is the **A1 = material**
  cost component (F30026 cost components), which is what makes this a *raw material* margin rather
  than a full-standard-cost margin. `DELV_FREIGHT`, `WAREHOUSE`, `ADD_FREIGHT` come from
  `PRICE_ORDER_SUMMARY`, the warehouse's per-order-line summary of price adjustments — i.e. the
  delivery freight, warehousing and additional-freight adjustments carried on the line. Both
  derivations should be confirmed against the legacy ETL before the measure is built; neither
  column exists in `BIQLTabular` or EDW today.

## 2. What we built from the cube (validation only — not in the delivered report)

`SSASPROD` / `BIQLTabular`, table `Sales`. The cube has extended **standard** cost per line
(`AmountExtendedCost`, `AmountExtendedCostUSD`, `AmountExtendedCostEUR`, `AmtStdExtCostUSD`,
`FSDAmountUnitCost`, `BackOrderedExtendedCost`) but no material-only cost and no freight /
warehouse charges, so the closest reproducible definition is net less extended standard cost:

```dax
-- per Sales row (line grain); the report's Net amounts use the same @Net variables
"@NetUSD",   Sales[AmountOrderNetUSD] + Sales[BackOrderedExtendedAmount]
"@NetEUR",   Sales[AmountOrderNetEUR] + Sales[BackOrderedExtendedAmountEUR]
"@RateDate", IF ( Sales[GL Date] <= DATE ( 1900, 12, 31 ), Sales[Order Date], Sales[GL Date] )
"@EurToUsd", MAXX ( FILTER ( EurUsdMonthEnd,
                 'Currency Rates'[CalendarDate] = EOMONTH ( [@RateDate], 0 ) ),
                 'Currency Rates'[ToRateA] )        -- one EUR→USD month-end row per month

"Raw Material Margin USD (Line)",
    [@NetUSD] - Sales[AmountExtendedCostUSD]

"Raw Material Margin EUR (Line)",
    IF ( Sales[LocalCurrency] = "EUR",
         [@NetEUR] - Sales[AmountExtendedCostEUR],                       -- EUR companies: native
         DIVIDE ( [@NetUSD] - Sales[AmountExtendedCostUSD], [@EurToUsd] ) )  -- USD companies: USD ÷ rate A
```

where `EurUsdMonthEnd = FILTER ( 'Currency Rates', [CurrencyCodeFrom] = "EUR" && [CurrencyCodeTo] = "USD"
&& [CalendarDate] = [PeriodEndDate] )`. The EUR branch exists because `AmountOrderNetEUR` /
`AmountExtendedCostEUR` are null for USD-local companies (00010 / 00030) in the cube.

As cube measures the same thing would be, over the report's row set (70 CM bulk items, promised
ship date ≥ 2020-01-01, not cancelled, order types other than SB / SR):

```dax
Raw Material Margin USD := SUM ( Sales[AmountOrderNetUSD] ) + SUM ( Sales[BackOrderedExtendedAmount] )
                         - SUM ( Sales[AmountExtendedCostUSD] )
Raw Material Margin EUR := -- needs the USD→EUR rate for USD-local companies; see above
```

## 3. How the standard-cost version ties to Cognos (2,864 lines, 2026-08-19)

| | Cognos (A1 + freight) | Cube (standard cost) | Net diff | Abs diff (sum of per-line abs) | Lines exact at 0 dp |
|---|---|---|---|---|---|
| USD | 15,033,380 | 15,217,561 | +184,181 (+1.2%) | 807,305 (5.4%) | 1,854 / 2,864 |
| EUR | 13,522,155 | 13,626,871 | +104,716 (+0.8%) | 609,982 (4.5%) | 2,140 / 2,864 |

The net amounts themselves tie (USD +0.25%, EUR within the month-end vs monthly rate basis), so
the whole margin gap is the **cost basis**: standard cost versus A1 material cost plus the three
freight / warehouse adjustments. The largest per-line gaps are concentrated on a few items
(HP1632-T2: 108,662 / 65,748 / 47,817 on three lines; U502.E-TO 35,510; APT10-T2 ~9,000 per line),
which suggests the standard cost on those items carries material that the A1 component does not,
or vice versa — worth a look when the cost basis is chosen.

## 4. What a cube measure needs (for the review)

1. **Cost basis decision**: A1 (material-only) cost per sales line, or full standard cost. If
   A1: it needs a per-line material cost in the fact (e.g. F30026 component A1 × quantity at
   the line's cost date), which `FactSalesDetail` / `Sales` does not carry today.
2. **Freight / warehouse adjustments**: delivery freight, warehouse and additional freight per
   sales line — the `PRICE_ORDER_SUMMARY` columns. These look like summed price-adjustment
   amounts (F4074) by adjustment name; the cube would need them as line-level columns.
3. **Currency**: Cognos uses rate type M on the GL date; the cube's native USD amounts are at
   the JDE order-time rate, and EUR for USD-local companies must be derived. Pick one basis and
   state it in the measure description.
4. **Back-ordered lines**: Cognos re-prices a back-ordered line with zero net as
   `ordered qty × net price`; the cube's `BackOrderedExtendedAmount` covers the same case (2 lines
   in this row set) and is already part of Order Net Amount USD.

Source references: `Shipments.commented.m` (the shipped query with the margin removed),
`PROBE\FINDINGS.md` (Shipments section), `PROBE\06_shipments_lines.dax` / `09_shipments_amounts.dax`
(the cost columns probed), `PROBE\an_ship3.py` / `cmp_ship.py` (the tie-out scripts).
