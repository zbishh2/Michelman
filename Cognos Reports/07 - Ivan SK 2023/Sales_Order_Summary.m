// ============================================================================
// Report 07 - Ivan SK 2023   (page 3 of 5: "Sales Orders")   [structural clone of report 09; SK filter literals]
// QUERY: Sales Order Summary  ->  Cognos list "List3", query object "Sales Order Summary"
//
// Columns (RENDERED order, 29): Order Company | Customer Code | Customer Name |
//   Customer Segmentation | Global Parent | Country Name | Branch Plant |
//   Order Number | Hold Orders Code | Global Bulk Item | Bulk Item |
//   2nd Item Number | Next Status | Last Status | ORDER KGs | ORDER LBs |
//   Primary Quantity Ordered | Primary UOM | Secondary Quantity Ordered |
//   Secondary UOM | Order Date | Requested Date | Promised Ship Date |
//   Scheduled Pick Date | CSR Name | TM Name | Customer PO |
//   Master Planning Family | Stock Type
//   (Display LABELS: Customer Segmentation->"Segmentation", Primary Quantity
//    Ordered->"Prim QTY", Primary UOM->"UOM", Secondary Quantity Ordered->"2nd QTY",
//    Secondary UOM->"UOM2", Master Planning Family->"MPF". See BUILD.md.)
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//   UDC country decode uses PRODCTL.F0005 (schema PRODCTL, per HANDOFF).
//
// SHAPE (faithful to Cognos "Sales Order Summary" - statement 3 of the raw SQL):
//   The raw was a WITH chain of 5 CTEs. PBI wraps the query as SELECT * FROM (...),
//   so a leading WITH is illegal -> ALL CTEs rewritten as NESTED DERIVED TABLES,
//   preserving the join graph, group-bys and the KG/LB CASE logic exactly:
//     Item_Information8 (II)          -> SELECT DISTINCT item attributes
//     F4211_Open_Sales_Orders (os)    -> F4211 projection w/ Julian->date
//     F4211_F0006_join_to_F42140 (f0006j) -> F4211 LEFT JOIN F0006, CMRTYPE = MCRP01+'GTM'
//     F42140__CSR (csr)               -> F42140/F0101 where CMRTYPE='CSR'
//     Sales_Orders7 (SO7)             -> the big open-order join, GROUP BY
//   Final: II LEFT OUTER JOIN SO7 on Branch_Plant + 2nd Item, GROUP BY, KG/LB CASE.
//   NOTE: the final WHERE re-asserts SO7.Branch_Plant=II.Branch_Plant AND
//   SO7.2nd_Item=II.2nd_Item, which makes the LEFT JOIN behave as an inner join
//   (Cognos quirk - kept verbatim), plus II.Bulk_Item in the SK 99-entry whitelist.
//   NOTE: SK's SO7 SDMCU branch list adds CINC/CIN2/CIN4/BARC/CIND/CINR to the 6 FC
//   plants, but II's branch list stays at the 6 APAC/EMEA plants; the LEFT-JOIN-as-
//   inner-join on Branch_Plant means only plants present in BOTH survive (Cognos quirk).
//
// Oracle -> T-SQL conversions:
//   decode(x, NULL, 'Unassigned', x)   -> CASE WHEN x IS NULL THEN 'Unassigned' ELSE x END (TM Name)
//   NVL(trim(MCRP01),'-') || 'GTM'     -> ISNULL(LTRIM(RTRIM(MCRP01)),'-') + 'GTM'
//   trim(both from x)                  -> LTRIM(RTRIM(x))
//   PRODDTA.JUL2DATE(col) w/ >0 guard  -> CASE WHEN col>0 THEN
//       DATEADD(DAY,(col%1000)-1,DATEFROMPARTS(1900+(col/1000),1,1)) END
//   x/10000                            -> x/10000.0
//   '00  ' = DRSY (2 trailing spaces)  -> kept verbatim
//   order by ... nulls last            -> OMITTED (folding). Cognos sort was Order
//       Company, Global Bulk Item, Bulk Item, Scheduled Pick Date -> set in visual.
//
// PARITY QUIRKS reproduced on purpose (documented in BUILD.md):
//   1. ORDER KGs / ORDER LBs: MIN(Primary_UOM) inside CASE while GROUP BY Primary_UOM
//      (MIN over group == the group's single UOM); EA multipliers x20 / x44; the ELSE
//      sentinel 1000000. Kept verbatim.
//   2. Scheduled Pick Date == Promised Ship Date (both = SDPDDJ; Cognos aliased the
//      same column twice). Emitted as two identical output columns.
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            SO7.Order_Company                         AS [Order Company],
            SO7.Customer_Code                         AS [Customer Code],
            SO7.Customer_Name                         AS [Customer Name],
            SO7.Customer_Segmentation                 AS [Customer Segmentation],
            SO7.Global_Parent                         AS [Global Parent],
            SO7.Country_Name                          AS [Country Name],
            SO7.Branch_Plant                          AS [Branch Plant],
            SO7.Order_Number                          AS [Order Number],
            SO7.Hold_Orders_Code                      AS [Hold Orders Code],
            II.Global_Bulk_Item                       AS [Global Bulk Item],
            II.Bulk_Item                              AS [Bulk Item],
            SO7.C_2nd_Item_Number                     AS [2nd Item Number],
            SO7.Next_Status                           AS [Next Status],
            SO7.Last_Status                           AS [Last Status],
            CASE WHEN MIN(SO7.Primary_UOM) = 'LB' THEN SUM(SO7.Primary_Quantity_Ordered) * 0.453593
                 WHEN MIN(SO7.Primary_UOM) = 'KG' THEN SUM(SO7.Primary_Quantity_Ordered)
                 WHEN MIN(SO7.Primary_UOM) = 'EA' THEN SUM(SO7.Primary_Quantity_Ordered) * 20
                 ELSE 1000000
            END                                       AS [ORDER KGs],
            CASE WHEN MIN(SO7.Primary_UOM) = 'LB' THEN SUM(SO7.Primary_Quantity_Ordered)
                 WHEN MIN(SO7.Primary_UOM) = 'KG' THEN SUM(SO7.Primary_Quantity_Ordered) / 0.453593
                 WHEN MIN(SO7.Primary_UOM) = 'EA' THEN SUM(SO7.Primary_Quantity_Ordered) * 44
                 ELSE 1000000
            END                                       AS [ORDER LBs],
            SUM(SO7.Primary_Quantity_Ordered)         AS [Primary Quantity Ordered],
            SO7.Primary_UOM                           AS [Primary UOM],
            SUM(SO7.Secondary_Quantity_Ordered)       AS [Secondary Quantity Ordered],
            SO7.Secondary_UOM                         AS [Secondary UOM],
            SO7.Order_Date                            AS [Order Date],
            SO7.Requested_Date                        AS [Requested Date],
            SO7.Promised_Ship_Date                    AS [Promised Ship Date],
            SO7.Promised_Ship_Date                    AS [Scheduled Pick Date],
            SO7.CSR_Name                              AS [CSR Name],
            SO7.TM_Name                               AS [TM Name],
            SO7.Customer_PO                           AS [Customer PO],
            II.Master_Planning_Family                 AS [Master Planning Family],
            II.Stock_Type                             AS [Stock Type]
        FROM (
            SELECT DISTINCT
                LTRIM(RTRIM(ib.IBMCU))   AS Branch_Plant,
                LTRIM(RTRIM(tag.IMGBLK)) AS Global_Bulk_Item,
                LTRIM(RTRIM(tag.IMBULK)) AS Bulk_Item,
                LTRIM(RTRIM(ib.IBLITM))  AS C_2nd_Item_Number,
                LTRIM(RTRIM(ib.IBPRP4))  AS Master_Planning_Family,
                LTRIM(RTRIM(ib.IBSTKT))  AS Stock_Type
            FROM PRODDTA.F4102 ib, PRODDTA.F554101 tag, PRODDTA.F4101 im
            WHERE LTRIM(RTRIM(ib.IBMCU)) IN ('SING', 'SNG4', 'MUM3', 'SHAN', 'AUBA', 'AUB2')
              AND LTRIM(RTRIM(ib.IBSTKT)) NOT IN ('I', 'O')
              AND ib.IBITM = im.IMITM
              AND im.IMITM = tag.IMITM
        ) II
        LEFT OUTER JOIN (
            SELECT
                os.SDKCOO                                                                            AS Order_Company,
                st.ABAN8                                                                             AS Customer_Code,
                LTRIM(RTRIM(st.ABALPH))                                                              AS Customer_Name,
                st.ABAC06                                                                            AS Customer_Segmentation,
                st.ABAN86                                                                            AS Global_Parent,
                LTRIM(RTRIM(t3.DRDL01))                                                              AS Country_Name,
                LTRIM(RTRIM(os.SDMCU))                                                               AS Branch_Plant,
                os.SDDOCO                                                                            AS Order_Number,
                LTRIM(RTRIM(os.SDLITM))                                                              AS C_2nd_Item_Number,
                os.SDNXTR                                                                            AS Next_Status,
                os.SDLTTR                                                                            AS Last_Status,
                SUM(os.SDPQOR/10000.0)                                                               AS Primary_Quantity_Ordered,
                os.SDUOM1                                                                            AS Primary_UOM,
                SUM(os.SDSQOR/10000.0)                                                               AS Secondary_Quantity_Ordered,
                os.SDUOM2                                                                            AS Secondary_UOM,
                os.SDTRDJ                                                                            AS Order_Date,
                os.SDDRQJ                                                                            AS Requested_Date,
                os.SDPDDJ                                                                            AS Promised_Ship_Date,
                LTRIM(RTRIM(CASE WHEN salesrepab.ABALPH IS NULL THEN 'Unassigned' ELSE salesrepab.ABALPH END)) AS TM_Name,
                LTRIM(RTRIM(os.SDVR01))                                                              AS Customer_PO,
                oh.SHHOLD                                                                            AS Hold_Orders_Code,
                LTRIM(RTRIM(csr.ABALPH))                                                             AS CSR_Name
            FROM ((((((
                (SELECT
                     SDKCOO, SDDOCO, SDDCTO, SDLNID, SDSFXO, SDMCU, SDSHAN,
                     CASE WHEN SDDRQJ > 0 THEN DATEADD(DAY,(SDDRQJ%1000)-1,DATEFROMPARTS(1900+(SDDRQJ/1000),1,1)) END AS SDDRQJ,
                     CASE WHEN SDTRDJ > 0 THEN DATEADD(DAY,(SDTRDJ%1000)-1,DATEFROMPARTS(1900+(SDTRDJ/1000),1,1)) END AS SDTRDJ,
                     CASE WHEN SDPDDJ > 0 THEN DATEADD(DAY,(SDPDDJ%1000)-1,DATEFROMPARTS(1900+(SDPDDJ/1000),1,1)) END AS SDPDDJ,
                     SDVR01, SDLITM, SDLNTY, SDNXTR, SDLTTR, SDEMCU, SDUOM1, SDPQOR, SDUOM2, SDSQOR
                 FROM PRODDTA.F4211) os
                INNER JOIN PRODDTA.F0101 st ON os.SDSHAN = st.ABAN8 )
                INNER JOIN PRODDTA.F0116 addr ON st.ABAN8 = addr.ALAN8 )
                INNER JOIN PRODDTA.F4201 oh ON os.SDKCOO = oh.SHKCOO AND os.SDDOCO = oh.SHDOCO AND os.SDDCTO = oh.SHDCTO AND os.SDSFXO = oh.SHSFXO )
                LEFT OUTER JOIN (
                    SELECT
                        f.SDKCOO, f.SDDOCO, f.SDDCTO, f.SDLNID, f.SDSHAN,
                        CASE WHEN ISNULL(LTRIM(RTRIM(mc.MCRP01)), '-') IS NULL THEN NULL
                             ELSE ISNULL(LTRIM(RTRIM(mc.MCRP01)), '-') + 'GTM' END AS CMRTYPE
                    FROM PRODDTA.F4211 f LEFT OUTER JOIN PRODDTA.F0006 mc ON f.SDEMCU = mc.MCMCU
                ) f0006j ON os.SDKCOO = f0006j.SDKCOO AND os.SDDOCO = f0006j.SDDOCO AND os.SDDCTO = f0006j.SDDCTO AND os.SDLNID = f0006j.SDLNID )
                LEFT OUTER JOIN (PRODDTA.F42140 salesrep INNER JOIN PRODDTA.F0101 salesrepab ON salesrep.CMSLSM = salesrepab.ABAN8) ON f0006j.SDSHAN = salesrep.CMAN8 AND f0006j.CMRTYPE = salesrep.CMRTYPE )
                LEFT OUTER JOIN (
                    SELECT c.CMAN8, ab.ABALPH
                    FROM PRODDTA.F42140 c, PRODDTA.F0101 ab
                    WHERE c.CMRTYPE = 'CSR' AND c.CMSLSM = ab.ABAN8
                ) csr ON os.SDSHAN = csr.CMAN8 )
                LEFT OUTER JOIN PRODCTL.F0005 t3 ON LTRIM(RTRIM(addr.ALCTR)) = LTRIM(RTRIM(t3.DRKY)) AND '00  ' = t3.DRSY AND 'CN' = t3.DRRT
            WHERE os.SDLNTY = 'S'
              AND os.SDPQOR/10000.0 > 0
              AND os.SDNXTR NOT IN ('570', '580', '620', '999')
              AND LTRIM(RTRIM(os.SDMCU)) IN ('AUBA', 'AUB2', 'SING', 'SNG4', 'MUM3', 'SHAN', 'CINC', 'CIN2', 'CIN4', 'BARC', 'CIND', 'CINR')
            GROUP BY
                os.SDKCOO, st.ABAN8, LTRIM(RTRIM(st.ABALPH)), st.ABAC06, st.ABAN86,
                LTRIM(RTRIM(t3.DRDL01)), LTRIM(RTRIM(os.SDMCU)), os.SDDOCO,
                LTRIM(RTRIM(os.SDLITM)), os.SDNXTR, os.SDLTTR, os.SDLNTY, os.SDUOM1, os.SDUOM2,
                os.SDTRDJ, os.SDDRQJ, os.SDPDDJ, os.SDEMCU,
                LTRIM(RTRIM(CASE WHEN salesrepab.ABALPH IS NULL THEN 'Unassigned' ELSE salesrepab.ABALPH END)),
                LTRIM(RTRIM(os.SDVR01)), oh.SHHOLD, LTRIM(RTRIM(csr.ABALPH))
        ) SO7
          ON II.Branch_Plant = SO7.Branch_Plant AND II.C_2nd_Item_Number = SO7.C_2nd_Item_Number
        WHERE SO7.Branch_Plant = II.Branch_Plant
          AND SO7.C_2nd_Item_Number = II.C_2nd_Item_Number
          AND II.Bulk_Item IN ('PR3460', 'PR3460.E', 'PR5980I', 'PR5980I.E', 'PR5980I.S', 'PR5985', 'PR5985.E', 'PR5985.S', 'DPI8600.E', 'PH00007E.E', '201250PX.E', 'DPI8200.E', 'MF4915.E', 'MFHS1130.E', 'MFP1857.E', 'MP3000.E', 'MP48525R.E', 'MP4932.E', 'MP498340R.E', 'PH00017E.E', 'MFP1853R.E', 'MP498345P.E', 'MP4983RHSA.E', '201081CX', '241083PX.S', '241088PX.S', '241089PX.S', '241199PX.S', '241252PX.S', '251095NX.S', '251142PX.S', '251144PX.S', '251194NX.S', '251268PX.S', 'MF1204.S', 'MF1306D.S', 'MF1406.S', 'MFHS1881.S', 'MFP1853R.S', 'MFP1883.S', 'MP4982SC.S', 'MP498340R.S', 'MP498345N.S', 'MP4983R.S', 'MP4983RHS.S', 'PH00017E.S', 'PI8545.S', '241253PX.S', '241168PX', '241201FX', 'DP040', 'DPI8600', 'HSCF280', 'ILP040', 'KHI205', 'KHI340', 'MED310', 'MED800', 'MFHS168', 'MFHS268', 'MFP1853R', 'MP04422R', 'MP3000', 'MP48525R', 'MP498340D', 'MP498340R', 'MP498345N', 'MP4983RHS', 'MT242AF', 'PA845H', 'PH00015E', 'PH00017E', 'UBD211', 'UBD268', 'UTS610', '251379PX.E', 'MFP1883.E', 'MP4983RAM.E', 'PH00001A.E', '251095NX.E', '251194NX.E', 'MD7900.E', 'MP4983R.E', '251246NX.E', '251095NX', '251194NX', '261044NX', '261074NX', '605000007', 'MFP1883', 'MP4983R', 'MP4983RN', 'RM108', 'UPR420', '221247PX.E', 'MP2960.E', '221247PX', '231093FX', 'MP2960')
        GROUP BY
            SO7.Order_Company, SO7.Customer_Code, SO7.Customer_Name, SO7.Customer_Segmentation,
            SO7.Global_Parent, SO7.Country_Name, SO7.Hold_Orders_Code, SO7.Branch_Plant,
            SO7.Order_Number, SO7.C_2nd_Item_Number, SO7.Next_Status, SO7.Last_Status,
            SO7.Primary_UOM, SO7.Secondary_UOM, SO7.Requested_Date, SO7.Promised_Ship_Date,
            SO7.TM_Name, SO7.CSR_Name, SO7.Order_Date, SO7.Customer_PO,
            II.Global_Bulk_Item, II.Bulk_Item, II.Master_Planning_Family, II.Stock_Type
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Order Company", type text},
            {"Customer Code", Int64.Type},
            {"Customer Name", type text},
            {"Customer Segmentation", type text},
            {"Global Parent", Int64.Type},
            {"Country Name", type text},
            {"Branch Plant", type text},
            {"Order Number", Int64.Type},
            {"Hold Orders Code", type text},
            {"Global Bulk Item", type text},
            {"Bulk Item", type text},
            {"2nd Item Number", type text},
            {"Next Status", type text},
            {"Last Status", type text},
            {"ORDER KGs", type number},
            {"ORDER LBs", type number},
            {"Primary Quantity Ordered", type number},
            {"Primary UOM", type text},
            {"Secondary Quantity Ordered", type number},
            {"Secondary UOM", type text},
            {"Order Date", type date},
            {"Requested Date", type date},
            {"Promised Ship Date", type date},
            {"Scheduled Pick Date", type date},
            {"CSR Name", type text},
            {"TM Name", type text},
            {"Customer PO", type text},
            {"Master Planning Family", type text},
            {"Stock Type", type text}
        },
        "en-US"
    )
in
    Typed
