==============================================================================
REPORT : 07 - Ivan SK 2023
==============================================================================

Power BI file : 1 - Ivan SK 2023.pbix
                Standalone, 5 pages. Structural twin of report 09 - Ivan FC 2023; differs only in the filter literals (SK vs FC).
Source        : ODSPROD / ODS, SQL Server. Business tables in PRODDTA (JDE).

Queries in this folder (5 .txt):

  Inventory.txt
     Page 1 "Inventory" (Cognos list "List1"). On-hand inventory at lot/location grain across the nine
     global branches (AUBA/AUB2/SING/SNG4/MUM3/SHAN/CINC/CIN2/CIN4), with hard commit and KG/LB.
     Tables: F4102, F4101, F554101, F41021.

  Work_Orders.txt
     Page 2 "Work Order" (Cognos list "List4"). Work orders with component issued/ordered/remaining
     quantities (P7 issued/ordered KG and LB). Reproduces the Cognos window-function fan-out shape.
     Tables: F4801, F3111, F4102, F4101, F554101.

  Sales_Order_Summary.txt
     Page 3 "Sales Orders" (Cognos list "List3"). Open sales-order lines with customer segmentation,
     global parent, country name, hold code, CSR and TM names, order KG/LB, and both qty/UOM pairs.
     Tables: F4211, F42140, F0101, F0116 (address by date), F0006, F4201 (SO header), F4102, F4101,
     F554101; country UDC decode uses PRODCTL.F0005.

  Inventory_HP.txt
     Page 4 "Inventory HP" (Cognos list "List5", query object "Inventory - New"). Same on-hand grain as
     page 1 but restricted to available lot statuses (blank or T/B/Q/H), fewer columns.
     Tables: F4102, F4101, F554101, F41021.

  Safety_Stock_HP.txt
     Page 5 "Safety Stock HP" (Cognos list "List2", query object "Safety Stock - New"). SELECT DISTINCT
     safety stock (F4102.IBSAFE) per item/branch with an LB conversion. No aggregation.
     Tables: F4102, F4101, F554101.

  _Reference - Cognos generated SQL (Oracle).sql
     Verbatim copy of the ORIGINAL Oracle SQL that IBM Cognos generated for this
     report. Reference / lineage only - it is NOT what Power BI runs, and it will
     not execute against SQL Server unchanged.

NOTES
-----
A Cognos reading trap on this report. In a Cognos report specification,
`<detailFilter use="prohibited">` means the filter is DISABLED - and a disabled
filter often sits directly beside an ACTIVE twin on the same column. Reading one
without noticing the other produces confident, wrong conclusions about what the
report filters on.

The specification for this report carries three DISABLED `[Bulk Item] in (...)`
filters holding the item list that belongs to reports 09 and 10 (`JS168.S`,
`ME91735.S`, ...), sitting beside the ACTIVE `[Bulk Item] in ('PR3460', ...)`
filters that this report really uses. Only the active list is implemented here. Do
not read the disabled list as this report's scope.

`Sales_Order_Summary.txt` decodes a country user-defined code from
`PRODCTL.F0005`. Running it needs READ on BOTH `PRODDTA` and `PRODCTL` - a grant on
`PRODDTA` alone will fail on the F0005 join.
The other four queries in this folder need `PRODDTA` only.

------------------------------------------------------------------------------
The .txt files contain the native T-SQL that Power BI actually sends to SQL Server
(query folding is enabled). Each is directly runnable in SSMS as-is.
------------------------------------------------------------------------------
