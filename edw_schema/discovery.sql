/* =============================================================================
   EDW discovery — for the self-sourced Complaints model (EDW Fact/Dim star)
   Run on the jump box in SSMS against:  Server EDWPROD.michem.com  /  DB: EDW
   Read-only (INFORMATION_SCHEMA + sys only). Run each numbered block, then
   right-click the results grid -> "Save Results As..." -> CSV (with headers)
   into this folder (edw_schema\) using the filename noted on each block.

   Goal: see the whole Fact/Dim layer so we can pick the complaints-relevant
   tables (orders denominator + SF case numerator + date/region/customer dims),
   then map the locked business logic onto the real physical columns.
   ============================================================================= */


/* -----------------------------------------------------------------------------
   01  ->  save as  01_tables.csv
   Full inventory of tables AND views, all schemas. We want everything so we
   don't miss an oddly-named table. TABLE_TYPE tells base table vs view.
   ----------------------------------------------------------------------------- */
SELECT  TABLE_CATALOG,
        TABLE_SCHEMA,
        TABLE_NAME,
        TABLE_TYPE
FROM    INFORMATION_SCHEMA.TABLES
ORDER BY TABLE_TYPE, TABLE_SCHEMA, TABLE_NAME;


/* -----------------------------------------------------------------------------
   02  ->  save as  02_rowcounts.csv
   Row counts for BASE TABLES only (fast, from sys metadata — no full scan).
   Lets us spot the real fact tables (big) vs empty/stub tables. Views excluded
   (they have no stored row count).
   ----------------------------------------------------------------------------- */
SELECT  s.name                      AS TABLE_SCHEMA,
        t.name                      AS TABLE_NAME,
        SUM(p.rows)                 AS [RowCount]
FROM    sys.tables       t
JOIN    sys.schemas      s ON s.schema_id = t.schema_id
JOIN    sys.partitions   p ON p.object_id = t.object_id
                          AND p.index_id IN (0,1)   -- heap or clustered = the table itself
GROUP BY s.name, t.name
ORDER BY [RowCount] DESC;


/* -----------------------------------------------------------------------------
   03  ->  save as  03_columns.csv
   Full column schema for the Fact/Dim star layer plus anything that could be
   complaints-relevant (orders, SF cases, date, region/location, company,
   customer, lot, product, item, user). One pass = the schema of every table
   we're likely to touch. Adjust the LIKE list if 01_tables.csv shows other
   naming (e.g. a 'fact'/'dim' schema instead of a name prefix).
   ----------------------------------------------------------------------------- */
SELECT  c.TABLE_SCHEMA,
        c.TABLE_NAME,
        c.ORDINAL_POSITION,
        c.COLUMN_NAME,
        c.DATA_TYPE,
        c.CHARACTER_MAXIMUM_LENGTH,
        c.NUMERIC_PRECISION,
        c.NUMERIC_SCALE,
        c.IS_NULLABLE
FROM    INFORMATION_SCHEMA.COLUMNS c
WHERE   c.TABLE_NAME LIKE 'Fact%'
   OR   c.TABLE_NAME LIKE 'Dim%'
   OR   c.TABLE_NAME LIKE '%Sales%'
   OR   c.TABLE_NAME LIKE '%Order%'
   OR   c.TABLE_NAME LIKE '%Case%'
   OR   c.TABLE_NAME LIKE '%Complaint%'
   OR   c.TABLE_NAME LIKE '%Date%'
   OR   c.TABLE_NAME LIKE '%Calendar%'
   OR   c.TABLE_NAME LIKE '%Customer%'
   OR   c.TABLE_NAME LIKE '%Company%'
   OR   c.TABLE_NAME LIKE '%Region%'
   OR   c.TABLE_NAME LIKE '%Location%'
   OR   c.TABLE_NAME LIKE '%Lot%'
   OR   c.TABLE_NAME LIKE '%Product%'
   OR   c.TABLE_NAME LIKE '%Item%'
   OR   c.TABLE_NAME LIKE '%User%'
ORDER BY c.TABLE_SCHEMA, c.TABLE_NAME, c.ORDINAL_POSITION;


/* -----------------------------------------------------------------------------
   04  ->  save as  04_factsalesdetail_sample.csv   (OPTIONAL but helpful)
   You've already loaded FactSalesDetail — a 20-row sample lets me see the
   actual data shape (how Order Type / company / dates / status look) without
   guessing from column names. Trim columns if it's very wide.
   ----------------------------------------------------------------------------- */
SELECT TOP (20) *
FROM   EDW..FactSalesDetail;   -- adjust schema prefix if 01_tables.csv shows one
