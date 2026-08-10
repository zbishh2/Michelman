let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            base.Scheduled_Pick_Date              AS [Scheduled Pick Date],
            base.Carrier_AB_Number                AS [Carrier AB Number],
            base.Customer_Name                    AS [Customer Name],
            base.Order_Number                     AS [Order Number],
            base.Next_Status                      AS [Next Status],
            base.Order_Type                       AS [Order Type],
            base.Order_Line                       AS [Order Line],
            base.Carrier_Name                     AS [Carrier Name],
            base.CSR_Name                         AS [CSR Name],
            SUM(base.Primary_Quantity_Ordered)    AS [Primary Quantity Ordered],
            base.Primary_UOM                      AS [Primary UOM],
            base.CSR_AB_Number                    AS [CSR AB Number]
        FROM (
            SELECT
                o.SDDOCO                          AS Order_Number,
                o.SDDCTO                          AS Order_Type,
                o.SDCARS                          AS Carrier_AB_Number,
                LTRIM(RTRIM(carr.ABALPH))         AS Carrier_Name,
                LTRIM(RTRIM(csr.ABALPH))          AS CSR_Name,
                o.SDPQOR / 10000.0                AS Primary_Quantity_Ordered,
                LTRIM(RTRIM(o.SDUOM1))            AS Primary_UOM,
                o.SDNXTR                          AS Next_Status,
                LTRIM(RTRIM(shipto.ABALPH))       AS Customer_Name,
                o.SDLNID / 1000.0                 AS Order_Line,
                CASE WHEN o.SDPDDJ > 0
                     THEN DATEADD(DAY, (o.SDPDDJ % 1000) - 1, DATEFROMPARTS(1900 + (o.SDPDDJ / 1000), 1, 1))
                END                               AS Scheduled_Pick_Date,
                csr.CMSLSM                        AS CSR_AB_Number
            FROM PRODDTA.F4211 o
            INNER JOIN PRODDTA.F0101 shipto
                ON o.SDSHAN = shipto.ABAN8
            LEFT OUTER JOIN (
                SELECT c.CMAN8, c.CMSLSM, a.ABALPH
                FROM PRODDTA.F42140 c
                INNER JOIN PRODDTA.F0101 a
                    ON c.CMSLSM = a.ABAN8
                WHERE c.CMRTYPE = 'CSR'
            ) csr
                ON o.SDSHAN = csr.CMAN8
            LEFT OUTER JOIN PRODDTA.F0101 carr
                ON o.SDCARS = carr.ABAN8
            WHERE o.SDKCOO = '00010'
              AND o.SDDCTO IN ('S4','S5','SZ','SC','ST')
              AND o.SDNXTR IN ('560','550','545','540','535','530','525')
              AND o.SDCARS NOT IN (293371,29671,288676,26185,293492,98725,301322,195487,136656,293919,304977,309791,301333,309741,27710,26171,283919,26175,301761,292099,309757,316502)
              AND o.SDPQOR / 10000.0 > 20000
              AND o.SDCARS <> 308636
        ) base
        GROUP BY
            base.Scheduled_Pick_Date,
            base.Carrier_AB_Number,
            base.Customer_Name,
            base.Order_Number,
            base.Next_Status,
            base.Order_Type,
            base.Order_Line,
            base.Carrier_Name,
            base.CSR_Name,
            base.Primary_UOM,
            base.CSR_AB_Number
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Scheduled Pick Date", type date},
            {"Carrier AB Number", Int64.Type},
            {"Customer Name", type text},
            {"Order Number", Int64.Type},
            {"Next Status", type text},
            {"Order Type", type text},
            {"Order Line", type number},
            {"Carrier Name", type text},
            {"CSR Name", type text},
            {"Primary Quantity Ordered", type number},
            {"Primary UOM", type text},
            {"CSR AB Number", Int64.Type}
        },
        "en-US"
    )
in
    Typed
