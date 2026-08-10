// ============================================================================
// Report 07 - Ivan SK 2023   (page 5 of 5: "Safety Stock HP")   [structural clone of report 09; SK filter literals]
// QUERY: Safety Stock - New  ->  Cognos list "List2", query object "Safety Stock - New"
//
// Columns (RENDERED order, 9): REGION | Branch Plant | Global Bulk Item |
//   Bulk Item | 2nd Item Number | Primary UOM | Safety Stock | LB Safety Stock | REGION
//   NOTE: REGION appears TWICE (columns 1 and 9) - a Cognos quirk. This query
//   produces ONE [REGION] column; the builder places the [REGION] field twice in
//   the visual (col 9 is right-aligned). See BUILD.md.
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//
// LOGIC (faithful to the Cognos "Safety Stock - New" query - statement 5 of raw SQL):
//   SELECT DISTINCT (no aggregation) over F4102 ib / F554101 tag / F4101 im,
//   joins IBITM=IMITM, IMITM=tag.IMITM. Item-branch grain (F4102.IBSAFE).
//   Filters: Branch in ('AUBA','AUB2','SING','SNG4','MUM3','SHAN','CINC','CIN2','CIN4'); Bulk Item in
//   the SK 21-entry HP whitelist. (No prohibited filter in this query.)
//   REGION decode: CINC/CIN2/CIN4->Americas, AUBA/AUB2->EMEA, SING/SNG4->PacRim,
//   MUM3->India, SHAN->China, NO default (Oracle even-arg decode) -> ELSE NULL.
//
// Oracle -> T-SQL conversions:
//   decode(x, ...) with no default -> CASE ... END  (no ELSE -> NULL)
//   trim(both from x)              -> LTRIM(RTRIM(x))
//   x/10000                        -> x/10000.0
//   order by REGION ... nulls last -> OMITTED (folding). Sort = REGION -> set in visual.
//
// PARITY QUIRK (documented in BUILD.md):
//   LB Safety Stock uses IMUOM1 DIRECTLY (no MIN - this query has no GROUP BY):
//     'LB'? IBSAFE/10000 : 'KG'? (IBSAFE/10000)/0.453593 : 'EA'? (IBSAFE/10000)*40 : 0.
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT DISTINCT
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
            im.IMUOM1                               AS [Primary UOM],
            ib.IBSAFE/10000.0                       AS [Safety Stock],
            CASE WHEN im.IMUOM1 = 'LB' THEN ib.IBSAFE/10000.0
                 WHEN im.IMUOM1 = 'KG' THEN (ib.IBSAFE/10000.0) / 0.453593
                 WHEN im.IMUOM1 = 'EA' THEN (ib.IBSAFE/10000.0) * 40
                 ELSE 0
            END                                     AS [LB Safety Stock]
        FROM PRODDTA.F4102 ib
        JOIN PRODDTA.F4101   im  ON ib.IBITM = im.IMITM
        JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
        WHERE LTRIM(RTRIM(ib.IBMCU)) IN ('AUBA', 'AUB2', 'SING', 'SNG4', 'MUM3', 'SHAN', 'CINC', 'CIN2', 'CIN4')
          AND LTRIM(RTRIM(tag.IMBULK)) IN ('251194NX', 'DPI8200', '201250PX', '251095NX', 'DPI8600', 'DP040', '251194NX.E', 'DPI8200.E', '201250PX.E', '251095NX.E', 'DPI8600.E', 'DP040.E', '251194NX.S', 'DPI8200.S', '201250PX.S', '251095NX.S', 'DPI8600.S', 'DP040.S', 'PR5985', 'PR5985.E', 'PR5985.S')
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
            {"Primary UOM", type text},
            {"Safety Stock", type number},
            {"LB Safety Stock", type number}
        },
        "en-US"
    )
in
    Typed
