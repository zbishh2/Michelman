/* ============================================================================
   Report 13 - 1 - Ivan LIVE Global Inventory Excel
   SSMS pre-flight for the ODSPROD / "ODS" / PRODDTA (JDE) route.

   Run each block against ODSPROD.ODS. Every block must return rows / resolve
   before the .m files are trusted. This report is a faithful 1:1 port of the
   Cognos-generated Oracle SQL; unlike report 12 there are NO open field-mapping
   questions - every source column is pinned by the generated SQL. These blocks
   only confirm the tables are reachable and the ports behave.
   ============================================================================ */

/* ---- 0. Server / database sanity -------------------------------------- */
SELECT @@SERVERNAME AS ServerName, DB_NAME() AS DbName;   -- expect ODSPROD / ODS

/* ---- 1. Core tables reachable (row counts sane) ----------------------- */
SELECT 'F4102'   AS TableName, COUNT(*) AS Rows FROM PRODDTA.F4102;    -- item branch (all pages)
SELECT 'F4101'   AS TableName, COUNT(*) AS Rows FROM PRODDTA.F4101;    -- item master (all pages)
SELECT 'F554101' AS TableName, COUNT(*) AS Rows FROM PRODDTA.F554101;  -- item tag (Global Bulk / Bulk Item)
SELECT 'F41021'  AS TableName, COUNT(*) AS Rows FROM PRODDTA.F41021;   -- item LOCATION (Inv Summary lot/location grain)
SELECT 'F4108'   AS TableName, COUNT(*) AS Rows FROM PRODDTA.F4108;    -- lot master (Supplier Lot / Expiration / On Hand Date)
SELECT 'F30026'  AS TableName, COUNT(*) AS Rows FROM PRODDTA.F30026;   -- cost components (A1/B1/C1/C2)
SELECT 'F4105'   AS TableName, COUNT(*) AS Rows FROM PRODDTA.F4105;    -- item cost ledger (cost method 'I')
SELECT 'F4311'   AS TableName, COUNT(*) AS Rows FROM PRODDTA.F4311;    -- PO detail (PO page)
SELECT 'F0101'   AS TableName, COUNT(*) AS Rows FROM PRODDTA.F0101;    -- address book (vendor / customer names)
SELECT 'F4211'   AS TableName, COUNT(*) AS Rows FROM PRODDTA.F4211;    -- sales-order detail (Sales page)
SELECT 'F4201'   AS TableName, COUNT(*) AS Rows FROM PRODDTA.F4201;    -- order header (Hold Orders Code)
SELECT 'F4801'   AS TableName, COUNT(*) AS Rows FROM PRODDTA.F4801;    -- work-order header (Work Order / WO Parts)
SELECT 'F3111'   AS TableName, COUNT(*) AS Rows FROM PRODDTA.F3111;    -- work-order parts (WO Parts page)

/* ---- 2. Key columns exist (spot-check the less-common ones) ------------ */
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='PRODDTA' AND TABLE_NAME='F41021'
  AND COLUMN_NAME IN ('LIITM','LIMCU','LILOCN','LILOTN','LILOTS','LIPQOH','LIHCOM')
ORDER BY COLUMN_NAME;                                   -- expect all 7

SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='PRODDTA' AND TABLE_NAME='F30026'
  AND COLUMN_NAME IN ('IEITM','IEMMCU','IELEDG','IECOST','IECSL')
ORDER BY COLUMN_NAME;                                   -- expect all 5

SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='PRODDTA' AND TABLE_NAME='F4108'
  AND COLUMN_NAME IN ('IOLOTN','IORLOT','IOMMEJ','IOOHDJ')
ORDER BY COLUMN_NAME;                                   -- expect all 4

/* ---- 3. Julian conversion sanity (CYYDDD -> date) ---------------------- */
/* The house port is:
     CASE WHEN j>0 THEN DATEADD(DAY,(j%1000)-1,DATEFROMPARTS(1900+(j/1000),1,1)) ELSE NULL END
   Spot-check against a few real PO promised dates. */
SELECT TOP 20
    PDPDDJ AS Julian,
    CASE WHEN PDPDDJ>0 THEN DATEADD(DAY,(PDPDDJ%1000)-1,DATEFROMPARTS(1900+(PDPDDJ/1000),1,1)) ELSE NULL END AS AsDate
FROM PRODDTA.F4311
WHERE PDPDDJ > 0
ORDER BY PDPDDJ DESC;

/* ---- 4. Scaling sanity: /10000 quantities, /1000 order line ------------ */
SELECT TOP 5 SDLNID, SDLNID/1000.0 AS OrderLine, SDPQOR, SDPQOR/10000.0 AS PrimaryQty
FROM PRODDTA.F4211 WHERE SDPQOR > 0;

/* ---- 5. Live population smoke tests (expected rendered counts, as-of xlsx capture)
   These date floors roll (sysdate-based), so today's live counts WILL differ.
   Use for order-of-magnitude, not exact parity to the captured xlsx:
     Page 1  Inventory OH   -> 7,257 rows
     Page 2  PO             -> 7,098 rows
     Page 3  Sales          -> 1,034 rows
     Page 4  Work Order     ->   460 rows
     Page 5  WO Parts List  -> 1,676 rows
     Page 6  OH and Expiry  -> 6,868 rows
   Run each finished .m in Power BI and compare to the matching xlsx sheet.
   NOTE: no expired hard-coded date ceilings exist in this report (all filters are
   relative to sysdate) - it is a genuinely LIVE report, so it should never return
   zero rows the way the forecast twins 08/10 do after their 2026-06-30 ceiling. */
