/* ============================================================================
   Report 15 - Open Orders - Live Data  |  PROBE SET
   Run once on the JUMPBOX in SSMS against ODSPROD / ODS (JDE, PRODDTA) BEFORE
   the first PBIP refresh. Local SQL is firewalled - do not run here.
   Paste results into probe_results.txt. Six categories, per house rule.
   ============================================================================ */

-------------------------------------------------------------------------------
-- BLOCK 1 - COLUMN EXISTENCE (every column the .m selects actually exists)
-- Expect: one row per table, no "Invalid column name" error.
-------------------------------------------------------------------------------
SELECT TOP 1
    SDKCOO, SDDOCO, SDDCTO, SDSFXO, SDMCU, SDAN8, SDSHAN, SDITM, SDLITM,
    SDLNTY, SDNXTR, SDUOM, SDUORG, SDCARS, SDUOM1, SDPQOR, SDUOM2, SDSQOR, SDUOM4,
    SDDRQJ, SDPDDJ
FROM PRODDTA.F4211;

SELECT TOP 1 SHKCOO, SHDOCO, SHDCTO, SHSFXO, SHHOLD, SHMOT, SHDEL1, SHDEL2
FROM PRODDTA.F4201;

SELECT TOP 1 CMAN8, CMRTYPE, CMSLSM FROM PRODDTA.F42140;

SELECT TOP 1 ABAN8, ABALPH FROM PRODDTA.F0101;

SELECT TOP 1 UMMCU, UMITM, UMUM, UMRUM, UMCONV FROM PRODDTA.F41002;

-------------------------------------------------------------------------------
-- BLOCK 2 - COUNT PARITY vs the xlsx "Other_5" sheet (394 rows captured 7/15).
-- Live/sysdate-relative -> expect drift; want same order of magnitude (~350-450).
-- 2a = full report population (all pages; = "Other" today because 4 names stale).
-------------------------------------------------------------------------------
SELECT COUNT(*) AS [Report_Row_Count_all_pages]
FROM (
    SELECT
        o.SDDOCO, sold.ABALPH AS Cust, o.SDNXTR, o.SDMCU,
        CASE WHEN o.SDDRQJ>0 THEN DATEADD(DAY,(o.SDDRQJ%1000)-1,DATEFROMPARTS(1900+(o.SDDRQJ/1000),1,1)) END AS Requested,
        CASE WHEN o.SDPDDJ>0 THEN DATEADD(DAY,(o.SDPDDJ%1000)-1,DATEFROMPARTS(1900+(o.SDPDDJ/1000),1,1)) END AS Promised,
        o.SDUOM, o.SDLITM, hdr.SHHOLD, carr.ABALPH AS Carr, hdr.SHMOT, hdr.SHDEL1, hdr.SHDEL2,
        csr.ABALPH AS CSR
    FROM PRODDTA.F4211 o
    INNER JOIN PRODDTA.F0101 sold ON o.SDAN8 = sold.ABAN8
    INNER JOIN PRODDTA.F4201 hdr  ON o.SDKCOO=hdr.SHKCOO AND o.SDDOCO=hdr.SHDOCO AND o.SDDCTO=hdr.SHDCTO AND o.SDSFXO=hdr.SHSFXO
    INNER JOIN (SELECT c.CMAN8, LTRIM(RTRIM(n.ABALPH)) AS ABALPH
                FROM PRODDTA.F42140 c INNER JOIN PRODDTA.F0101 n ON c.CMSLSM=n.ABAN8
                WHERE c.CMRTYPE='CSR') csr ON o.SDSHAN = csr.CMAN8
    LEFT JOIN PRODDTA.F0101 carr ON o.SDCARS = carr.ABAN8
    WHERE o.SDNXTR < '570' AND o.SDKCOO='00010' AND o.SDLNTY NOT IN ('FS','T') AND o.SDDCTO <> 'SQ'
    GROUP BY o.SDDOCO, sold.ABALPH, o.SDNXTR, o.SDMCU,
        CASE WHEN o.SDDRQJ>0 THEN DATEADD(DAY,(o.SDDRQJ%1000)-1,DATEFROMPARTS(1900+(o.SDDRQJ/1000),1,1)) END,
        CASE WHEN o.SDPDDJ>0 THEN DATEADD(DAY,(o.SDPDDJ%1000)-1,DATEFROMPARTS(1900+(o.SDPDDJ/1000),1,1)) END,
        o.SDUOM, o.SDLITM, hdr.SHHOLD, carr.ABALPH, hdr.SHMOT, hdr.SHDEL1, hdr.SHDEL2, csr.ABALPH
) x;

-- 2b = rows PER derived page. Expect Tammy/Nae/Kim/Shannon = 0, Other = ~394.
--      (This is the visible proof of the stale-CSR-name defect.)
SELECT
    CASE
        WHEN csr.ABALPH='Runyan, Tammy' THEN 'Tammy'
        WHEN csr.ABALPH='McCrary, Nae' THEN 'Nae'
        WHEN csr.ABALPH='Benjamin, Kim' THEN 'Kim'
        WHEN csr.ABALPH='Garner, Shannon' THEN 'Shannon'
        ELSE 'Other'
    END AS CSR_Page,
    COUNT(*) AS Lines
FROM PRODDTA.F4211 o
INNER JOIN (SELECT c.CMAN8, LTRIM(RTRIM(n.ABALPH)) AS ABALPH
            FROM PRODDTA.F42140 c INNER JOIN PRODDTA.F0101 n ON c.CMSLSM=n.ABAN8
            WHERE c.CMRTYPE='CSR') csr ON o.SDSHAN = csr.CMAN8
WHERE o.SDNXTR < '570' AND o.SDKCOO='00010' AND o.SDLNTY NOT IN ('FS','T') AND o.SDDCTO <> 'SQ'
GROUP BY CASE
        WHEN csr.ABALPH='Runyan, Tammy' THEN 'Tammy'
        WHEN csr.ABALPH='McCrary, Nae' THEN 'Nae'
        WHEN csr.ABALPH='Benjamin, Kim' THEN 'Kim'
        WHEN csr.ABALPH='Garner, Shannon' THEN 'Shannon'
        ELSE 'Other'
    END;

-------------------------------------------------------------------------------
-- BLOCK 3 - FAN-OUT: customers with >1 CMRTYPE='CSR' row in F42140.
-- Each such customer's orders DOUBLE-count (CSR join fans out; Qty/Weight SUM
-- over the copies). Cognos has the same quirk - we reproduce it. If this returns
-- rows, note it as an accepted over-count at validation.
-------------------------------------------------------------------------------
SELECT c.CMAN8, COUNT(*) AS CSR_Rows
FROM PRODDTA.F42140 c
WHERE c.CMRTYPE = 'CSR'
GROUP BY c.CMAN8
HAVING COUNT(*) > 1
ORDER BY CSR_Rows DESC;

-------------------------------------------------------------------------------
-- BLOCK 4 - CODE DECODES / STALE-NAME EVIDENCE:
-- Who are the CSRs ACTUALLY assigned today? (business evidence for the defect -
-- shows the four hard-coded names are gone / renamed.) Look for the four names.
-------------------------------------------------------------------------------
SELECT LTRIM(RTRIM(n.ABALPH)) AS CSR_Name, COUNT(DISTINCT c.CMAN8) AS Customers
FROM PRODDTA.F42140 c
INNER JOIN PRODDTA.F0101 n ON c.CMSLSM = n.ABAN8
WHERE c.CMRTYPE = 'CSR'
GROUP BY LTRIM(RTRIM(n.ABALPH))
ORDER BY Customers DESC;

-- distinct next-status and doc-type present in the open population (sanity of filters)
SELECT o.SDNXTR, COUNT(*) AS Lines
FROM PRODDTA.F4211 o
WHERE o.SDNXTR < '570' AND o.SDKCOO='00010' AND o.SDLNTY NOT IN ('FS','T') AND o.SDDCTO <> 'SQ'
GROUP BY o.SDNXTR ORDER BY o.SDNXTR;

-------------------------------------------------------------------------------
-- BLOCK 5 - JOIN DROPS: how many open lines lack a header (F4201) or a CSR row.
-- header match should be ~100% (F4201 is the parent). CSR-less lines are DROPPED
-- from the report by design (INNER CSR); quantify how many orders that removes.
-------------------------------------------------------------------------------
SELECT
    SUM(CASE WHEN hdr.SHDOCO IS NULL THEN 1 ELSE 0 END) AS Lines_missing_F4201_header,
    SUM(CASE WHEN csr.CMAN8 IS NULL THEN 1 ELSE 0 END)  AS Lines_dropped_no_CSR,
    COUNT(*)                                            AS Open_lines_pre_CSR
FROM PRODDTA.F4211 o
LEFT JOIN PRODDTA.F4201 hdr ON o.SDKCOO=hdr.SHKCOO AND o.SDDOCO=hdr.SHDOCO AND o.SDDCTO=hdr.SHDCTO AND o.SDSFXO=hdr.SHSFXO
LEFT JOIN (SELECT DISTINCT CMAN8 FROM PRODDTA.F42140 WHERE CMRTYPE='CSR') csr ON o.SDSHAN = csr.CMAN8
WHERE o.SDNXTR < '570' AND o.SDKCOO='00010' AND o.SDLNTY NOT IN ('FS','T') AND o.SDDCTO <> 'SQ';

-------------------------------------------------------------------------------
-- BLOCK 6 - FORMAT / MAGNITUDE SPOT-CHECK: sample 20 rows, compare Qty & Weight
-- magnitudes and dates to the xlsx (Qty ~ tens/hundreds, Weight ~ hundreds/thou).
-- Confirms the /10000 and /10000000 implied-decimal scaling is right.
-------------------------------------------------------------------------------
SELECT TOP 20
    o.SDDOCO AS [Order], sold.ABALPH AS Customer, o.SDNXTR AS Next, o.SDMCU AS BP,
    CASE WHEN o.SDPDDJ>0 THEN DATEADD(DAY,(o.SDPDDJ%1000)-1,DATEFROMPARTS(1900+(o.SDPDDJ/1000),1,1)) END AS Promised,
    SUM(o.SDUORG/10000.0) AS Qty, o.SDUOM AS UOM,
    SUM(CASE WHEN o.SDUOM4=o.SDUOM1 THEN o.SDPQOR/10000.0
             WHEN o.SDUOM4=o.SDUOM2 THEN o.SDSQOR/10000.0
             WHEN o.SDUOM4=o.SDUOM  THEN o.SDUORG/10000.0
             ELSE ISNULL((conv.UMCONV/10000000.0*o.SDUORG)/10000.0,0) END) AS Weight,
    o.SDLITM AS Item
FROM PRODDTA.F4211 o
INNER JOIN PRODDTA.F0101 sold ON o.SDAN8=sold.ABAN8
INNER JOIN (SELECT c.CMAN8, LTRIM(RTRIM(n.ABALPH)) AS ABALPH
            FROM PRODDTA.F42140 c INNER JOIN PRODDTA.F0101 n ON c.CMSLSM=n.ABAN8
            WHERE c.CMRTYPE='CSR') csr ON o.SDSHAN=csr.CMAN8
LEFT JOIN PRODDTA.F41002 conv ON o.SDMCU=conv.UMMCU AND o.SDITM=conv.UMITM AND o.SDUOM=conv.UMUM AND o.SDUOM4=conv.UMRUM
WHERE o.SDNXTR < '570' AND o.SDKCOO='00010' AND o.SDLNTY NOT IN ('FS','T') AND o.SDDCTO <> 'SQ'
GROUP BY o.SDDOCO, sold.ABALPH, o.SDNXTR, o.SDMCU,
    CASE WHEN o.SDPDDJ>0 THEN DATEADD(DAY,(o.SDPDDJ%1000)-1,DATEFROMPARTS(1900+(o.SDPDDJ/1000),1,1)) END,
    o.SDUOM, o.SDLITM
ORDER BY o.SDDOCO;
