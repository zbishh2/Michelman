/* =============================================================================
   probe4 — ODS Salesforce as the numerator source
   EDW's BIQL.TbSF_Case is frozen at 2024-08-19 (probe3 C1), so the live
   complaint feed must come from ODS. Run these on the ODS connection.
   Table (confirmed by Zack):  [ODS_SalesForce].[dbo].[Case]
   Read-only. Save each grid to CSV in edw_schema\ with the noted filename.
   ============================================================================= */


/* E1 -> p4_ods_case_columns.csv
   Schema of the raw ODS Case object — its column names may differ slightly from
   the EDW view, so confirm the exact field names we'll bind the numerator to.
   NOTE: switch DB context first, then query INFORMATION_SCHEMA unqualified
   (the three-part form ODS_SalesForce.INFORMATION_SCHEMA.COLUMNS errors). */
USE [ODS_SalesForce];
SELECT  ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE,
        CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM    INFORMATION_SCHEMA.COLUMNS
WHERE   TABLE_NAME = 'Case'
ORDER BY ORDINAL_POSITION;


/* E2 -> p4_ods_freshness.csv
   THE confirmation: does ODS run to the present (2026) where EDW stopped at
   2024-08? If MaxCreated/MaxModified are recent, ODS is the live source. */
SELECT  COUNT(*)               AS Rows,
        MAX(CreatedDate)       AS MaxCreated,
        MAX(LastModifiedDate)  AS MaxModified,
        MAX(SystemModstamp)    AS MaxSysModstamp
FROM    [ODS_SalesForce].[dbo].[Case];


/* E3 -> p4_ods_level1.csv
   Re-confirm the numerator on the live data: complaint split + valid flag.
   (If a column name errors, check it against p4_ods_case_columns.csv and adjust.) */
SELECT  Level_1__c,
        Complaint_Valid__c,
        COUNT(*)                    AS Cases,
        COUNT(DISTINCT CaseNumber)  AS DistinctCases
FROM    [ODS_SalesForce].[dbo].[Case]
GROUP BY Level_1__c, Complaint_Valid__c
ORDER BY Cases DESC;


/* E4 -> p4_ods_daterange.csv
   Occurrence-date coverage on the live data (how many recent cases lack it). */
SELECT  MIN(Date_of_Occurance__c) AS MinOcc,
        MAX(Date_of_Occurance__c) AS MaxOcc,
        SUM(CASE WHEN Date_of_Occurance__c IS NULL THEN 1 ELSE 0 END) AS NullOccDates,
        COUNT(*)                   AS Rows
FROM    [ODS_SalesForce].[dbo].[Case];
