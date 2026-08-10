/* ============================================================================
   Report 11 - BOM WERCS Integrity Check -- SSMS pre-flight
   Connection: ODSPROD / ODS (SQL Server).  Schema: PRODDTA.
   Run each block; every JDE block should return >0 rows.  The WERCS DISCOVERY
   block is the whole point of this file -- the WERCS table's PRODDTA name is
   UNKNOWN and must be found (or proven absent) before Report.m can be finished.
   ============================================================================ */

/* ---- 1. JDE side: base tables reachable ---------------------------------- */
SELECT TOP 5 * FROM PRODDTA.F3002;   -- Bill of Material Master (bom)
SELECT TOP 5 * FROM PRODDTA.F4101;   -- Item Master (parent & component)
SELECT TOP 5 * FROM PRODDTA.F0006;   -- Business Unit Master (branch type MCSTYL)

/* ---- 2. JDE side: the exact columns the port uses exist ------------------
   2026-07-14: F3002's prefix on ODS is IX*, NOT IB* (IB = F4102) -- confirmed
   by the TOP 5 dump.  IX names below; F3002 also carries 2nd item numbers
   directly (IXKITL parent / IXLITM component).                              */
SELECT TOP 1 IXKIT, IXKITL, IXITM, IXLITM, IXMMCU, IXTBM, IXQNTY, IXEFFT FROM PRODDTA.F3002;
SELECT TOP 1 IMITM, IMLITM, IMSTKT FROM PRODDTA.F4101;
SELECT TOP 1 MCMCU, MCSTYL          FROM PRODDTA.F0006;

/* ---- 3. Sanity: does the JDE side return the screenshot's parents? -------
   Expect 1%CAR934, 161107INT, 161107PX, 161183PX.S, 181139INT, 181139IX ...
   and JDE% for 181139INT / DIH2O = 55.4802 (final tie-out of the /10000 scale;
   already corroborated by the TOP 5 dump: 997500 + 2500 -> 99.75 + 0.25 = 100). */
SELECT
    LTRIM(RTRIM(pim.IMLITM))            AS ParentSecondItem,
    LTRIM(RTRIM(cim.IMLITM))            AS ComponentSecondItem,
    LTRIM(RTRIM(bom.IXMMCU))            AS BranchPlant,
    SUM(ROUND(bom.IXQNTY / 10000.0, 4)) AS JDEPercent
FROM PRODDTA.F3002 bom
    INNER JOIN PRODDTA.F4101 pim ON pim.IMITM = bom.IXKIT
    INNER JOIN PRODDTA.F4101 cim ON cim.IMITM = bom.IXITM
    INNER JOIN PRODDTA.F0006 org ON LTRIM(RTRIM(org.MCMCU)) = LTRIM(RTRIM(bom.IXMMCU))
WHERE pim.IMSTKT = 'M' AND bom.IXTBM = 'M' AND LTRIM(RTRIM(org.MCSTYL)) <> 'LAB'
  AND LTRIM(RTRIM(pim.IMLITM)) IN ('181139INT','161107INT','1%CAR934')
GROUP BY LTRIM(RTRIM(pim.IMLITM)), LTRIM(RTRIM(cim.IMLITM)), LTRIM(RTRIM(bom.IXMMCU))
ORDER BY ParentSecondItem, ComponentSecondItem;

/* ============================================================================
   4. WERCS DISCOVERY -- RESOLVED to a table FAMILY, column mapping still open.
   2026-07-14, David Bubash: "We have the WERCS tables only in ODS" -- the
   PRODDTA.T_* family (standard WERCS product-stewardship schema):
       T_PRODUCTS, T_PROD_COMP, T_PROD_DATA, T_COMP_DATA,
       T_PROD_TEXT, T_TEXT_DETAILS, T_PDF_MSDS
   Working hypothesis for DW_LEGACY.BILL_OF_MATERIAL_WERCS:
       T_PROD_COMP  = the composition rows (parent product -> component + PERCENT)
       T_PRODUCTS   = product master (carries the item number matching F4101.IMLITM)
       T_COMP_DATA  = component identity (if components aren't themselves products)
   Run 4a-4d below and paste the full output back; that fixes the exact column
   names so Report.m's placeholder tokens can be replaced.
   ============================================================================ */

/* 4a. Confirm the seven tables exist + row counts */
SELECT s.name AS [schema], t.name AS [table], SUM(p.rows) AS [rows]
FROM sys.tables t
    JOIN sys.schemas s ON s.schema_id = t.schema_id
    JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE s.name = 'PRODDTA' AND t.name IN
    ('T_PRODUCTS','T_PROD_COMP','T_PROD_DATA','T_COMP_DATA',
     'T_PROD_TEXT','T_TEXT_DETAILS','T_PDF_MSDS')
GROUP BY s.name, t.name
ORDER BY t.name;

/* 4b. Full column dump of the three structurally interesting tables */
SELECT TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE,
       CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'PRODDTA'
  AND TABLE_NAME IN ('T_PRODUCTS','T_PROD_COMP','T_COMP_DATA')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

/* 4c. Sample rows -- shapes + real values */
SELECT TOP 10 * FROM PRODDTA.T_PRODUCTS;
SELECT TOP 10 * FROM PRODDTA.T_PROD_COMP;
SELECT TOP 10 * FROM PRODDTA.T_COMP_DATA;

/* 4d. Bridge probes -- columns known from 4b (2026-07-14):
       T_PROD_COMP.F_PRODUCT = parent product code, F_COMPONENT_ID = component,
       F_PERCENT = composition percent (decimal(20,10)).
       Open question: is F_COMPONENT_ID a JDE item code (bulk BOM) or a
       CAS/chemical ID?  4d-1/4d-2 answer it; 4d-3 proves the item-code bridge;
       4d-4 sanity-checks the percent basis (rows should sum to ~100/parent). */

/* 4d-1. Raw shape of the composition rows */
SELECT TOP 20 F_PRODUCT, F_COMPONENT_ID, F_CAS_NUMBER, F_CHEM_NAME,
              F_PERCENT, F_PERCENT_RANGE, F_UNITS
FROM PRODDTA.T_PROD_COMP;

/* 4d-2. Probe with screenshot items.  Parents (181139INT etc.) SHOULD return
         nothing under F_PRODUCT -- that missing-from-WERCS state is exactly why
         they render as discrepancies.  The component probe tells us whether
         F_COMPONENT_ID speaks JDE item codes. */
SELECT TOP 50 F_PRODUCT, F_COMPONENT_ID, F_CAS_NUMBER, F_PERCENT, F_UNITS
FROM PRODDTA.T_PROD_COMP
WHERE LTRIM(RTRIM(F_COMPONENT_ID)) IN
      ('SH2O','DIH2O','DMEA45','ESC5200','SH2OF','MD353D','GLUT50','CAR934')
   OR LTRIM(RTRIM(F_PRODUCT)) IN
      ('181139INT','161107INT','161107PX','1%CAR934','171195PX.E');

/* 4d-3. Item-code bridge: how many WERCS products match a JDE 2nd item number? */
SELECT COUNT(*) AS wercs_products,
       SUM(CASE WHEN im.IMLITM IS NOT NULL THEN 1 ELSE 0 END) AS matching_jde_items
FROM PRODDTA.T_PRODUCTS p
    LEFT JOIN PRODDTA.F4101 im
        ON LTRIM(RTRIM(im.IMLITM)) = LTRIM(RTRIM(p.F_PRODUCT));

/* 4d-4. Percent basis: per-product sums should land near 100 */
SELECT TOP 20 LTRIM(RTRIM(F_PRODUCT)) AS Product,
       SUM(F_PERCENT) AS PctSum, COUNT(*) AS ComponentRows
FROM PRODDTA.T_PROD_COMP
GROUP BY LTRIM(RTRIM(F_PRODUCT))
ORDER BY Product;

/* 4d-5. Unit basis (4c showed mixed F_UNITS: blank rows look like weight-%,
         'PPH' rows look like parts-per-hundred).  If the DW bulk BOM filtered
         to one basis, Report.m's WERCS SUM needs the same filter. */
SELECT F_UNITS, COUNT(*) AS [rows],
       AVG(F_PERCENT) AS avg_pct, MAX(F_PERCENT) AS max_pct
FROM PRODDTA.T_PROD_COMP
GROUP BY F_UNITS
ORDER BY [rows] DESC;

/* 4d-6. Same product+component pair carrying MORE THAN ONE unit basis?
         (the case where an unfiltered SUM would actually distort) */
SELECT TOP 20 LTRIM(RTRIM(F_PRODUCT)) AS Product,
       LTRIM(RTRIM(F_COMPONENT_ID)) AS Component,
       COUNT(DISTINCT LTRIM(RTRIM(ISNULL(F_UNITS,'')))) AS unit_bases,
       COUNT(*) AS [rows], SUM(F_PERCENT) AS pct_sum
FROM PRODDTA.T_PROD_COMP
GROUP BY LTRIM(RTRIM(F_PRODUCT)), LTRIM(RTRIM(F_COMPONENT_ID))
HAVING COUNT(DISTINCT LTRIM(RTRIM(ISNULL(F_UNITS,'')))) > 1
ORDER BY [rows] DESC;

/* Paste 4d output back to Claude; Report.m's WERCS subquery gets its final
   unit filter (or confirmation that none is needed) from it (BUILD.md §2/§11). */

/* ============================================================================
   5. BRANCH-TYPE DECODE (added 2026-07-14 after first data validation).
   First refresh proved F0006.MCSTYL is NOT the DW's ORGANIZATION.BRANCH_TYPE:
   LABA/LABO/LABC/LABS passed MCSTYL <> 'LAB', and 1%CAR934 vanished (suspected
   NULL MCSTYL on its branch).  The port now excludes LAB* by branch NAME as an
   evidence-based stand-in.  Run 5a/5b to find the true type column and confirm.
   ============================================================================ */

/* 5a. What does F0006 actually say for the branches seen in the data? */
SELECT LTRIM(RTRIM(MCMCU)) AS Branch, MCSTYL, LTRIM(RTRIM(MCDL01)) AS Description
FROM PRODDTA.F0006
WHERE LTRIM(RTRIM(MCMCU)) IN
    ('CINC','CIN2','CIN4','LABA','LABO','LABC','LABS','SING','AUBA',
     'COLR','EUCM','FRES','DANC')
ORDER BY Branch;

/* 5b. Hunt the column where LAB* branches read 'LAB': eyeball the category
       codes.  (DW BRANCH_TYPE is likely one of MCRP01..MCRP30.) */
SELECT TOP 20 LTRIM(RTRIM(MCMCU)) AS Branch, MCSTYL,
       MCRP01, MCRP02, MCRP03, MCRP04, MCRP05, MCRP06, MCRP07, MCRP08, MCRP09, MCRP10
FROM PRODDTA.F0006
WHERE LTRIM(RTRIM(MCMCU)) IN ('CINC','CIN2','LABO','LABA','LABS','SING','AUBA')
ORDER BY Branch;

/* 5c. Which branch owns 1%CAR934's BOM?  (It is in the Cognos render but was
       dropped by the first port — confirms the NULL-style / join-drop theory.) */
SELECT LTRIM(RTRIM(pim.IMLITM)) AS Parent, LTRIM(RTRIM(bom.IXMMCU)) AS Branch,
       org.MCSTYL, LTRIM(RTRIM(pim.IMSTKT)) AS ParentStockType
FROM PRODDTA.F3002 bom
    INNER JOIN PRODDTA.F4101 pim ON pim.IMITM = bom.IXKIT
    LEFT  JOIN PRODDTA.F0006 org ON LTRIM(RTRIM(org.MCMCU)) = LTRIM(RTRIM(bom.IXMMCU))
WHERE LTRIM(RTRIM(pim.IMLITM)) = '1%CAR934' AND bom.IXTBM = 'M'
GROUP BY LTRIM(RTRIM(pim.IMLITM)), LTRIM(RTRIM(bom.IXMMCU)), org.MCSTYL, LTRIM(RTRIM(pim.IMSTKT));
