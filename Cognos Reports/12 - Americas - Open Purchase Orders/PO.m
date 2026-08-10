let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            LTRIM(RTRIM(d.PDMCU))              AS [Branch Plant],
            d.PDDOCO                           AS [PO Number],
            d.PDLNID / 1000.0                  AS [Line Number],
            LTRIM(RTRIM(d.PDLITM))             AS [2nd Item Number],
            d.PO_Date                          AS [PO Date],
            d.Requested_Date                   AS [Requested Date],
            d.Promised_Date                    AS [Promised Date],
            d.PDAN8                            AS [Vendor ID],
            LTRIM(RTRIM(v.ABALPH))             AS [Vendor Name],
            ib.IBLTLV                          AS [Lead Time Level],
            d.Qty_Ordered                      AS [PO Quantity Ordered],
            d.Qty_Open                         AS [Open Quantity],
            d.Qty_Received                     AS [Quantity Received],
            d.Amt_Spend                        AS [Spend Amount USD],
            d.Amt_Purchase                     AS [Purchase Amount USD],
            d.PDITM                            AS [Item Key],
            LTRIM(RTRIM(im.IMUOM1))            AS [Primary UOM],
            CAST(d.PDITM AS varchar(20)) + '|' + LTRIM(RTRIM(im.IMUOM1)) AS [LB Key],
            LTRIM(RTRIM(d.PDKCOO)) + '|' + CAST(d.PDDOCO AS varchar(20)) + '|' + LTRIM(RTRIM(d.PDDCTO)) + '|' + CAST(d.PDLNID AS varchar(20)) AS [Line Key]
        FROM (
            SELECT
                PDKCOO, PDMCU, PDDOCO, PDLNID, PDLITM, PDITM, PDAN8, PDDCTO,
                CASE WHEN PDTRDJ>0 THEN DATEADD(DAY,(PDTRDJ%1000)-1,DATEFROMPARTS(1900+(PDTRDJ/1000),1,1)) END AS PO_Date,
                CASE WHEN PDDRQJ>0 THEN DATEADD(DAY,(PDDRQJ%1000)-1,DATEFROMPARTS(1900+(PDDRQJ/1000),1,1)) END AS Requested_Date,
                CASE WHEN PDPDDJ>0 THEN DATEADD(DAY,(PDPDDJ%1000)-1,DATEFROMPARTS(1900+(PDPDDJ/1000),1,1)) END AS Promised_Date,
                PDPQOR / 10000.0                     AS Qty_Ordered,
                PDUOPN / 10000.0                     AS Qty_Open,
                PDUREC / 10000.0                     AS Qty_Received,
                PDAEXP                               AS Amt_Spend,
                PDAOPN                               AS Amt_Purchase
            FROM PRODDTA.F4311
        ) d
        JOIN PRODDTA.F0101 v  ON d.PDAN8 = v.ABAN8
        LEFT JOIN PRODDTA.F4102 ib ON LTRIM(RTRIM(d.PDMCU)) = LTRIM(RTRIM(ib.IBMCU))
                                  AND LTRIM(RTRIM(d.PDLITM)) = LTRIM(RTRIM(ib.IBLITM))
        LEFT JOIN PRODDTA.F4101 im ON im.IMITM = d.PDITM
        WHERE d.Promised_Date >= DATEADD(DAY,-365, CAST(GETDATE() AS date))
          AND LTRIM(RTRIM(d.PDMCU)) IN ('CINC','CIN2','CIN4')
          AND LTRIM(RTRIM(d.PDDCTO)) IN ('OP','OD')
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Branch Plant", type text},
            {"PO Number", Int64.Type},
            {"Line Number", type number},
            {"2nd Item Number", type text},
            {"PO Date", type date},
            {"Requested Date", type date},
            {"Promised Date", type date},
            {"Vendor ID", Int64.Type},
            {"Vendor Name", type text},
            {"Lead Time Level", Int64.Type},
            {"PO Quantity Ordered", type number},
            {"Open Quantity", type number},
            {"Quantity Received", type number},
            {"Spend Amount USD", type number},
            {"Purchase Amount USD", type number},
            {"Item Key", Int64.Type},
            {"Primary UOM", type text},
            {"LB Key", type text},
            {"Line Key", type text}
        },
        "en-US"
    )
in
    Typed
