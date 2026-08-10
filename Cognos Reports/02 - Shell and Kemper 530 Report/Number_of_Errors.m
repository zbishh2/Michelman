// ============================================================================
// Report 02 - Shell and Kemper 530 Report
// QUERY: Number_of_Errors  ->  the "Number of Errors = N" scalar indicator
//        (Cognos singleton "Singleton1" / query object "Main w Routing 530",
//         data item COUNT ERROR = total([FLAG ERROR]) where FLAG ERROR = 1 when
//         NEW OWNER = 'ERROR').
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//
// This reproduces Cognos "Block 1": the same Main_w_Bulk12 FULL OUTER JOIN
//   Routing13 pipeline as Shell_Kemper_530.m, filtered to Next_Status = '530'
//   and 2nd item IS NOT NULL, returning ONE row = the count of order lines whose
//   planner does NOT decode to a known owner (NEW_OWNER = 'ERROR').
//
// RECOMMENDED ALTERNATIVE (see BUILD.md): rather than load this separate query,
//   drive the indicator from a DAX measure over the detail table -
//     Number of Errors := CALCULATE(COUNTROWS('Shell_Kemper_530'),
//                                    'Shell_Kemper_530'[Owner] = "ERROR")
//   It ties 1:1 to the red rows in the visible list and needs no extra query.
//   This .m is provided for parity / a standalone card if the builder prefers it;
//   with the DISTINCT-Routing13 rewrite it returns the same N as the DAX measure.
//
// HAVING COUNT(*) > 0 mirrors Cognos (suppresses the row when there are no 530s).
// See Shell_Kemper_530.m for the full derivation of the mb / r subqueries; the
// inner logic here is identical (kept in sync by hand - update both together).
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            SUM(CASE WHEN (CASE mb.Planner
                                WHEN '324363' THEN 'Eric'         WHEN '20444'  THEN 'Eric'
                                WHEN '20445'  THEN 'Lance'        WHEN '291740' THEN 'Mark Tilley'
                                WHEN '328907' THEN 'Lance'        WHEN '333530' THEN 'Lance'
                                WHEN '316775' THEN 'Lance'        WHEN '334927' THEN 'Tammy'
                                WHEN '290808' THEN 'David Kramer' WHEN '335951' THEN 'Lance'
                                WHEN '300021' THEN 'Tammy'        WHEN '324287' THEN 'Brent'
                                ELSE 'ERROR'
                           END) = 'ERROR'
                     THEN 1 ELSE 0 END)                           AS [Number of Errors]
        FROM (
            /* ---- Main_w_Bulk12 : MAIN8 INNER JOIN ITEM9 (see Shell_Kemper_530.m) ---- */
            SELECT
                m8.C_2nd_Item_Number, m8.Next_Status, i9.Bulk_Item, i9.Planner
            FROM (
                SELECT
                    LTRIM(RTRIM(so.SDMCU))  AS Branch_Plant,
                    so.SDDOCO               AS Order_Number,
                    so.SDLNID / 1000.0      AS Order_Line,
                    LTRIM(RTRIM(so.SDLITM)) AS C_2nd_Item_Number,
                    so.SDNXTR               AS Next_Status
                FROM PRODDTA.F4211 so
                INNER JOIN PRODDTA.F0101 cust ON so.SDSHAN = cust.ABAN8
                WHERE so.SDNXTR IN ('525','530','535','540','545','550')
                  AND so.SDKCOO = '00010'
                GROUP BY
                    LTRIM(RTRIM(so.SDMCU)), so.SDDOCO, so.SDLNID / 1000.0,
                    LTRIM(RTRIM(so.SDLITM)), so.SDNXTR
            ) m8
            INNER JOIN (
                SELECT DISTINCT
                    LTRIM(RTRIM(ib.IBMCU))   AS Branch_Plant,
                    LTRIM(RTRIM(tag.IMBULK)) AS Bulk_Item,
                    LTRIM(RTRIM(ib.IBLITM))  AS C_2nd_Item_Number,
                    ib.IBANPL                AS Planner
                FROM PRODDTA.F4102 ib
                JOIN PRODDTA.F4101 im  ON ib.IBITM = im.IMITM
                JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
            ) i9
              ON m8.Branch_Plant = i9.Branch_Plant
             AND m8.C_2nd_Item_Number = i9.C_2nd_Item_Number
            GROUP BY
                m8.Branch_Plant, m8.Order_Number, m8.Order_Line,
                m8.C_2nd_Item_Number, m8.Next_Status,
                i9.Bulk_Item, i9.Planner
        ) mb
        FULL OUTER JOIN (
            SELECT DISTINCT
                LTRIM(RTRIM(ib.IBLITM)) AS C_2nd_Item_Number,
                LTRIM(RTRIM(cp.CWMCU))  AS Work_Center
            FROM PRODDTA.F3312 cp
            JOIN PRODDTA.F4102 ib ON cp.CWITM = ib.IBITM AND cp.CWWMCU = ib.IBMCU
            JOIN PRODDTA.F3313 cl ON cp.CWMCU  = cl.CRMCU
                                 AND cp.CWCAPM = cl.CRCAPM
                                 AND cp.CWDRQJ = cl.CRSTRT
                                 AND cp.CWWMCU = cl.CRWMCU
            WHERE LTRIM(RTRIM(cp.CWMMCU)) IN ('CINC','CIN2')
              AND LTRIM(RTRIM(ib.IBLITM)) NOT LIKE '%-%'
              AND LTRIM(RTRIM(cp.CWMCU)) IN
                  ('SREC23','SREC37','SREC48','SREC72','SREC130','SDMD','SPEC','SPREC',
                   'SECG','SE2','SCOLD','SPDMD','SPCOLD','SLAB','SRENAME','SREPACK',
                   'SHILDA','KLAB','KBB','KSB','KWG','KBOT','KREPACK','KRENAME')
              AND cp.CWDOCO = 0
              AND (CASE WHEN cp.CWDRQJ > 0
                        THEN DATEADD(DAY, (cp.CWDRQJ % 1000) - 1, DATEFROMPARTS(1900 + (cp.CWDRQJ / 1000), 1, 1))
                        ELSE DATEFROMPARTS(1900, 1, 1)
                   END) > DATEADD(DAY, 31, CAST(GETDATE() AS date))
        ) r
          ON mb.Bulk_Item = r.C_2nd_Item_Number
        WHERE mb.C_2nd_Item_Number IS NOT NULL
          AND mb.Next_Status = '530'
        HAVING COUNT(*) > 0
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(Data, {{"Number of Errors", Int64.Type}})
in
    Typed
