/* =============================================================================
   probe5 — hunt for a LIVE Salesforce case source (prod chain frozen 2024-08-19)
   ODSPROD.ODS_SalesForce.dbo.Case and EDWPROD.BIQL.TbSF_Case are both frozen at
   2024-08-19. ssasprod reportedly shows 2026 data -> check the DEV chain, which
   may have a live feed (or be what ssasprod actually processes from).
   Run each block on the noted connection. We just need: does ANY source show a
   2025/2026 case? If yes, that's our numerator source.
   ============================================================================= */


/* --- F1: EDW *DEV* connection  (EDW view that feeds SSAS) -------------------- */
/* p5_edwdev_tbsfcase.csv */
SELECT  @@SERVERNAME          AS ServerName,
        DB_NAME()             AS CurrentDb,
        COUNT(*)              AS Rows,
        MAX(CreatedDate)      AS MaxCreated,
        MAX(LastModifiedDate) AS MaxModified,
        MAX(Date_of_Occurance__c) AS MaxOcc
FROM    BIQL.TbSF_Case;

/* --- F2: EDW *DEV* — is the dbo star case table populated/fresh in dev? ------ */
/* (it was EMPTY in prod) */
SELECT  COUNT(*) AS Rows, MAX(CreatedDate) AS MaxCreated
FROM    dbo.SF_DimCase;


/* --- F3: ODS *DEV* connection, if one exists separate from ODSPROD ----------- */
/* p5_odsdev_case.csv  — adjust DB name if dev ODS differs */
SELECT  @@SERVERNAME         AS ServerName,
        DB_NAME()            AS CurrentDb,
        COUNT(*)             AS Rows,
        MAX(CreatedDate)     AS MaxCreated,
        MAX(LastModifiedDate) AS MaxModified
FROM    [ODS_SalesForce].[dbo].[Case];


/* --- F4: ssasprod (and/or ssasdev) — run as a DAX query in DAX Studio / SSMS --
   This is the one you saw 2026 data in. Confirm whether it's CASES or orders. -- */
-- EVALUATE
-- ROW(
--     "MaxOccurrence", MAX ( SF_Case[Date_of_Occurance__c] ),
--     "MaxCreated",    MAX ( SF_Case[CreatedDate] ),
--     "TotalCases",    COUNTROWS ( SF_Case ),
--     "Cases2025plus", CALCULATE ( COUNTROWS ( SF_Case ), YEAR ( SF_Case[CreatedDate] ) >= 2025 )
-- )
