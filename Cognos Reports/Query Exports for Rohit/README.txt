==============================================================================
COGNOS -> POWER BI REBUILD :  QUERY EXPORTS
Prepared for Rohit / Michelman IT
==============================================================================

Last updated 2026-07-09.

WHAT IS IN HERE
---------------
One subfolder per rebuilt report (10 in total). Inside each subfolder:

  *.txt
      The NATIVE T-SQL that Power BI actually executes against SQL Server, one file
      per Power Query query. Query folding is enabled, so this is the statement that
      reaches the server. Each file is directly runnable in SSMS - the Power Query M
      wrapper has been stripped and nothing else was changed. No SQL was reformatted,
      renamed or 'improved'.

  _Reference - Cognos generated SQL (Oracle).sql
      A verbatim copy of the ORIGINAL Oracle SQL that IBM Cognos generated for that
      report. Kept for lineage and side-by-side comparison only. It is Oracle dialect
      and will NOT run against SQL Server. Present for 9 of the 10 reports - report 01
      has no such file in the repo.

  _README.txt
      Per-report index: the Power BI file it ships in, the source database, and a
      one-line description of each query with its main JDE tables.

READ FIRST - THE COGNOS FORECAST REPORTS RETURN ZERO ROWS
---------------------------------------------------------
This affects reports 08 and 10, and it is the one thing to know before running
anything.

The Cognos source for both forecast reports filters the requested date like this:

    REQUESTED_DATE__GREG between
        (sysdate - NUMTODSINTERVAL(EXTRACT(DAY FROM sysdate),'DAY')
                 + INTERVAL '1' DAY)      <- dynamic: the 1st of the current month
      and DATE '2026-06-30'               <- a hard-coded literal

The lower bound moves with the clock. The upper bound does not. Since 2026-07-01
Cognos has therefore been asking for rows `between 2026-07-01 and 2026-06-30` - an
empty range. Both Cognos forecast reports have silently returned no forecast rows
since 1 July 2026.

The evidence is in the repo. `Cognos Reports\Ivan Reports\Ivan SK 2023 Forecast.xlsx`
was exported from Cognos on 2026-07-05. Its Forecast sheet holds a single cell
reading `No Data Available`; its Sales History sheet on the same export holds 882
rows. The report ran. The forecast query returned nothing.

Two consequences:

  * This is a defect in the Cognos source report, not in the rebuild. Our
    `Forecast.txt` uses a DYNAMIC month-end (`<= EOMONTH(GETDATE())`) in place of the
    frozen literal, so it returns current-month data.

  * THE FORECAST PAGES CANNOT BE RECONCILED AGAINST COGNOS TODAY. Running both and
    comparing will show the rebuild returning rows and Cognos returning none. That is
    the expected result. It is not evidence that the rebuild is wrong.

Someone with the report's history needs to decide which behaviour is intended: was
`DATE '2026-06-30'` a deliberate frozen snapshot, or an expired hard-code that was
never maintained? That decision determines whether our dynamic ceiling is a fix or a
deviation. Until it is made, the forecast pages carry an open question rather than a
parity result.

SOURCE AND GRANTS
-----------------
All 25 queries read SQL Server: server ODSPROD, database ODS.

Business tables live in the PRODDTA (JDE) schema. Four queries also decode a
user-defined code from PRODCTL.F0005:

  07 - Ivan SK 2023          Sales_Order_Summary.txt
  08 - Ivan SK 2023 Forecast Sales_History.txt
  09 - Ivan FC 2023          Sales_Order_Summary.txt
  10 - Ivan SFC2023 Forecast Sales_History.txt

All four join `PRODCTL.F0005` to decode the country UDC on the customer address.

Anyone provisioned to run these queries therefore needs READ on BOTH `PRODDTA` AND
`PRODCTL`. A grant on `PRODDTA` alone is not enough - those four queries will fail on
the F0005 join. The other 21 queries need `PRODDTA` only.

REPORT -> POWER BI FILE
-----------------------
PBIX files are in `Cognos Reports\FINAL - for handover\`.

  Report                                                  Queries  Power BI file
  --------------------------------------------------------------------------
  01 - RM Staging at Shell Road 2026 (ODS)                 3     DEMO - RM Staging at Shell Road 2026.pbix
  02 - Shell and Kemper 530 Report                         2     Dashboard - CM Overview LIVE.pbix
  03 - CM Sales Orders Under 560 (Not Enough Inventory)    3     Dashboard - CM Overview LIVE.pbix
  04 - CM Open Sales Orders Live                           1     Dashboard - CM Overview LIVE.pbix
  05 - CM Inventory on Hand                                1     Dashboard - CM Overview LIVE.pbix
  06 - CM PO Live                                          1     Dashboard - CM Overview LIVE.pbix
  07 - Ivan SK 2023                                        5     1 - Ivan SK 2023.pbix
  08 - Ivan SK 2023 Forecast                               2     1 - Ivan SK 2023 Forecast.pbix
  09 - Ivan FC 2023                                        5     1 - Ivan FC 2023.pbix
  10 - Ivan SFC2023 Forecast                               2     1 - Ivan FC 2023 Forecast.pbix

Reports 02, 03, 04, 05 and 06 are the five pages of ONE dashboard and share a single
semantic model, so they all ship inside `Dashboard - CM Overview LIVE.pbix`.
Reports 01, 07, 08, 09 and 10 are standalone, one PBIX each.

Reports 07 and 09 are structural twins (Ivan SK vs Ivan FC) and carry the same five
query names; likewise reports 08 and 10. The filter literals differ.

UNVALIDATED : REPORT 08 AND 10 `Forecast.txt`
---------------------------------------------
Both `Forecast.txt` files are UNVALIDATED, best-effort rebuilds. Cognos sourced them
from the DW_LEGACY Oracle data warehouse, which we have no connection to, so they were
reverse-mapped onto the JDE forecast file F3460. Uncertain fields are marked inline
with `-- TODO verify` and must be checked by someone with JDE access before the
forecast pages are trusted.

Not all the markers are worth the same. In descending order of value:

  1. `MFFQT` and its `/10000` scaling.   HIGHEST VALUE.
     Every quantity on the page depends on this one column and one divisor - the
     forecast quantity itself, and both the KG and LB conversions derived from it. If
     the column name or the implied 4-decimal scaling is wrong, every number on the
     page is wrong by a constant factor. Roughly 15-30 minutes for someone with JDE
     access to settle.

  2. The date column, coded as `MFDRQJ`.   HIGHEST VALUE.
     The month filter and the Year / Month / Week columns all hang on this single
     Julian date column. It is coded as `MFDRQJ` and flagged `-- TODO verify`; the
     transposed spelling `MFRQDJ` is the obvious alternative and should be checked
     against the F3460 data dictionary. If it is the wrong column, the page filters and
     groups on the wrong date. Also 15-30 minutes.

  3. `RELOAD_KEY = 'N'`   - a conscious, documented omission, not a silent drop.
     The Cognos generated SQL applies `RELOAD_KEY = N'N'` against DW_LEGACY. F3460 has
     no equivalent column, so the filter was omitted. That decision is recorded in the
     source `Forecast.m` (line 59 in report 08, line 57 in report 10). It corresponds
     to a Cognos filter named `[Active Forecast Only]` and reads like ETL load-control
     metadata marking the current warehouse load. Rohit or the DW_LEGACY owner can
     settle it in one question. If it is load-control metadata, the omission is right
     and nothing changes.

  4. `Revenue Business Unit` is a placeholder.
     Cognos reads a genuinely distinct dimension for this column. Our query currently
     returns a copy of `Branch Plant` (both are `ft.MFMCU`). Treat the column as
     unpopulated rather than as a value.

DELIBERATE COGNOS QUIRKS REPRODUCED
-----------------------------------
Some queries deliberately reproduce defects in the Cognos originals, so that the Power
BI numbers tie 1:1 to the live Cognos reports. These are faithful, not accidental.
Anyone reconciling numbers will otherwise chase them as bugs. Each is documented in
the source `.m` file and in that report's `BUILD.md`.

  Report 01 - `Total RM Needed` DOUBLE-COUNTS.
     The Cognos join fans `Planned WO` out by the number of on-hand lot statuses, then
     sums the open RM. An item holding stock in both the `' '` and the `'-'` status
     reports twice its real need.

  Report 01 - `Qty On Hand CINC` uses AVG across lot statuses, not SUM.
     100 in `' '` plus 50 in `'-'` reports as 75, not 150.

     Both are reproduced on purpose. Corrected formulas are in `01\BUILD.md` under
     "Known Cognos quirks". Do not apply them without a planner decision - the rebuild
     stops matching Cognos the moment you do.

  Report 02 - Cognos's `Number of Errors` card disagrees with Cognos's own rows.
     The card reads 1,299. The list on the same page shows a couple of dozen red rows
     (16 on the 2026-07-05 snapshot; 12 on 2026-07-06 - the population moves with the
     data). 1,299 is a fan-out artefact of Cognos's un-grouped COUNT query, which
     counts each ERROR order line once per matching routing row. Our rebuild counts the
     visible ERROR rows, so it ties to Cognos's LIST, not to Cognos's CARD. This is a
     deliberate correction of a Cognos defect, and it is the single most likely false
     alarm in the whole handover.

  Report 01 - four DISABLED Cognos filters are correctly NOT implemented.
     `Report XML.md` carries four `use="prohibited"` filters: `[2nd Item Number] =
     'POLYMINP'` twice (on `IOH CIN2` and on `IOH All`), `[Status] in (' ','-')` on
     `IOH All`, and `[OPEN RM] > [Quantity On Hand]` on `RM Shortage CINC`. All four
     are inactive in Cognos. Implementing any of them would over-filter the rebuild.

A GENERAL TRAP, WORTH STATING ONCE
----------------------------------
In a Cognos report specification, `<detailFilter use="prohibited">` means the filter is
DISABLED. A disabled filter very often sits directly beside an ACTIVE twin of the same
expression - same column, same or nearly the same value list. Reading one without
noticing the other produces confident, wrong conclusions about what the report filters
on.

Three reports in this set carry such pairs:

  Report 06 - `[REGION] in ?Select_Region?` appears twice, identically: ACTIVE
              (`use="optional"`) on the live `Purchase Orders` query, and DISABLED
              (`use="prohibited"`) on `PO Summary`.

  Report 07 - three DISABLED `[Bulk Item] in (...)` filters carrying report 09/10's
              item list, sitting beside the ACTIVE `[Bulk Item] in ('PR3460', ...)`
              filters that the report really uses.

  Report 09 - three DISABLED `[Bulk Item] in (...)` filters sitting beside ACTIVE
              `[Bulk Item] in (...)` filters on the same column. The two lists overlap
              but are not identical. Per `09\BUILD.md`, the disabled copies never
              reached the Cognos generated SQL, so they are not applied. We match the
              generated SQL, which is the record of what actually ran.

REPORT 01 - NO COGNOS REFERENCE SQL EXISTS
------------------------------------------
Report 01 is the only report with no `_Reference - Cognos generated SQL (Oracle).sql`.
No Cognos-generated Oracle SQL for it exists anywhere in the repo.

This matters more than it looks. Report 01 is the report on which a row-count
discrepancy was raised, and it is the one report where there is no Cognos SQL to diff
our T-SQL against. Everything below was established by reading the Cognos report
specification (`Report XML.md`) directly rather than by comparing generated SQL.

REPORT 01 - THE ROW-COUNT DISCREPANCY : CURRENT CONCLUSION
----------------------------------------------------------
Every `<filterExpression>` in the Cognos report 01 specification maps 1:1 onto
`RM_Requirements.txt`:

  manufacturing branch `CINC`                     `WAMMCU = 'CINC'`
  work-order status exclusion list                `WASRST NOT IN ('93','94','95',
                                                   '97','99','MM','CD')`
  open RM greater than zero                       `(WMUORG - WMTRQT)/10000 > 0`
  FG item does not contain `-`                    `WALITM NOT LIKE '%-%'`
  component does not contain `H2O`                `WMCPIL NOT LIKE '%H2O%'`
  raw-material MPF whitelist                      `IBPRP4 IN ('RRC','REC','RCB',
                                                   'TOL','PKG','RBW')`
  on-hand lot status                              `LILOTS IN (' ','-')`
  on-hand quantity greater than zero              `LIPQOH/10000 > 0`
  requested-date window                           `WMDRQJ` between today-7 and
                                                   today + N business days

The business-day window (Thursday and Friday -> +4, Saturday -> +3, otherwise -> +2)
is a faithful port. Nothing in the Cognos filter set is missing from our query, and
our query adds nothing Cognos does not have.

The rows that differed were on page 1's BOTTOM work-order table, not the top summary
table. The DEPLOYED Power BI query was missing the short-material INNER JOIN that the
repo's `WorkOrder_Detail.m` has, so the page rendered 135 rows where Cognos rendered
15. That was a real defect in the deployed model - not a filter defect, and not a
difference in the SQL you are holding. It was fixed on 2026-07-06 by pushing the repo
query into the live partition. Once filtered to the eight short materials, Power BI
matched Cognos 15 rows out of 15, on all four columns. The `WorkOrder_Detail.txt` in
this folder is the corrected query.

The page-1 top summary table ties 8 rows out of 8, every column exact, at full
precision.

Separately, an earlier one-cell difference on that top table was traced to the Cognos
export and the Power BI model having been refreshed at different moments - a
refresh-timing artefact, not a formula or rounding defect. Re-running both the same
evening produced an exact tie. A "last refreshed" timestamp card has since been added
to every page of every report, precisely so that this question can be settled by
looking rather than by arguing.

PLEASE NOTE
-----------
* None of the queries carry an ORDER BY. Power BI wraps a folded query as
  `SELECT * FROM (<query>)`, where ORDER BY is illegal in SQL Server; the sort is set
  on the visual instead. Add your own ORDER BY when running these ad hoc in SSMS.

==============================================================================
