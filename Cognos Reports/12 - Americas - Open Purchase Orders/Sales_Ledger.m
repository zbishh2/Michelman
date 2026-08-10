let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT DISTINCT
            LTRIM(RTRIM(l.SLKCOO))            AS [Order Company],
            l.SLDOCO                          AS [Order Number],
            l.SLLNID / 1000.0                 AS [Line Number],
            LTRIM(RTRIM(l.SLLITM))            AS [2nd Item Number],
            CASE WHEN o.SDTRDJ>0 THEN DATEADD(DAY,(o.SDTRDJ%1000)-1,DATEFROMPARTS(1900+(o.SDTRDJ/1000),1,1)) END AS [Ordered Date],
            CASE WHEN l.SLUPMJ>0 THEN DATEADD(DAY,(l.SLUPMJ%1000)-1,DATEFROMPARTS(1900+(l.SLUPMJ/1000),1,1)) END AS [Date Created],
            l.SLLTTR                          AS [Last Status],
            l.SLNXTR                          AS [Next Status],
            CASE WHEN l.SLUPMJ>0 THEN
                DATEADD(SECOND,
                        (l.SLTDAY/10000)*3600 + ((l.SLTDAY/100)%100)*60 + (l.SLTDAY%100),
                        CAST(DATEADD(DAY,(l.SLUPMJ%1000)-1,DATEFROMPARTS(1900+(l.SLUPMJ/1000),1,1)) AS datetime2))
            END                               AS [Order Line Last Updated],
            LTRIM(RTRIM(l.SLUSER))            AS [Order Line Last Updated By]
        FROM PRODDTA.F42199 l
        JOIN (
            SELECT SDKCOO, SDDOCO, SDDCTO, SDLNID, SDMCU, SDLITM, SDTRDJ
            FROM PRODDTA.F4211
            UNION ALL
            SELECT h.SDKCOO, h.SDDOCO, h.SDDCTO, h.SDLNID, h.SDMCU, h.SDLITM, h.SDTRDJ
            FROM PRODDTA.F42119 h
            WHERE NOT EXISTS (SELECT 1 FROM PRODDTA.F4211 c
                              WHERE c.SDKCOO = h.SDKCOO AND c.SDDOCO = h.SDDOCO
                                AND c.SDDCTO = h.SDDCTO AND c.SDLNID = h.SDLNID)
        ) o   ON o.SDKCOO = l.SLKCOO AND o.SDDOCO = l.SLDOCO
             AND o.SDDCTO = l.SLDCTO AND o.SDLNID = l.SLLNID
        JOIN PRODDTA.F4102 it ON LTRIM(RTRIM(o.SDMCU))  = LTRIM(RTRIM(it.IBMCU))
                            AND LTRIM(RTRIM(o.SDLITM)) = LTRIM(RTRIM(it.IBLITM))
        LEFT JOIN PRODDTA.F4101 im   ON it.IBITM = im.IMITM
        LEFT JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
        WHERE CASE WHEN o.SDTRDJ>0 THEN DATEADD(DAY,(o.SDTRDJ%1000)-1,DATEFROMPARTS(1900+(o.SDTRDJ/1000),1,1)) END >= '2024-01-01'
          AND LTRIM(RTRIM(l.SLKCOO)) = '00010'
          AND LTRIM(RTRIM(l.SLNXTR)) IN ('520','525','530')
          AND LTRIM(RTRIM(l.SLUSER)) <> 'SCHED'
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
            {"Order Company", type text},
            {"Order Number", Int64.Type},
            {"Line Number", type number},
            {"2nd Item Number", type text},
            {"Ordered Date", type date},
            {"Date Created", type date},
            {"Last Status", type text},
            {"Next Status", type text},
            {"Order Line Last Updated", type datetime},
            {"Order Line Last Updated By", type text}
        },
        "en-US"
    )
in
    Typed
