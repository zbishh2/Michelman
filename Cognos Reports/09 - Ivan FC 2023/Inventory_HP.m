// ============================================================================
// Report 09 - Ivan FC 2023   (page 4 of 5: "Inventory HP")
// QUERY: Inventory - New  ->  Cognos list "List5", query object "Inventory - New"
//
// Columns (RENDERED order, 11): REGION | Branch Plant | Global Bulk Item |
//   Bulk Item | 2nd Item Number | Location | Lot Number | Status |
//   Primary UOM | Quantity On Hand | LB
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//
// LOGIC (faithful to the Cognos "Inventory - New" query - statement 4 of raw SQL):
//   Flat SELECT + GROUP BY over F4102 ib / F554101 tag / F41021 loc / F4101 im
//   (lot/location grain), joins IBITM=IMITM, IMITM=tag.IMITM, IBITM=LIITM AND
//   IBMCU=LIMCU. Filters:
//     * Status: LILOTS IS NULL OR LILOTS in ('T','B','Q','H')  (available lots)
//     * Branch in ('AUBA','AUB2','SING','SNG4','SHAN','MUM3')
//     * Bulk Item in the 31-entry whitelist
//   NOTE: the report XML has a SECOND use="prohibited" Bulk-Item filter that did NOT
//   survive into the generated SQL, so it is intentionally NOT applied (match the
//   generated SQL). This differs from the page-1 REGION decode: here REGION decode
//   is CINC/CIN2/CIN4->Americas, AUBA/AUB2->EMEA, SING/SNG4->PacRim, MUM3->India,
//   SHAN->China, with NO default (Oracle even-arg decode) -> ELSE NULL.
//
// Oracle -> T-SQL conversions:
//   decode(x, ...) with no default -> CASE ... END  (no ELSE -> NULL)
//   trim(both from x)              -> LTRIM(RTRIM(x))
//   x/10000                        -> x/10000.0
//   order by ... nulls last        -> OMITTED (folding). Cognos sort was Global Bulk
//       Item, Bulk Item, 2nd Item Number -> set in the visual. See BUILD.md.
//
// PARITY QUIRK (documented in BUILD.md):
//   LB = MIN(IMUOM1)='LB'? SUM(QOH) : 'KG'? SUM(QOH)/0.453593 : 'EA'? SUM(QOH)*40 : 0.
//   MIN(IMUOM1) inside CASE while GROUP BY IMUOM1 (group's single UOM). ELSE 0.
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
                 WHEN 'AUBA' THEN 'EMEA'
                 WHEN 'AUB2' THEN 'EMEA'
                 WHEN 'SING' THEN 'PacRim'
                 WHEN 'SNG4' THEN 'PacRim'
                 WHEN 'MUM3' THEN 'India'
                 WHEN 'SHAN' THEN 'China'
            END                                     AS [REGION],
            LTRIM(RTRIM(ib.IBMCU))                  AS [Branch Plant],
            LTRIM(RTRIM(tag.IMGBLK))                AS [Global Bulk Item],
            LTRIM(RTRIM(tag.IMBULK))                AS [Bulk Item],
            LTRIM(RTRIM(ib.IBLITM))                 AS [2nd Item Number],
            LTRIM(RTRIM(loc.LILOCN))                AS [Location],
            LTRIM(RTRIM(loc.LILOTN))                AS [Lot Number],
            LTRIM(RTRIM(loc.LILOTS))                AS [Status],
            im.IMUOM1                               AS [Primary UOM],
            SUM(loc.LIPQOH/10000.0)                 AS [Quantity On Hand],
            CASE WHEN MIN(im.IMUOM1) = 'LB' THEN SUM(loc.LIPQOH/10000.0)
                 WHEN MIN(im.IMUOM1) = 'KG' THEN SUM(loc.LIPQOH/10000.0) / 0.453593
                 WHEN MIN(im.IMUOM1) = 'EA' THEN SUM(loc.LIPQOH/10000.0) * 40
                 ELSE 0
            END                                     AS [LB]
        FROM PRODDTA.F4102 ib
        JOIN PRODDTA.F4101   im  ON ib.IBITM = im.IMITM
        JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
        JOIN PRODDTA.F41021  loc ON ib.IBITM = loc.LIITM
                                AND ib.IBMCU = loc.LIMCU
        WHERE (loc.LILOTS IS NULL OR LTRIM(RTRIM(loc.LILOTS)) = '' OR LTRIM(RTRIM(loc.LILOTS)) IN ('T', 'B', 'Q', 'H'))
          AND LTRIM(RTRIM(ib.IBMCU)) IN ('AUBA', 'AUB2', 'SING', 'SNG4', 'SHAN', 'MUM3')
          AND LTRIM(RTRIM(tag.IMBULK)) IN ('JS168.S', 'ME91735.S', 'ME92040.S', 'PP05S.S', 'ME91240G.S', 'MG7140.S', 'TSPP01.S', 'ME92040.S', 'ME91735.S', 'ME87235.S', 'ME91735.S', 'ME90640.S', '211018IX.S', 'ME92040.S', 'PP236A.S', 'NYS2104.S', 'PP236A.S', 'ME91240G.S', 'JS168.E', 'ME92040.S', 'PP236A.S', 'ME91240G.S', 'ME91735.S', 'ME91735.S', 'ME91735.S', 'BRIJS2.S', 'BRIJS20.S', 'JS168.E', 'BRIJS2.E', 'BRIJS20.E', 'ME91735.E')
        GROUP BY
            CASE LTRIM(RTRIM(ib.IBMCU))
                 WHEN 'CINC' THEN 'Americas'
                 WHEN 'CIN2' THEN 'Americas'
                 WHEN 'CIN4' THEN 'Americas'
                 WHEN 'AUBA' THEN 'EMEA'
                 WHEN 'AUB2' THEN 'EMEA'
                 WHEN 'SING' THEN 'PacRim'
                 WHEN 'SNG4' THEN 'PacRim'
                 WHEN 'MUM3' THEN 'India'
                 WHEN 'SHAN' THEN 'China'
            END,
            LTRIM(RTRIM(ib.IBMCU)),
            LTRIM(RTRIM(tag.IMGBLK)),
            LTRIM(RTRIM(tag.IMBULK)),
            LTRIM(RTRIM(ib.IBLITM)),
            LTRIM(RTRIM(loc.LILOCN)),
            LTRIM(RTRIM(loc.LILOTN)),
            LTRIM(RTRIM(loc.LILOTS)),
            im.IMUOM1
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
            {"Location", type text},
            {"Lot Number", type text},
            {"Status", type text},
            {"Primary UOM", type text},
            {"Quantity On Hand", type number},
            {"LB", type number}
        },
        "en-US"
    )
in
    Typed
