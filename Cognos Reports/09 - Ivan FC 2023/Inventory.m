// ============================================================================
// Report 09 - Ivan FC 2023   (page 1 of 5: "Inventory")
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
//   Filters: Branch in ('SHAN','MUM3','SING','SNG4','AUBA','AUB2'),
//            on-hand qty > 0, Bulk Item in the fixed 31-entry whitelist.
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
        WHERE LTRIM(RTRIM(ib.IBMCU)) IN ('SHAN', 'MUM3', 'SING', 'SNG4', 'AUBA', 'AUB2')
          AND loc.LIPQOH/10000.0 > 0
          AND LTRIM(RTRIM(tag.IMBULK)) IN ('JS168.S', 'ME91735.S', 'ME92040.S', 'PP05S.S', 'ME91240G.S', 'MG7140.S', 'TSPP01.S', 'ME92040.S', 'ME91735.S', 'ME87235.S', 'ME91735.S', 'ME90640.S', '211018IX.S', 'ME92040.S', 'PP236A.S', 'NYS2104.S', 'PP236A.S', 'ME91240G.S', 'JS168.E', 'ME92040.S', 'PP236A.S', 'ME91240G.S', 'ME91735.S', 'ME91735.S', 'ME91735.S', 'BRIJS2.S', 'BRIJS20.S', 'JS168.E', 'BRIJS2.E', 'BRIJS20.E', 'ME91735.E')
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
