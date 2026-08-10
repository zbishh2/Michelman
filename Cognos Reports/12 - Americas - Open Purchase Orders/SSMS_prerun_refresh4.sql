-- ============================================================================
-- Report 12 "Americas - Open Purchase Orders" — SSMS pre-run before refresh #4
-- Run on the jumpbox in SSMS against ODSPROD, database ODS.
-- Purpose: catch runtime errors + time each production query BEFORE burning a
-- Desktop refresh, and prove the #temp rep-lookup rewrite (r14/r17 pattern)
-- so the OUTER APPLY hang risk in Sales_Orders_Static can be removed first.
--
-- Run sections top to bottom. Paste ALL output back.
-- §5 (the current OUTER APPLY construct) runs LAST — cancel it if it exceeds
-- ~5 minutes; a cancel there IS the answer (it means we swap in the #temp).
-- ============================================================================

SET NOCOUNT ON;
SET STATISTICS TIME ON;

-- ---------------------------------------------------------------------------
-- §1  PO query row count (production shape). Expect ≈ 3,770
--     (F4102 now LEFT JOIN — the 772 restored rows have NULL Lead Time Level)
-- ---------------------------------------------------------------------------
SELECT '§1 PO' AS probe, COUNT(*) AS rows_total,
       SUM(CASE WHEN it.IBLTLV IS NULL THEN 1 ELSE 0 END) AS rows_null_leadtime
FROM PRODDTA.F4311 p
LEFT JOIN PRODDTA.F4102 it ON LTRIM(RTRIM(p.PDMCU)) = LTRIM(RTRIM(it.IBMCU))
                          AND LTRIM(RTRIM(p.PDLITM)) = LTRIM(RTRIM(it.IBLITM))
WHERE p.PDNXTR < '999'
  AND LTRIM(RTRIM(p.PDMCU)) IN ('CINC','CIN2','CIN4');
-- NOTE: this is a COUNT-shaped approximation of the PO filter set. If the count
-- is wildly off from 3,770, paste the real filter block from PO.m §WHERE here
-- and re-run — the point is a fast sanity number, not exact parity.

-- ---------------------------------------------------------------------------
-- §2  Build #reps — one row per ship-to, earliest CSR + earliest '%TM' rep.
--     Equivalent to the two OUTER APPLY (TOP 1 ... ORDER BY CMSLSM) picks.
--     This is the r14/r17 proven pattern: materialize once, indexed join.
-- ---------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#reps') IS NOT NULL DROP TABLE #reps;

SELECT CMAN8,
       MIN(CASE WHEN LTRIM(RTRIM(CMRTYPE)) = 'CSR'      THEN CMSLSM END) AS CSR_AN8,
       MIN(CASE WHEN LTRIM(RTRIM(CMRTYPE)) LIKE '%TM'   THEN CMSLSM END) AS TM_AN8
INTO #reps
FROM PRODDTA.F42140
GROUP BY CMAN8;

CREATE UNIQUE CLUSTERED INDEX IX_reps ON #reps (CMAN8);

SELECT '§2 #reps' AS probe, COUNT(*) AS shipto_rows,
       SUM(CASE WHEN CSR_AN8 IS NOT NULL THEN 1 ELSE 0 END) AS with_csr,
       SUM(CASE WHEN TM_AN8  IS NOT NULL THEN 1 ELSE 0 END) AS with_tm
FROM #reps;

-- ---------------------------------------------------------------------------
-- §3  Sales_Orders_Static with the #reps rewrite. Expect rows ≈ 12,196,
--     CSR/TM names mostly populated ('David Sifuentes' mailing-name format).
--     If this section is fast and the count ties, the rewrite goes to
--     production before refresh #4.
-- ---------------------------------------------------------------------------
SELECT '§3 SOS (#reps rewrite)' AS probe,
       COUNT(*)                                              AS rows_total,
       SUM(CASE WHEN csr_name IS NULL THEN 1 ELSE 0 END)     AS csr_blank,
       SUM(CASE WHEN tm_name  IS NULL THEN 1 ELSE 0 END)     AS tm_blank,
       COUNT(DISTINCT csr_name)                              AS csr_distinct,
       COUNT(DISTINCT tm_name)                               AS tm_distinct
FROM (
    SELECT
        o.SDDOCO, o.SDLNID,
        LTRIM(RTRIM(csrw.WWMLNM)) AS csr_name,
        LTRIM(RTRIM(tmw.WWMLNM))  AS tm_name
    FROM (
        SELECT SDKCOO, SDDOCO, SDDCTO, SDSFXO, SDLNID, SDMCU, SDLITM, SDNXTR,
               SDDSC1, SDPQOR, SDSHAN, SDFRTH, SDCARS,
               CASE WHEN SDPDDJ>0 THEN DATEADD(DAY,(SDPDDJ%1000)-1,DATEFROMPARTS(1900+(SDPDDJ/1000),1,1)) END AS Promised_Ship_Date
        FROM (
            SELECT SDKCOO, SDDOCO, SDDCTO, SDSFXO, SDLNID, SDMCU, SDLITM, SDNXTR,
                   SDDSC1, SDPQOR, SDSHAN, SDFRTH, SDCARS, SDTRDJ, SDPDDJ
            FROM PRODDTA.F4211
            UNION ALL
            SELECT h.SDKCOO, h.SDDOCO, h.SDDCTO, h.SDSFXO, h.SDLNID, h.SDMCU, h.SDLITM, h.SDNXTR,
                   h.SDDSC1, h.SDPQOR, h.SDSHAN, h.SDFRTH, h.SDCARS, h.SDTRDJ, h.SDPDDJ
            FROM PRODDTA.F42119 h
            WHERE NOT EXISTS (SELECT 1 FROM PRODDTA.F4211 c
                              WHERE c.SDKCOO = h.SDKCOO AND c.SDDOCO = h.SDDOCO
                                AND c.SDDCTO = h.SDDCTO AND c.SDLNID = h.SDLNID
                                AND c.SDSFXO = h.SDSFXO)
        ) u
    ) o
    INNER JOIN PRODDTA.F0101 shipto ON o.SDSHAN = shipto.ABAN8
    LEFT JOIN PRODDTA.F4101 im  ON LTRIM(RTRIM(im.IMLITM)) = LTRIM(RTRIM(o.SDLITM))
    LEFT JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
    LEFT JOIN #reps r            ON r.CMAN8 = o.SDSHAN
    LEFT JOIN PRODDTA.F0111 csrw ON csrw.WWAN8 = r.CSR_AN8 AND csrw.WWIDLN = 0
    LEFT JOIN PRODDTA.F0111 tmw  ON tmw.WWAN8  = r.TM_AN8  AND tmw.WWIDLN = 0
    WHERE o.Promised_Ship_Date BETWEEN DATEADD(DAY,-365, CAST(GETDATE() AS date))
                                   AND DATEADD(DAY, 30, CAST(GETDATE() AS date))
      AND LTRIM(RTRIM(o.SDMCU)) IN ('CINC','CIN2','CIN4')
      AND CASE WHEN ISNULL(LTRIM(RTRIM(tag.IMGBLK)),'-')='-'
               THEN LTRIM(RTRIM(o.SDLITM)) ELSE LTRIM(RTRIM(tag.IMGBLK)) END
          NOT IN ('IGST','CGST','SGST','CVD','ADD')
    GROUP BY o.SDDOCO, o.SDLNID, LTRIM(RTRIM(csrw.WWMLNM)), LTRIM(RTRIM(tmw.WWMLNM))
) g;

-- Sample 10 rep names so the mailing-name format can be eyeballed:
SELECT TOP 10 '§3b sample' AS probe,
       LTRIM(RTRIM(csrw.WWMLNM)) AS csr_name, LTRIM(RTRIM(tmw.WWMLNM)) AS tm_name
FROM #reps r
JOIN PRODDTA.F0111 csrw ON csrw.WWAN8 = r.CSR_AN8 AND csrw.WWIDLN = 0
JOIN PRODDTA.F0111 tmw  ON tmw.WWAN8  = r.TM_AN8  AND tmw.WWIDLN = 0
ORDER BY r.CMAN8;

-- ---------------------------------------------------------------------------
-- §4  Sales_Ledger row count (production shape is a straight join set —
--     no correlated constructs). Expect ≈ 91,613. Timing matters here:
--     this is the table that makes the refresh slow.
-- ---------------------------------------------------------------------------
SELECT '§4 Ledger' AS probe, COUNT(*) AS rows_total
FROM PRODDTA.F42199 l
JOIN (
    SELECT SDKCOO, SDDOCO, SDDCTO, SDSFXO, SDLNID
    FROM PRODDTA.F4211
    UNION ALL
    SELECT h.SDKCOO, h.SDDOCO, h.SDDCTO, h.SDSFXO, h.SDLNID
    FROM PRODDTA.F42119 h
    WHERE NOT EXISTS (SELECT 1 FROM PRODDTA.F4211 c
                      WHERE c.SDKCOO = h.SDKCOO AND c.SDDOCO = h.SDDOCO
                        AND c.SDDCTO = h.SDDCTO AND c.SDLNID = h.SDLNID
                        AND c.SDSFXO = h.SDSFXO)
) o ON o.SDKCOO = l.SLKCOO AND o.SDDOCO = l.SLDOCO
   AND o.SDDCTO = l.SLDCTO AND o.SDSFXO = l.SLSFXO AND o.SDLNID = l.SLLNID
WHERE LTRIM(RTRIM(l.SLMCU)) IN ('CINC','CIN2','CIN4');
-- NOTE: approximation of the ledger filter set (same caveat as §1).

-- ---------------------------------------------------------------------------
-- §5  LAST: the CURRENT production OUTER APPLY construct, count only.
--     *** CANCEL IF > 5 MINUTES — a cancel means we ship the #reps rewrite ***
--     If it completes: rows_total / csr_blank / tm_blank must equal §3's.
-- ---------------------------------------------------------------------------
SELECT '§5 SOS (current OUTER APPLY)' AS probe,
       COUNT(*)                                          AS rows_total,
       SUM(CASE WHEN csr_name IS NULL THEN 1 ELSE 0 END) AS csr_blank,
       SUM(CASE WHEN tm_name  IS NULL THEN 1 ELSE 0 END) AS tm_blank
FROM (
    SELECT
        o.SDDOCO, o.SDLNID,
        LTRIM(RTRIM(csrw.WWMLNM)) AS csr_name,
        LTRIM(RTRIM(tmw.WWMLNM))  AS tm_name
    FROM (
        SELECT SDKCOO, SDDOCO, SDDCTO, SDSFXO, SDLNID, SDMCU, SDLITM, SDNXTR,
               SDDSC1, SDPQOR, SDSHAN, SDFRTH, SDCARS,
               CASE WHEN SDPDDJ>0 THEN DATEADD(DAY,(SDPDDJ%1000)-1,DATEFROMPARTS(1900+(SDPDDJ/1000),1,1)) END AS Promised_Ship_Date
        FROM (
            SELECT SDKCOO, SDDOCO, SDDCTO, SDSFXO, SDLNID, SDMCU, SDLITM, SDNXTR,
                   SDDSC1, SDPQOR, SDSHAN, SDFRTH, SDCARS, SDTRDJ, SDPDDJ
            FROM PRODDTA.F4211
            UNION ALL
            SELECT h.SDKCOO, h.SDDOCO, h.SDDCTO, h.SDSFXO, h.SDLNID, h.SDMCU, h.SDLITM, h.SDNXTR,
                   h.SDDSC1, h.SDPQOR, h.SDSHAN, h.SDFRTH, h.SDCARS, h.SDTRDJ, h.SDPDDJ
            FROM PRODDTA.F42119 h
            WHERE NOT EXISTS (SELECT 1 FROM PRODDTA.F4211 c
                              WHERE c.SDKCOO = h.SDKCOO AND c.SDDOCO = h.SDDOCO
                                AND c.SDDCTO = h.SDDCTO AND c.SDLNID = h.SDLNID
                                AND c.SDSFXO = h.SDSFXO)
        ) u
    ) o
    INNER JOIN PRODDTA.F0101 shipto ON o.SDSHAN = shipto.ABAN8
    LEFT JOIN PRODDTA.F4101 im  ON LTRIM(RTRIM(im.IMLITM)) = LTRIM(RTRIM(o.SDLITM))
    LEFT JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
    OUTER APPLY (SELECT TOP 1 x.CMSLSM FROM PRODDTA.F42140 x
                 WHERE x.CMAN8 = o.SDSHAN AND LTRIM(RTRIM(x.CMRTYPE)) = 'CSR'
                 ORDER BY x.CMSLSM) csrx
    LEFT JOIN PRODDTA.F0111 csrw ON csrw.WWAN8 = csrx.CMSLSM AND csrw.WWIDLN = 0
    OUTER APPLY (SELECT TOP 1 x.CMSLSM FROM PRODDTA.F42140 x
                 WHERE x.CMAN8 = o.SDSHAN AND LTRIM(RTRIM(x.CMRTYPE)) LIKE '%TM'
                 ORDER BY x.CMSLSM) tmx
    LEFT JOIN PRODDTA.F0111 tmw ON tmw.WWAN8 = tmx.CMSLSM AND tmw.WWIDLN = 0
    WHERE o.Promised_Ship_Date BETWEEN DATEADD(DAY,-365, CAST(GETDATE() AS date))
                                   AND DATEADD(DAY, 30, CAST(GETDATE() AS date))
      AND LTRIM(RTRIM(o.SDMCU)) IN ('CINC','CIN2','CIN4')
      AND CASE WHEN ISNULL(LTRIM(RTRIM(tag.IMGBLK)),'-')='-'
               THEN LTRIM(RTRIM(o.SDLITM)) ELSE LTRIM(RTRIM(tag.IMGBLK)) END
          NOT IN ('IGST','CGST','SGST','CVD','ADD')
    GROUP BY o.SDDOCO, o.SDLNID, LTRIM(RTRIM(csrw.WWMLNM)), LTRIM(RTRIM(tmw.WWMLNM))
) g;

SET STATISTICS TIME OFF;
