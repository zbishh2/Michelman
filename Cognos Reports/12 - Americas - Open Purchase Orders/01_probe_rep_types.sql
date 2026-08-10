-- Report 12: CSR Name / TM Name came back blank after refresh #2.
-- Run each block on the jumpbox (ODSPROD / ODS) and send back all results.
-- Goal: find (a) which F42140 CMRTYPE code = CSR ("type 9") and which = TM,
--       (b) whether the join key is really CMAN8 = ship-to (SDSHAN),
--       (c) whether F4211 carries an order-level rep column (Cognos TM came
--           from ORDER_ACTIVITY.SALES_REP_ID, an ORDER-level attribute).

-- 1) What rep-type codes exist, and how common is each?
SELECT LTRIM(RTRIM(CMRTYPE)) AS rep_type, COUNT(*) AS n
FROM PRODDTA.F42140
GROUP BY LTRIM(RTRIM(CMRTYPE))
ORDER BY n DESC;

-- 2) Reverse lookup: known names from the Cognos output.
--    CSR names: David Sifuentes, Kristine Corcoran, Lakeia Chatman
--    TM names:  Bryan Fuka, Brendan Schloerb, Dave Jeffers
--    Whatever rep_type shows next to the CSR names is the CSR literal;
--    same for the TM names.
SELECT DISTINCT LTRIM(RTRIM(f.CMRTYPE)) AS rep_type, f.CMSLSM,
       LTRIM(RTRIM(ab.ABALPH)) AS ab_name, LTRIM(RTRIM(ww.WWMLNM)) AS mailing_name
FROM PRODDTA.F42140 f
JOIN PRODDTA.F0101 ab ON ab.ABAN8 = f.CMSLSM
LEFT JOIN PRODDTA.F0111 ww ON ww.WWAN8 = f.CMSLSM AND ww.WWIDLN = 0
WHERE ab.ABALPH LIKE '%Fuka%' OR ab.ABALPH LIKE '%Schloerb%' OR ab.ABALPH LIKE '%Jeffers%'
   OR ab.ABALPH LIKE '%Sifuentes%' OR ab.ABALPH LIKE '%Corcoran%' OR ab.ABALPH LIKE '%Chatman%'
ORDER BY rep_type, ab_name;

-- 3) Shape check: full F42140 rows for ship-tos that are on current orders.
--    Confirms CMAN8 really holds the ship-to AN8 (vs sold-to) and shows any
--    extra key columns that matter.
SELECT TOP 50 f.*
FROM PRODDTA.F42140 f
WHERE f.CMAN8 IN (SELECT TOP 5 SDSHAN FROM PRODDTA.F4211
                  WHERE LTRIM(RTRIM(SDMCU)) IN ('CINC','CIN2','CIN4'));

-- 4) Does the order line itself carry a rep column? (Cognos TM joined on
--    ORDER_ACTIVITY.SALES_REP_ID.) List candidate columns on F4211/F42119.
SELECT OBJECT_NAME(object_id) AS tbl, name AS col
FROM sys.columns
WHERE object_id IN (OBJECT_ID('PRODDTA.F4211'), OBJECT_ID('PRODDTA.F42119'))
  AND (name LIKE '%SLSM%' OR name LIKE '%SLSP%' OR name LIKE '%REP%')
ORDER BY tbl, col;

-- ---------------------------------------------------------------------------
-- PO page loaded ~750 rows short of Cognos (2,998 vs 3,749). Two suspects.

-- 5a) Purged PO detail history (F43119) — the purchasing twin of the F42119
--     sales gotcha. If this errors with "Invalid object name", suspect ruled out.
SELECT COUNT(*) AS f43119_rows_in_window
FROM PRODDTA.F43119
WHERE PDPDDJ > 0
  AND DATEADD(DAY,(PDPDDJ%1000)-1,DATEFROMPARTS(1900+(PDPDDJ/1000),1,1))
      >= DATEADD(DAY,-365, CAST(GETDATE() AS date))
  AND LTRIM(RTRIM(PDMCU)) IN ('CINC','CIN2','CIN4')
  AND LTRIM(RTRIM(PDDCTO)) IN ('OP','OD');

-- 5b) F4311 lines dropped by the branch-item (F4102) inner join — DW ITEM is
--     item-level, so Cognos keeps lines my branch-item join loses.
SELECT COUNT(*) AS f4311_lines_without_f4102,
       SUM(CASE WHEN NOT EXISTS (SELECT 1 FROM PRODDTA.F0101 v WHERE v.ABAN8 = d.PDAN8)
                THEN 1 ELSE 0 END) AS also_missing_vendor
FROM PRODDTA.F4311 d
WHERE d.PDPDDJ > 0
  AND DATEADD(DAY,(d.PDPDDJ%1000)-1,DATEFROMPARTS(1900+(d.PDPDDJ/1000),1,1))
      >= DATEADD(DAY,-365, CAST(GETDATE() AS date))
  AND LTRIM(RTRIM(d.PDMCU)) IN ('CINC','CIN2','CIN4')
  AND LTRIM(RTRIM(d.PDDCTO)) IN ('OP','OD')
  AND NOT EXISTS (SELECT 1 FROM PRODDTA.F4102 ib
                  WHERE LTRIM(RTRIM(ib.IBMCU))  = LTRIM(RTRIM(d.PDMCU))
                    AND LTRIM(RTRIM(ib.IBLITM)) = LTRIM(RTRIM(d.PDLITM)));
