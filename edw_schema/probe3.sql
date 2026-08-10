/* =============================================================================
   probe3 — is the EDW Salesforce feed CURRENT or STALE?
   Date_of_Occurance__c maxes at 2024-08-19 (probe2 A3) and dbo.SF_DimCase is
   empty. Need to know: did the SF->EDW feed stop, or is occurrence-date just a
   sparse field while the feed is live? If stale, the numerator must come from
   ODS Salesforce (live feed) instead of EDW.
   ============================================================================= */


/* --- C: EDW side  (Server EDWPROD.michem.com / DB EDW) ---------------------- */

/* C1 -> p3_edw_freshness.csv
   If MaxCreated / MaxModified are recent (2026), the feed is LIVE and the 2024
   occurrence-date ceiling is just field usage. If they're also ~2024, the feed
   is STALE. */
SELECT  MAX(CreatedDate)            AS MaxCreated,
        MAX(LastModifiedDate)       AS MaxModified,
        MAX(SystemModstamp)         AS MaxSysModstamp,
        MAX(Date_of_Occurance__c)   AS MaxOccurrence,
        COUNT(*)                    AS Rows
FROM    BIQL.TbSF_Case;

/* C2 -> p3_edw_byyear.csv
   Where does the feed stop, and how sparse is occurrence date over time? */
SELECT  YEAR(CreatedDate) AS CreatedYear,
        COUNT(*)          AS Cases,
        SUM(CASE WHEN Date_of_Occurance__c IS NULL THEN 1 ELSE 0 END) AS NullOccDates,
        SUM(CASE WHEN UPPER(LTRIM(RTRIM(Level_1__c))) IN ('PRODUCT QUALITY','PRODUCT DELIVERY')
                 THEN 1 ELSE 0 END) AS ComplaintCases
FROM    BIQL.TbSF_Case
GROUP BY YEAR(CreatedDate)
ORDER BY CreatedYear DESC;


/* --- D: ODS side  (connect to the ODS Salesforce instance, DB ODS_Salesforce)
   Run these on the ODS dev connection, NOT EDW. Adjust DB/schema/table if the
   object name differs (per the data-flow doc it's ODS_Salesforce.dbo.Case). --- */

/* D1 -> p3_ods_freshness.csv
   Does ODS have fresher cases than EDW? This decides the numerator source. */
SELECT  COUNT(*)               AS Rows,
        MAX(CreatedDate)       AS MaxCreated,
        MAX(LastModifiedDate)  AS MaxModified
FROM    dbo.[Case];

/* D2 -> p3_ods_byyear.csv  (optional — same shape as C2 if the columns exist) */
SELECT  YEAR(CreatedDate) AS CreatedYear, COUNT(*) AS Cases
FROM    dbo.[Case]
GROUP BY YEAR(CreatedDate)
ORDER BY CreatedYear DESC;
