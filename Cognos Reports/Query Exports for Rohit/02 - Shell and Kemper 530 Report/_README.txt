==============================================================================
REPORT : 02 - Shell and Kemper 530 Report
==============================================================================

Power BI file : Dashboard - CM Overview LIVE.pbix
                Page 1 of the 5-page "Dashboard - CM Overview LIVE" (reports 02-06 share one semantic model).
Source        : ODSPROD / ODS, SQL Server. Business tables in PRODDTA (JDE).

Queries in this folder (2 .txt):

  Shell_Kemper_530.txt
     The visible "530" detail list (Cognos list "List2", query object "Main w Routing 530").
     Open sales-order lines for company 00010 at next status 525-550, joined to bulk item + planner,
     then FULL OUTER JOINed to work-center routing/capacity.
     Tables: F4211 (SO detail), F42140 (sales rep), F0101 (address book), F4102, F4101 (item master),
     F554101 (item tag), F3312 (capacity pegging), F3313 (capacity load).

  Number_of_Errors.txt
     The "Number of Errors = N" scalar indicator: count of 530 order lines whose planner does not
     decode to a known owner (NEW_OWNER = 'ERROR'). Same pipeline as Shell_Kemper_530.
     Tables: F4211, F0101, F4102, F4101, F554101, F3312, F3313.

  _Reference - Cognos generated SQL (Oracle).sql
     Verbatim copy of the ORIGINAL Oracle SQL that IBM Cognos generated for this
     report. Reference / lineage only - it is NOT what Power BI runs, and it will
     not execute against SQL Server unchanged.

NOTES
-----
`Number of Errors`: COGNOS'S OWN CARD DISAGREES WITH COGNOS'S OWN ROWS.

The Cognos card reads 1,299. The list on the same page shows a couple of dozen red
ERROR rows - 16 on the 2026-07-05 snapshot, 12 on 2026-07-06; the population moves
with the data. 1,299 is a fan-out artefact of the un-grouped COUNT query behind the
card, which counts each ERROR order line once per matching work-centre routing row.

`Number_of_Errors.txt` counts the visible ERROR rows, so the rebuild ties to
Cognos's LIST, not to Cognos's CARD. This is a deliberate correction of a Cognos
defect, not a parity miss - and it is the single most likely false alarm in this
handover. Expect the two numbers to differ, and expect the rebuild to be the one
that is right.

------------------------------------------------------------------------------
The .txt files contain the native T-SQL that Power BI actually sends to SQL Server
(query folding is enabled). Each is directly runnable in SSMS as-is.
------------------------------------------------------------------------------
