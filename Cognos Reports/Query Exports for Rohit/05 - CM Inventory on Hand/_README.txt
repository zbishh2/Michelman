==============================================================================
REPORT : 05 - CM Inventory on Hand
==============================================================================

Power BI file : Dashboard - CM Overview LIVE.pbix
                Page 4 of "Dashboard - CM Overview LIVE".
Source        : ODSPROD / ODS, SQL Server. Business tables in PRODDTA (JDE).

Queries in this folder (1 .txt):

  CM_Inventory_on_Hand.txt
     The inventory table (Cognos list "List1", query object "Inventory"). On-hand quantity and hard
     commit grouped by branch / bulk item / 2nd item / lot status / primary UOM, with KG and LB
     conversions. Filtered to qty on hand > 0 and a fixed bulk-item whitelist. REGION is both a
     displayed column and the region slicer source.
     Tables: F4102, F4101, F554101, F41021.

  _Reference - Cognos generated SQL (Oracle).sql
     Verbatim copy of the ORIGINAL Oracle SQL that IBM Cognos generated for this
     report. Reference / lineage only - it is NOT what Power BI runs, and it will
     not execute against SQL Server unchanged.

------------------------------------------------------------------------------
The .txt files contain the native T-SQL that Power BI actually sends to SQL Server
(query folding is enabled). Each is directly runnable in SSMS as-is.
------------------------------------------------------------------------------
