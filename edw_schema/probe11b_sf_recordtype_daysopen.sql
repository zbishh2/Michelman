/* ===========================================================================
   PROBE 11b - Salesforce RecordType LABEL and "# of Days Open"
   Replaces probe11, which hardcoded USE ODS_SalesForce and died on a server
   that has no such database.  This version names no database at all: it sweeps
   every database on whatever server you are connected to.

   RUN IT ON:  ODSDEV, then ODSPROD.  (Harmless on EDWDEV/EDWPROD too, and
   worth one pass each so we get a definitive answer per server.)
   ODS_SalesForce is recorded on ODSPROD (EDW_MODEL.md) and Complaints.m reads
   it from ODSDEV - but "recorded" is 2026-06, so let the probe say, not the doc.

   No USE.  No GO.  Highlight all, execute, send back all four result sets.
   Each one stamps @@SERVERNAME so the outputs can't get mixed up.

   ALREADY RULED OUT LOCALLY (from the 2026-08-05 snapshot's _EDW Columns and
   _EDWDEV Columns - do not redo these):
     - EDWPROD and EDWDEV BIQL.TbSF_Case / SF_DimCase / dbo.SF_DimCase carry
       RecordTypeId (nvarchar(18)) and no label column.
     - No table named *Record* anywhere in EDW on either server.
     - No day/age/open column on any SF_* or TbSF_* table on either server.
   =========================================================================== */

SET NOCOUNT ON;

DECLARE @dbs TABLE (name sysname);
INSERT  @dbs (name)
SELECT  name FROM sys.databases
WHERE   state = 0
  AND   HAS_DBACCESS(name) = 1
  AND   name NOT IN ('master','tempdb','model','msdb');

DECLARE @sql nvarchar(max);


/* --- A. Where am I, and what is here? -------------------------------------
   If ODS_SalesForce is absent from this list, this is the wrong server -
   note it and move on to the next one.  Send this back either way.           */
SELECT @@SERVERNAME AS server_name, DB_NAME() AS connected_db;

SELECT @@SERVERNAME AS server_name, name AS database_name, state_desc, create_date
FROM   sys.databases
WHERE  name NOT IN ('master','tempdb','model','msdb')
ORDER  BY name;


/* --- B. Every Case / RecordType / Complaint table, in every database -------
   This is the "where does Salesforce actually live on this server" answer.
   Returns the table list only - column lists come in D.                      */
SET @sql = N'';
SELECT @sql = @sql + N'
SELECT @@SERVERNAME AS server_name, ''' + name + N''' AS db_name,
       s.name AS sch, t.name AS tbl,
       (SELECT COUNT(*) FROM ' + QUOTENAME(name) + N'.sys.columns c
         WHERE c.object_id = t.object_id) AS col_count,
       (SELECT ISNULL(SUM(p.rows),0) FROM ' + QUOTENAME(name) + N'.sys.partitions p
         WHERE p.object_id = t.object_id AND p.index_id IN (0,1)) AS row_count
FROM   ' + QUOTENAME(name) + N'.sys.tables  t WITH (NOLOCK)
JOIN   ' + QUOTENAME(name) + N'.sys.schemas s ON s.schema_id = t.schema_id
WHERE  t.name LIKE ''%RecordType%''
   OR  t.name LIKE ''%Complaint%''
   OR  t.name = ''Case'' OR t.name LIKE ''%[_]Case'' OR t.name LIKE ''Case[_]%''
   OR  t.name LIKE ''SF[_]%'' OR t.name LIKE ''TbSF[_]%''
UNION ALL '
FROM @dbs;
IF @sql <> N''
BEGIN
    SET @sql = LEFT(@sql, LEN(@sql) - 10) + N' ORDER BY db_name, sch, tbl;';
    EXEC sp_executesql @sql;
END


/* --- C. Any RecordType-ish or days-open-ish COLUMN, in every database ------
   Two failure modes probe11 could not see, both covered here:
     1. the label may sit ON the Case table (RecordTypeName / RecordType_Name)
        rather than in a separate RecordType lookup;
     2. probe11 restricted the day-word search to Case-ish table names, which
        would have hidden it on any table named something else.
   The scope filter here is the SALESFORCE SIGNATURE instead - a table that has
   an nvarchar(18) column called Id.  Every replicated SF object has one; no
   JDE PRODDTA table does.  That keeps ODSPROD from returning thousands of rows
   while still searching every SF object on the server.                       */
SET @sql = N'';
SELECT @sql = @sql + N'
SELECT @@SERVERNAME AS server_name, ''' + name + N''' AS db_name,
       s.name AS sch, t.name AS tbl, c.column_id, c.name AS col,
       ty.name AS typ, c.max_length, c.precision, c.scale, c.is_nullable
FROM   ' + QUOTENAME(name) + N'.sys.tables  t  WITH (NOLOCK)
JOIN   ' + QUOTENAME(name) + N'.sys.schemas s  ON s.schema_id = t.schema_id
JOIN   ' + QUOTENAME(name) + N'.sys.columns c  ON c.object_id = t.object_id
JOIN   ' + QUOTENAME(name) + N'.sys.types   ty ON ty.user_type_id = c.user_type_id
WHERE  ( c.name LIKE ''%RecordType%''
      OR c.name LIKE ''%Day%''   OR c.name LIKE ''%Age%''
      OR c.name LIKE ''%Open%''  OR c.name LIKE ''%Elapsed%''
      OR c.name LIKE ''%Duration%'' OR c.name LIKE ''%Cycle%''
      OR c.name LIKE ''%Aging%'' )
  AND  EXISTS (SELECT 1 FROM ' + QUOTENAME(name) + N'.sys.columns i
               JOIN ' + QUOTENAME(name) + N'.sys.types ity
                 ON ity.user_type_id = i.user_type_id
               WHERE i.object_id = t.object_id
                 AND i.name = ''Id'' AND ity.name = ''nvarchar''
                 AND i.max_length = 36)
UNION ALL '
FROM @dbs;
IF @sql <> N''
BEGIN
    SET @sql = LEFT(@sql, LEN(@sql) - 10) + N' ORDER BY db_name, sch, tbl, column_id;';
    EXEC sp_executesql @sql;
END


/* --- D. FULL column list of every Salesforce Case object on this server ----
   Valuable whatever the answer is: we have never had a column dump of the raw
   SF objects.  BIQL.TbSF_Case is curated down to 139 columns; the raw object
   carries every field Salesforce syncs, which is where a field that "is in
   there now" would be.  Send the whole result set - it becomes the
   ODS_SalesForce half of edw_schema/ and retires this whole class of trip.    */
SET @sql = N'';
SELECT @sql = @sql + N'
SELECT @@SERVERNAME AS server_name, ''' + name + N''' AS db_name,
       s.name AS sch, t.name AS tbl, c.column_id, c.name AS column_name,
       ty.name AS data_type, c.max_length, c.precision, c.scale, c.is_nullable
FROM   ' + QUOTENAME(name) + N'.sys.tables  t  WITH (NOLOCK)
JOIN   ' + QUOTENAME(name) + N'.sys.schemas s  ON s.schema_id = t.schema_id
JOIN   ' + QUOTENAME(name) + N'.sys.columns c  ON c.object_id = t.object_id
JOIN   ' + QUOTENAME(name) + N'.sys.types   ty ON ty.user_type_id = c.user_type_id
WHERE  t.name IN (''Case'', ''RecordType'')
UNION ALL '
FROM @dbs;
IF @sql <> N''
BEGIN
    SET @sql = LEFT(@sql, LEN(@sql) - 10) + N' ORDER BY db_name, sch, tbl, column_id;';
    EXEC sp_executesql @sql;
END


/* ===========================================================================
   FOLLOW-UPS - only after the above says where things are.  Left commented so
   the script above stays one-click.  Fill in <DB> / <COL> from the results.
   ===========================================================================

-- D1. The RecordType lookup itself, and whether every id our cases use resolves.
--     012f4000000DyF9AAK is hardcoded in two shipped measures ([Batch Mfg
--     Issues], and through it [RTFT %]), so confirm its label before we lean on
--     a join.  A non-zero unmatched count means the join would silently blank.
SELECT  c.RecordTypeId,
        COUNT_BIG(*)         AS cases,
        MAX(r.Name)          AS record_type_label,
        MAX(r.DeveloperName) AS developer_name
FROM    <DB>.dbo.[Case]       c WITH (NOLOCK)
LEFT    JOIN <DB>.dbo.RecordType r WITH (NOLOCK) ON r.Id = c.RecordTypeId
GROUP   BY c.RecordTypeId
ORDER   BY cases DESC;

-- D2. Profile the days-open column against the derivation Complaints.m already
--     does as [Days_Case_Open] (CreatedDate -> ClosedDate, counting to today
--     while open).  Three things decide whether we adopt theirs or ship ours:
--       (a) is it populated or mostly NULL;
--       (b) is it frozen at close, or still counting on closed cases;
--       (c) does it agree with the derivation.
--     If (c) disagrees, THEIRS wins - it is the number the business quotes -
--     but we need to see the gap before switching, not after.
SELECT  IsClosed,
        COUNT_BIG(*)                                    AS cases,
        SUM(CASE WHEN <COL> IS NULL THEN 1 ELSE 0 END)  AS null_col,
        MIN(<COL>) AS min_col, MAX(<COL>) AS max_col,
        AVG(CAST(<COL> AS float))                       AS avg_col,
        AVG(CAST(DATEDIFF(day, CreatedDate,
              COALESCE(ClosedDate, GETDATE())) AS float)) AS avg_derived
FROM    <DB>.dbo.[Case] WITH (NOLOCK)
GROUP   BY IsClosed;

SELECT TOP 20 CaseNumber, CreatedDate, ClosedDate, IsClosed,
       <COL> AS their_days,
       DATEDIFF(day, CreatedDate, COALESCE(ClosedDate, GETDATE())) AS our_days,
       ABS(<COL> - DATEDIFF(day, CreatedDate, COALESCE(ClosedDate, GETDATE()))) AS gap
FROM   <DB>.dbo.[Case] WITH (NOLOCK)
WHERE  <COL> IS NOT NULL
ORDER  BY gap DESC;

   =========================================================================== */
