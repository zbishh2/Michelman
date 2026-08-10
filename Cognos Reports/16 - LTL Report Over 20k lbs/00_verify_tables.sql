/* ============================================================================
   Report 16 - LTL report over 20k lbs  -  PRE-BUILD PROBES
   Run ONCE on the jumpbox (SSMS) against ODSPROD / ODS before first refresh.
   Local SQL is firewalled - do not retry locally.
   Six categories: (1) column existence  (2) join drops  (3) fan-out
                   (4) code decodes       (5) count parity (validation target)
                   (6) format spot-checks
   ============================================================================ */

/* ---- (1) COLUMN EXISTENCE ------------------------------------------------- */
-- F4211 columns used: SDKCOO SDDOCO SDDCTO SDLNID SDSHAN SDCARS SDNXTR SDUOM1 SDPQOR SDPDDJ
SELECT TOP 1 SDKCOO, SDDOCO, SDDCTO, SDLNID, SDSHAN, SDCARS, SDNXTR, SDUOM1, SDPQOR, SDPDDJ
FROM PRODDTA.F4211;
-- F42140 columns used: CMAN8 CMSLSM CMRTYPE
SELECT TOP 1 CMAN8, CMSLSM, CMRTYPE FROM PRODDTA.F42140;
-- F0101 columns used: ABAN8 ABALPH
SELECT TOP 1 ABAN8, ABALPH FROM PRODDTA.F0101;

/* ---- (2) JOIN DROPS ------------------------------------------------------- */
-- Ship-to F0101 is INNER JOIN in Cognos -> any qualifying line with no F0101
-- ship-to would be DROPPED. Count how many (expect 0; if >0 the INNER differs
-- from what the business expects).
SELECT
    COUNT(*)                                                       AS qualifying_lines,
    SUM(CASE WHEN st.ABAN8 IS NULL THEN 1 ELSE 0 END)             AS dropped_no_shipto
FROM PRODDTA.F4211 o
LEFT JOIN PRODDTA.F0101 st ON o.SDSHAN = st.ABAN8
WHERE o.SDKCOO = '00010'
  AND o.SDDCTO IN ('S4','S5','SZ','SC','ST')
  AND o.SDNXTR IN ('560','550','545','540','535','530','525')
  AND o.SDCARS NOT IN (293371,29671,288676,26185,293492,98725,301322,195487,136656,293919,304977,309791,301333,309741,27710,26171,283919,26175,301761,292099,309757,316502)
  AND o.SDPQOR / 10000.0 > 20000
  AND o.SDCARS <> 308636;
-- Carrier LEFT JOIN + CSR LEFT JOIN: how many rows get NO carrier name / NO CSR
-- (blank is legitimate, just quantify).
SELECT
    SUM(CASE WHEN carr.ABAN8 IS NULL THEN 1 ELSE 0 END)          AS lines_no_carrier_name,
    SUM(CASE WHEN csr.CMAN8  IS NULL THEN 1 ELSE 0 END)          AS lines_no_csr
FROM PRODDTA.F4211 o
LEFT JOIN PRODDTA.F0101 carr ON o.SDCARS = carr.ABAN8
LEFT JOIN (SELECT DISTINCT CMAN8 FROM PRODDTA.F42140 WHERE CMRTYPE='CSR') csr ON o.SDSHAN = csr.CMAN8
WHERE o.SDKCOO='00010' AND o.SDDCTO IN ('S4','S5','SZ','SC','ST')
  AND o.SDNXTR IN ('560','550','545','540','535','530','525')
  AND o.SDPQOR/10000.0 > 20000 AND o.SDCARS <> 308636
  AND o.SDCARS NOT IN (293371,29671,288676,26185,293492,98725,301322,195487,136656,293919,304977,309791,301333,309741,27710,26171,283919,26175,301761,292099,309757,316502);

/* ---- (3) FAN-OUT : CSR join multiplicity ---------------------------------- */
-- The CSR join is on ship-to (CMAN8) only, CMRTYPE='CSR'. If any CMAN8 has >1
-- 'CSR' row in F42140 the order line duplicates. List the worst offenders.
SELECT TOP 20 CMAN8, COUNT(*) AS csr_rows,
       COUNT(DISTINCT CMSLSM) AS distinct_csr_reps
FROM PRODDTA.F42140
WHERE CMRTYPE = 'CSR'
GROUP BY CMAN8
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;

/* ---- (4) CODE DECODES ----------------------------------------------------- */
-- Distinct Next Status / Order Type actually present in the qualifying set,
-- to confirm the IN-lists cover live data.
SELECT o.SDNXTR AS next_status, o.SDDCTO AS order_type, COUNT(*) AS lines
FROM PRODDTA.F4211 o
WHERE o.SDKCOO='00010' AND o.SDDCTO IN ('S4','S5','SZ','SC','ST')
  AND o.SDNXTR IN ('560','550','545','540','535','530','525')
  AND o.SDPQOR/10000.0 > 20000 AND o.SDCARS <> 308636
  AND o.SDCARS NOT IN (293371,29671,288676,26185,293492,98725,301322,195487,136656,293919,304977,309791,301333,309741,27710,26171,283919,26175,301761,292099,309757,316502)
GROUP BY o.SDNXTR, o.SDDCTO
ORDER BY o.SDNXTR, o.SDDCTO;

/* ---- (5) COUNT PARITY (validation target - none exists yet) --------------- */
-- (5a) DEPLOYED semantics: per-row >20k in WHERE, grouped to line grain.
--      This should tie to the rebuilt table's row count TODAY.
SELECT COUNT(*) AS deployed_line_rows FROM (
    SELECT o.SDDOCO, o.SDLNID/1000.0 AS ln, o.SDDCTO, o.SDCARS, o.SDNXTR,
           o.SDUOM1, o.SDSHAN, o.SDPDDJ, csr.CMSLSM
    FROM PRODDTA.F4211 o
    INNER JOIN PRODDTA.F0101 st ON o.SDSHAN = st.ABAN8
    LEFT JOIN (SELECT c.CMAN8, c.CMSLSM, a.ABALPH FROM PRODDTA.F42140 c
               INNER JOIN PRODDTA.F0101 a ON c.CMSLSM=a.ABAN8 WHERE c.CMRTYPE='CSR') csr
        ON o.SDSHAN = csr.CMAN8
    LEFT JOIN PRODDTA.F0101 carr ON o.SDCARS = carr.ABAN8
    WHERE o.SDKCOO='00010' AND o.SDDCTO IN ('S4','S5','SZ','SC','ST')
      AND o.SDNXTR IN ('560','550','545','540','535','530','525')
      AND o.SDCARS NOT IN (293371,29671,288676,26185,293492,98725,301322,195487,136656,293919,304977,309791,301333,309741,27710,26171,283919,26175,301761,292099,309757,316502)
      AND o.SDPQOR/10000.0 > 20000 AND o.SDCARS <> 308636
    GROUP BY o.SDDOCO, o.SDLNID/1000.0, o.SDDCTO, o.SDCARS, o.SDNXTR,
             o.SDUOM1, o.SDSHAN, o.SDPDDJ, csr.CMSLSM
) d;
-- (5b) LILLY semantics (HAVING SUM>20k). Diff (5b - 5a) = lines the deployed
--      report drops but the rewrite keeps (multi-row line groups summing >20k).
SELECT COUNT(*) AS having_line_rows FROM (
    SELECT o.SDDOCO, o.SDLNID/1000.0 AS ln
    FROM PRODDTA.F4211 o
    INNER JOIN PRODDTA.F0101 st ON o.SDSHAN = st.ABAN8
    WHERE o.SDKCOO='00010' AND o.SDDCTO IN ('S4','S5','SZ','SC','ST')
      AND o.SDNXTR IN ('560','550','545','540','535','530','525')
      AND o.SDCARS NOT IN (293371,29671,288676,26185,293492,98725,301322,195487,136656,293919,304977,309791,301333,309741,27710,26171,283919,26175,301761,292099,309757,316502)
      AND o.SDCARS <> 308636
    GROUP BY o.SDDOCO, o.SDLNID/1000.0
    HAVING SUM(o.SDPQOR/10000.0) > 20000
) h;

/* ---- (5c) MULTI-ROW (order,line) - the SUM question ----------------------- */
-- Does any (order,line) have >1 F4211 row (before the >20k filter)? If 0, the
-- WHERE-vs-HAVING distinction is moot and SUM is pure cosmetics.
SELECT TOP 20 SDDOCO, SDDCTO, SDKCOO, SDLNID/1000.0 AS ln, COUNT(*) AS rows_per_line
FROM PRODDTA.F4211
WHERE SDKCOO='00010' AND SDDCTO IN ('S4','S5','SZ','SC','ST')
  AND SDNXTR IN ('560','550','545','540','535','530','525')
GROUP BY SDDOCO, SDDCTO, SDKCOO, SDLNID/1000.0
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;

/* ---- (6) FORMAT SPOT-CHECKS ----------------------------------------------- */
-- Sample decoded output: confirm Julian date decode, /10000 and /1000 scaling
-- look sane (pick date is a real date near today; qty in tens of thousands;
-- line like 1.000, 2.000).
SELECT TOP 25
    CASE WHEN o.SDPDDJ>0 THEN DATEADD(DAY,(o.SDPDDJ%1000)-1,DATEFROMPARTS(1900+(o.SDPDDJ/1000),1,1)) END AS Scheduled_Pick_Date,
    o.SDCARS AS Carrier_AB_Number, LTRIM(RTRIM(st.ABALPH)) AS Customer_Name,
    o.SDDOCO AS Order_Number, o.SDNXTR AS Next_Status, o.SDDCTO AS Order_Type,
    o.SDLNID/1000.0 AS Order_Line, LTRIM(RTRIM(carr.ABALPH)) AS Carrier_Name,
    LTRIM(RTRIM(csr.ABALPH)) AS CSR_Name, o.SDPQOR/10000.0 AS Primary_Quantity_Ordered,
    LTRIM(RTRIM(o.SDUOM1)) AS Primary_UOM, csr.CMSLSM AS CSR_AB_Number
FROM PRODDTA.F4211 o
INNER JOIN PRODDTA.F0101 st ON o.SDSHAN = st.ABAN8
LEFT JOIN (SELECT c.CMAN8,c.CMSLSM,a.ABALPH FROM PRODDTA.F42140 c
           INNER JOIN PRODDTA.F0101 a ON c.CMSLSM=a.ABAN8 WHERE c.CMRTYPE='CSR') csr ON o.SDSHAN=csr.CMAN8
LEFT JOIN PRODDTA.F0101 carr ON o.SDCARS = carr.ABAN8
WHERE o.SDKCOO='00010' AND o.SDDCTO IN ('S4','S5','SZ','SC','ST')
  AND o.SDNXTR IN ('560','550','545','540','535','530','525')
  AND o.SDCARS NOT IN (293371,29671,288676,26185,293492,98725,301322,195487,136656,293919,304977,309791,301333,309741,27710,26171,283919,26175,301761,292099,309757,316502)
  AND o.SDPQOR/10000.0 > 20000 AND o.SDCARS <> 308636
ORDER BY o.SDPDDJ, o.SDCARS;
