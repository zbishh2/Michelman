// ============================================================================
// Report 07 - Ivan SK 2023   (page 1 of 5: "Inventory")   [structural clone of report 09; SK filter literals]
// QUERY: Inventory  ->  Cognos list "List1", query object "Inventory"
//
// Columns (RENDERED order, 16): REGION | Branch Plant | Global Bulk Item |
//   Bulk Item | 2nd Item Number | Stock Type | Lot Number | Location | Status |
//   Quantity On Hand | Hard Commit | Primary UOM | Master Planning Family |
//   NOW | OH KG | OH LB
//   (Column display LABELS in the visual: REGION->"Site", Master Planning
//    Family->"MPF", NOW->"Date".  See BUILD.md.)
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//   House pattern: edw_model/JDE_Orders/Orders.m + report 05 CM_Inventory_on_Hand.m.
//
// LOGIC (faithful to the Cognos "Inventory" query - statement 1 of the raw SQL):
//   Flat SELECT + GROUP BY over four PRODDTA tables (lot/location grain):
//     F4102   ib  (Item Branch)   -> Branch Plant (IBMCU), 2nd Item (IBLITM),
//                                    Stock Type (IBSTKT), MPF (IBPRP4)
//     F554101 tag (Item Tag)      -> Global Bulk (IMGBLK), Bulk Item (IMBULK)
//     F41021  loc (Item Location) -> on-hand (LIPQOH), hard commit (LIHCOM),
//                                    lot status (LILOTS), location (LILOCN),
//                                    lot number (LILOTN)
//     F4101   im  (Item Master)   -> Primary UOM (IMUOM1)
//   Joins: IBITM=IMITM, IMITM=tag.IMITM, IBITM=LIITM AND IBMCU=LIMCU.
//   Filters: Branch in ('AUBA','AUB2','SING','SNG4','MUM3','SHAN','CINC','CIN2','CIN4'),
//            on-hand qty > 0, Bulk Item in the fixed SK bulk-item whitelist (99 entries).
//   NOTE: the report XML has a SECOND use="prohibited" Bulk-Item filter, but it
//   did NOT survive into the generated SQL, so it is intentionally NOT applied
//   here (we match the generated SQL, the source of truth for what ran).
//
// Oracle -> T-SQL conversions:
//   decode(expr,k,v,...,'ERROR')  -> CASE expr WHEN k THEN v ... ELSE 'ERROR' END
//   trim(both from trim(both from x)) -> LTRIM(RTRIM(x))
//   to_date(sysdate)              -> CAST(GETDATE() AS date)     ("NOW")
//   x/10000                       -> x/10000.0 (keep decimals; matches Orders.m)
//   order by ... nulls last       -> OMITTED (illegal in the folded subquery;
//                                     PBI wraps as SELECT * FROM (<query>)).
//                                     Cognos sort was Global Bulk Item, Bulk Item,
//                                     2nd Item Number -> set in the visual. See BUILD.md.
//
// PARITY QUIRKS reproduced on purpose (documented in BUILD.md):
//   1. UOM CONVERSION (OH KG / OH LB): re-express the SAME on-hand SUM in one unit.
//      OH KG: KG->as-is, LB->*0.453593, EA->*20, ELSE sentinel 100000.
//      OH LB: LB->as-is, KG->/0.453593, EA->*44, ELSE sentinel 100000.
//   2. MIN(IMUOM1) inside the CASE while GROUP BY IMUOM1: MIN over the group == the
//      group's single UOM value; Cognos emitted MIN() as its aggregate wrapper. Kept.
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            CASE LTRIM(RTRIM(ib.IBMCU))
                 WHEN 'SING' THEN 'Singapore'
                 WHEN 'SNG4' THEN 'Singapore'
                 WHEN 'MUM3' THEN 'India'
                 WHEN 'SHAN' THEN 'China'
                 WHEN 'AUBA' THEN 'Aubange'
                 WHEN 'AUB2' THEN 'Aubange'
                 WHEN 'CINC' THEN 'Americas'
                 WHEN 'CIN2' THEN 'Americas'
                 WHEN 'CIN4' THEN 'Americas'
                 ELSE 'ERROR'
            END                                     AS [REGION],
            LTRIM(RTRIM(ib.IBMCU))                  AS [Branch Plant],
            LTRIM(RTRIM(tag.IMGBLK))                AS [Global Bulk Item],
            LTRIM(RTRIM(tag.IMBULK))                AS [Bulk Item],
            LTRIM(RTRIM(ib.IBLITM))                 AS [2nd Item Number],
            LTRIM(RTRIM(ib.IBSTKT))                 AS [Stock Type],
            LTRIM(RTRIM(loc.LILOTN))                AS [Lot Number],
            LTRIM(RTRIM(loc.LILOCN))                AS [Location],
            loc.LILOTS                              AS [Status],
            SUM(loc.LIPQOH/10000.0)                 AS [Quantity On Hand],
            SUM(loc.LIHCOM/10000.0)                 AS [Hard Commit],
            im.IMUOM1                               AS [Primary UOM],
            LTRIM(RTRIM(ib.IBPRP4))                 AS [Master Planning Family],
            CAST(GETDATE() AS date)                 AS [NOW],
            CASE WHEN MIN(im.IMUOM1) = 'KG' THEN SUM(loc.LIPQOH/10000.0)
                 WHEN MIN(im.IMUOM1) = 'LB' THEN SUM(loc.LIPQOH/10000.0) * 0.453593
                 WHEN MIN(im.IMUOM1) = 'EA' THEN SUM(loc.LIPQOH/10000.0) * 20
                 ELSE 100000
            END                                     AS [OH KG],
            CASE WHEN MIN(im.IMUOM1) = 'LB' THEN SUM(loc.LIPQOH/10000.0)
                 WHEN MIN(im.IMUOM1) = 'KG' THEN SUM(loc.LIPQOH/10000.0) / 0.453593
                 WHEN MIN(im.IMUOM1) = 'EA' THEN SUM(loc.LIPQOH/10000.0) * 44
                 ELSE 100000
            END                                     AS [OH LB]
        FROM PRODDTA.F4102 ib
        JOIN PRODDTA.F4101   im  ON ib.IBITM = im.IMITM
        JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
        JOIN PRODDTA.F41021  loc ON ib.IBITM = loc.LIITM
                                AND ib.IBMCU = loc.LIMCU
        WHERE LTRIM(RTRIM(ib.IBMCU)) IN ('AUBA', 'AUB2', 'SING', 'SNG4', 'MUM3', 'SHAN', 'CINC', 'CIN2', 'CIN4')
          AND loc.LIPQOH/10000.0 > 0
          AND LTRIM(RTRIM(tag.IMBULK)) IN ('PR3460', 'PR3460.E', 'PR5980I', 'PR5980I.E', 'PR5980I.S', 'PR5985', 'PR5985.E', 'PR5985.S', 'DPI8600.E', 'PH00007E.E', '201250PX.E', 'DPI8200.E', 'MF4915.E', 'MFHS1130.E', 'MFP1857.E', 'MP3000.E', 'MP48525R.E', 'MP4932.E', 'MP498340R.E', 'PH00017E.E', 'MFP1853R.E', 'MP498345P.E', 'MP4983RHSA.E', '201081CX', '241083PX.S', '241088PX.S', '241089PX.S', '241199PX.S', '241252PX.S', '251095NX.S', '251142PX.S', '251144PX.S', '251194NX.S', '251268PX.S', 'MF1204.S', 'MF1306D.S', 'MF1406.S', 'MFHS1881.S', 'MFP1853R.S', 'MFP1883.S', 'MP4982SC.S', 'MP498340R.S', 'MP498345N.S', 'MP4983R.S', 'MP4983RHS.S', 'PH00017E.S', 'PI8545.S', '241253PX.S', '241168PX', '241201FX', 'DP040', 'DPI8600', 'HSCF280', 'ILP040', 'KHI205', 'KHI340', 'MED310', 'MED800', 'MFHS168', 'MFHS268', 'MFP1853R', 'MP04422R', 'MP3000', 'MP48525R', 'MP498340D', 'MP498340R', 'MP498345N', 'MP4983RHS', 'MT242AF', 'PA845H', 'PH00015E', 'PH00017E', 'UBD211', 'UBD268', 'UTS610', '251379PX.E', 'MFP1883.E', 'MP4983RAM.E', 'PH00001A.E', '251095NX.E', '251194NX.E', 'MD7900.E', 'MP4983R.E', '251246NX.E', '251095NX', '251194NX', '261044NX', '261074NX', '605000007', 'MFP1883', 'MP4983R', 'MP4983RN', 'RM108', 'UPR420', '221247PX.E', 'MP2960.E', '221247PX', '231093FX', 'MP2960')
        GROUP BY
            LTRIM(RTRIM(ib.IBMCU)),
            LTRIM(RTRIM(tag.IMGBLK)),
            LTRIM(RTRIM(tag.IMBULK)),
            LTRIM(RTRIM(ib.IBLITM)),
            LTRIM(RTRIM(loc.LILOCN)),
            LTRIM(RTRIM(loc.LILOTN)),
            loc.LILOTS,
            im.IMUOM1,
            LTRIM(RTRIM(ib.IBPRP4)),
            LTRIM(RTRIM(ib.IBSTKT)),
            CASE LTRIM(RTRIM(ib.IBMCU))
                 WHEN 'SING' THEN 'Singapore'
                 WHEN 'SNG4' THEN 'Singapore'
                 WHEN 'MUM3' THEN 'India'
                 WHEN 'SHAN' THEN 'China'
                 WHEN 'AUBA' THEN 'Aubange'
                 WHEN 'AUB2' THEN 'Aubange'
                 WHEN 'CINC' THEN 'Americas'
                 WHEN 'CIN2' THEN 'Americas'
                 WHEN 'CIN4' THEN 'Americas'
                 ELSE 'ERROR'
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
            {"Global Bulk Item", type text},
            {"Bulk Item", type text},
            {"2nd Item Number", type text},
            {"Stock Type", type text},
            {"Lot Number", type text},
            {"Location", type text},
            {"Status", type text},
            {"Quantity On Hand", type number},
            {"Hard Commit", type number},
            {"Primary UOM", type text},
            {"Master Planning Family", type text},
            {"NOW", type date},
            {"OH KG", type number},
            {"OH LB", type number}
        },
        "en-US"
    )
in
    Typed
