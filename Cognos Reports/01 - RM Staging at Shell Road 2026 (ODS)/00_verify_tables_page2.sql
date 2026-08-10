/* ============================================================================
   Report 01 - Page 2 "Shortage Details" - PRE-BUILD VERIFICATION
   Confirms the extra F41021 columns page 2 needs (Location, Lot Number) exist.
   Run in SSMS against ODSPROD (ODS). Expect 1 row, no "invalid column" error.
   ============================================================================ */
USE ODS;
GO

-- F41021 Location + Lot columns used by page 2
SELECT TOP 1
       LIITM, LIMCU, LILOTS, LIPQOH,
       LILOCN,   -- Location
       LILOTN    -- Lot / Serial Number
FROM   PRODDTA.F41021;

-- Sanity: CIN2 + CINC on-hand rows (all lot statuses; page 2 does NOT filter status)
SELECT COUNT(*) AS IOH_All_CIN2_CINC_rows
FROM   PRODDTA.F4102 ib
JOIN   PRODDTA.F41021 il ON ib.IBITM = il.LIITM AND ib.IBMCU = il.LIMCU
WHERE  il.LIPQOH > 0
  AND  LTRIM(RTRIM(ib.IBMCU)) IN ('CIN2','CINC');
