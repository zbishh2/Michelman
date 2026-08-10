let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            PO5.Company                     AS [Company],
            PO5.Branch_Plant                AS [Branch Plant],
            PO5.C_2nd_Item_Number           AS [2nd Item Number],
            PO5.Purchase_Order_Number       AS [Purchase Order Number],
            PO5.Reference_2                 AS [Reference 2],
            PO5.Reporting_Code_3            AS [Reporting Code 3],
            SUM(PO5.Open_Quantity)          AS [Open Quantity],
            SUM(PO5.Primary_Quantity)       AS [Primary Quantity],
            Item6.Primary_UOM               AS [Primary UOM],
            SUM(PO5.Secondary_Quantity)     AS [Secondary Quantity],
            Item6.Secondary_UOM             AS [Secondary UOM],
            PO5.Last_Status                 AS [Last Status],
            PO5.Next_Status                 AS [Next Status],
            PO5.Requested_Date              AS [Requested Date],
            PO5.Promised_Date               AS [Promised Date],
            SUM(PO5.Vendor_Code)            AS [Vendor Code],
            PO5.Vendor_Name                 AS [Vendor Name],
            PO5.Freeze_Code_Flag            AS [Freeze Code Flag],
            Item6.Branch_Plant              AS [Branch Plant1],
            Item6.Global_Bulk_Item          AS [Global Bulk Item],
            Item6.Bulk_Item                 AS [Bulk Item],
            Item6.C_2nd_Item_Number         AS [2nd Item Number1],
            Item6.Commodity_Class           AS [Commodity Class],
            Item6.Sub_Class                 AS [Sub Class],
            Item6.Master_Planning_Family    AS [Master Planning Family],
            Item6.GL_Category               AS [GL Category],
            Item6.Primary_Supplier          AS [Primary Supplier],
            Item6.Safety_Stock              AS [Safety Stock],
            Item6.Leadtime_Level            AS [Leadtime Level]
        FROM
        (
            SELECT DISTINCT
                LTRIM(RTRIM(LTRIM(RTRIM(ib.IBMCU))))    AS Branch_Plant,
                LTRIM(RTRIM(LTRIM(RTRIM(tag.IMGBLK))))  AS Global_Bulk_Item,
                LTRIM(RTRIM(LTRIM(RTRIM(tag.IMBULK))))  AS Bulk_Item,
                LTRIM(RTRIM(LTRIM(RTRIM(ib.IBLITM))))   AS C_2nd_Item_Number,
                ib.IBPRP1                               AS Commodity_Class,
                ib.IBPRP2                               AS Sub_Class,
                ib.IBPRP4                               AS Master_Planning_Family,
                ib.IBGLPT                               AS GL_Category,
                ib.IBVEND                               AS Primary_Supplier,
                ib.IBSAFE/10000.0                       AS Safety_Stock,
                ib.IBLTLV                               AS Leadtime_Level,
                im.IMUOM1                               AS Primary_UOM,
                im.IMUOM2                               AS Secondary_UOM
            FROM PRODDTA.F4102 ib, PRODDTA.F554101 tag, PRODDTA.F4101 im
            WHERE ib.IBITM = im.IMITM AND im.IMITM = tag.IMITM
        ) Item6
        INNER JOIN
        (
            SELECT
                pod.PDKCOO                          AS Company,
                LTRIM(RTRIM(pod.PDMCU))             AS Branch_Plant,
                LTRIM(RTRIM(pod.PDLITM))            AS C_2nd_Item_Number,
                pod.PDDOCO                          AS Purchase_Order_Number,
                pod.PDDRQJ                          AS Requested_Date,
                pod.PDVR02                          AS Reference_2,
                pod.PDPDP3                          AS Reporting_Code_3,
                SUM(pod.PDUOPN/10000.0)             AS Open_Quantity,
                SUM(pod.PDPQOR/10000.0)             AS Primary_Quantity,
                SUM(pod.PDSQOR/10000.0)             AS Secondary_Quantity,
                pod.PDLTTR                          AS Last_Status,
                pod.PDNXTR                          AS Next_Status,
                pod.PDPDDJ                          AS Promised_Date,
                SUM(pod.PDAN8)                      AS Vendor_Code,
                LTRIM(RTRIM(ab.ABALPH))             AS Vendor_Name,
                pod.PDUNCD                          AS Freeze_Code_Flag
            FROM
            (
                SELECT
                    PDKCOO, PDDOCO, PDDCTO, PDMCU, PDAN8,
                    CASE WHEN PDDRQJ>0 THEN DATEADD(DAY,(PDDRQJ%1000)-1,DATEFROMPARTS(1900+(PDDRQJ/1000),1,1)) ELSE NULL END AS PDDRQJ,
                    CASE WHEN PDPDDJ>0 THEN DATEADD(DAY,(PDPDDJ%1000)-1,DATEFROMPARTS(1900+(PDPDDJ/1000),1,1)) ELSE NULL END AS PDPDDJ,
                    PDVR02, PDLITM, PDNXTR, PDLTTR, PDPDP3, PDUOPN, PDPQOR, PDSQOR,
                    ISNULL(NULLIF(LTRIM(RTRIM(PDUNCD)),''),'-') AS PDUNCD
                FROM PRODDTA.F4311
            ) pod,
            PRODDTA.F0101 ab
            WHERE pod.PDPDDJ >= DATEADD(DAY,-365,CAST(GETDATE() AS date))
              AND pod.PDDCTO = 'OP'
              AND pod.PDAN8 = ab.ABAN8
            GROUP BY
                pod.PDKCOO, LTRIM(RTRIM(pod.PDMCU)), LTRIM(RTRIM(pod.PDLITM)), pod.PDDOCO,
                pod.PDDCTO, pod.PDDRQJ, pod.PDVR02, pod.PDPDP3, pod.PDLTTR, pod.PDNXTR,
                pod.PDPDDJ, LTRIM(RTRIM(ab.ABALPH)), pod.PDUNCD
        ) PO5
            ON Item6.Branch_Plant = PO5.Branch_Plant
           AND Item6.C_2nd_Item_Number = PO5.C_2nd_Item_Number
        GROUP BY
            PO5.Company, PO5.Branch_Plant, PO5.C_2nd_Item_Number, PO5.Purchase_Order_Number,
            PO5.Requested_Date, PO5.Reference_2, PO5.Reporting_Code_3, PO5.Last_Status,
            PO5.Next_Status, PO5.Promised_Date, PO5.Vendor_Name, PO5.Freeze_Code_Flag,
            Item6.Branch_Plant, Item6.Global_Bulk_Item, Item6.Bulk_Item, Item6.C_2nd_Item_Number,
            Item6.Commodity_Class, Item6.Sub_Class, Item6.Master_Planning_Family, Item6.GL_Category,
            Item6.Primary_Supplier, Item6.Safety_Stock, Item6.Leadtime_Level,
            Item6.Primary_UOM, Item6.Secondary_UOM
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Company", type text}, {"Branch Plant", type text}, {"2nd Item Number", type text},
            {"Purchase Order Number", Int64.Type}, {"Reference 2", type text}, {"Reporting Code 3", type text},
            {"Open Quantity", type number}, {"Primary Quantity", type number}, {"Primary UOM", type text},
            {"Secondary Quantity", type number}, {"Secondary UOM", type text}, {"Last Status", type text},
            {"Next Status", type text}, {"Requested Date", type date}, {"Promised Date", type date},
            {"Vendor Code", Int64.Type}, {"Vendor Name", type text}, {"Freeze Code Flag", type text},
            {"Branch Plant1", type text}, {"Global Bulk Item", type text}, {"Bulk Item", type text},
            {"2nd Item Number1", type text}, {"Commodity Class", type text}, {"Sub Class", type text},
            {"Master Planning Family", type text}, {"GL Category", type text}, {"Primary Supplier", Int64.Type},
            {"Safety Stock", type number}, {"Leadtime Level", type number}
        },
        "en-US"
    )
in
    Typed
