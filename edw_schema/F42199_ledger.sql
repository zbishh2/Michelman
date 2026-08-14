/* =============================================================================
   F42199 — JDE Sales Order Detail Ledger File
   Purpose: pull the change history for sales order lines, including the
            reason code recorded each time the Promised Delivery Date changes.

   NOTE: F42199 is NOT in EDWPROD/EDW. It lives in the JDE business-data DB
         (or an ODS copy). Run STEP 1 first to confirm the database, schema,
         and exact column aliases, THEN adjust + run STEP 2.

   JDE specifics:
     - Date columns are Julian (CYYDDD) integers -> converted inline below.
     - F42199 uses the F4211 layout with the "SD" alias prefix.
     - VERIFY every alias (especially the reason code) against STEP 1 output.
   ============================================================================= */


/* -----------------------------------------------------------------------------
   STEP 1 — locate F42199 and list its columns
   ----------------------------------------------------------------------------- */

-- 1a. Find which database has it (run on the JDE/ODS server)
SELECT DB_NAME(database_id) AS DbName
FROM   sys.master_files;

-- 1a-2. dbo.F42199 errored "Invalid object name" -> find the real schema/name.
--       JDE tables in ODS may use a different schema (CRPDTA/PRODDTA/jde/etc.)
--       or a renamed object. Run these to locate it:
USE [ODS];

-- (i) any table/view whose name contains 42199, across ALL schemas:
SELECT  TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE
FROM    INFORMATION_SCHEMA.TABLES
WHERE   TABLE_NAME LIKE '%42199%'
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- (ii) sanity check: how are the sales-order JDE tables named here?
--      (look for F4211 / F42119 to learn the schema + naming convention)
SELECT  TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE
FROM    INFORMATION_SCHEMA.TABLES
WHERE   TABLE_NAME LIKE '%4211%'
     OR TABLE_NAME LIKE '%42119%'
     OR TABLE_NAME LIKE '%Ledger%'
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- 1b. Once located, list its columns (replace <schema>.<table> from (i) above):
SELECT  TABLE_SCHEMA, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE,
        CHARACTER_MAXIMUM_LENGTH
FROM    INFORMATION_SCHEMA.COLUMNS
WHERE   TABLE_NAME = 'F42199'      -- <-- update to the actual TABLE_NAME from (i)
ORDER BY ORDINAL_POSITION;


/* -----------------------------------------------------------------------------
   STEP 2 — query the ledger (promised-date change history)
   Fill in @OrderNo / @OrderType. Verify aliases against STEP 1 first.
   ----------------------------------------------------------------------------- */

USE [ODS];

-- CONFIRMED from STEP 1:  schema = PRODDTA, table = F42199, alias prefix = SL.
-- Dates are JDE Julian (CYYDDD) ints:  date = Jan-1 of (1900 + CYY) + (DDD-1) days.


/* -----------------------------------------------------------------------------
   STEP 1.5 — DIAGNOSTICS (run these first; the example order returned 0 rows)
   ----------------------------------------------------------------------------- */

-- !! PRODDTA = LIVE PRODUCTION JDE. Table is 19.4M rows. Every query below uses
--    WITH (NOLOCK) and a recent-date filter (@SinceJul) to keep scans cheap and
--    avoid blocking the ERP. Widen @SinceJul only if you must.
--    Julian: 126001 = 2026-001, 125001 = 2025-001, 124001 = 2024-001.
DECLARE @SinceJul int = 125001;   -- only ledger rows updated on/after 2025-001

-- D1. (already run) 19,356,664 rows; SLUPMJ 111350 (2011-12-16) .. 126161 (2026-06-10).


/* =============================================================================
   *** FAST PATH ***  Scan F42199 ONCE into #led, then explore #led instantly.
   #led lives for the life of THIS SSMS window's connection. Run this block once
   (keep the tab/connection open); every query after it is sub-second.
   Re-run only if you reconnect or want a wider window.
   ============================================================================= */
IF OBJECT_ID('tempdb..#led') IS NOT NULL DROP TABLE #led;

SELECT  SLKCOO AS OrderCompany, SLDOCO AS OrderNumber, SLDCTO AS OrderType,
        SLSFXO AS OrderSuffix, SLLNID AS LineNumber, SLMCU AS BusinessUnit,
        SLLITM AS Item, SLLNTY AS LineType, SLNXTR AS NextStatus,
        SLLTTR AS LastStatus, SLRCD AS ReasonCode,
        SLPDDJ, SLOPDJ, SLDRQJ, SLRSDJ, SLADDJ, SLCNDJ, SLDGL,   -- raw Julian dates
        SLUPMJ, SLTDAY, SLUSER AS UpdatedByUser, SLPID AS ProgramID, SLJOBN AS WorkStation
INTO    #led
FROM    PRODDTA.F42199 WITH (NOLOCK)
WHERE   SLUPMJ >= 125001;          -- 2025+; lower to 124001 (2024) / 122001 (2022) for more

CREATE CLUSTERED INDEX IX_led ON #led (OrderNumber, OrderType, LineNumber, SLUPMJ, SLTDAY);
CREATE INDEX IX_led_rcd ON #led (ReasonCode);

-- ---- now everything below is instant. Examples against #led: -------------------

-- F1. reason codes in use (was 3a):
SELECT ReasonCode, COUNT(*) AS Rows
FROM   #led
WHERE  ReasonCode <> '' AND ReasonCode IS NOT NULL
GROUP BY ReasonCode ORDER BY Rows DESC;

-- F2. order types in use (was D2):
SELECT OrderType, COUNT(*) AS Rows, COUNT(DISTINCT OrderNumber) AS DistinctOrders
FROM   #led GROUP BY OrderType ORDER BY Rows DESC;

-- F3. lines whose Promised Delivery Date actually changed (was D3):
SELECT TOP (50) OrderCompany, OrderNumber, OrderType, LineNumber,
       COUNT(*) AS LedgerRows, COUNT(DISTINCT SLPDDJ) AS DistinctPromisedDates,
       COUNT(DISTINCT ReasonCode) AS DistinctReasonCodes
FROM   #led
GROUP BY OrderCompany, OrderNumber, OrderType, LineNumber
HAVING COUNT(DISTINCT SLPDDJ) > 1
ORDER BY DistinctPromisedDates DESC, LedgerRows DESC;

-- F4. inspect one reason code (set the literal):
SELECT TOP (200) OrderNumber, OrderType, LineNumber, Item, ReasonCode,
       DATEADD(DAY,(SLPDDJ%1000)-1,DATEFROMPARTS(1900+(SLPDDJ/1000),1,1)) AS PromisedDeliveryDate,
       DATEADD(DAY,(SLUPMJ%1000)-1,DATEFROMPARTS(1900+(SLUPMJ/1000),1,1)) AS UpdatedDate,
       SLTDAY AS UpdatedTime, UpdatedByUser
FROM   #led
WHERE  ReasonCode = '001'          -- <- set from F1
ORDER BY UpdatedDate DESC, UpdatedTime DESC;

-- F5. full change sequence for one order (instant; from F3 pick):
SELECT OrderNumber, OrderType, LineNumber, ReasonCode,
       DATEADD(DAY,(SLPDDJ%1000)-1,DATEFROMPARTS(1900+(SLPDDJ/1000),1,1)) AS PromisedDeliveryDate,
       DATEADD(DAY,(SLUPMJ%1000)-1,DATEFROMPARTS(1900+(SLUPMJ/1000),1,1)) AS UpdatedDate,
       SLTDAY AS UpdatedTime, UpdatedByUser, ProgramID
FROM   #led
WHERE  OrderNumber = 0 /*<-set*/ AND OrderType = 'S4'
ORDER BY LineNumber, UpdatedDate, UpdatedTime;

-- F6. Is SLRCD a returns/credit code? show reason-code coverage by order type.
--     Expect reason codes to cluster on CM/SR/CO (returns/credits), proving
--     SLRCD is NOT the promised-date-change reason.
SELECT OrderType,
       COUNT(*) AS Rows,
       SUM(CASE WHEN ReasonCode <> '' THEN 1 ELSE 0 END) AS RowsWithReason
FROM   #led
GROUP BY OrderType
ORDER BY RowsWithReason DESC;

-- F7. THE proof: of lines whose Promised Delivery Date actually changed, how
--     many ever carry ANY reason code? If ~0, the date-change reason is NOT
--     in SLRCD and lives in another field/table.
SELECT COUNT(*) AS ChangedLines,
       SUM(CASE WHEN HasReason > 0 THEN 1 ELSE 0 END) AS ChangedLinesWithAnyReason
FROM (
    SELECT OrderNumber, OrderType, LineNumber,
           COUNT(DISTINCT SLPDDJ) AS DistinctPromised,
           SUM(CASE WHEN ReasonCode <> '' THEN 1 ELSE 0 END) AS HasReason
    FROM   #led
    GROUP BY OrderNumber, OrderType, LineNumber
    HAVING COUNT(DISTINCT SLPDDJ) > 1
) x;


/* ===========================================================================
   The queries below (D2/D3/STEP 2-4) hit PRODDTA.F42199 DIRECTLY (~2 min each).
   Prefer the #led versions above unless you need a window wider than #led holds.
   =========================================================================== */


-- D2. Which order types exist (recent window; pick a real @OrderType from here):
SELECT SLDCTO AS OrderType, COUNT(*) AS Rows,
       COUNT(DISTINCT SLDOCO) AS DistinctOrders
FROM   PRODDTA.F42199 WITH (NOLOCK)
WHERE  SLUPMJ >= @SinceJul
GROUP BY SLDCTO
ORDER BY Rows DESC;

-- D3. THE one that matters: order lines that have >1 distinct Promised Delivery
--     Date across recent ledger rows = a real date change. Pick an
--     OrderNumber/OrderType from this list to feed STEP 2.
SELECT TOP (50)
       SLKCOO AS OrderCompany, SLDOCO AS OrderNumber, SLDCTO AS OrderType,
       SLLNID AS LineNumber,
       COUNT(*)                  AS LedgerRows,
       COUNT(DISTINCT SLPDDJ)    AS DistinctPromisedDates,
       COUNT(DISTINCT SLRCD)     AS DistinctReasonCodes
FROM   PRODDTA.F42199 WITH (NOLOCK)
WHERE  SLUPMJ >= @SinceJul
GROUP BY SLKCOO, SLDOCO, SLDCTO, SLLNID
HAVING COUNT(DISTINCT SLPDDJ) > 1
ORDER BY DistinctPromisedDates DESC, LedgerRows DESC;


/* -----------------------------------------------------------------------------
   STEP 2 — query the ledger for ONE order (set the two vars from D2/D3 above)
   ----------------------------------------------------------------------------- */

DECLARE @OrderNo   int     = 719533;   -- SLDOCO  <- replace with a real order from D3
DECLARE @OrderType char(2) = 'SO';     -- SLDCTO  <- replace with its order type

;WITH led AS (
    SELECT
        SLKCOO                                   AS OrderCompany,
        SLDOCO                                   AS OrderNumber,
        SLDCTO                                   AS OrderType,
        SLSFXO                                   AS OrderSuffix,
        SLLNID                                   AS LineNumber,
        SLMCU                                    AS BusinessUnit,
        SLLITM                                   AS Item,
        SLLNTY                                   AS LineType,
        SLNXTR                                   AS NextStatus,
        SLLTTR                                   AS LastStatus,
        SLRCD                                    AS ReasonCode,
        -- key dates (Julian -> date)
        CASE WHEN SLPDDJ = 0 THEN NULL ELSE DATEADD(DAY,(SLPDDJ%1000)-1,DATEFROMPARTS(1900+(SLPDDJ/1000),1,1)) END AS PromisedDeliveryDate,
        CASE WHEN SLOPDJ = 0 THEN NULL ELSE DATEADD(DAY,(SLOPDJ%1000)-1,DATEFROMPARTS(1900+(SLOPDJ/1000),1,1)) END AS OriginalPromisedDeliveryDate,
        CASE WHEN SLDRQJ = 0 THEN NULL ELSE DATEADD(DAY,(SLDRQJ%1000)-1,DATEFROMPARTS(1900+(SLDRQJ/1000),1,1)) END AS RequestedDate,
        CASE WHEN SLRSDJ = 0 THEN NULL ELSE DATEADD(DAY,(SLRSDJ%1000)-1,DATEFROMPARTS(1900+(SLRSDJ/1000),1,1)) END AS ScheduledPickDate,
        CASE WHEN SLADDJ = 0 THEN NULL ELSE DATEADD(DAY,(SLADDJ%1000)-1,DATEFROMPARTS(1900+(SLADDJ/1000),1,1)) END AS ActualShipDate,
        CASE WHEN SLCNDJ = 0 THEN NULL ELSE DATEADD(DAY,(SLCNDJ%1000)-1,DATEFROMPARTS(1900+(SLCNDJ/1000),1,1)) END AS CancelDate,
        CASE WHEN SLDGL  = 0 THEN NULL ELSE DATEADD(DAY,(SLDGL %1000)-1,DATEFROMPARTS(1900+(SLDGL /1000),1,1)) END AS GLDate,
        -- audit: who/when this ledger row was written
        CASE WHEN SLUPMJ = 0 THEN NULL ELSE DATEADD(DAY,(SLUPMJ%1000)-1,DATEFROMPARTS(1900+(SLUPMJ/1000),1,1)) END AS UpdatedDate,
        SLTDAY                                   AS UpdatedTime,    -- HHMMSS int
        SLUSER                                   AS UpdatedByUser,
        SLPID                                    AS ProgramID,
        SLJOBN                                   AS WorkStation
    FROM PRODDTA.F42199 WITH (NOLOCK)
    WHERE SLDOCO = @OrderNo AND SLDCTO = @OrderType   -- pushed down: avoids full scan
)
SELECT *
FROM   led
WHERE  OrderNumber = @OrderNo
  AND  OrderType   = @OrderType
ORDER BY OrderNumber, LineNumber, UpdatedDate, UpdatedTime;   -- change sequence per line


/* -----------------------------------------------------------------------------
   STEP 3 (optional) — resolve ReasonCode (SLRCD) to its description via UDC F0005
   The UDC product code (DRSY) + type (DRRT) for SLRCD is config-specific.
   First see what reason codes actually appear, then find their UDC bucket:
   ----------------------------------------------------------------------------- */

-- 3a. distinct reason codes used on the ledger (recent window):
SELECT SLRCD AS ReasonCode, COUNT(*) AS Rows
FROM   PRODDTA.F42199 WITH (NOLOCK)
WHERE  SLUPMJ >= 125001 AND SLRCD <> '' AND SLRCD IS NOT NULL
GROUP BY SLRCD
ORDER BY Rows DESC;

-- 3b. find which UDC table (DRSY/DRRT) those codes live in (F0005 = UDC master):
SELECT DRSY AS ProductCode, DRRT AS UdcType, DRKY AS Code,
       DRDL01 AS Description
FROM   PRODDTA.F0005 WITH (NOLOCK)
WHERE  DRKY IN (SELECT DISTINCT SLRCD FROM PRODDTA.F42199 WITH (NOLOCK)
                WHERE SLUPMJ >= 125001 AND SLRCD <> '')
ORDER BY DRSY, DRRT, DRKY;

-- 3c. once you know DRSY/DRRT (say '42'/'RC'), join it into the main query:
--   LEFT JOIN PRODDTA.F0005 udc
--          ON udc.DRSY = '42' AND udc.DRRT = 'RC'
--         AND RTRIM(udc.DRKY) = RTRIM(led.ReasonCode)
--   ... SELECT udc.DRDL01 AS ReasonCodeDesc


/* -----------------------------------------------------------------------------
   STEP 4 — inspect ONE reason code: sample ledger rows that carry it.
   Flow: run 3a to see the list, set @ReasonCode below, run this.
   (SLRCD isn't indexed -> this scans; @SinceJul4 keeps it bounded. TOP 200.)
   ----------------------------------------------------------------------------- */

DECLARE @ReasonCode char(3) = '';        -- <- set from 3a, e.g. '001'
DECLARE @SinceJul4  int      = 125001;   -- 2025+ window

SELECT TOP (200)
       SLKCOO AS OrderCompany, SLDOCO AS OrderNumber, SLDCTO AS OrderType,
       SLSFXO AS OrderSuffix, SLLNID AS LineNumber, SLLITM AS Item,
       SLRCD  AS ReasonCode, SLNXTR AS NextStatus, SLLTTR AS LastStatus,
       CASE WHEN SLPDDJ = 0 THEN NULL ELSE DATEADD(DAY,(SLPDDJ%1000)-1,DATEFROMPARTS(1900+(SLPDDJ/1000),1,1)) END AS PromisedDeliveryDate,
       CASE WHEN SLOPDJ = 0 THEN NULL ELSE DATEADD(DAY,(SLOPDJ%1000)-1,DATEFROMPARTS(1900+(SLOPDJ/1000),1,1)) END AS OriginalPromisedDeliveryDate,
       CASE WHEN SLUPMJ = 0 THEN NULL ELSE DATEADD(DAY,(SLUPMJ%1000)-1,DATEFROMPARTS(1900+(SLUPMJ/1000),1,1)) END AS UpdatedDate,
       SLTDAY AS UpdatedTime, SLUSER AS UpdatedByUser, SLPID AS ProgramID
FROM   PRODDTA.F42199 WITH (NOLOCK)
WHERE  SLRCD = @ReasonCode
  AND  SLUPMJ >= @SinceJul4
ORDER BY UpdatedDate DESC, UpdatedTime DESC;


/* -----------------------------------------------------------------------------
   Notes:
     - F42199 is the Sales Ledger: it holds MULTIPLE rows per order line over
       time (one per ledger write), so ORDER BY line + UpdatedDate/Time gives the
       change sequence. Watch the Promised Delivery Date (SLPDDJ) move across
       rows, with SLRCD as the reason captured on that change.
     - Other promised-date candidates present: SLPPDJ (col 30), SLPEFJ (col 29),
       plus time-stamp partners SLPDTT/SLOPTT/SLPSTM if you need intra-day order.
   ----------------------------------------------------------------------------- */
