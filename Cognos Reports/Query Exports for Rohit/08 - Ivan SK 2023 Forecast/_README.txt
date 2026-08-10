==============================================================================
REPORT : 08 - Ivan SK 2023 Forecast
==============================================================================

Power BI file : 1 - Ivan SK 2023 Forecast.pbix
                Standalone, 2 pages. Structural twin of report 10; differs only in the item whitelist and start date.
Source        : ODSPROD / ODS, SQL Server. Business tables in PRODDTA (JDE).

Queries in this folder (2 .txt):

  Forecast.txt
     Page "Forecast". Current forecast quantity by company / branch / bulk item / requested date, with
     KG and LB conversions and customer + global-parent attributes.
     *** UNVALIDATED - BEST EFFORT. *** Cognos read the DW_LEGACY Oracle warehouse
     (INVENTORY_DEMAND star schema); with no DW_LEGACY connection this was reverse-mapped onto the
     JDE forecast file F3460. Several F3460 field names and the /10000 quantity scaling are
     UNCONFIRMED and are marked inline with `-- TODO verify`. A human with JDE access must check
     these before the page is trusted. See BUILD.md -> "ASSUMPTIONS & VALIDATION RISKS".
     Tables: F3460 (forecast file), F4101, F554101, F0006, F0101, F42140.

  Sales_History.txt
     Page "Sales History". Shipped/booked sales history by customer, item and due date, with KG/LB.
     Reads F4211 UNION ALL F42119: completed lines (next status 999) are purged out of F4211 into the
     sales-history file F42119, so F4211 alone decays over time. Rebuilt off base JDE tables because
     the Cognos original reads the DW_LEGACY warehouse (ORDER_ACTIVITY star schema).
     Tables: F4211, F42119 (sales order history), F42140, F0101, F0116, F0006, F554101;
     country UDC decode uses PRODCTL.F0005.

  _Reference - Cognos generated SQL (Oracle).sql
     Verbatim copy of the ORIGINAL Oracle SQL that IBM Cognos generated for this
     report. Reference / lineage only - it is NOT what Power BI runs, and it will
     not execute against SQL Server unchanged.

NOTES
-----
READ FIRST: THE COGNOS ORIGINAL RETURNS NO FORECAST ROWS.

The Cognos source filters the requested date `between` a DYNAMIC lower bound (the
1st of the current month) `and` the HARD-CODED literal `DATE '2026-06-30'`. The
lower bound moves with the clock. The upper bound does not. Since 2026-07-01 Cognos
has been asking for rows between 2026-07-01 and 2026-06-30 - an empty range. This
Cognos report has silently returned no forecast rows since 1 July 2026.

The evidence is in the repo. `Cognos Reports\Ivan Reports\Ivan SK 2023 Forecast.xlsx`
was exported from Cognos on 2026-07-05. Its Forecast sheet holds a single cell
reading `No Data Available`; its Sales History sheet, from the same export, holds
882 rows. The report ran. The forecast query returned nothing.

This is a defect in the Cognos source report, not in the rebuild. `Forecast.txt`
here uses a DYNAMIC month-end (`<= EOMONTH(GETDATE())`) in place of the frozen
literal, so it returns current-month data.

THEREFORE THIS FORECAST PAGE CANNOT BE RECONCILED AGAINST COGNOS TODAY. Running
both and comparing will show the rebuild returning rows and Cognos returning none.
That is the expected result. It is not evidence that the rebuild is wrong.

Someone with the report's history needs to decide whether the Cognos literal was an
intentional frozen snapshot or an expired hard-code that was never maintained. That
decision determines whether our dynamic ceiling is a fix or a deviation.

WHERE TO SPEND VERIFICATION TIME ON `Forecast.txt`

The `-- TODO verify` markers are not equally valuable. In descending order:

  1. `MFFQT` and its `/10000` scaling.   HIGHEST VALUE.
     Every quantity on the page depends on this one column and one divisor - the
     forecast quantity itself, and both the KG and LB conversions derived from it.
     If the column name or the implied scaling is wrong, every number on the page
     is wrong by a constant factor. Roughly 15-30 minutes for someone with JDE
     access.

  2. The date column, coded as `MFDRQJ`.   HIGHEST VALUE.
     The month filter and the Year / Month / Week columns all hang on this single
     Julian date column. The transposed spelling `MFRQDJ` is the obvious
     alternative and should be checked against the F3460 data dictionary. If it is
     the wrong column, the page filters and groups on the wrong date. Also 15-30
     minutes.

  3. `RELOAD_KEY = 'N'` - a conscious, documented omission, not a silent drop.
     The Cognos generated SQL applies `RELOAD_KEY = N'N'` against DW_LEGACY. F3460
     has no equivalent column, so the filter was omitted. That decision is recorded
     in the source `Forecast.m` at line 59. It corresponds to a Cognos filter
     named `[Active Forecast Only]` and reads like ETL load-control metadata
     marking the current warehouse load. Rohit or the DW_LEGACY owner can settle it
     in one question. If it is load-control metadata, the omission is right and
     nothing changes.

  4. `Revenue Business Unit` is a placeholder.
     Cognos reads a genuinely distinct dimension for this column. Our query returns
     a copy of `Branch Plant` (both are `ft.MFMCU`). Treat the column as
     unpopulated rather than as a value.

`Sales_History.txt` decodes a country user-defined code from
`PRODCTL.F0005`. Running it needs READ on BOTH `PRODDTA` and `PRODCTL` - a grant on
`PRODDTA` alone will fail on the F0005 join.
`Forecast.txt` needs `PRODDTA` only.

------------------------------------------------------------------------------
The .txt files contain the native T-SQL that Power BI actually sends to SQL Server
(query folding is enabled). Each is directly runnable in SSMS as-is.
------------------------------------------------------------------------------
