let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            o.SDDOCO                          AS [Order Number],
            o.SDLNID / 1000.0                 AS [Line Number],
            o.Ordered_Date                    AS [Ordered Date],
            o.Promised_Ship_Date              AS [Promised Ship Date],
            LTRIM(RTRIM(shipto.ABALPH))       AS [Customer Name],
            LTRIM(RTRIM(o.SDLITM))            AS [2nd Item Number],
            LTRIM(RTRIM(o.SDDSC1))            AS [Description 1],
            LTRIM(RTRIM(o.SDDSC1))            AS [Description 1 (2)],
            LTRIM(RTRIM(h.SHDEL1))            AS [Delivery Instructions Line 1],
            LTRIM(RTRIM(h.SHDEL2))            AS [Delivery Instructions Line 2],
            o.SDNXTR                          AS [Next Status],
            o.SDUORG / 10000.0                AS [Ordered Qty (units)],
            LTRIM(RTRIM(o.SDUOM))             AS [Trans UOM],
            LTRIM(RTRIM(im.IMUOM1))           AS [Primary UOM],
            LTRIM(RTRIM(shipto.ABAC06))       AS [Customer Segmentation],
            CASE
                WHEN LTRIM(RTRIM(o.SDMCU))='CIN2' AND LTRIM(RTRIM(COALESCE(it.IBSTKT, im.IMSTKT))) IN ('S','M','Q','P') THEN 'Kemper'
                WHEN LTRIM(RTRIM(o.SDMCU))='CIN2' AND LTRIM(RTRIM(COALESCE(it.IBSTKT, im.IMSTKT))) IN ('D')             THEN 'Shell'
                WHEN LTRIM(RTRIM(o.SDMCU))='CINC' AND LTRIM(RTRIM(COALESCE(it.IBSTKT, im.IMSTKT))) IN ('S','M','Q','P') THEN 'Shell'
                ELSE 'OTHER'
            END                               AS [Make Site],
            it.IBLTLV                         AS [Lead Time Order to Ship],
            CASE
                WHEN LTRIM(RTRIM(o.SDMCU))='CIN2' THEN 'Kemper'
                WHEN LTRIM(RTRIM(o.SDMCU))='CINC' THEN 'Shell'
                ELSE 'OTHER'
            END                               AS [Ship Site],
            LTRIM(RTRIM(car.ABALPH))          AS [Carrier Name],
            LTRIM(RTRIM(o.SDFRTH))            AS [Freight Handling Code],
            o.SDITM                           AS [Item Key],
            o.SDSHAN                          AS [Ship To Key],
            CAST(o.SDITM AS varchar(20)) + '|' + LTRIM(RTRIM(o.SDUOM)) + '|' + LTRIM(RTRIM(im.IMUOM1)) AS [Conv Key],
            CAST(o.SDITM AS varchar(20)) + '|' + LTRIM(RTRIM(im.IMUOM1)) AS [LB Key]
        FROM (
            SELECT
                SDKCOO, SDDOCO, SDDCTO, SDSFXO, SDLNID, SDMCU, SDLITM, SDITM, SDNXTR,
                SDDSC1, SDUORG, SDUOM, SDSHAN, SDFRTH, SDCARS,
                CASE WHEN SDTRDJ>0 THEN DATEADD(DAY,(SDTRDJ%1000)-1,DATEFROMPARTS(1900+(SDTRDJ/1000),1,1)) END AS Ordered_Date,
                CASE WHEN SDPDDJ>0 THEN DATEADD(DAY,(SDPDDJ%1000)-1,DATEFROMPARTS(1900+(SDPDDJ/1000),1,1)) END AS Promised_Ship_Date
            FROM (
                SELECT SDKCOO, SDDOCO, SDDCTO, SDSFXO, SDLNID, SDMCU, SDLITM, SDITM, SDNXTR,
                       SDDSC1, SDUORG, SDUOM, SDSHAN, SDFRTH, SDCARS, SDTRDJ, SDPDDJ
                FROM PRODDTA.F4211
                UNION ALL
                SELECT h.SDKCOO, h.SDDOCO, h.SDDCTO, h.SDSFXO, h.SDLNID, h.SDMCU, h.SDLITM, h.SDITM, h.SDNXTR,
                       h.SDDSC1, h.SDUORG, h.SDUOM, h.SDSHAN, h.SDFRTH, h.SDCARS, h.SDTRDJ, h.SDPDDJ
                FROM PRODDTA.F42119 h
                WHERE NOT EXISTS (SELECT 1 FROM PRODDTA.F4211 c
                                  WHERE c.SDKCOO = h.SDKCOO AND c.SDDOCO = h.SDDOCO
                                    AND c.SDDCTO = h.SDDCTO AND c.SDLNID = h.SDLNID
                                    AND c.SDSFXO = h.SDSFXO)
            ) u
        ) o
        LEFT JOIN PRODDTA.F4201 h ON h.SHKCOO = o.SDKCOO AND h.SHDOCO = o.SDDOCO
                                 AND h.SHDCTO = o.SDDCTO AND h.SHSFXO = o.SDSFXO
        INNER JOIN PRODDTA.F0101 shipto ON o.SDSHAN = shipto.ABAN8
        LEFT JOIN PRODDTA.F4102 it ON LTRIM(RTRIM(o.SDMCU))  = LTRIM(RTRIM(it.IBMCU))
                                  AND LTRIM(RTRIM(o.SDLITM)) = LTRIM(RTRIM(it.IBLITM))
        LEFT JOIN PRODDTA.F4101 im  ON im.IMITM = o.SDITM
        LEFT JOIN PRODDTA.F554101 tag ON tag.IMITM = o.SDITM
        LEFT JOIN PRODDTA.F0101 car ON o.SDCARS = car.ABAN8
        WHERE o.Promised_Ship_Date BETWEEN DATEADD(DAY,-365, CAST(GETDATE() AS date))
                                       AND DATEADD(DAY, 30, CAST(GETDATE() AS date))
          AND LTRIM(RTRIM(o.SDMCU)) IN ('CINC','CIN2','CIN4')
          AND CASE WHEN ISNULL(LTRIM(RTRIM(tag.IMGBLK)),'-')='-'
                   THEN LTRIM(RTRIM(o.SDLITM)) ELSE LTRIM(RTRIM(tag.IMGBLK)) END
              NOT IN ('IGST','CGST','SGST','CVD','ADD')
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Order Number", Int64.Type},
            {"Line Number", type number},
            {"Ordered Date", type date},
            {"Promised Ship Date", type date},
            {"Customer Name", type text},
            {"2nd Item Number", type text},
            {"Description 1", type text},
            {"Description 1 (2)", type text},
            {"Delivery Instructions Line 1", type text},
            {"Delivery Instructions Line 2", type text},
            {"Next Status", type text},
            {"Ordered Qty (units)", type number},
            {"Trans UOM", type text},
            {"Primary UOM", type text},
            {"Customer Segmentation", type text},
            {"Make Site", type text},
            {"Lead Time Order to Ship", Int64.Type},
            {"Ship Site", type text},
            {"Carrier Name", type text},
            {"Freight Handling Code", type text},
            {"Item Key", Int64.Type},
            {"Ship To Key", Int64.Type},
            {"Conv Key", type text},
            {"LB Key", type text}
        },
        "en-US"
    )
in
    Typed
