// ============================================================================
// Report 06 - CM PO Live   (page 5 of the "Dashboard - CM Overview LIVE" rebuild)
// QUERY: CM_PO_Live  ->  the main PO table ("List1" / Cognos query object "PO Summary")
//
// Columns (rendered order): Company | Branch | PO # | Line # | Bulk Item | Item |
//   QTY | Open QTY | 2nd QTY | Next Status | Requested Date | Promised Date | Vendor Name
//   (+ REGION carried as a hidden slicer column — see NOTE below)
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//   Matches the house pattern in edw_model/JDE_Orders/Orders.m.
//
// NOTE: written with INLINE DERIVED TABLES (not a top-level WITH/CTE). With
//   [EnableFolding=true] Power BI wraps the query as "SELECT * FROM (<query>)",
//   and a leading CTE can't be wrapped -> "Incorrect syntax near 'WITH'". Derived
//   tables wrap fine and keep folding on. The 3 Cognos CTEs
//   (Item_Branch6, F4311_Purchase_Order_Details, Purchase_Orders5) become nested
//   derived tables here.
//
// LOGIC (faithful to the Cognos "PO Summary" join):
//   ib  (Item_Branch6)     = F4102 item-branch x F4101 item-master x F554101 item-tag,
//                            DISTINCT (Branch_Plant, Global_Bulk_Item, Bulk_Item,
//                            2nd_Item). Supplies the "Bulk Item" and the bulk-item
//                            whitelist.
//   po  (Purchase_Orders5) = open F4311 PO lines (PDUOPN/10000 > 0) whose Promised
//                            Date (PDPDDJ, Julian->date) is within the last 90 days
//                            (>= today-90), joined to F0101 for the vendor name.
//                            Aggregated to the PO line.
//   Output = ib LEFT OUTER JOIN po on (Branch_Plant, 2nd_Item), restricted by the
//            Bulk_Item whitelist, one row per PO line. SORT is set in the visual
//            (Promised Date asc) — an ORDER BY inside the folded subquery is illegal
//            in SQL Server (PBI wraps the query as "SELECT * FROM (<query>)"), same
//            reason reports 01/02 omit it. See BUILD.md.
//
// REGION: the Cognos report has an optional "Select the Region" prompt that filters
//   on REGION = decode(Branch_Plant, ...). REGION is derivable from Branch_Plant, so
//   rather than a separate region query we carry REGION as a column on this table;
//   the builder points the region slicer straight at it (its distinct values are the
//   same set the Cognos prompt dropdown listed). See BUILD.md.
//
// Oracle -> T-SQL conversions applied:
//   "PRODDTA".JUL2DATE(x)      -> CASE WHEN x>0 THEN DATEADD(DAY,(x%1000)-1,DATEFROMPARTS(1900+(x/1000),1,1)) END
//   to_date(sysdate) - 90      -> DATEADD(DAY,-90, CAST(GETDATE() AS date))  (compared to the CONVERTED date)
//   decode(expr,k,v,...,dflt)  -> CASE expr WHEN k THEN v ... ELSE dflt END
//   trim(both from x)          -> LTRIM(RTRIM(x))
//   x/10000, x/1000            -> x/10000.0, x/1000.0 (keep decimals; matches Orders.m)
//   order by ... nulls last    -> OMITTED here (illegal in the folded subquery); the
//                                 Cognos "Promised Date asc, nulls last" sort is set in
//                                 the visual instead. PBI table sorting puts blanks last.
//
// ⚠ PARITY QUIRKS reproduced on purpose (documented in BUILD.md):
//   1. DOUBLE-SUM: Purchase_Orders5 SUMs PDPQOR/PDUOPN/PDSQOR, then the outer query
//      SUMs those again. Harmless at one-PO-line grain, BUT it also re-sums when the
//      ib join fans a PO line out to >1 Item_Branch row (see #2) -> that fan-out qty
//      is what the outer SUM adds up. Kept faithfully.
//   2. FAN-OUT on (Branch_Plant, 2nd_Item): ib is DISTINCT including Global_Bulk_Item,
//      but the join key is only (Branch_Plant, 2nd_Item) and the final GROUP BY keeps
//      Bulk_Item (not Global_Bulk_Item). So an item/branch tagged with the same Bulk
//      Item under >1 Global Bulk Item duplicates its PO quantity within one Bulk Item
//      row. Reproduced to tie to the live report.
//
// JULIAN: JDE CYYDDD -> date via DATEADD/DATEFROMPARTS (1900+CYY, day-of-year); 0 -> NULL.
// sysdate -> CAST(GETDATE() AS date) = refresh day; report is "as of last refresh".
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            po.[Company]                    AS [Company],
            po.[Branch_Plant]               AS [Branch Plant],
            po.[Purchase_Order_Number]      AS [Purchase Order Number],
            po.[Line_Number]                AS [Line Number],
            ib.[Bulk_Item]                  AS [Bulk Item],
            po.[C_2nd_Item_Number]          AS [2nd Item Number],
            SUM(po.[Primary_Quantity])      AS [Primary Quantity],
            SUM(po.[Open_Quantity])         AS [Open Quantity],
            SUM(po.[Secondary_Quantity])    AS [Secondary Quantity],
            po.[Next_Status]                AS [Next Status],
            po.[Requested_Date]             AS [Requested Date],
            po.[Promised_Date]              AS [Promised Date],
            po.[Vendor_Name]                AS [Vendor Name],
            po.[REGION]                     AS [REGION]
        FROM (
            -- Item_Branch6 : F4102 x F4101 x F554101, distinct branch/item -> Bulk Item
            SELECT DISTINCT
                LTRIM(RTRIM(ib.IBMCU))    AS Branch_Plant,
                LTRIM(RTRIM(tag.IMGBLK))  AS Global_Bulk_Item,
                LTRIM(RTRIM(tag.IMBULK))  AS Bulk_Item,
                LTRIM(RTRIM(ib.IBLITM))   AS C_2nd_Item_Number
            FROM PRODDTA.F4102 ib
            JOIN PRODDTA.F4101   im  ON ib.IBITM = im.IMITM
            JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
        ) ib
        LEFT OUTER JOIN (
            -- Purchase_Orders5 : open PO lines, promised within 90 days, + vendor + region
            SELECT
                d.PDKCOO                        AS Company,
                d.PDDOCO                        AS Purchase_Order_Number,
                d.PDDCTO                        AS Purchase_Order_Type,
                d.PDLNID/1000.0                 AS Line_Number,
                LTRIM(RTRIM(d.PDMCU))           AS Branch_Plant,
                d.Requested_Date                AS Requested_Date,
                d.PDVR02                        AS Reference_2,
                d.PDPDP3                        AS Reporting_Code_3,
                LTRIM(RTRIM(d.PDLITM))          AS C_2nd_Item_Number,
                SUM(d.PDSQOR/10000.0)           AS Secondary_Quantity,
                SUM(d.PDPQOR/10000.0)           AS Primary_Quantity,
                d.PDLTTR                         AS Last_Status,
                d.PDNXTR                         AS Next_Status,
                d.Promised_Date                 AS Promised_Date,
                SUM(d.PDUOPN/10000.0)           AS Open_Quantity,
                SUM(d.PDAN8)                     AS Vendor_Code,
                LTRIM(RTRIM(v.ABALPH))          AS Vendor_Name,
                CASE LTRIM(RTRIM(d.PDMCU))
                     WHEN 'CINC' THEN 'Americas'
                     WHEN 'CIN2' THEN 'Americas'
                     WHEN 'CIN4' THEN 'Americas'
                     WHEN 'GRAN' THEN 'Americas'
                     WHEN 'DANC' THEN 'Americas'
                     WHEN 'AUBA' THEN 'Aubange'
                     WHEN 'AUB2' THEN 'Aubange'
                     WHEN 'SHAN' THEN 'Shanghai'
                     WHEN 'SING' THEN 'Singapore'
                     WHEN 'SNG4' THEN 'Singapore'
                     WHEN 'MUM3' THEN 'Mumbai'
                     ELSE 'OTHER'
                END                              AS REGION
            FROM (
                -- F4311_Purchase_Order_Details : raw F4311 with Julian dates decoded
                SELECT
                    PDKCOO, PDDOCO, PDDCTO, PDLNID, PDMCU, PDAN8,
                    CASE WHEN PDDRQJ>0 THEN DATEADD(DAY,(PDDRQJ%1000)-1,DATEFROMPARTS(1900+(PDDRQJ/1000),1,1)) END AS Requested_Date,
                    CASE WHEN PDPDDJ>0 THEN DATEADD(DAY,(PDPDDJ%1000)-1,DATEFROMPARTS(1900+(PDPDDJ/1000),1,1)) END AS Promised_Date,
                    PDVR02, PDLITM, PDNXTR, PDLTTR, PDPDP3, PDUOPN, PDPQOR, PDSQOR
                FROM PRODDTA.F4311
            ) d
            JOIN PRODDTA.F0101 v ON d.PDAN8 = v.ABAN8
            WHERE d.PDUOPN/10000.0 > 0
              AND d.Promised_Date >= DATEADD(DAY,-90, CAST(GETDATE() AS date))
            GROUP BY
                d.PDKCOO, d.PDDOCO, d.PDDCTO, d.PDLNID/1000.0,
                LTRIM(RTRIM(d.PDMCU)), d.Requested_Date, d.PDVR02, d.PDPDP3,
                LTRIM(RTRIM(d.PDLITM)), d.PDLTTR, d.PDNXTR, d.Promised_Date,
                LTRIM(RTRIM(v.ABALPH)),
                CASE LTRIM(RTRIM(d.PDMCU))
                     WHEN 'CINC' THEN 'Americas'
                     WHEN 'CIN2' THEN 'Americas'
                     WHEN 'CIN4' THEN 'Americas'
                     WHEN 'GRAN' THEN 'Americas'
                     WHEN 'DANC' THEN 'Americas'
                     WHEN 'AUBA' THEN 'Aubange'
                     WHEN 'AUB2' THEN 'Aubange'
                     WHEN 'SHAN' THEN 'Shanghai'
                     WHEN 'SING' THEN 'Singapore'
                     WHEN 'SNG4' THEN 'Singapore'
                     WHEN 'MUM3' THEN 'Mumbai'
                     ELSE 'OTHER'
                END
        ) po
            ON  ib.Branch_Plant      = po.Branch_Plant
            AND ib.C_2nd_Item_Number = po.C_2nd_Item_Number
        -- WHERE on the right-side cols is verbatim Cognos; it makes the LEFT JOIN
        -- behave as an inner join (drops the ib rows with no matching PO line).
        WHERE po.Branch_Plant      = ib.Branch_Plant
          AND po.C_2nd_Item_Number = ib.C_2nd_Item_Number
          AND ib.Bulk_Item IN ('161017CX', '161190PX', '171143PX', '171228PX.E', '181020CX.E', '181136IX', '181192IX', '181193EU.E', '191011CX', '191026CX.E', '191245PX', '23409A', 'ABEX2525', 'APT10', 'APT11', 'DMAEMA', 'EMA3065', 'ET2012.E', 'ET2022.E', 'ET4075.E', 'ET440.E', 'FERSUL7W', 'HP1432AT', 'HP1632', 'MD4020', 'MD4020C', 'MD4020S', 'MD4021', 'MD4021C', 'MD4021S', 'MD4022', 'MD4022C', 'MD4023', 'MD4023C', 'MDU20', 'MDU2012.E', 'MDU2012B.E', 'MDU4075.E', 'MDU4075B.E', 'MDU440.E', 'MDU440B.E', 'MPEG2000', 'MW40504', 'MW40514', 'NP4LF', 'NP4LF.S', 'OMS', 'PUD1.E', 'STODSO', 'U1001', 'U101', 'U201', 'U2022', 'U2022EU.E', 'U2023', 'U204', 'U204EU.E', 'U470', 'U501', 'U501B', 'U502', 'U502.E', 'U502X1.E', 'U601', 'U701', 'U802', 'U802.E', 'WAV501', 'WD40', 'WD40T', 'DPE3500', 'JS037', 'HP401', 'HSCF410', 'UNYTEC201')
        GROUP BY
            po.[Company], po.[Purchase_Order_Number], po.[Line_Number],
            po.[Branch_Plant], po.[Requested_Date], po.[C_2nd_Item_Number],
            po.[Next_Status], po.[Promised_Date], po.[Vendor_Name],
            ib.[Bulk_Item], po.[REGION]
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Company", type text},
            {"Branch Plant", type text},
            {"Purchase Order Number", Int64.Type},
            {"Line Number", type number},
            {"Bulk Item", type text},
            {"2nd Item Number", type text},
            {"Primary Quantity", type number},
            {"Open Quantity", type number},
            {"Secondary Quantity", type number},
            {"Next Status", type text},
            {"Requested Date", type date},
            {"Promised Date", type date},
            {"Vendor Name", type text},
            {"REGION", type text}
        },
        "en-US"
    )
in
    Typed
