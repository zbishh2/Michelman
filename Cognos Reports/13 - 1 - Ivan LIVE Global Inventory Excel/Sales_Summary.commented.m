// ============================================================================
// Report 13 - 1 - Ivan LIVE Global Inventory Excel   (page 3 of 6: "Sales")
// QUERY: Sales Summary  ->  Cognos list "List2", query object "Sales Summary"
// SOURCE SQL: "Sales Summary.2.sql"
//
// Columns (RENDERED order, 22 - headers verbatim):
//   Order Company | Branch Plant | Global Bulk Item | Bulk Item | 2nd Item Number |
//   Order Number | Order Line | Customer PO | Lot Number | Hold Orders Code |
//   Last Status | Next Status | Primary Quantity Ordered | Primary UOM |
//   Secondary Quantity Ordered | Secondary UOM | Order Date | Promised Ship Date |
//   Scheduled Pick Date | Customer Code | Customer Name | Order Type
//
// SOURCE: ODSPROD / "ODS" / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//
// LOGIC (faithful to "Sales Summary.2.sql"): Item master (Item6) INNER JOIN open sales
//   orders (Sales5) on Branch Plant + 2nd Item.
//     * Sales5 = F4211 sales-order detail joined to F4201 (order header -> Hold Orders
//                Code SHHOLD) and F0101 (ship-to customer name), grouped, filtered
//                Primary Qty > 0 AND Next Status NOT IN ('620','999') AND Order Type <> 'ST'.
//   These are OPEN orders only (620/999 excluded); no F42119 purge-history UNION is
//   needed (F42119 holds closed/999 lines, which this query deliberately excludes).
//
// COGNOS QUIRK reproduced: "Promised Ship Date" AND "Scheduled Pick Date" both map to
//   the SAME source column SDPDDJ (Cognos aliased C13 twice). Both are Julian(SDPDDJ).
//
// Oracle -> T-SQL: trim(both from x) -> LTRIM(RTRIM(x)); SDLNID/1000 -> SDLNID/1000.0
//   (Order Line has an implied 3-decimal scale); JUL2DATE guarded by >0 ->
//   CASE WHEN x>0 THEN DATEADD(DAY,(x%1000)-1,DATEFROMPARTS(1900+(x/1000),1,1)) ELSE NULL END;
//   x/10000 -> x/10000.0; NOT IN lists kept; no ORDER BY (folded).
//   Cognos sort: Global Bulk Item, Bulk Item, 2nd Item Number, Promised Ship Date
//   -> set in the visual (the hidden Cognos sort key "2nd Item Number1" equals the
//   visible "2nd Item Number" because the join forces them equal). See BUILD.md.
//   Numeric identifiers (Order Number, Customer Code) -> summarizeBy:none in the visual.
// Expected rows to xlsx "Sales_3": 1,034 (as-of capture; live counts drift).
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            Sales5.Order_Company                 AS [Order Company],
            Sales5.Branch_Plant                  AS [Branch Plant],
            Item6.Global_Bulk_Item               AS [Global Bulk Item],
            Item6.Bulk_Item                      AS [Bulk Item],
            Sales5.C_2nd_Item_Number             AS [2nd Item Number],
            Sales5.Order_Number                  AS [Order Number],
            Sales5.Order_Line                    AS [Order Line],
            Sales5.Customer_PO                   AS [Customer PO],
            Sales5.Lot_Number                    AS [Lot Number],
            Sales5.Hold_Orders_Code              AS [Hold Orders Code],
            Sales5.Last_Status                   AS [Last Status],
            Sales5.Next_Status                   AS [Next Status],
            SUM(Sales5.Primary_Quantity_Ordered) AS [Primary Quantity Ordered],
            Sales5.Primary_UOM                   AS [Primary UOM],
            SUM(Sales5.Secondary_Quantity_Ordered) AS [Secondary Quantity Ordered],
            Sales5.Secondary_UOM                 AS [Secondary UOM],
            Sales5.Order_Date                    AS [Order Date],
            Sales5.Promised_Ship_Date            AS [Promised Ship Date],
            Sales5.Scheduled_Pick_Date           AS [Scheduled Pick Date],
            Sales5.Customer_Code                 AS [Customer Code],
            Sales5.Customer_Name                 AS [Customer Name],
            Sales5.Order_Type                    AS [Order Type]
        FROM
        (
            SELECT DISTINCT
                LTRIM(RTRIM(LTRIM(RTRIM(ib.IBMCU))))    AS Branch_Plant,
                LTRIM(RTRIM(LTRIM(RTRIM(tag.IMGBLK))))  AS Global_Bulk_Item,
                LTRIM(RTRIM(LTRIM(RTRIM(tag.IMBULK))))  AS Bulk_Item,
                LTRIM(RTRIM(LTRIM(RTRIM(ib.IBLITM))))   AS C_2nd_Item_Number
            FROM PRODDTA.F4102 ib, PRODDTA.F554101 tag, PRODDTA.F4101 im
            WHERE ib.IBITM = im.IMITM AND im.IMITM = tag.IMITM
        ) Item6
        INNER JOIN
        (
            SELECT
                so.SDKCOO                        AS Order_Company,
                LTRIM(RTRIM(so.SDMCU))           AS Branch_Plant,
                so.SDDOCO                        AS Order_Number,
                so.SDLNID/1000.0                 AS Order_Line,
                LTRIM(RTRIM(so.SDVR01))          AS Customer_PO,
                LTRIM(RTRIM(so.SDLITM))          AS C_2nd_Item_Number,
                LTRIM(RTRIM(so.SDLOTN))          AS Lot_Number,
                oh.SHHOLD                        AS Hold_Orders_Code,
                so.SDLTTR                        AS Last_Status,
                so.SDNXTR                        AS Next_Status,
                SUM(so.SDPQOR/10000.0)           AS Primary_Quantity_Ordered,
                so.SDUOM1                        AS Primary_UOM,
                CASE WHEN so.SDTRDJ>0 THEN DATEADD(DAY,(so.SDTRDJ%1000)-1,DATEFROMPARTS(1900+(so.SDTRDJ/1000),1,1)) ELSE NULL END AS Order_Date,
                CASE WHEN so.SDPDDJ>0 THEN DATEADD(DAY,(so.SDPDDJ%1000)-1,DATEFROMPARTS(1900+(so.SDPDDJ/1000),1,1)) ELSE NULL END AS Promised_Ship_Date,
                CASE WHEN so.SDPDDJ>0 THEN DATEADD(DAY,(so.SDPDDJ%1000)-1,DATEFROMPARTS(1900+(so.SDPDDJ/1000),1,1)) ELSE NULL END AS Scheduled_Pick_Date,
                SUM(so.SDSQOR/10000.0)           AS Secondary_Quantity_Ordered,
                so.SDUOM2                        AS Secondary_UOM,
                cust.ABAN8                       AS Customer_Code,
                LTRIM(RTRIM(cust.ABALPH))        AS Customer_Name,
                so.SDDCTO                        AS Order_Type
            FROM PRODDTA.F4211 so,
                 PRODDTA.F4201 oh,
                 PRODDTA.F0101 cust
            WHERE so.SDPQOR/10000.0 > 0
              AND so.SDNXTR NOT IN ('620','999')
              AND so.SDDCTO NOT IN ('ST')
              AND so.SDSHAN = cust.ABAN8
              AND so.SDKCOO = oh.SHKCOO
              AND so.SDDOCO = oh.SHDOCO
              AND so.SDDCTO = oh.SHDCTO
              AND so.SDSFXO = oh.SHSFXO
            GROUP BY
                so.SDKCOO, LTRIM(RTRIM(so.SDMCU)), so.SDDOCO, so.SDLNID/1000.0,
                LTRIM(RTRIM(so.SDVR01)), LTRIM(RTRIM(so.SDLITM)), LTRIM(RTRIM(so.SDLOTN)),
                oh.SHHOLD, so.SDLTTR, so.SDNXTR, so.SDUOM1, so.SDTRDJ, so.SDPDDJ, so.SDUOM2,
                cust.ABAN8, LTRIM(RTRIM(cust.ABALPH)), so.SDDCTO
        ) Sales5
            ON Item6.Branch_Plant = Sales5.Branch_Plant
           AND Item6.C_2nd_Item_Number = Sales5.C_2nd_Item_Number
        GROUP BY
            Sales5.Order_Company, Sales5.Branch_Plant, Sales5.Order_Number, Sales5.Order_Line,
            Sales5.Customer_PO, Sales5.C_2nd_Item_Number, Sales5.Lot_Number, Sales5.Hold_Orders_Code,
            Sales5.Last_Status, Sales5.Next_Status, Sales5.Primary_UOM, Sales5.Order_Date,
            Sales5.Promised_Ship_Date, Sales5.Scheduled_Pick_Date, Sales5.Secondary_UOM,
            Sales5.Customer_Code, Sales5.Customer_Name, Sales5.Order_Type,
            Item6.Global_Bulk_Item, Item6.Bulk_Item, Item6.C_2nd_Item_Number
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Order Company", type text}, {"Branch Plant", type text}, {"Global Bulk Item", type text},
            {"Bulk Item", type text}, {"2nd Item Number", type text}, {"Order Number", Int64.Type},
            {"Order Line", type number}, {"Customer PO", type text}, {"Lot Number", type text},
            {"Hold Orders Code", type text}, {"Last Status", type text}, {"Next Status", type text},
            {"Primary Quantity Ordered", type number}, {"Primary UOM", type text},
            {"Secondary Quantity Ordered", type number}, {"Secondary UOM", type text},
            {"Order Date", type date}, {"Promised Ship Date", type date}, {"Scheduled Pick Date", type date},
            {"Customer Code", Int64.Type}, {"Customer Name", type text}, {"Order Type", type text}
        },
        "en-US"
    )
in
    Typed
