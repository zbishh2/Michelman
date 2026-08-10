let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            o.SDDOCO                                   AS [Order],
            sold.ABALPH                                AS [Customer],
            o.SDNXTR                                   AS [Next],
            o.SDMCU                                    AS [BP],
            o.Requested_Date                           AS [Requested],
            o.Promised_Ship_Date                       AS [Promised Ship],
            SUM(o.SDUORG / 10000.0)                    AS [Qty],
            o.SDUOM                                    AS [UOM],
            SUM(CASE
                    WHEN o.SDUOM4 = o.SDUOM1 THEN o.SDPQOR / 10000.0
                    WHEN o.SDUOM4 = o.SDUOM2 THEN o.SDSQOR / 10000.0
                    WHEN o.SDUOM4 = o.SDUOM  THEN o.SDUORG / 10000.0
                    ELSE ISNULL((conv.UMCONV / 10000000.0 * o.SDUORG) / 10000.0, 0)
                END)                                   AS [Weight],
            o.SDLITM                                   AS [Item],
            hdr.SHHOLD                                 AS [Hold],
            carr.ABALPH                                AS [Carrier],
            hdr.SHMOT                                  AS [MOT],
            hdr.SHDEL1                                 AS [DI1],
            hdr.SHDEL2                                 AS [DI2],
            csr.ABALPH                                 AS [CSR Name],
            CASE
                WHEN csr.ABALPH = 'Runyan, Tammy'   THEN 'Tammy'
                WHEN csr.ABALPH = 'McCrary, Nae'    THEN 'Nae'
                WHEN csr.ABALPH = 'Benjamin, Kim'   THEN 'Kim'
                WHEN csr.ABALPH = 'Garner, Shannon' THEN 'Shannon'
                ELSE 'Other'
            END                                        AS [CSR Page],
            CASE WHEN o.Promised_Ship_Date < DATEADD(DAY, 30, CAST(GETDATE() AS date)) THEN 1 ELSE 0 END AS [Kim Window]
        FROM (
            SELECT
                SDKCOO, SDDOCO, SDDCTO, SDSFXO, SDMCU, SDAN8, SDSHAN, SDITM, SDLITM,
                SDLNTY, SDNXTR, SDUOM, SDUORG, SDCARS, SDUOM1, SDPQOR, SDUOM2, SDSQOR, SDUOM4,
                CASE WHEN SDDRQJ > 0 THEN DATEADD(DAY,(SDDRQJ % 1000)-1,DATEFROMPARTS(1900+(SDDRQJ/1000),1,1)) END AS Requested_Date,
                CASE WHEN SDPDDJ > 0 THEN DATEADD(DAY,(SDPDDJ % 1000)-1,DATEFROMPARTS(1900+(SDPDDJ/1000),1,1)) END AS Promised_Ship_Date
            FROM PRODDTA.F4211
        ) o
        INNER JOIN PRODDTA.F0101 sold ON o.SDAN8 = sold.ABAN8
        INNER JOIN PRODDTA.F4201 hdr  ON o.SDKCOO = hdr.SHKCOO
                                     AND o.SDDOCO = hdr.SHDOCO
                                     AND o.SDDCTO = hdr.SHDCTO
                                     AND o.SDSFXO = hdr.SHSFXO
        LEFT JOIN PRODDTA.F41002 conv ON o.SDMCU  = conv.UMMCU
                                     AND o.SDITM  = conv.UMITM
                                     AND o.SDUOM  = conv.UMUM
                                     AND o.SDUOM4 = conv.UMRUM
        INNER JOIN (
            SELECT c.CMAN8, LTRIM(RTRIM(n.ABALPH)) AS ABALPH
            FROM PRODDTA.F42140 c
            INNER JOIN PRODDTA.F0101 n ON c.CMSLSM = n.ABAN8
            WHERE c.CMRTYPE = 'CSR'
        ) csr ON o.SDSHAN = csr.CMAN8
        LEFT JOIN PRODDTA.F0101 carr ON o.SDCARS = carr.ABAN8
        WHERE o.SDNXTR < '570'
          AND o.SDKCOO = '00010'
          AND o.SDLNTY NOT IN ('FS','T')
          AND o.SDDCTO <> 'SQ'
        GROUP BY
            o.SDDOCO, sold.ABALPH, o.SDNXTR, o.SDMCU,
            o.Requested_Date, o.Promised_Ship_Date, o.SDUOM, o.SDLITM,
            hdr.SHHOLD, carr.ABALPH, hdr.SHMOT, hdr.SHDEL1, hdr.SHDEL2,
            csr.ABALPH
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Order", Int64.Type},
            {"Customer", type text},
            {"Next", type text},
            {"BP", type text},
            {"Requested", type date},
            {"Promised Ship", type date},
            {"Qty", type number},
            {"UOM", type text},
            {"Weight", type number},
            {"Item", type text},
            {"Hold", type text},
            {"Carrier", type text},
            {"MOT", type text},
            {"DI1", type text},
            {"DI2", type text},
            {"CSR Name", type text},
            {"CSR Page", type text},
            {"Kim Window", Int64.Type}
        },
        "en-US"
    )
in
    Typed
