// ============================================================================
// Report 05 - CM Inventory on Hand   (page 4 of the "CM Overview LIVE" rebuild)
// QUERY: CM_Inventory_on_Hand  ->  the one inventory table (Cognos list "List1",
//        query object "Inventory")
//
// Columns (rendered order): REGION | Branch Plant | Bulk Item | 2nd Item Number |
//   Status | KG/EA OH | LB/EA OH | Hard Commit | Primary UOM
//   (REGION is BOTH a displayed column AND the source of the region slicer — see NOTE)
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//   Matches the house pattern in edw_model/JDE_Orders/Orders.m and report 06.
//
// LOGIC (faithful to the Cognos "Inventory" query — Statement 2 of the raw SQL):
//   A single flat SELECT + GROUP BY over four PRODDTA tables:
//     F4102   ib  (Item Branch)   -> Branch Plant (IBMCU), 2nd Item Number (IBLITM)
//     F4101   im  (Item Master)   -> Primary UOM (IMUOM1)  [join IBITM = IMITM]
//     F554101 tag (Item Tag)      -> Bulk Item (IMBULK)    [join IMITM = IMITM]
//     F41021  loc (Item Location) -> on-hand (LIPQOH), hard commit (LIHCOM),
//                                    lot status (LILOTS)   [join IBITM = LIITM
//                                                            AND IBMCU = LIMCU]
//   Filter: on-hand qty > 0  AND  Bulk Item (IMBULK) in the fixed whitelist.
//   Grouped to (Branch, Bulk Item, 2nd Item, Lot Status, Primary UOM, REGION).
//   SORT is set in the VISUAL (REGION asc, Bulk Item asc, 2nd Item Number asc) —
//   an ORDER BY inside the folded subquery is illegal in SQL Server (PBI wraps the
//   query as "SELECT * FROM (<query>)"), so the Cognos "order by REGION, Bulk_Item,
//   C_2nd_Item_Number" is DROPPED here. Same reason reports 01/02/06 omit it. See BUILD.md.
//
// REGION: Cognos derives REGION = decode(Branch_Plant, ...) and the "Select the
//   Region" prompt filters on it (optional). REGION is derivable from Branch Plant,
//   so we carry it as a column on this table and the region slicer points straight
//   at it. NOTE: here REGION is ALSO the first displayed column (report 06 hid it).
//   The decode DEFAULT is 'OTHER' (kept verbatim). See BUILD.md.
//
// Oracle -> T-SQL conversions applied:
//   decode(expr,k,v,...,dflt)  -> CASE expr WHEN k THEN v ... ELSE dflt END
//   trim(both from x)          -> LTRIM(RTRIM(x))
//   x/10000                    -> x/10000.0  (keep decimals; matches Orders.m)
//   order by ... nulls last    -> OMITTED here (illegal in the folded subquery);
//                                 the 3-key Cognos sort is set in the visual instead.
//   (No Julian dates in this report.)
//
// PARITY QUIRKS reproduced on purpose (documented in BUILD.md):
//   1. UOM CONVERSION: KG/EA OH and LB/EA OH re-express the SAME on-hand SUM in a
//      single unit. LB->KG uses factor 0.453593; KG->LB divides by it. Any other
//      UOM (the ELSE branch) is passed through unconverted. Kept verbatim.
//   2. MIN(IMUOM1) inside the CASE while GROUP BY IMUOM1: because the group is on
//      IMUOM1, MIN() over the group == the group's single UOM value. Cognos emitted
//      MIN() (its aggregate wrapper); kept verbatim — functionally the group's UOM.
//      Primary UOM itself is selected as the bare grouped IMUOM1 (same value).
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            CASE LTRIM(RTRIM(ib.IBMCU))
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
            END                                     AS [REGION],
            LTRIM(RTRIM(ib.IBMCU))                  AS [Branch Plant],
            LTRIM(RTRIM(tag.IMBULK))                AS [Bulk Item],
            LTRIM(RTRIM(ib.IBLITM))                 AS [2nd Item Number],
            LTRIM(RTRIM(loc.LILOTS))                AS [Status],
            CASE WHEN MIN(im.IMUOM1) = 'LB' THEN SUM(loc.LIPQOH/10000.0) * 0.453593
                 WHEN MIN(im.IMUOM1) = 'KG' THEN SUM(loc.LIPQOH/10000.0)
                 ELSE SUM(loc.LIPQOH/10000.0)
            END                                     AS [KG/EA OH],
            CASE WHEN MIN(im.IMUOM1) = 'KG' THEN SUM(loc.LIPQOH/10000.0) / 0.453593
                 WHEN MIN(im.IMUOM1) = 'LB' THEN SUM(loc.LIPQOH/10000.0)
                 ELSE SUM(loc.LIPQOH/10000.0)
            END                                     AS [LB/EA OH],
            SUM(loc.LIHCOM/10000.0)                 AS [Hard Commit],
            im.IMUOM1                               AS [Primary UOM]
        FROM PRODDTA.F4102 ib
        JOIN PRODDTA.F4101   im  ON ib.IBITM = im.IMITM
        JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
        JOIN PRODDTA.F41021  loc ON ib.IBITM = loc.LIITM
                                AND ib.IBMCU = loc.LIMCU
        WHERE loc.LIPQOH/10000.0 > 0
          AND LTRIM(RTRIM(tag.IMBULK)) IN ('161017CX', '161190PX', '171143PX', '171228PX.E', '181020CX.E', '181136IX', '181192IX', '181193EU.E', '191011CX', '191026CX.E', '191245PX', '23409A', 'ABEX2525', 'APT10', 'APT11', 'DMAEMA', 'EMA3065', 'ET2012.E', 'ET2022.E', 'ET4075.E', 'ET440.E', 'FERSUL7W', 'HP1432AT', 'HP1632', 'MD4020', 'MD4020C', 'MD4020S', 'MD4021', 'MD4021C', 'MD4021S', 'MD4022', 'MD4022C', 'MD4023', 'MD4023C', 'MDU20', 'MDU2012.E', 'MDU2012B.E', 'MDU4075.E', 'MDU4075B.E', 'MDU440.E', 'MDU440B.E', 'MPEG2000', 'MW40504', 'MW40514', 'NP4LF', 'NP4LF.S', 'OMS', 'PUD1.E', 'STODSO', 'U1001', 'U101', 'U201', 'U2022', 'U2022EU.E', 'U2023', 'U204', 'U204EU.E', 'U470', 'U501', 'U501B', 'U502', 'U502.E', 'U502X1.E', 'U601', 'U701', 'U802', 'U802.E', 'WAV501', 'WD40', 'WD40T', 'DPE3500', '191245PX', '201118CX.E', 'ACRYLA', 'ACTMBS', 'AMDBIO', 'AMMPERSU', 'APT10', 'BLACKAN', 'BPADA', 'CALDB45', 'DMAEMA', 'DPE3500', 'EMA3065', 'FERSUL7W', 'HP1432AT', 'HP1632', 'MD4020', 'MD4021', 'MD4022', 'MD4023', 'MDU20', 'MDU2012B.E', 'MDU4075B.E', 'MEHQ.E', 'PEG1450', 'STYRENE', 'TBHP70', 'U101', 'U201', 'U2022', 'U2022EU.E', 'U2023', 'U470', 'U501', 'U501B', 'U502', 'U502.E', 'U505.E', 'U601', 'U701', 'U802', 'U802.E', 'UNYTEC201', 'VER100', 'WAV501', 'WD40', 'JS037', 'HP401', 'HSCF410')
        GROUP BY
            LTRIM(RTRIM(ib.IBMCU)),
            LTRIM(RTRIM(tag.IMBULK)),
            LTRIM(RTRIM(ib.IBLITM)),
            LTRIM(RTRIM(loc.LILOTS)),
            im.IMUOM1,
            CASE LTRIM(RTRIM(ib.IBMCU))
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
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"REGION", type text},
            {"Branch Plant", type text},
            {"Bulk Item", type text},
            {"2nd Item Number", type text},
            {"Status", type text},
            {"KG/EA OH", type number},
            {"LB/EA OH", type number},
            {"Hard Commit", type number},
            {"Primary UOM", type text}
        },
        "en-US"
    )
in
    Typed
