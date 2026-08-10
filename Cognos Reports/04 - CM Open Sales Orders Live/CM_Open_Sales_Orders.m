// ============================================================================
// Report 04 - CM Open Sales Orders LIVE
// QUERY: CM_Open_Sales_Orders  ->  the visible "CM Open Sales Orders" detail list
//        (Cognos list "List1", query object "Sales Summary"). This is page 3 of
//        the shared "CM Overview LIVE" PBIP and the main deliverable panel.
//
// Columns (left -> right, Cognos label): Company | Branch | Order # | Line # |
//   Customer PO | Order Date | Requested | Promised Ship | Item | Next Status |
//   QTY | UOM | QTY | UOM | Customer Name | TM Name
//   (the two QTY/UOM pairs are Primary then Secondary). REGION is carried as a
//   non-visible column to drive the "Select the Region" slicer (see BUILD.md).
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//   Matches the house pattern in edw_model/JDE_Orders/Orders.m and reports 01/02.
//
// NOTE: written with INLINE DERIVED TABLES (not a top-level WITH/CTE). With
//   [EnableFolding=true] Power BI wraps the query as "SELECT * FROM (<query>)",
//   and a leading CTE throws "Incorrect syntax near 'WITH'". The Cognos CTE chain
//   (Item_Branch7 / F4211_Open_Sales_Orders / F4211_F0006_join_to_F42140 /
//   Sales_Orders6) is rewritten as nested subqueries.
//
// LOGIC (faithful to Cognos "Sales Summary"):
//   Item_Branch7  = DISTINCT item-branch (F4102) x item-master (F4101) x
//                   item-tag (F554101), giving Bulk_Item (IMBULK) and
//                   Global_Bulk_Item (IMGBLK) per (branch, 2nd item).
//   OpenSO (o)    = F4211 lines with the three Julian dates decoded to real
//                   dates (Requested / Order / Promised Ship).
//   TMkey (fj)    = F4211 LEFT JOIN F0006 (SDEMCU = MCMCU) building a synthetic
//                   CMRTYPE = ISNULL(trim(MCRP01),'-') + 'GTM' per SO line,
//                   keyed on (SDKCOO, SDDOCO, SDDCTO, SDLNID) + SDSHAN.
//   Sales_Orders6 = OpenSO INNER JOIN ship-to customer (F0101 via SDSHAN)
//                   LEFT JOIN TMkey (the 4 line keys)
//                   LEFT JOIN (F42140 sales_rep INNER JOIN F0101 rep-name on
//                             CMSLSM = ABAN8) on TMkey.SDSHAN = CMAN8
//                             AND TMkey.CMRTYPE = CMRTYPE.
//                   TM_Name = ISNULL(rep ABALPH,'Unassigned'); REGION = branch
//                   decode (default 'Americas'). Filter SDNXTR NOT IN ('999').
//                   Quantities SUMmed to the order-line grain.
//   FINAL = Item_Branch7 LEFT OUTER JOIN Sales_Orders6 on (Branch_Plant, 2nd
//           item), with a WHERE that forces the match (equi-join both keys) AND
//           a Bulk_Item whitelist (the long IN-list, copied verbatim from the
//           Cognos filter - note it includes DPE3500.E, JS037, HP401, HSCF410,
//           UNYTEC201). Quantities SUMmed AGAIN (Cognos double-sum, reproduced).
//
// The LEFT OUTER JOIN + WHERE (Sales_Orders6 keys = Item_Branch7 keys) is the
//   Cognos join; the WHERE forces it to behave as an inner join, so only order
//   lines whose (branch, 2nd item) sits in the whitelisted Item_Branch7 survive.
//
// DOUBLE-SUM reproduced on purpose (parity): Sales_Orders6 already SUMs the
//   quantities to the line grain, and the FINAL step SUMs the summed values
//   again. Item_Branch7 is DISTINCT on (Branch, Global_Bulk, Bulk, 2nd item), so
//   one SO line can fan out across multiple Bulk_Item rows for the same (branch,
//   2nd item); the final SUM adds those copies. This ties to the live Cognos
//   report. See BUILD.md "Known Cognos quirks".
//
// JULIAN: JDE CYYDDD -> date via DATEADD/DATEFROMPARTS (1900+CYY, day-of-year).
//   Requested / Order Date / Promised Ship come through as real dates.
// ORDER BY is intentionally OMITTED (an ORDER BY inside the folded subquery is
//   illegal in SQL Server); sort in the visual: Promised Ship, Order #, Line #
//   (all ascending). Cognos sorts NULLs last -> PBI puts blanks last ascending.
// NO date/company filter is baked in (both companies 00010 & 00020 appear). The
//   Cognos "Enter the Date Range" and "Select the Region" prompts are OPTIONAL
//   detail filters -> reproduce as PBI slicers (Promised Ship range + REGION).
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            so6.Order_Company                                 AS [Company],
            so6.Branch_Plant                                  AS [Branch],
            so6.Order_Number                                  AS [Order #],
            so6.Order_Line                                    AS [Line #],
            so6.Customer_PO                                   AS [Customer PO],
            so6.Order_Date                                    AS [Order Date],
            so6.Requested_Date                                AS [Requested],
            so6.Promised_Ship_Date                            AS [Promised Ship],
            so6.C_2nd_Item_Number                             AS [Item],
            so6.Next_Status                                   AS [Next Status],
            SUM(so6.Primary_Quantity_Ordered)                 AS [Primary Qty],
            so6.Primary_UOM                                   AS [Primary UOM],
            SUM(so6.Secondary_Quantity_Ordered)               AS [Secondary Qty],
            so6.Secondary_UOM                                 AS [Secondary UOM],
            so6.Customer_Name                                 AS [Customer Name],
            so6.TM_Name                                       AS [TM Name],
            so6.REGION                                        AS [REGION]
        FROM (
            /* ---- Item_Branch7 : item-branch x item-master x item-tag (bulk) ---- */
            SELECT DISTINCT
                LTRIM(RTRIM(ib.IBMCU))    AS Branch_Plant,
                LTRIM(RTRIM(tag.IMGBLK))  AS Global_Bulk_Item,
                LTRIM(RTRIM(tag.IMBULK))  AS Bulk_Item,
                LTRIM(RTRIM(ib.IBLITM))   AS C_2nd_Item_Number
            FROM PRODDTA.F4102 ib
            JOIN PRODDTA.F4101 im    ON ib.IBITM = im.IMITM
            JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
        ) ib7
        LEFT OUTER JOIN (
            /* ---- Sales_Orders6 : open SO lines + ship-to + TM name + region ---- */
            SELECT
                o.SDKCOO                          AS Order_Company,
                LTRIM(RTRIM(o.SDMCU))             AS Branch_Plant,
                o.SDDOCO                          AS Order_Number,
                o.SDLNID / 1000.0                 AS Order_Line,
                LTRIM(RTRIM(o.SDLITM))            AS C_2nd_Item_Number,
                o.SDNXTR                          AS Next_Status,
                o.SDTRDJ                          AS Order_Date,
                SUM(o.SDPQOR / 10000.0)           AS Primary_Quantity_Ordered,
                o.SDUOM1                          AS Primary_UOM,
                SUM(o.SDSQOR / 10000.0)           AS Secondary_Quantity_Ordered,
                o.SDUOM2                          AS Secondary_UOM,
                o.SDDRQJ                          AS Requested_Date,
                o.SDPDDJ                          AS Promised_Ship_Date,
                LTRIM(RTRIM(ISNULL(srn.ABALPH, 'Unassigned'))) AS TM_Name,
                LTRIM(RTRIM(o.SDVR01))            AS Customer_PO,
                LTRIM(RTRIM(shipto.ABALPH))       AS Customer_Name,
                CASE LTRIM(RTRIM(o.SDMCU))
                     WHEN 'CINC' THEN 'Americas'  WHEN 'CIN2' THEN 'Americas'
                     WHEN 'CIN4' THEN 'Americas'  WHEN 'GRAN' THEN 'Americas'
                     WHEN 'DANC' THEN 'Americas'  WHEN 'BPIP' THEN 'Americas'
                     WHEN 'AUBA' THEN 'Aubange'   WHEN 'AUB2' THEN 'Aubange'
                     WHEN 'SHAN' THEN 'Shanghai'
                     WHEN 'SING' THEN 'Singapore' WHEN 'SNG4' THEN 'Singapore'
                     WHEN 'MUM3' THEN 'Mumbai'
                     ELSE 'Americas'
                END                               AS REGION
            FROM (
                (
                    /* ---- OpenSO : F4211 lines, Julian dates decoded ---- */
                    SELECT
                        so.SDKCOO, so.SDDOCO, so.SDDCTO, so.SDLNID, so.SDMCU, so.SDSHAN,
                        (CASE WHEN so.SDDRQJ > 0
                              THEN DATEADD(DAY, (so.SDDRQJ % 1000) - 1, DATEFROMPARTS(1900 + (so.SDDRQJ / 1000), 1, 1))
                         END)                     AS SDDRQJ,
                        (CASE WHEN so.SDTRDJ > 0
                              THEN DATEADD(DAY, (so.SDTRDJ % 1000) - 1, DATEFROMPARTS(1900 + (so.SDTRDJ / 1000), 1, 1))
                         END)                     AS SDTRDJ,
                        (CASE WHEN so.SDPDDJ > 0
                              THEN DATEADD(DAY, (so.SDPDDJ % 1000) - 1, DATEFROMPARTS(1900 + (so.SDPDDJ / 1000), 1, 1))
                         END)                     AS SDPDDJ,
                        so.SDVR01, so.SDLITM, so.SDNXTR, so.SDUOM1, so.SDPQOR,
                        so.SDUOM2, so.SDSQOR
                    FROM PRODDTA.F4211 so
                ) o
                INNER JOIN PRODDTA.F0101 shipto ON o.SDSHAN = shipto.ABAN8
                LEFT OUTER JOIN (
                    /* ---- TMkey : F4211 LEFT JOIN F0006 -> synthetic CMRTYPE ---- */
                    SELECT
                        f.SDKCOO, f.SDDOCO, f.SDDCTO, f.SDLNID, f.SDSHAN,
                        CASE WHEN ISNULL(LTRIM(RTRIM(mc.MCRP01)), '-') IS NULL
                             THEN NULL
                             ELSE ISNULL(LTRIM(RTRIM(mc.MCRP01)), '-') + 'GTM'
                        END                       AS CMRTYPE
                    FROM PRODDTA.F4211 f
                    LEFT OUTER JOIN PRODDTA.F0006 mc ON f.SDEMCU = mc.MCMCU
                ) fj
                  ON  o.SDKCOO = fj.SDKCOO
                  AND o.SDDOCO = fj.SDDOCO
                  AND o.SDDCTO = fj.SDDCTO
                  AND o.SDLNID = fj.SDLNID
                LEFT OUTER JOIN (
                    PRODDTA.F42140 sr
                    INNER JOIN PRODDTA.F0101 srn ON sr.CMSLSM = srn.ABAN8
                )
                  ON  fj.SDSHAN  = sr.CMAN8
                  AND fj.CMRTYPE = sr.CMRTYPE
            )
            WHERE o.SDNXTR NOT IN ('999')
            GROUP BY
                o.SDKCOO, LTRIM(RTRIM(o.SDMCU)), o.SDDOCO, o.SDLNID / 1000.0,
                LTRIM(RTRIM(o.SDLITM)), o.SDNXTR, o.SDTRDJ, o.SDUOM1, o.SDUOM2,
                o.SDDRQJ, o.SDPDDJ,
                LTRIM(RTRIM(ISNULL(srn.ABALPH, 'Unassigned'))),
                LTRIM(RTRIM(o.SDVR01)), LTRIM(RTRIM(shipto.ABALPH)),
                CASE LTRIM(RTRIM(o.SDMCU))
                     WHEN 'CINC' THEN 'Americas'  WHEN 'CIN2' THEN 'Americas'
                     WHEN 'CIN4' THEN 'Americas'  WHEN 'GRAN' THEN 'Americas'
                     WHEN 'DANC' THEN 'Americas'  WHEN 'BPIP' THEN 'Americas'
                     WHEN 'AUBA' THEN 'Aubange'   WHEN 'AUB2' THEN 'Aubange'
                     WHEN 'SHAN' THEN 'Shanghai'
                     WHEN 'SING' THEN 'Singapore' WHEN 'SNG4' THEN 'Singapore'
                     WHEN 'MUM3' THEN 'Mumbai'
                     ELSE 'Americas'
                END
        ) so6
          ON  ib7.C_2nd_Item_Number = so6.C_2nd_Item_Number
          AND ib7.Branch_Plant      = so6.Branch_Plant
        WHERE so6.Branch_Plant      = ib7.Branch_Plant
          AND so6.C_2nd_Item_Number = ib7.C_2nd_Item_Number
          AND ib7.Bulk_Item IN
              ('161017CX', '161190PX', '171143PX', '171228PX.E', '181020CX.E',
               '181136IX', '181192IX', '181193EU.E', '191011CX', '191026CX.E',
               '191245PX', '23409A', 'ABEX2525', 'APT10', 'APT11', 'DMAEMA',
               'EMA3065', 'ET2012.E', 'ET2022.E', 'ET4075.E', 'ET440.E',
               'FERSUL7W', 'HP1432AT', 'HP1632', 'MD4020', 'MD4020C', 'MD4020S',
               'MD4021', 'MD4021C', 'MD4021S', 'MD4022', 'MD4022C', 'MD4023',
               'MD4023C', 'MDU20', 'MDU2012.E', 'MDU2012B.E', 'MDU4075.E',
               'MDU4075B.E', 'MDU440.E', 'MDU440B.E', 'MPEG2000', 'MW40504',
               'MW40514', 'NP4LF', 'NP4LF.S', 'OMS', 'PUD1.E', 'STODSO', 'U1001',
               'U101', 'U201', 'U2022', 'U2022EU.E', 'U2023', 'U204', 'U204EU.E',
               'U470', 'U501', 'U501B', 'U502', 'U502.E', 'U502X1.E', 'U601',
               'U701', 'U802', 'U802.E', 'WAV501', 'WD40', 'WD40T', 'DPE3500',
               'DPE3500.E', 'JS037', 'HP401', 'HSCF410', 'UNYTEC201')
        GROUP BY
            so6.Order_Company, so6.Branch_Plant, so6.Order_Number, so6.Order_Line,
            so6.C_2nd_Item_Number, so6.Next_Status, so6.Order_Date,
            so6.Primary_UOM, so6.Secondary_UOM, so6.Requested_Date,
            so6.Promised_Ship_Date, so6.TM_Name, so6.Customer_PO,
            so6.Customer_Name, so6.REGION
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Company", type text},
            {"Branch", type text},
            {"Order #", Int64.Type},
            {"Line #", type number},
            {"Customer PO", type text},
            {"Order Date", type date},
            {"Requested", type date},
            {"Promised Ship", type date},
            {"Item", type text},
            {"Next Status", type text},
            {"Primary Qty", type number},
            {"Primary UOM", type text},
            {"Secondary Qty", type number},
            {"Secondary UOM", type text},
            {"Customer Name", type text},
            {"TM Name", type text},
            {"REGION", type text}
        }
    )
in
    Typed
