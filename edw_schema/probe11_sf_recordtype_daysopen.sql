/* ===========================================================================
   PROBE 11 - Salesforce RecordType LABEL and "# of Days Open"
   Written 2026-08-07.  Run on ODSDEV first, then ODSPROD.  Also worth a pass
   on EDWDEV / EDWPROD (sections 1-3 are server-agnostic).

   WHY A PROBE AT ALL - what was already ruled out locally, don't redo it:
     - EDWPROD  BIQL.TbSF_Case / SF_DimCase / dbo.SF_DimCase  ->  RecordTypeId
       only (nvarchar(18), the raw SF 18-char id).  No Name, no Label.
     - EDWDEV   BIQL.TbSF_Case (139 cols, the live SF chain the dashboards
       actually read)  ->  identical: RecordTypeId, no label.
     - No table anywhere in EDW has "Record" in its name, so there is no
       RecordType dimension on either EDW server.
     - No days/age/open column on any SF_* or TbSF_* table on either server.
       The only near-misses are ClosedDate, IsClosed and the unrelated
       Age_Open_Monitor_Corrective_Actions__c.
     (Source: the 2026-08-05 snapshot's _EDW Columns and _EDWDEV Columns.)

   SO THE ONE PLACE LEFT IS ODS_SalesForce - the RAW Salesforce object mirror
   (dbo.Product2, dbo.User, dbo.Case).  It is the only database in play that no
   local dump covers: _ODS Columns filters to TABLE_SCHEMA IN ('PRODDTA',
   'PRODCTL') on ODS, so ODS_SalesForce has never been dumped.  Raw objects
   carry every field; BIQL.TbSF_Case is a curated view that drops most of them.
   That is exactly the shape of "it's in there now but not in our model".

   NAMING NOTE - "# of Days Open" is a Salesforce UI LABEL.  The COLUMN name is
   the API name, which cannot start with a digit, so expect one of
   Days_Open__c / X_of_Days_Open__c / Number_of_Days_Open__c / Case_Age__c /
   Days_to_Close__c.  Section 3 searches on the words, not a guess.

   FILL IN below and send back sections 1-5 as-is.
   =========================================================================== */


/* --- 1. What databases are on this server? --------------------------------
   Confirms ODS_SalesForce exists here and gets its exact name/casing.        */
SELECT name, state_desc, create_date
FROM   sys.databases
WHERE  name NOT IN ('master','tempdb','model','msdb')
ORDER  BY name;


/* --- 2. Any RecordType-ish table, in EVERY database on this server ---------
   Salesforce's standard RecordType object replicates as dbo.RecordType with
   Id / Name / DeveloperName / SobjectType / IsActive.  Name is the label.     */
DECLARE @sql nvarchar(max) = N'';
SELECT @sql = @sql + N'
SELECT ''' + QUOTENAME(name) + N''' AS db, s.name AS sch, t.name AS tbl,
       c.column_id, c.name AS col, ty.name AS typ, c.max_length
FROM ' + QUOTENAME(name) + N'.sys.tables t WITH (NOLOCK)
JOIN ' + QUOTENAME(name) + N'.sys.schemas s ON s.schema_id = t.schema_id
JOIN ' + QUOTENAME(name) + N'.sys.columns c ON c.object_id = t.object_id
JOIN ' + QUOTENAME(name) + N'.sys.types   ty ON ty.user_type_id = c.user_type_id
WHERE t.name LIKE ''%RecordType%''
UNION ALL '
FROM sys.databases
WHERE state = 0 AND name NOT IN ('master','tempdb','model','msdb');
SET @sql = LEFT(@sql, LEN(@sql) - 10) + N' ORDER BY db, sch, tbl, column_id;';
EXEC sp_executesql @sql;


/* --- 3. Any DAYS/AGE/OPEN column, in EVERY database on this server ---------
   Catches the "# of Days Open" field whatever its API name turned out to be.
   Restricted to Case-ish and SF-ish tables so the result stays readable.      */
DECLARE @sql2 nvarchar(max) = N'';
SELECT @sql2 = @sql2 + N'
SELECT ''' + QUOTENAME(name) + N''' AS db, s.name AS sch, t.name AS tbl,
       c.name AS col, ty.name AS typ, c.precision, c.scale
FROM ' + QUOTENAME(name) + N'.sys.tables t WITH (NOLOCK)
JOIN ' + QUOTENAME(name) + N'.sys.schemas s ON s.schema_id = t.schema_id
JOIN ' + QUOTENAME(name) + N'.sys.columns c ON c.object_id = t.object_id
JOIN ' + QUOTENAME(name) + N'.sys.types   ty ON ty.user_type_id = c.user_type_id
WHERE (c.name LIKE ''%Day%'' OR c.name LIKE ''%Age%''
       OR c.name LIKE ''%Open%'' OR c.name LIKE ''%Elapsed%''
       OR c.name LIKE ''%Duration%'' OR c.name LIKE ''%Cycle%'')
  AND (t.name LIKE ''%Case%'' OR t.name LIKE ''%SF[_]%'' OR t.name LIKE ''%Complaint%'')
UNION ALL '
FROM sys.databases
WHERE state = 0 AND name NOT IN ('master','tempdb','model','msdb');
SET @sql2 = LEFT(@sql2, LEN(@sql2) - 10) + N' ORDER BY db, sch, tbl, col;';
EXEC sp_executesql @sql2;


/* ===========================================================================
   SECTIONS 4-6 need ODS_SalesForce.  Skip them on a server that has no such
   database (section 1 will have told you).
   =========================================================================== */
USE ODS_SalesForce;   -- adjust if section 1 shows a different name
GO


/* --- 4. FULL column list of the raw Case object ---------------------------
   This is the important one.  BIQL.TbSF_Case is curated down to 139 columns;
   the raw object has everything Salesforce syncs.  Send the whole result -
   it becomes the ODS_SalesForce half of edw_schema/, which we have never had. */
SELECT c.column_id, c.name AS column_name, ty.name AS data_type,
       c.max_length, c.precision, c.scale, c.is_nullable
FROM   sys.columns c WITH (NOLOCK)
JOIN   sys.types  ty ON ty.user_type_id = c.user_type_id
WHERE  c.object_id = OBJECT_ID('dbo.Case')
ORDER  BY c.column_id;


/* --- 5. If dbo.RecordType exists, this is the whole lookup ----------------
   ~a few dozen rows.  Name is the label we want.  The row we already know we
   need is 012f4000000DyF9AAK = the Batch Mfg Issue type that gates [RTFT %]
   and [Batch Mfg Issues] - confirm its Name comes back as expected, because
   that id is hardcoded in two shipped measures.                              */
SELECT Id, Name, DeveloperName, SobjectType, IsActive, IsPersonType
FROM   dbo.RecordType WITH (NOLOCK)
ORDER  BY SobjectType, Name;

/* Coverage check: does every RecordTypeId our cases actually use resolve to a
   label?  A non-zero "unmatched" here means the join would silently blank.    */
SELECT  c.RecordTypeId,
        COUNT_BIG(*)                  AS cases,
        MAX(r.Name)                   AS record_type_label,
        MAX(r.DeveloperName)          AS developer_name
FROM    dbo.[Case] c WITH (NOLOCK)
LEFT    JOIN dbo.RecordType r WITH (NOLOCK) ON r.Id = c.RecordTypeId
GROUP   BY c.RecordTypeId
ORDER   BY cases DESC;


/* --- 6. If a days-open column turned up in section 3, profile it -----------
   Replace <COL> with the real name.  We need to know three things before it
   can back an "Average Open Days" measure:
     (a) is it populated, or NULL on most rows;
     (b) is it frozen at close, or does it keep counting for closed cases;
     (c) does it agree with the derived CreatedDate->ClosedDate arithmetic
         that edw_model/Complaints.m already does as [Days_Case_Open].
   If (c) disagrees, THEIRS wins - it is the number the business quotes - but
   we need to see the gap before switching.                                   */
/*
SELECT  IsClosed,
        COUNT_BIG(*)                                   AS cases,
        SUM(CASE WHEN <COL> IS NULL THEN 1 ELSE 0 END) AS null_col,
        MIN(<COL>)                                     AS min_col,
        MAX(<COL>)                                     AS max_col,
        AVG(CAST(<COL> AS float))                      AS avg_col,
        AVG(CAST(DATEDIFF(day, CreatedDate,
              COALESCE(ClosedDate, GETDATE())) AS float)) AS avg_derived
FROM    dbo.[Case] WITH (NOLOCK)
GROUP   BY IsClosed;

-- worst 20 disagreements, so we can see WHY they differ rather than guess
SELECT TOP 20 CaseNumber, CreatedDate, ClosedDate, IsClosed, <COL> AS their_days,
       DATEDIFF(day, CreatedDate, COALESCE(ClosedDate, GETDATE())) AS our_days,
       ABS(<COL> - DATEDIFF(day, CreatedDate, COALESCE(ClosedDate, GETDATE()))) AS gap
FROM   dbo.[Case] WITH (NOLOCK)
WHERE  <COL> IS NOT NULL
ORDER  BY gap DESC;
*/
