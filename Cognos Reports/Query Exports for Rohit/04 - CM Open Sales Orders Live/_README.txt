==============================================================================
REPORT : 04 - CM Open Sales Orders Live
==============================================================================

Power BI file : Dashboard - CM Overview LIVE.pbix
                Page 3 of "Dashboard - CM Overview LIVE".
Source        : ODSPROD / ODS, SQL Server. Business tables in PRODDTA (JDE).

Queries in this folder (1 .txt):

  CM_Open_Sales_Orders.txt
     The "CM Open Sales Orders" detail list (Cognos list "List1", query object "Sales Summary").
     Open sales-order lines with customer PO, order/requested/promised dates, primary and secondary
     qty + UOM, customer name and TM name. REGION is carried as a hidden column to drive the
     "Select the Region" slicer.
     Tables: F4211, F42140, F0101, F0006 (business unit), F4102, F4101, F554101.

  _Reference - Cognos generated SQL (Oracle).sql
     Verbatim copy of the ORIGINAL Oracle SQL that IBM Cognos generated for this
     report. Reference / lineage only - it is NOT what Power BI runs, and it will
     not execute against SQL Server unchanged.

------------------------------------------------------------------------------
The .txt files contain the native T-SQL that Power BI actually sends to SQL Server
(query folding is enabled). Each is directly runnable in SSMS as-is.
------------------------------------------------------------------------------
