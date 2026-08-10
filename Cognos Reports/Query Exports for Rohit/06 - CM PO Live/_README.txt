==============================================================================
REPORT : 06 - CM PO Live
==============================================================================

Power BI file : Dashboard - CM Overview LIVE.pbix
                Page 5 of "Dashboard - CM Overview LIVE".
Source        : ODSPROD / ODS, SQL Server. Business tables in PRODDTA (JDE).

Queries in this folder (1 .txt):

  CM_PO_Live.txt
     The main PO table (Cognos list "List1", query object "PO Summary"). Open purchase-order lines
     (open qty > 0) whose promised date falls within the last 90 days, with vendor name, next status
     and REGION. Restricted to the bulk-item whitelist.
     Tables: F4311 (PO detail), F0101 (vendor), F4102, F4101, F554101.

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

On this report, `[REGION] in ?Select_Region?` appears twice, identically: ACTIVE
(`use="optional"`) on the live `Purchase Orders` query, and DISABLED
(`use="prohibited"`) on `PO Summary`. Reading either copy alone gives the wrong
answer about whether the report filters on region.

Because the active copy is optional, the default - no region selected - returns all
regions. The Power BI slicer is configured to allow "no selection = show all" to
match.

------------------------------------------------------------------------------
The .txt files contain the native T-SQL that Power BI actually sends to SQL Server
(query folding is enabled). Each is directly runnable in SSMS as-is.
------------------------------------------------------------------------------
