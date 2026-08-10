/* ============================================================================
   Report 01 - RM Staging at Shell Road 2026 (ODS)
   PRE-BUILD VERIFICATION — run in SSMS against the ODSPROD server (ODS database).
   Goal: confirm the 4 JDE work-order/inventory tables + key columns are present
         in PRODDTA before we invest in the .m queries.
   Expectation: each block returns 1 row of data (or at least no "invalid object"
                / "invalid column" error). The CINC counts should be > 0.
   ============================================================================ */

USE ODS;
GO

-- 1) F4801  Work Order Master ------------------------------------------------
SELECT TOP 1
       WADOCO, WAMMCU, WASRST, WASTRT, WADRQJ, WALITM, WAUORG, WASOQS, WAUOM
FROM   PRODDTA.F4801;

-- 2) F3111  Work Order Parts List --------------------------------------------
SELECT TOP 1
       WMDOCO, WMCPIT, WMCPIL, WMTRDJ, WMDRQJ, WMUORG, WMTRQT, WMMCU
FROM   PRODDTA.F3111;

-- 3) F41021 Item Location (on-hand) ------------------------------------------
SELECT TOP 1
       LIITM, LIMCU, LIPQOH, LILOTS
FROM   PRODDTA.F41021;

-- 4) F4102  Item Branch (master planning family) -----------------------------
SELECT TOP 1
       IBMCU, IBITM, IBLITM, IBPRP4
FROM   PRODDTA.F4102;

-- 5) Sanity: do these actually have CINC data in the expected shape? ----------
SELECT COUNT(*) AS F4801_CINC_open_WOs
FROM   PRODDTA.F4801
WHERE  LTRIM(RTRIM(WAMMCU)) = 'CINC'
  AND  WASRST NOT IN ('93','94','95','97','99','MM','CD');

SELECT COUNT(*) AS F41021_CINC_onhand_rows
FROM   PRODDTA.F4102 ib
JOIN   PRODDTA.F41021 il ON ib.IBITM = il.LIITM AND ib.IBMCU = il.LIMCU
WHERE  LTRIM(RTRIM(ib.IBMCU)) = 'CINC'
  AND  il.LIPQOH > 0
  AND  il.LILOTS IN (' ','-');

SELECT COUNT(*) AS F4102_CINC_RMfamily_items
FROM   PRODDTA.F4102
WHERE  LTRIM(RTRIM(IBMCU)) = 'CINC'
  AND  IBPRP4 IN ('RRC','REC','RCB','TOL','PKG','RBW');
