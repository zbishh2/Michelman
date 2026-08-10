/* =============================================================================
   probe2 — confirm the complaint (numerator) source + lock denominator codes
   Run on the jump box in SSMS:  Server EDWPROD.michem.com  /  DB: EDW
   Read-only. Run each block, save the grid to CSV in edw_schema\ with the
   filename noted. Blocks A* are the priority (they unblock the build).
   ============================================================================= */


/* === A. NUMERATOR SOURCE =====================================================
   dbo.SF_DimCase is empty (0 rows). Find which object actually has the cases.
   ----------------------------------------------------------------------------- */

/* A1 -> p2_sfcase_rowcounts.csv  (THE blocker: which SF case object has rows?) */
SELECT 'BIQL.TbSF_Case'       AS Src, COUNT(*) AS Rows FROM BIQL.TbSF_Case
UNION ALL SELECT 'BIQL.SF_DimCase',      COUNT(*) FROM BIQL.SF_DimCase
UNION ALL SELECT 'BIQL.TbSF_Case_Null',  COUNT(*) FROM BIQL.TbSF_Case_Null
UNION ALL SELECT 'dbo.SF_DimCase',       COUNT(*) FROM dbo.SF_DimCase;

/* A2 -> p2_level1_catalog.csv  (complaint split values + valid flag — exact spacing/casing)
   If A1 shows a different view has the rows, swap the FROM here to match. */
SELECT  Level_1__c,
        Complaint_Valid__c,
        COUNT(*)                    AS Cases,
        COUNT(DISTINCT CaseNumber)  AS DistinctCases
FROM    BIQL.TbSF_Case
GROUP BY Level_1__c, Complaint_Valid__c
ORDER BY Cases DESC;

/* A3 -> p2_case_daterange.csv  (recent coverage? how many cases have no occurrence date?) */
SELECT  MIN(Date_of_Occurance__c) AS MinOcc,
        MAX(Date_of_Occurance__c) AS MaxOcc,
        SUM(CASE WHEN Date_of_Occurance__c IS NULL THEN 1 ELSE 0 END) AS NullOccDates,
        COUNT(*)                   AS Rows
FROM    BIQL.TbSF_Case;


/* === B. DENOMINATOR — lock the real codes ====================================
   FactSalesDetail = line grain, count DISTINCT OrderNum for "orders".
   ----------------------------------------------------------------------------- */

/* B1 -> p2_ordertype_catalog.csv  (exclude list: CM,CO,S5,SA,SL,SR,ST,SK,SQ — confirm) */
SELECT  OrderType, COUNT(*) AS Lines, COUNT(DISTINCT OrderNum) AS DistinctOrders
FROM    dbo.FactSalesDetail
GROUP BY OrderType ORDER BY Lines DESC;

/* B2 -> p2_linetype_catalog.csv  (freight = which LineType? doc assumes 'FS') */
SELECT  LineType, LineTypeDesc, COUNT(*) AS Lines
FROM    dbo.FactSalesDetail
GROUP BY LineType, LineTypeDesc ORDER BY Lines DESC;

/* B3 -> p2_recordtype_catalog.csv  (confirm the exact 'GL Detail' value to drop) */
SELECT  RecordType, COUNT(*) AS Lines
FROM    dbo.FactSalesDetail
GROUP BY RecordType ORDER BY Lines DESC;

/* B4 -> p2_company_catalog.csv  (region map: 10/20 -> Americas/Europe, 30/34/35 -> Asia) */
SELECT  OrderCompany, Company, COUNT(*) AS Lines, COUNT(DISTINCT OrderNum) AS DistinctOrders
FROM    dbo.FactSalesDetail
GROUP BY OrderCompany, Company ORDER BY Lines DESC;

/* B5 -> p2_salesdetail_byyear.csv  (data window + cancelled split, to size the import) */
SELECT  YEAR(GLDate) AS GLYear, Cancelled_Flag,
        COUNT(*) AS Lines, COUNT(DISTINCT OrderNum) AS DistinctOrders
FROM    dbo.FactSalesDetail
GROUP BY YEAR(GLDate), Cancelled_Flag
ORDER BY GLYear DESC, Cancelled_Flag;
