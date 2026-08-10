/* =============================================================================
   probe7 — resolve display names for the two ID-gap columns on the complaint case
   Run on ODSDEV (the LIVE dev Salesforce chain — same server family Complaints.m
   now reads via EDWDEV). Database: [ODS_SalesForce] (1 table per SF object, same
   place dbo.Case lives). Goal: confirm Product2 + User exist, find the name column,
   and verify the join from Case actually matches (keys are NOT assumed clean).
   Save each grid to edw_schema\ as the noted CSV.
   ============================================================================= */

USE [ODS_SalesForce];

/* G1 -> p7_product2_cols.csv  — does Product2 exist? what's the name/code column? */
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM   INFORMATION_SCHEMA.COLUMNS
WHERE  TABLE_NAME = 'Product2'
ORDER  BY ORDINAL_POSITION;

/* G2 -> p7_user_cols.csv  — does User exist? what's the name column? */
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM   INFORMATION_SCHEMA.COLUMNS
WHERE  TABLE_NAME = 'User'
ORDER  BY ORDINAL_POSITION;

/* G3 -> p7_product_join.csv  — coverage: how many complaint product IDs resolve?
   (18- vs 15-char ID mismatch shows up here as Matched < HasProductId.) */
SELECT
    COUNT(*)                                              AS ComplaintCases,
    SUM(CASE WHEN c.Product_Code__c IS NOT NULL THEN 1 ELSE 0 END) AS HasProductId,
    SUM(CASE WHEN p.Id IS NOT NULL THEN 1 ELSE 0 END)     AS Matched
FROM   dbo.[Case] c
LEFT   JOIN dbo.Product2 p ON p.Id = c.Product_Code__c
WHERE  UPPER(LTRIM(RTRIM(c.Level_1__c))) IN ('PRODUCT QUALITY','PRODUCT DELIVERY');

/* G4 -> p7_champion_join.csv  — coverage: how many champion IDs resolve to a user? */
SELECT
    COUNT(*)                                          AS ComplaintCases,
    SUM(CASE WHEN c.Champion__c IS NOT NULL THEN 1 ELSE 0 END) AS HasChampionId,
    SUM(CASE WHEN u.Id IS NOT NULL THEN 1 ELSE 0 END) AS Matched
FROM   dbo.[Case] c
LEFT   JOIN dbo.[User] u ON u.Id = c.Champion__c
WHERE  UPPER(LTRIM(RTRIM(c.Level_1__c))) IN ('PRODUCT QUALITY','PRODUCT DELIVERY');

/* G5 -> p7_sample.csv  — eyeball the resolved names on real complaint rows.
   (Adjust p.Name / u.Name / p.ProductCode if G1/G2 show different column names.) */
SELECT TOP (30)
    c.CaseNumber,
    c.Product_Code__c, p.Name AS ProductName, p.ProductCode,
    c.Champion__c,     u.Name AS ChampionName
FROM   dbo.[Case] c
LEFT   JOIN dbo.Product2 p ON p.Id = c.Product_Code__c
LEFT   JOIN dbo.[User]   u ON u.Id = c.Champion__c
WHERE  UPPER(LTRIM(RTRIM(c.Level_1__c))) IN ('PRODUCT QUALITY','PRODUCT DELIVERY')
ORDER  BY c.Date_of_Occurance__c DESC;
