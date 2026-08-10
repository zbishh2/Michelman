==============================================================================
REPORT : 03 - CM Sales Orders Under 560 (Not Enough Inventory)
==============================================================================

Power BI file : Dashboard - CM Overview LIVE.pbix
                Page 2 of "Dashboard - CM Overview LIVE". Master-detail: SO list (left) + inventory (middle) + work orders (right).
Source        : ODSPROD / ODS, SQL Server. Business tables in PRODDTA (JDE).

Queries in this folder (3 .txt):

  SO_Not_Shipping.txt
     Master list (left block), Cognos query object "Open Orders". Open sales-order lines in the
     Cincinnati plants for the next 21 days that are still pre-shipping (next status 525-550,
     line type 'S'), on the CM item whitelist, with no lot assigned yet.
     Tables: F4211, F0101, F0010 (company constants).

  Inventory_Availability.txt
     Inventory detail (middle block), Cognos query object "Inventory On Hand". On-hand item/location
     balances at CINC/CIN2/CIN4 where qty on hand > 0, with a status-gated AVAIL column.
     Deliberately NOT item-filtered - the model relationship to the SO list does the filtering.
     Tables: F41021, F4102, F4101, F554101.

  WorkOrder_Detail.txt
     Work-order detail (right block), Cognos query object "Work Orders". Open manufacturing work
     orders in the Cincinnati plants, active WO status, requested within the next 31 days.
     Tables: F4801, F4102, F4101, F554101.

  _Reference - Cognos generated SQL (Oracle).sql
     Verbatim copy of the ORIGINAL Oracle SQL that IBM Cognos generated for this
     report. Reference / lineage only - it is NOT what Power BI runs, and it will
     not execute against SQL Server unchanged.

------------------------------------------------------------------------------
The .txt files contain the native T-SQL that Power BI actually sends to SQL Server
(query folding is enabled). Each is directly runnable in SSMS as-is.
------------------------------------------------------------------------------
