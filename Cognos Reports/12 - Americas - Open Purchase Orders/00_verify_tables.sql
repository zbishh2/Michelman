/* ============================================================================
   Report 12 - Americas - Open Purchase Orders
   SSMS pre-flight for the ODSPROD / ODS / PRODDTA (JDE) route.

   Run each block against ODSPROD.ODS. Every block must return rows / resolve
   before the .m files are trusted. Blocks flagged "RESOLVE" settle an open
   field-mapping question called out in BUILD.md; capture the answer there.
   ============================================================================ */

/* ---- 0. Server / database sanity -------------------------------------- */
SELECT @@SERVERNAME AS ServerName, DB_NAME() AS DbName;   -- expect ODSPROD / ODS

/* ---- 1. Core tables reachable (row counts sane) ----------------------- */
SELECT 'F4311'  AS TableName, COUNT(*) AS Rows FROM PRODDTA.F4311;   -- PO detail (page 1)
SELECT 'F4211'  AS TableName, COUNT(*) AS Rows FROM PRODDTA.F4211;   -- SO detail (page 2)
SELECT 'F42199' AS TableName, COUNT(*) AS Rows FROM PRODDTA.F42199;  -- SO ledger (page 3)  *** may not exist / may be empty ***
SELECT 'F4101'  AS TableName, COUNT(*) AS Rows FROM PRODDTA.F4101;   -- item master
SELECT 'F4102'  AS TableName, COUNT(*) AS Rows FROM PRODDTA.F4102;   -- item branch
SELECT 'F554101' AS TableName, COUNT(*) AS Rows FROM PRODDTA.F554101;-- item tag (Global Bulk Item)
SELECT 'F0101'  AS TableName, COUNT(*) AS Rows FROM PRODDTA.F0101;   -- address book (vendor / customer / carrier / rep names)
SELECT 'F0006'  AS TableName, COUNT(*) AS Rows FROM PRODDTA.F0006;   -- business unit master
SELECT 'F0015'  AS TableName, COUNT(*) AS Rows FROM PRODDTA.F0015;   -- currency exchange rates (USD conversion) *** verify name ***

/* ---- 2. RESOLVE: F42199 column prefix (SH* standard vs SD* on this box) --
   Reports 08/10 found F42119 on THIS instance uses SD* names, not the JDE
   standard SH* (SHKCOO -> "Invalid column name"). F42199 may be the same.
   Inspect the real column list and set the page-3 query prefix accordingly. */
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'PRODDTA' AND TABLE_NAME = 'F42199'
ORDER BY ORDINAL_POSITION;

/* ---- 3. RESOLVE: F4311 quantity / amount / date fields for page 1 -------
   Report 06 validated PDPQOR (ordered), PDSQOR (2nd), PDUOPN (open), PDDRQJ
   (requested), PDPDDJ (promised), PDMCU/PDDOCO/PDLNID/PDLITM/PDKCOO/PDDCTO/PDAN8.
   The NEW page-12 columns below are NOT yet proven — confirm they exist and
   carry the intended meaning:
     PO Date            -> PDTRDJ (order/transaction date, Julian)
     Receipt Date       -> PDRCDJ (PO_DETAIL_CLOSED_DATE)  ** candidate **
     Quantity Cancelled -> PDUCAN ? (or derive PDPQOR-PDUOPN-PDUREC)  ** candidate **
     Spend Amount       -> PDAEXP (domestic extended cost)  ** candidate **
     Purchase Amount    -> PDAOPN (open amount) ?            ** candidate **
     currency code      -> PDCRCD ;  domestic/foreign flag   */
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'PRODDTA' AND TABLE_NAME = 'F4311'
  AND COLUMN_NAME IN ('PDTRDJ','PDRCDJ','PDDGL','PDADDJ','PDUCAN','PDUREC','PDPQOR',
                      'PDSQOR','PDUOPN','PDAEXP','PDAOPN','PDFEA','PDCRCD','PDPRRC','PDUNCS')
ORDER BY COLUMN_NAME;

/* ---- 4. RESOLVE: leadtime level source (page 1 "Lead Time Level") -------
   DW_LEGACY ITEM.LEADTIME_LEVEL_. Candidate JDE: F4102.IBLTLV (item-branch
   leadtime level) or F4101 leadtime. Confirm which is populated. */
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='PRODDTA' AND TABLE_NAME='F4102'
  AND COLUMN_NAME IN ('IBLTLV','IBLTPU','IBLTMF') ORDER BY COLUMN_NAME;

/* ---- 5. RESOLVE: LB weight conversion (PO/SO "... LBs" columns) ---------
   DW_LEGACY multiplied primary qty by CONVERSION_FACTOR_LB. JDE has no single
   precomputed factor. Candidate sources: F41002 (item UOM conversion, primary
   UOM -> LB) or F4101.IMITWT / IMWUMD (unit weight + weight UOM). Confirm one. */
SELECT TOP 20 * FROM PRODDTA.F41002
WHERE UMUM  IN ('LB','LB ') OR UMRUM IN ('LB','LB ');   -- item UOM conversion rows to LB

/* ---- 6. RESOLVE: currency -> USD (page 1 Spend / Purchase Amount USD) ----
   DW joined FIN_CURRENCY_CONVERSION: FROM=line currency, TO='USD', RATE_TYPE='M',
   PO_DATE between EFFECTIVE_START and EFFECTIVE_END. Confirm F0015 key fields and
   whether a "rate type" concept exists here (JDE F0015 has no native rate-type). */
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='PRODDTA' AND TABLE_NAME='F0015' ORDER BY ORDINAL_POSITION;

/* ---- 7. RESOLVE: page-2 enrichments ------------------------------------
   CSR Name  = customer ship-to sales rep "type 9" name  -> F03012 / F42140 chain
   TM Name   = ORDER_ACTIVITY.SALES_REP_ID -> address-book mailing name
   Carrier   = ORDER_ACTIVITY_MEASURE.CARRIER_NUMBER_ -> F0101.ABALPH
   Freight   = F4211.SDFRTH
   Cust Seg  = ship-to F0101 category code AC06 (ABAC06)
   Confirm the F4211 field that holds SALES_REP_ID and CARRIER_NUMBER. */
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='PRODDTA' AND TABLE_NAME='F4211'
  AND COLUMN_NAME IN ('SDSLSM','SDASN','SDCARS','SDFRTH','SDSHAN','SDAN8','SDVR01',
                      'SDDSC1','SDDEL1','SDDEL2','SDTRDJ','SDPDDJ','SDDRQJ','SDNXTR',
                      'SDPQOR','SDSQOR','SDUOM1','SDUOM2','SDEMCU','SDLITM')
ORDER BY COLUMN_NAME;

/* ---- 8. Live population smoke tests (expected rendered counts) ----------
   Page 1 (PO):            ~3,749 rows   (Promised >= today-365, branch in CINC/CIN2/CIN4, type OP/OD)
   Page 2 (Sales Orders):  ~12,196 rows  (Due between today-365 and today+30, branch CINC/CIN2/CIN4)
   Page 3 (Sales Ledger):  ~91,613 rows  (Ordered >= 2024-01-01, company 00010, next 520/525/530, not SCHED, DISTINCT)
   These are as-of the captured xlsx; today's live counts will differ because the
   date floors roll. Use them for order-of-magnitude, not exact parity. */
