==============================================================================
REPORT : 19 - 1 - Inventory - Safety Stock and Order Size
==============================================================================

Power BI file : 19 - Safety Stock and Order Size.pbip
                PBIP (PBIR) format. Three pages - the two Cognos sheets, plus
                an analysis page that joins them.
                (The artifact name is kept short on purpose - the repo path is
                already long, and past 256 characters Power BI Desktop opens
                the file as "Untitled" with no error.)
Source        : EDWPROD / EDW, SQL Server (two queries).
                ODSPROD / ODS / PRODDTA for the planner-name lookup only.

Cognos original : Public Folders > Michelman Reporting > Production and
                  Shipping > Cogan Excel AD HOC Reports
                  "1 - Inventory - Safety Stock and Order Size"
                  Package: Data Warehouse (the DW_LEGACY Oracle star).
                  A two-sheet Excel data dump - two independent queries, one
                  flat list each, no grouping, no prompts, no parameters.

Queries in this folder (3 .txt):

  Safety Stock.txt
     Sheet 1 "Safety Stock" (177 rows, 10 columns). Standing safety stock per
     item/branch across the six branch plants, restricted to finished goods
     (Master Planning Family LIKE '%F%') and non-obsolete stocking types.
     Table: BIQL.TbItemBranch. No joins - EDW denormalises the planner name
     onto the row, so the Cognos VENDOR join disappears.

  Shipments.txt
     Sheet 2 "Shipments" (5,675 rows, 19 columns). Six months of closed order
     lines for those same six plants, aggregated to order x item grain with
     three quantity measures.
     Tables: BIQL.FactSalesDetail joined to BIQL.TbItemBranch, BIQL.DimCustomer,
     BIQL.DimAddress (twice - ship-to, and the global parent by address number)
     and BIQL.TbTerritoryManager.

  Planner Names.txt
     Hidden lookup, about 57 rows. Supplies the Cognos 'Last, First' planner
     spelling from JDE F0101.ABALPH. ODS only.
     Table: PRODDTA.F0101, scoped through PRODDTA.F4102.

  _Reference - Cognos generated SQL (Oracle).sql
     Verbatim copy of the ORIGINAL Oracle SQL that IBM Cognos generated for this
     report. Reference / lineage only - it is NOT what Power BI runs, and it will
     not execute against SQL Server unchanged.

NOTES
-----
SIX PLACES THE OBVIOUS PORT IS WRONG. Each was measured against a tight Cognos
capture taken 2026-08-06; the report ties at 177/177 and 5,675/5,675.

  1. "Ordered Quantity" is QuantityOrderedPrimaryUOM, NOT
     QuantityOrdered * SalesFactor. FactSalesDetail HAS a column called
     SalesFactor and it is not a UOM conversion - it is 1.0000 on 977,203 rows
     and 0.0000 on 2,140, every row. The real conversion is in
     QuantityOrderedPrimaryUOM, which differs from QuantityOrdered on 65.7% of
     in-window lines.

  2. Cognos's CANCELLED_INDICATOR is StatusCodeLast IN ('980','984'), NOT
     Cancelled_Flag. Cancelled_Flag is set on only 366 rows model-wide and
     catches 118 of the 486 cancelled lines in scope - using it leaves the
     report 263 rows (+4.6%) too high, spread proportionally across every
     branch.

  3. "Global Parent Name" comes from the ship-to address book's FIFTH address
     number (AddressNum5th), NOT the fact's ParentAddressSKey. The latter
     reproduces Cognos on 20.4% of rows; AddressNum5th does it on 99.9%.

  4. The Territory Manager join must be LEFT, not INNER, even though Cognos's
     comma-join is an inner join. BIQL.TbTerritoryManager is incomplete - 22
     TerritoryManagerSKey values on the fact do not resolve in it, including
     the -1 unknown member - while Cognos's VENDOR dimension resolves all of
     them. An inner join drops 13 output rows. This is the one place EDW's
     dimension is THINNER than Oracle's.

  5. Cognos's OPEN_INDICATOR <> 'Y' ports to StatusCodeNext = '999'.
     OPEN_INDICATOR is a stored Y/N column on ORDER_ACTIVITY, and a jumpbox
     probe on the neighbouring report 21 cross-tabbed it against that report's
     own Cognos export over 17,259 rows: 'N' corresponds to
     StatusCodeNext = '999' and 'Y' to the in-flight statuses (540, 530, 560,
     535, 580, 525, 550, 570), with zero exceptions.
     An earlier draft used SalesTableSource <> 1. In report 19's six-month
     window the two are exactly equivalent - zero disagreements over 8,077
     lines - but they diverge in wider windows, so the status test is the one
     to keep. StatusCodeNext is nchar(3): TRIM before comparing, or the test
     matches nothing and the query returns no rows.

  6. The two weight columns are NOT quantity x conversion factor.
     dbo.FactSalesDetail's ConversionFactorLB / ConversionFactorKG are wrong on
     about 5% of rows in an item-specific way (ratios of 2.0, 1/22, 60,
     0.9072 ...), and using them puts both weight totals +0.376% high.
     Use BIQL.FactSalesDetail's Unit_Weight_Adj instead. Despite the name it is
     the LINE TOTAL weight, not a per-unit weight, expressed in the unit named
     by UOM_Weight_Adj - so it is NOT multiplied by quantity, only converted:
         LBs = IF(UOM_Weight_Adj='LB', Unit_Weight_Adj,
                                       Unit_Weight_Adj * 2.2045992)
         KGs = IF(UOM_Weight_Adj='KG', Unit_Weight_Adj,
                                       Unit_Weight_Adj / 2.2045992)
     Measured against all 5,675 export rows, this moves the LBs column from
     57.89% to 98.96% of groups exact and both column totals from +0.376% to
     -0.0021%.
     Note 2.2045992 is the Cognos warehouse's constant, deliberately not the
     physically-correct 2.20462262 - 176 / 2.2045992 reproduces Cognos's
     79.833105264 exactly, where the physical constant does not.
     Note also that BIQL.FactSalesDetail_UOM_Fix and the [Fix U/M] / [Fix Qty]
     columns are a red herring for this report: [Fix U/M] is populated on zero
     of 15,823 in-scope lines, and the view and the table carry identical
     conversion factors.

"Ordered Quantity" itself is exact - 5,674 of 5,674 rows, totals agreeing to
the cent.

Residual after all of the above: about 1% of groups (59 LB / 57 KG of 5,675)
where the warehouse and EDW genuinely disagree about an item's weight - not a
formula error. Examples: DF201-JG (Cognos 8.34 LB, EDW 7.0, old basis 14.0 -
neither reproduces it) and 251067CX.S-PD, whose Unit_Weight_Adj of 0.005 KG is
simply wrong in EDW.

------------------------------------------------------------------------------
The .txt files contain the native T-SQL that Power BI actually sends to SQL
Server. Each is directly runnable in SSMS as-is. Note that Shipments.txt returns
LINE grain - see the header comment in that file for how to reproduce the
Cognos row count.
------------------------------------------------------------------------------
