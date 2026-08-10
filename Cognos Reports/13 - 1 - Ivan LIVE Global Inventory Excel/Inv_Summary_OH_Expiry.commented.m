// ============================================================================
// Report 13 - 1 - Ivan LIVE Global Inventory Excel   (page 6 of 6: "OH and Expiry")
// QUERY: Inv Summary  ->  Cognos list "List6" (SECOND rendering of the SAME query)
// SOURCE SQL: "Inv Summary.5.sql" (10-column SELECT DISTINCT rendering)
//
// Columns (RENDERED order, 10):
//   Branch Plant | Global Bulk Item | Bulk Item | 2nd Item Number | Lot Number |
//   Lot Number1 | Supplier Lot Number | On Hand Date | Expiration Date Month | TIME
//   (Lot Number1 header column is dark blue in Cognos; reproduce name verbatim.)
//
// WHY A SEPARATE TABLE FROM "Inv_Summary.m":
//   Page 1 (List1 / .0) aggregates to the lot+location+status+UOM grain -> 7,257 rows.
//   Page 6 (List6 / .5) is SELECT DISTINCT over only 10 identity columns -> 6,868 rows
//   (multiple locations/statuses of the same lot collapse to one row). The two counts
//   differ, so this page needs its own DISTINCT projection to hit 6,868 exactly.
//   Cognos runs the same underlying "Inv Summary" query twice with different SELECT
//   lists; we mirror that with a dedicated table. Do NOT try to serve both pages from
//   one table + a subset visual unless the render row count is verified to tie to 6,868.
//
// Everything else (derived tables, joins, Julian conversion, scaling, sysdate handling)
// is identical to Inv_Summary.commented.m - see that file for the full porting notes.
// Expected rows to xlsx "OH and Expiry_6": 6,868 (as-of capture; live counts drift).
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT DISTINCT
            Inventory6.Branch_Plant          AS [Branch Plant],
            Inventory6.Global_Bulk_Item      AS [Global Bulk Item],
            Inventory6.Bulk_Item             AS [Bulk Item],
            Inventory6.C_2nd_Item_Number     AS [2nd Item Number],
            Inventory6.Lot_Number            AS [Lot Number],
            Quality7.Lot_Number              AS [Lot Number1],
            Quality7.Supplier_Lot_Number     AS [Supplier Lot Number],
            Quality7.On_Hand_Date            AS [On Hand Date],
            Quality7.Expiration_Date_Month   AS [Expiration Date Month],
            Inventory6.TIME24                AS [TIME]
        FROM
        (
            SELECT
                T0.C0  AS Branch_Plant,
                T0.C1  AS Global_Bulk_Item,
                T0.C2  AS Bulk_Item,
                T0.C3  AS C_2nd_Item_Number,
                T0.C14 AS Lot_Number,
                T0.C23 AS TIME24
            FROM
            (
                SELECT
                    LTRIM(RTRIM(LTRIM(RTRIM(ib.IBMCU))))    AS C0,
                    LTRIM(RTRIM(tag.IMGBLK))                AS C1,
                    LTRIM(RTRIM(tag.IMBULK))                AS C2,
                    LTRIM(RTRIM(LTRIM(RTRIM(ib.IBLITM))))   AS C3,
                    LTRIM(RTRIM(loc.LILOTN))                AS C14,
                    CAST(GETDATE() AS date)                 AS C23
                FROM PRODDTA.F4102 ib,
                     PRODDTA.F554101 tag,
                     PRODDTA.F41021 loc,
                     PRODDTA.F4101 im,
                     (
                        SELECT
                            f.IBITM, f.IBMCU, e.IELEDG,
                            SUM(CASE WHEN e.IECOST='A1 ' THEN e.IECSL/10000.0 ELSE 0 END) AS A1_Unit_Cost,
                            SUM(CASE WHEN e.IECOST='B1 ' THEN e.IECSL/10000.0 ELSE 0 END) AS B1_Unit_Cost,
                            SUM(CASE WHEN e.IECOST='C1 ' THEN e.IECSL/10000.0 ELSE 0 END) AS C1_Unit_Cost,
                            SUM(CASE WHEN e.IECOST='C2 ' THEN e.IECSL/10000.0 ELSE 0 END) AS C2_Unit_Cost
                        FROM PRODDTA.F4102 f,
                             PRODDTA.F4105 c
                             LEFT OUTER JOIN PRODDTA.F30026 e
                                 ON c.COITM=e.IEITM AND c.COMCU=e.IEMMCU AND c.COLEDG=e.IELEDG
                        WHERE f.IBITM=c.COITM AND f.IBMCU=c.COMCU AND c.COCSIN='I'
                        GROUP BY f.IBITM, f.IBMCU, e.IELEDG
                     ) cost
                WHERE loc.LIPQOH/10000.0 > 0
                  AND ib.IBITM = im.IMITM
                  AND im.IMITM = tag.IMITM
                  AND ib.IBITM = loc.LIITM
                  AND ib.IBMCU = loc.LIMCU
                  AND ib.IBITM = cost.IBITM
                  AND ib.IBMCU = cost.IBMCU
                GROUP BY
                    LTRIM(RTRIM(LTRIM(RTRIM(ib.IBMCU)))),
                    LTRIM(RTRIM(tag.IMGBLK)),
                    LTRIM(RTRIM(tag.IMBULK)),
                    LTRIM(RTRIM(LTRIM(RTRIM(ib.IBLITM)))),
                    ib.IBPRP1, ib.IBPRP2, ib.IBPRP4, ib.IBSAFE/10000.0, ib.IBSLD, ib.IBSTKT,
                    ib.IBGLPT, ib.IBLTLV, ib.IBLTMF,
                    LTRIM(RTRIM(loc.LILOCN)), LTRIM(RTRIM(loc.LILOTN)), loc.LILOTS, im.IMUOM1
            ) T0
        ) Inventory6
        INNER JOIN
        (
            SELECT DISTINCT
                LTRIM(RTRIM(lm.IOLOTN)) AS Lot_Number,
                -- ODS stores the 4-char text 'NULL' in F4108.IORLOT where live JDE holds an
                -- empty value; Cognos renders those lots blank. NULLIF restores parity
                -- (532 rows on this projection, confirmed 2026-07-14).
                NULLIF(LTRIM(RTRIM(lm.IORLOT)), 'NULL') AS Supplier_Lot_Number,
                lm.Expiration_Date_Month AS Expiration_Date_Month,
                lm.On_Hand_Date          AS On_Hand_Date
            FROM
            (
                SELECT
                    IOLOTN, IORLOT,
                    CASE WHEN IOMMEJ>0 THEN DATEADD(DAY,(IOMMEJ%1000)-1,DATEFROMPARTS(1900+(IOMMEJ/1000),1,1)) ELSE NULL END AS Expiration_Date_Month,
                    CASE WHEN IOOHDJ>0 THEN DATEADD(DAY,(IOOHDJ%1000)-1,DATEFROMPARTS(1900+(IOOHDJ/1000),1,1)) ELSE NULL END AS On_Hand_Date
                FROM PRODDTA.F4108
            ) lm
            WHERE lm.Expiration_Date_Month IS NOT NULL
        ) Quality7
            ON Inventory6.Lot_Number = Quality7.Lot_Number
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Branch Plant", type text}, {"Global Bulk Item", type text}, {"Bulk Item", type text},
            {"2nd Item Number", type text}, {"Lot Number", type text}, {"Lot Number1", type text},
            {"Supplier Lot Number", type text}, {"On Hand Date", type date},
            {"Expiration Date Month", type date}, {"TIME", type date}
        },
        "en-US"
    )
in
    Typed
