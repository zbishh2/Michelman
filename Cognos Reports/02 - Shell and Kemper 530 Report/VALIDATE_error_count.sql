/* ============================================================================
   Report 02 — "Number of Errors" reconciliation (run in SSMS on the JUMPBOX,
   against ODSPROD / ODS).  T-SQL, folds; no CTE, safe to paste as-is.

   PURPOSE: Cognos's "Number of Errors = 1,299" card does NOT equal the number
   of red ERROR rows in Cognos's own 530 list (which is ~16).  This script shows
   why, by computing BOTH numbers from the same source pipeline:

     Q1  Errors_FanOut     -> should reproduce Cognos's card value (~1,299)
                             = the count query WITHOUT the detail GROUP BY, so
                               every ERROR order-line is counted once per matching
                               Routing13 row (work-center x period x capacity row).
     Q2  Errors_Collapsed  -> should reproduce the PBI card / red-row count (16)
     Q2  Total_Collapsed   -> should reproduce the PBI 530 row count (57)
                             = the DETAIL query's GROUP BY collapses Routing13 to
                               distinct Work_Center per line, so each ERROR line is
                               counted once.

   If Q1 = 1299 and Q2 = 16 / 57, the discrepancy is confirmed as a Cognos
   list-vs-counter fan-out artifact (the card over-counts; the list is correct).
   ============================================================================ */

------------------------------------------------------------------- Q1: FAN-OUT
-- Reproduces Cognos "COUNT_ERROR" block: FULL OUTER JOIN to the *un-collapsed*
-- Routing13, no GROUP BY on the outer query. Expect ~1,299.
SELECT
    SUM(CASE WHEN mb.NewOwner = 'ERROR' THEN 1 ELSE 0 END) AS Errors_FanOut,
    COUNT(*)                                               AS Rows_FanOut
FROM (
    SELECT
        m8.C_2nd_Item_Number, m8.Next_Status, i9.Bulk_Item,
        CASE i9.Planner
            WHEN '324363' THEN 'Eric'  WHEN '20444'  THEN 'Eric'
            WHEN '20445'  THEN 'Lance' WHEN '291740' THEN 'Mark Tilley'
            WHEN '328907' THEN 'Lance' WHEN '333530' THEN 'Lance'
            WHEN '316775' THEN 'Lance' WHEN '334927' THEN 'Tammy'
            WHEN '290808' THEN 'David Kramer' WHEN '335951' THEN 'Lance'
            WHEN '300021' THEN 'Tammy' WHEN '324287' THEN 'Brent'
            ELSE 'ERROR'
        END AS NewOwner
    FROM (
        SELECT LTRIM(RTRIM(so.SDMCU)) AS Branch_Plant, so.SDDOCO AS Order_Number,
               so.SDLNID/1000.0 AS Order_Line, LTRIM(RTRIM(so.SDLITM)) AS C_2nd_Item_Number,
               so.SDNXTR AS Next_Status
        FROM PRODDTA.F4211 so
        INNER JOIN PRODDTA.F0101 cust ON so.SDSHAN = cust.ABAN8
        WHERE so.SDNXTR IN ('525','530','535','540','545','550') AND so.SDKCOO='00010'
        GROUP BY LTRIM(RTRIM(so.SDMCU)), so.SDDOCO, so.SDLNID/1000.0,
                 LTRIM(RTRIM(so.SDLITM)), so.SDNXTR
    ) m8
    INNER JOIN (
        SELECT DISTINCT LTRIM(RTRIM(ib.IBMCU)) AS Branch_Plant,
               LTRIM(RTRIM(tag.IMBULK)) AS Bulk_Item,
               LTRIM(RTRIM(ib.IBLITM)) AS C_2nd_Item_Number, ib.IBANPL AS Planner
        FROM PRODDTA.F4102 ib
        JOIN PRODDTA.F4101 im  ON ib.IBITM = im.IMITM
        JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
    ) i9 ON m8.Branch_Plant = i9.Branch_Plant AND m8.C_2nd_Item_Number = i9.C_2nd_Item_Number
    GROUP BY m8.Branch_Plant, m8.Order_Number, m8.Order_Line, m8.C_2nd_Item_Number,
             m8.Next_Status, i9.Bulk_Item, i9.Planner
) mb
FULL OUTER JOIN (
    /* Routing13 as Cognos left it: grouped on many cols => NOT distinct on Work_Center,
       so one Bulk_Item matches MANY rows here. THIS is what inflates the count. */
    SELECT LTRIM(RTRIM(ib.IBLITM)) AS C_2nd_Item_Number, LTRIM(RTRIM(cp.CWMCU)) AS Work_Center
    FROM PRODDTA.F3312 cp
    JOIN PRODDTA.F4102 ib ON cp.CWITM = ib.IBITM AND cp.CWWMCU = ib.IBMCU
    JOIN PRODDTA.F3313 cl ON cp.CWMCU=cl.CRMCU AND cp.CWCAPM=cl.CRCAPM
                         AND cp.CWDRQJ=cl.CRSTRT AND cp.CWWMCU=cl.CRWMCU
    WHERE LTRIM(RTRIM(cp.CWMMCU)) IN ('CINC','CIN2')
      AND LTRIM(RTRIM(ib.IBLITM)) NOT LIKE '%-%'
      AND LTRIM(RTRIM(cp.CWMCU)) IN
          ('SREC23','SREC37','SREC48','SREC72','SREC130','SDMD','SPEC','SPREC','SECG','SE2',
           'SCOLD','SPDMD','SPCOLD','SLAB','SRENAME','SREPACK','SHILDA','KLAB','KBB','KSB',
           'KWG','KBOT','KREPACK','KRENAME')
      AND cp.CWDOCO = 0
      AND (CASE WHEN cp.CWDRQJ > 0
                THEN DATEADD(DAY,(cp.CWDRQJ%1000)-1,DATEFROMPARTS(1900+(cp.CWDRQJ/1000),1,1))
                ELSE DATEFROMPARTS(1900,1,1) END) > DATEADD(DAY,31,CAST(GETDATE() AS date))
    GROUP BY LTRIM(RTRIM(ib.IBLITM)), LTRIM(RTRIM(cp.CWMCU)),
             cp.CWDRQJ, cl.CRSTRT, cl.CRTRQT, cl.CRCQT, cp.CWCAPM, cp.CWMMCU, cp.CWDOCO
) r ON mb.Bulk_Item = r.C_2nd_Item_Number
WHERE mb.C_2nd_Item_Number IS NOT NULL AND mb.Next_Status = '530';


---------------------------------------------------------------- Q2: COLLAPSED
-- Reproduces the DETAIL list grain (distinct Work_Center per line) => the red-row
-- count PBI shows. Expect Errors_Collapsed=16, Total_Collapsed=57.
SELECT
    SUM(CASE WHEN d.NewOwner='ERROR' THEN 1 ELSE 0 END) AS Errors_Collapsed,
    COUNT(*)                                            AS Total_Collapsed
FROM (
    SELECT mb.Branch_Plant, mb.Order_Number, mb.Order_Line, mb.C_2nd_Item_Number,
           mb.Bulk_Item, mb.NewOwner, r.Work_Center
    FROM (
        SELECT m8.Branch_Plant, m8.Order_Number, m8.Order_Line, m8.C_2nd_Item_Number,
               m8.Next_Status, i9.Bulk_Item,
               CASE i9.Planner
                   WHEN '324363' THEN 'Eric'  WHEN '20444'  THEN 'Eric'
                   WHEN '20445'  THEN 'Lance' WHEN '291740' THEN 'Mark Tilley'
                   WHEN '328907' THEN 'Lance' WHEN '333530' THEN 'Lance'
                   WHEN '316775' THEN 'Lance' WHEN '334927' THEN 'Tammy'
                   WHEN '290808' THEN 'David Kramer' WHEN '335951' THEN 'Lance'
                   WHEN '300021' THEN 'Tammy' WHEN '324287' THEN 'Brent'
                   ELSE 'ERROR'
               END AS NewOwner
        FROM (
            SELECT LTRIM(RTRIM(so.SDMCU)) AS Branch_Plant, so.SDDOCO AS Order_Number,
                   so.SDLNID/1000.0 AS Order_Line, LTRIM(RTRIM(so.SDLITM)) AS C_2nd_Item_Number,
                   so.SDNXTR AS Next_Status
            FROM PRODDTA.F4211 so
            INNER JOIN PRODDTA.F0101 cust ON so.SDSHAN = cust.ABAN8
            WHERE so.SDNXTR IN ('525','530','535','540','545','550') AND so.SDKCOO='00010'
            GROUP BY LTRIM(RTRIM(so.SDMCU)), so.SDDOCO, so.SDLNID/1000.0,
                     LTRIM(RTRIM(so.SDLITM)), so.SDNXTR
        ) m8
        INNER JOIN (
            SELECT DISTINCT LTRIM(RTRIM(ib.IBMCU)) AS Branch_Plant,
                   LTRIM(RTRIM(tag.IMBULK)) AS Bulk_Item,
                   LTRIM(RTRIM(ib.IBLITM)) AS C_2nd_Item_Number, ib.IBANPL AS Planner
            FROM PRODDTA.F4102 ib
            JOIN PRODDTA.F4101 im  ON ib.IBITM = im.IMITM
            JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
        ) i9 ON m8.Branch_Plant=i9.Branch_Plant AND m8.C_2nd_Item_Number=i9.C_2nd_Item_Number
        GROUP BY m8.Branch_Plant, m8.Order_Number, m8.Order_Line, m8.C_2nd_Item_Number,
                 m8.Next_Status, i9.Bulk_Item, i9.Planner
    ) mb
    FULL OUTER JOIN (
        SELECT DISTINCT LTRIM(RTRIM(ib.IBLITM)) AS C_2nd_Item_Number,
               LTRIM(RTRIM(cp.CWMCU)) AS Work_Center
        FROM PRODDTA.F3312 cp
        JOIN PRODDTA.F4102 ib ON cp.CWITM = ib.IBITM AND cp.CWWMCU = ib.IBMCU
        JOIN PRODDTA.F3313 cl ON cp.CWMCU=cl.CRMCU AND cp.CWCAPM=cl.CRCAPM
                             AND cp.CWDRQJ=cl.CRSTRT AND cp.CWWMCU=cl.CRWMCU
        WHERE LTRIM(RTRIM(cp.CWMMCU)) IN ('CINC','CIN2')
          AND LTRIM(RTRIM(ib.IBLITM)) NOT LIKE '%-%'
          AND LTRIM(RTRIM(cp.CWMCU)) IN
              ('SREC23','SREC37','SREC48','SREC72','SREC130','SDMD','SPEC','SPREC','SECG','SE2',
               'SCOLD','SPDMD','SPCOLD','SLAB','SRENAME','SREPACK','SHILDA','KLAB','KBB','KSB',
               'KWG','KBOT','KREPACK','KRENAME')
          AND cp.CWDOCO = 0
          AND (CASE WHEN cp.CWDRQJ > 0
                    THEN DATEADD(DAY,(cp.CWDRQJ%1000)-1,DATEFROMPARTS(1900+(cp.CWDRQJ/1000),1,1))
                    ELSE DATEFROMPARTS(1900,1,1) END) > DATEADD(DAY,31,CAST(GETDATE() AS date))
    ) r ON mb.Bulk_Item = r.C_2nd_Item_Number
    WHERE mb.C_2nd_Item_Number IS NOT NULL AND mb.Next_Status='530'
    GROUP BY mb.Branch_Plant, mb.Order_Number, mb.Order_Line, mb.C_2nd_Item_Number,
             mb.Bulk_Item, mb.NewOwner, r.Work_Center
) d;
