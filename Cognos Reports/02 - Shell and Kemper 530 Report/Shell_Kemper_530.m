// ============================================================================
// Report 02 - Shell and Kemper 530 Report
// QUERY: Shell_Kemper_530  ->  the visible "530" detail list (Cognos list "List2",
//        query object "Main w Routing 530"). This is the main deliverable panel.
//
// Columns (left -> right, Cognos label): Promised Ship | Requested | Plant |
//   Ship To | CS | Order# | Line# | Bulk | Item | Description | Owner | Planner |
//   Status | Qty | UOM | Qty | UOM | Order Date | CSR Name | Work Ctr | MPF
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//   Matches the house pattern in edw_model/JDE_Orders/Orders.m and report 01.
//
// NOTE: written with INLINE DERIVED TABLES (not a top-level WITH/CTE). With
//   [EnableFolding=true] Power BI wraps the query as "SELECT * FROM (<query>)",
//   and a leading CTE throws "Incorrect syntax near 'WITH'". The whole Cognos
//   CTE chain (F4211_Open_Sales_Orders / F42140__CSR / MAIN8 / ITEM9 /
//   Main_w_Bulk12 / Routing13) is rewritten as nested subqueries.
//
// LOGIC (faithful to Cognos "Main w Routing 530"):
//   MAIN8  = open sales orders (F4211) for company '00010' at Next Status in
//            (525..550), joined to the ship-to customer (F0101) and left-joined
//            to the CSR sales rep (F42140 CMRTYPE='CSR' -> F0101 name).
//            Quantities SUMmed to the order-line grain.
//   ITEM9  = item-branch (F4102) x item master (F4101) x item tag (F554101),
//            giving Bulk_Item (IMBULK) and Planner (IBANPL) per (branch, 2nd item).
//   Main_w_Bulk12 = MAIN8 INNER JOIN ITEM9 on (Branch_Plant, 2nd item), re-summed.
//   Routing13 = capacity pegging (F3312) x item-branch (F4102) x capacity load
//            (F3313), whitelisted work centers, planned (CWDOCO=0), period end
//            date > today+31; yields Work_Center per routing 2nd item number.
//   FINAL  = Main_w_Bulk12 FULL OUTER JOIN Routing13 on Bulk_Item = 2nd item,
//            kept where 2nd item IS NOT NULL and Next_Status = '530'.
//            NEW_OWNER = planner-number -> name decode (else 'ERROR').
//            DESCRIPTION = only shown for NEWITEMFG / NEWITEMPKG placeholder items.
//
// FULL OUTER JOIN is kept per the Cognos SQL; the WHERE on Main columns
//   (2nd item IS NOT NULL) discards routing-only rows, so it behaves like a
//   left join from Main_w_Bulk12 to the work centers. SQL Server supports it.
//
// Routing13 is reduced to SELECT DISTINCT (Item_Branch, 2nd item, Work_Center):
//   the only Routing column consumed downstream is Work_Center, and the FINAL
//   GROUP BY collapses on Work_Center (not on the routing dates Cognos grouped by),
//   so DISTINCT is result-equivalent to Cognos's grouped Routing13 while staying
//   fold-friendly.
//
// (X)PARITY QUIRK reproduced on purpose (see BUILD.md "Known Cognos quirks"):
//   Cognos AVERAGES the quantities in the final step (average([Primary Quantity
//   Ordered]) / average([Secondary Quantity Ordered])) instead of SUMming. Because
//   the final GROUP BY is at the order-line grain (each group = one line), the
//   AVG collapses identical repeated values back to that value, so it ties to the
//   live report. Corrected form (SUM) is documented in BUILD.md.
//
// JULIAN: JDE CYYDDD -> date via DATEADD/DATEFROMPARTS (1900+CYY, day-of-year).
//   Requested / Promised Ship / Order Date come through as real dates.
// sysdate -> CAST(GETDATE() AS date) in the Routing13 period-end-date window.
// ORDER BY is intentionally OMITTED (an ORDER BY inside the folded subquery is
//   illegal in SQL Server); sort in the visual: Bulk, Promised Ship, Order#,
//   Line#, Owner (all ascending). See BUILD.md.
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            mb.Promised_Ship_Date                                     AS [Promised Ship],
            mb.Requested_Date                                         AS [Requested],
            mb.Branch_Plant                                           AS [Plant],
            mb.Customer_Name                                          AS [Ship To],
            mb.Customer_Segmentation                                  AS [CS],
            mb.Order_Number                                           AS [Order#],
            mb.Order_Line                                             AS [Line#],
            mb.Bulk_Item                                              AS [Bulk],
            mb.C_2nd_Item_Number                                      AS [Item],
            CASE mb.C_2nd_Item_Number
                 WHEN 'NEWITEMFG'  THEN mb.Description_1
                 WHEN 'NEWITEMPKG' THEN mb.Description_1
                 ELSE ' '
            END                                                       AS [Description],
            CASE mb.Planner
                 WHEN '324363' THEN 'Eric'
                 WHEN '20444'  THEN 'Eric'
                 WHEN '20445'  THEN 'Lance'
                 WHEN '291740' THEN 'Mark Tilley'
                 WHEN '328907' THEN 'Lance'
                 WHEN '333530' THEN 'Lance'
                 WHEN '316775' THEN 'Lance'
                 WHEN '334927' THEN 'Tammy'
                 WHEN '290808' THEN 'David Kramer'
                 WHEN '335951' THEN 'Lance'
                 WHEN '300021' THEN 'Tammy'
                 WHEN '324287' THEN 'Brent'
                 ELSE 'ERROR'
            END                                                       AS [Owner],
            mb.Planner                                                AS [Planner],
            mb.Next_Status                                            AS [Status],
            AVG(mb.Primary_Quantity_Ordered)                          AS [Primary Qty],
            mb.Primary_UOM                                            AS [Primary UOM],
            AVG(mb.Secondary_Quantity_Ordered)                        AS [Secondary Qty],
            mb.Secondary_UOM                                          AS [Secondary UOM],
            mb.Order_Date                                             AS [Order Date],
            mb.CSR_Name                                               AS [CSR Name],
            r.Work_Center                                             AS [Work Ctr],
            mb.MPF                                                    AS [MPF]
        FROM (
            /* ---- Main_w_Bulk12 : MAIN8 (open SOs) INNER JOIN ITEM9 (bulk+planner) ---- */
            SELECT
                m8.Branch_Plant, m8.CSR_Name, m8.Order_Number, m8.Order_Line,
                m8.Customer_PO, m8.Customer_Name, m8.Customer_Segmentation,
                m8.C_2nd_Item_Number, m8.Last_Status, m8.Next_Status, m8.Order_Date,
                SUM(m8.Primary_Quantity_Ordered)   AS Primary_Quantity_Ordered,
                m8.Primary_UOM, m8.Requested_Date, m8.Promised_Ship_Date,
                SUM(m8.Secondary_Quantity_Ordered) AS Secondary_Quantity_Ordered,
                m8.Secondary_UOM, m8.MPF, m8.Description_1,
                i9.Bulk_Item, i9.Planner
            FROM (
                /* ---- MAIN8 : F4211 open SOs + ship-to customer + CSR rep ---- */
                SELECT
                    so.SDKCOO                          AS Order_Company,
                    LTRIM(RTRIM(so.SDMCU))             AS Branch_Plant,
                    LTRIM(RTRIM(csr.ABALPH))           AS CSR_Name,
                    so.SDDOCO                          AS Order_Number,
                    so.SDLNID / 1000.0                 AS Order_Line,
                    so.SDVR01                          AS Customer_PO,
                    LTRIM(RTRIM(cust.ABALPH))          AS Customer_Name,
                    LTRIM(RTRIM(cust.ABAC06))          AS Customer_Segmentation,
                    LTRIM(RTRIM(so.SDLITM))            AS C_2nd_Item_Number,
                    so.SDLTTR                          AS Last_Status,
                    so.SDNXTR                          AS Next_Status,
                    (CASE WHEN so.SDTRDJ > 0
                          THEN DATEADD(DAY, (so.SDTRDJ % 1000) - 1, DATEFROMPARTS(1900 + (so.SDTRDJ / 1000), 1, 1))
                     END)                              AS Order_Date,
                    SUM(so.SDPQOR / 10000.0)           AS Primary_Quantity_Ordered,
                    so.SDUOM1                          AS Primary_UOM,
                    (CASE WHEN so.SDDRQJ > 0
                          THEN DATEADD(DAY, (so.SDDRQJ % 1000) - 1, DATEFROMPARTS(1900 + (so.SDDRQJ / 1000), 1, 1))
                     END)                              AS Requested_Date,
                    (CASE WHEN so.SDPDDJ > 0
                          THEN DATEADD(DAY, (so.SDPDDJ % 1000) - 1, DATEFROMPARTS(1900 + (so.SDPDDJ / 1000), 1, 1))
                     END)                              AS Promised_Ship_Date,
                    SUM(so.SDSQOR / 10000.0)           AS Secondary_Quantity_Ordered,
                    so.SDUOM2                          AS Secondary_UOM,
                    so.SDPRP4                          AS MPF,
                    LTRIM(RTRIM(so.SDDSC1))            AS Description_1
                FROM PRODDTA.F4211 so
                INNER JOIN PRODDTA.F0101 cust ON so.SDSHAN = cust.ABAN8
                LEFT OUTER JOIN (
                    SELECT cm.CMAN8, ab.ABALPH
                    FROM PRODDTA.F42140 cm
                    JOIN PRODDTA.F0101 ab ON cm.CMSLSM = ab.ABAN8
                    WHERE cm.CMRTYPE = 'CSR'
                ) csr ON so.SDSHAN = csr.CMAN8
                WHERE so.SDNXTR IN ('525','530','535','540','545','550')
                  AND so.SDKCOO = '00010'
                GROUP BY
                    so.SDKCOO, LTRIM(RTRIM(so.SDMCU)), LTRIM(RTRIM(csr.ABALPH)),
                    so.SDDOCO, so.SDLNID / 1000.0, so.SDVR01,
                    LTRIM(RTRIM(cust.ABALPH)), LTRIM(RTRIM(cust.ABAC06)),
                    LTRIM(RTRIM(so.SDLITM)), so.SDLTTR, so.SDNXTR,
                    (CASE WHEN so.SDTRDJ > 0
                          THEN DATEADD(DAY, (so.SDTRDJ % 1000) - 1, DATEFROMPARTS(1900 + (so.SDTRDJ / 1000), 1, 1))
                     END),
                    so.SDUOM1,
                    (CASE WHEN so.SDDRQJ > 0
                          THEN DATEADD(DAY, (so.SDDRQJ % 1000) - 1, DATEFROMPARTS(1900 + (so.SDDRQJ / 1000), 1, 1))
                     END),
                    (CASE WHEN so.SDPDDJ > 0
                          THEN DATEADD(DAY, (so.SDPDDJ % 1000) - 1, DATEFROMPARTS(1900 + (so.SDPDDJ / 1000), 1, 1))
                     END),
                    so.SDUOM2, so.SDPRP4, LTRIM(RTRIM(so.SDDSC1))
            ) m8
            INNER JOIN (
                /* ---- ITEM9 : item-branch x item-master x item-tag (bulk + planner) ---- */
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
                m8.Order_Company, m8.Branch_Plant, m8.CSR_Name, m8.Order_Number,
                m8.Order_Line, m8.Customer_PO, m8.Customer_Name, m8.Customer_Segmentation,
                m8.C_2nd_Item_Number, m8.Last_Status, m8.Next_Status, m8.Order_Date,
                m8.Primary_UOM, m8.Requested_Date, m8.Promised_Ship_Date,
                m8.Secondary_UOM, m8.MPF, m8.Description_1,
                i9.Branch_Plant, i9.Bulk_Item, i9.C_2nd_Item_Number, i9.Planner
        ) mb
        FULL OUTER JOIN (
            /* ---- Routing13 : capacity pegging -> Work_Center per routing 2nd item ---- */
            SELECT DISTINCT
                LTRIM(RTRIM(cp.CWMMCU)) AS Item_Branch,
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
        GROUP BY
            mb.Branch_Plant, mb.CSR_Name, mb.Order_Number, mb.Order_Line,
            mb.Customer_Name, mb.Customer_Segmentation, mb.C_2nd_Item_Number,
            mb.Next_Status, mb.Primary_UOM, mb.Secondary_UOM, mb.Order_Date,
            mb.Requested_Date, mb.Promised_Ship_Date, mb.MPF, mb.Bulk_Item,
            r.Work_Center, mb.Planner,
            CASE mb.Planner
                 WHEN '324363' THEN 'Eric'      WHEN '20444'  THEN 'Eric'
                 WHEN '20445'  THEN 'Lance'     WHEN '291740' THEN 'Mark Tilley'
                 WHEN '328907' THEN 'Lance'     WHEN '333530' THEN 'Lance'
                 WHEN '316775' THEN 'Lance'     WHEN '334927' THEN 'Tammy'
                 WHEN '290808' THEN 'David Kramer' WHEN '335951' THEN 'Lance'
                 WHEN '300021' THEN 'Tammy'     WHEN '324287' THEN 'Brent'
                 ELSE 'ERROR'
            END,
            CASE mb.C_2nd_Item_Number
                 WHEN 'NEWITEMFG'  THEN mb.Description_1
                 WHEN 'NEWITEMPKG' THEN mb.Description_1
                 ELSE ' '
            END
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Promised Ship", type date},
            {"Requested", type date},
            {"Plant", type text},
            {"Ship To", type text},
            {"CS", type text},
            {"Order#", Int64.Type},
            {"Line#", type number},
            {"Bulk", type text},
            {"Item", type text},
            {"Description", type text},
            {"Owner", type text},
            {"Planner", Int64.Type},
            {"Status", type text},
            {"Primary Qty", type number},
            {"Primary UOM", type text},
            {"Secondary Qty", type number},
            {"Secondary UOM", type text},
            {"Order Date", type date},
            {"CSR Name", type text},
            {"Work Ctr", type text},
            {"MPF", type text}
        }
    )
in
    Typed
