==============================================================================
REPORT : 01 - RM Staging at Shell Road 2026 (ODS)
==============================================================================

Power BI file : DEMO - RM Staging at Shell Road 2026.pbix
                Standalone report.
Source        : ODSPROD / ODS, SQL Server. Business tables in PRODDTA (JDE).

Queries in this folder (3 .txt):

  RM_Requirements.txt
     Page 1 "Raw Material requirements": raw materials that are SHORT at CINC - qty on hand,
     total RM needed, and qty required from CIN2. Built from open CINC work-order parts.
     Tables: F4801 (work order), F3111 (WO parts list), F4102 (item branch), F41021 (item location).

  Shortage_Detail.txt
     Page 2 "Shortage Details": for every short material, every on-hand inventory lot at BOTH
     CIN2 and CINC (location / lot / status / qty on hand) so a planner can see where to pull from.
     Tables: F41021, F4102, F4801, F3111.

  WorkOrder_Detail.txt
     Bottom table (Cognos query object "Query1"): only the work orders whose raw material is short -
     WO start, raw material, WO number, FG item. Inner-joins the same shortage subquery as RM_Requirements.
     Tables: F4801, F3111, F4102, F41021.

  (No `Generated SQL (Cognos - raw).sql` exists for this report, so no Oracle
   reference file is included.)

NOTES
-----
NO COGNOS REFERENCE SQL EXISTS FOR THIS REPORT - not in this folder, and not
anywhere in the repo. Report 01 is also the report on which a row-count discrepancy
was raised, so it is the one report with no Cognos-generated Oracle SQL to diff our
T-SQL against. Everything below was established by reading the Cognos report
specification directly.

TWO NUMBERS ON PAGE 1 ARE DELIBERATELY LEFT WRONG, so that the rebuild ties 1:1 to
the live Cognos report:

  * `Total RM Needed` DOUBLE-COUNTS. The Cognos join fans the planned work-order
    demand out by the number of on-hand lot statuses, then sums the open RM. An
    item holding stock in both the `' '` and the `'-'` status reports twice its
    real need.

  * `Qty On Hand CINC` uses AVG across lot statuses, not SUM. 100 in `' '` plus 50
    in `'-'` reports as 75, not 150.

Corrected formulas are in `01\BUILD.md` under "Known Cognos quirks". Do not apply
them without a planner decision - the rebuild stops matching Cognos the moment you
do.

FOUR DISABLED COGNOS FILTERS ARE CORRECTLY NOT IMPLEMENTED. The specification
carries four `use="prohibited"` (disabled) filters: `[2nd Item Number]='POLYMINP'`
on `IOH CIN2`, the same filter again on `IOH All`, `[Status] in (' ','-')` on
`IOH All`, and `[OPEN RM] > [Quantity On Hand]` on `RM Shortage CINC`. All four are
inactive in Cognos. Implementing any of them would over-filter the rebuild.

THE ROW-COUNT DISCREPANCY - CURRENT CONCLUSION

Every `<filterExpression>` in the Cognos specification maps 1:1 onto
`RM_Requirements.txt`: manufacturing branch `CINC`, the work-order status exclusion
list `('93','94','95','97','99','MM','CD')`, open RM greater than zero, FG item not
containing `-`, component not containing `H2O`, the raw-material MPF whitelist
`RRC / REC / RCB / TOL / PKG / RBW`, on-hand lot status `LILOTS in (' ','-')`,
on-hand quantity greater than zero, and the requested-date window. The business-day
window (Thursday and Friday -> +4, Saturday -> +3, otherwise -> +2) is a faithful
port. Nothing in the Cognos filter set is missing from our query, and our query
adds nothing Cognos does not have.

The rows that differed were on page 1's BOTTOM work-order table, not the top
summary table. The DEPLOYED Power BI query was missing the short-material INNER
JOIN that the repo's `WorkOrder_Detail.m` has, so the page rendered 135 rows where
Cognos rendered 15. That was a real defect in the deployed model - not a filter
defect, and not a difference in the SQL you are holding. It was fixed on 2026-07-06
by pushing the repo query into the live partition. Once filtered to the eight short
materials, Power BI matched Cognos 15 rows out of 15, on all four columns. The
`WorkOrder_Detail.txt` in this folder is the corrected query.

The page-1 top summary table ties 8 rows out of 8, every column exact, at full
precision.

Separately, an earlier one-cell difference on that top table was traced to the
Cognos export and the Power BI model having been refreshed at different moments - a
refresh-timing artefact, not a formula or rounding defect. Re-running both the same
evening produced an exact tie. A "last refreshed" timestamp card has since been
added to every page of every report, precisely so this can be settled by looking
rather than by arguing.

------------------------------------------------------------------------------
The .txt files contain the native T-SQL that Power BI actually sends to SQL Server
(query folding is enabled). Each is directly runnable in SSMS as-is.
------------------------------------------------------------------------------
