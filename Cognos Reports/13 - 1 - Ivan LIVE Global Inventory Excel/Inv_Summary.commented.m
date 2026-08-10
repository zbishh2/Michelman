// ============================================================================
// Report 13 - 1 - Ivan LIVE Global Inventory Excel   (page 1 of 6: "Inventory OH")
// QUERY: Inv Summary  ->  Cognos list "List1", query object "Inv Summary"
// SOURCE SQL: "Inv Summary.0.sql" (full 28-column rendering of the Inv Summary query)
//
// Columns (RENDERED order, 28 - headers are the Cognos data-item names verbatim):
//   Branch Plant | Global Bulk Item | Bulk Item | 2nd Item Number | Commodity Class |
//   Sub Class | Master Planning Family | Safety Stock | Shelf Life | Stock Type |
//   GL Category | Leadtime Level | Leadtime MFG | Location | Lot Number | Status |
//   Quantity On Hand | Primary UOM | Hard Commit | A1 Cost | B1 Cost | C1 Cost |
//   C2 Cost | Lot Number1 | Supplier Lot Number | On Hand Date | Expiration Date Month | TIME
//   NOTE: "Lot Number1" is the JOIN-DUPLICATE of the lot key coming from the Quality
//   (Lot Master) side. Cognos renders the raw data-item name, trailing "1" and all.
//   Reproduce it verbatim as the PBIR displayName - do NOT clean it up (parity).
//
// SOURCE: ODSPROD / "ODS" / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//   House pattern: report 07 "Inventory.m" (same F4102/F4101/F554101/F41021 grain),
//   report 01 RM_Requirements.m (Julian conversion, /10000.0 scaling).
//   Cognos model is "JDE Live Data" (live Oracle) -> we port to the ODS mirror.
//
// LOGIC (faithful to the Cognos generated Oracle SQL, statement "Inv Summary.0"):
//   Three stacked layers, reproduced exactly (Cognos redundancy kept for parity):
//     * "cost"       = F30026 standard-cost pivot (A1/B1/C1/C2 unit cost) per item-branch-ledger,
//                      via F4102 -> F4105 (cost method 'I') LEFT JOIN F30026.
//     * "Inventory6"  = F41021 lot/location on-hand grain: SUM on-hand, hard commit, and
//                      on-hand * each unit cost, grouped to the item-branch-lot-location-status-UOM grain.
//     * "Quality7"    = F4108 Lot Master: lot -> supplier lot, expiration month, on-hand date
//                      (DISTINCT, expiration month NOT NULL).
//   Final: Inventory6 INNER JOIN Quality7 on Lot_Number, GROUP BY every non-fact column
//   (SUM re-collapses the lot-master fan-out). The Cognos FULL OUTER JOIN + WHERE
//   equality is an inner join; ported as INNER JOIN.
//
// Oracle -> T-SQL conversions:
//   with <cte> ... select               -> nested derived tables (PBI wraps as
//                                          SELECT * FROM (<query>); WITH is illegal there).
//   trim(both from trim(both from x))    -> LTRIM(RTRIM(x))
//   Decode(IECOST,'A1 ',IECSL/10000,0)   -> SUM(CASE WHEN IECOST='A1 ' THEN IECSL/10000.0 ELSE 0 END)
//   PRODDTA.JUL2DATE(x) guarded by >0    -> CASE WHEN x>0 THEN
//                                          DATEADD(DAY,(x%1000)-1,DATEFROMPARTS(1900+(x/1000),1,1)) ELSE NULL END
//   TRUNC(cast(<jul-date> as timestamp)) -> the JUL2DATE port is already day-grain: no extra TRUNC.
//   sysdate ({sysdate} TIME item)        -> CAST(GETDATE() AS date). Constant scalar: allowed in
//                                          SELECT with GROUP BY WITHOUT being in GROUP BY (proven in report 07);
//                                          so it is DROPPED from every GROUP BY list.
//   x/10000                              -> x/10000.0 (keep decimals; matches Orders.m / report 07)
//   FULL OUTER JOIN + WHERE a=b          -> INNER JOIN
//   order by ... nulls last              -> OMITTED (illegal in the folded subquery). Cognos sort was
//                                          Global Bulk Item, Bulk Item, 2nd Item Number, Branch Plant
//                                          -> set in the visual (see BUILD.md).
//
// PARITY NOTES:
//   * use="prohibited" filter [Global Bulk Item] in ('MD353D','MP4983R') is DISABLED in Cognos
//     and never reached the generated SQL -> intentionally NOT applied (same call as report 07).
//   * Expected rows to the xlsx "Inventory OH_1" sheet: 7,257 data rows (as-of capture; live counts drift).
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            Inventory6.Branch_Plant             AS [Branch Plant],
            Inventory6.Global_Bulk_Item         AS [Global Bulk Item],
            Inventory6.Bulk_Item                AS [Bulk Item],
            Inventory6.C_2nd_Item_Number        AS [2nd Item Number],
            Inventory6.Commodity_Class          AS [Commodity Class],
            Inventory6.Sub_Class                AS [Sub Class],
            Inventory6.Master_Planning_Family   AS [Master Planning Family],
            Inventory6.Safety_Stock             AS [Safety Stock],
            Inventory6.Shelf_Life               AS [Shelf Life],
            Inventory6.Stock_Type               AS [Stock Type],
            Inventory6.GL_Category              AS [GL Category],
            Inventory6.Leadtime_Level           AS [Leadtime Level],
            Inventory6.Leadtime_MFG             AS [Leadtime MFG],
            Inventory6.Location                 AS [Location],
            Inventory6.Lot_Number               AS [Lot Number],
            Inventory6.Status                   AS [Status],
            SUM(Inventory6.Quantity_On_Hand)    AS [Quantity On Hand],
            Inventory6.Primary_UOM              AS [Primary UOM],
            SUM(Inventory6.Hard_Commit)         AS [Hard Commit],
            SUM(Inventory6.A1_Cost)             AS [A1 Cost],
            SUM(Inventory6.B1_Cost)             AS [B1 Cost],
            SUM(Inventory6.C1_Cost)             AS [C1 Cost],
            SUM(Inventory6.C2_Cost)             AS [C2 Cost],
            Quality7.Lot_Number                 AS [Lot Number1],
            Quality7.Supplier_Lot_Number        AS [Supplier Lot Number],
            Quality7.On_Hand_Date               AS [On Hand Date],
            Quality7.Expiration_Date_Month      AS [Expiration Date Month],
            Inventory6.TIME24                   AS [TIME]
        FROM
        (
            SELECT
                T0.C0  AS Branch_Plant,
                T0.C1  AS Global_Bulk_Item,
                T0.C2  AS Bulk_Item,
                T0.C3  AS C_2nd_Item_Number,
                T0.C4  AS Commodity_Class,
                T0.C5  AS Sub_Class,
                T0.C6  AS Master_Planning_Family,
                T0.C7  AS Safety_Stock,
                T0.C8  AS Shelf_Life,
                T0.C9  AS Stock_Type,
                T0.C10 AS GL_Category,
                T0.C11 AS Leadtime_Level,
                T0.C12 AS Leadtime_MFG,
                T0.C13 AS Location,
                T0.C14 AS Lot_Number,
                T0.C15 AS Status,
                SUM(T0.C16) OVER (PARTITION BY T0.C0,T0.C1,T0.C2,T0.C3,T0.C4,T0.C5,T0.C6,T0.C7,T0.C8,T0.C9,T0.C10,T0.C11,T0.C12,T0.C13,T0.C14,T0.C15,T0.C17) AS Quantity_On_Hand,
                T0.C17 AS Primary_UOM,
                SUM(T0.C18) OVER (PARTITION BY T0.C0,T0.C1,T0.C2,T0.C3,T0.C4,T0.C5,T0.C6,T0.C7,T0.C8,T0.C9,T0.C10,T0.C11,T0.C12,T0.C13,T0.C14,T0.C15,T0.C17) AS Hard_Commit,
                SUM(T0.C19) OVER (PARTITION BY T0.C0,T0.C1,T0.C2,T0.C3,T0.C4,T0.C5,T0.C6,T0.C7,T0.C8,T0.C9,T0.C10,T0.C11,T0.C12,T0.C13,T0.C14,T0.C15,T0.C17) AS A1_Cost,
                SUM(T0.C20) OVER (PARTITION BY T0.C0,T0.C1,T0.C2,T0.C3,T0.C4,T0.C5,T0.C6,T0.C7,T0.C8,T0.C9,T0.C10,T0.C11,T0.C12,T0.C13,T0.C14,T0.C15,T0.C17) AS B1_Cost,
                SUM(T0.C21) OVER (PARTITION BY T0.C0,T0.C1,T0.C2,T0.C3,T0.C4,T0.C5,T0.C6,T0.C7,T0.C8,T0.C9,T0.C10,T0.C11,T0.C12,T0.C13,T0.C14,T0.C15,T0.C17) AS C1_Cost,
                SUM(T0.C22) OVER (PARTITION BY T0.C0,T0.C1,T0.C2,T0.C3,T0.C4,T0.C5,T0.C6,T0.C7,T0.C8,T0.C9,T0.C10,T0.C11,T0.C12,T0.C13,T0.C14,T0.C15,T0.C17) AS C2_Cost,
                T0.C23 AS TIME24
            FROM
            (
                SELECT
                    LTRIM(RTRIM(LTRIM(RTRIM(ib.IBMCU))))    AS C0,
                    LTRIM(RTRIM(tag.IMGBLK))                AS C1,
                    LTRIM(RTRIM(tag.IMBULK))                AS C2,
                    LTRIM(RTRIM(LTRIM(RTRIM(ib.IBLITM))))   AS C3,
                    ib.IBPRP1                               AS C4,
                    ib.IBPRP2                               AS C5,
                    ib.IBPRP4                               AS C6,
                    ib.IBSAFE/10000.0                       AS C7,
                    ib.IBSLD                                AS C8,
                    ib.IBSTKT                               AS C9,
                    ib.IBGLPT                               AS C10,
                    ib.IBLTLV                               AS C11,
                    ib.IBLTMF                               AS C12,
                    LTRIM(RTRIM(loc.LILOCN))                AS C13,
                    LTRIM(RTRIM(loc.LILOTN))                AS C14,
                    loc.LILOTS                              AS C15,
                    SUM(loc.LIPQOH/10000.0)                 AS C16,
                    im.IMUOM1                               AS C17,
                    SUM(loc.LIHCOM/10000.0)                 AS C18,
                    SUM((loc.LIPQOH/10000.0)*cost.A1_Unit_Cost) AS C19,
                    SUM((loc.LIPQOH/10000.0)*cost.B1_Unit_Cost) AS C20,
                    SUM((loc.LIPQOH/10000.0)*cost.C1_Unit_Cost) AS C21,
                    SUM((loc.LIPQOH/10000.0)*cost.C2_Unit_Cost) AS C22,
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
                -- empty value (Oracle '' IS NULL; the replica materialised it as a string).
                -- Cognos renders those lots blank, so NULLIF restores parity. 552 rows here /
                -- 532 on the OH-and-Expiry projection, confirmed 2026-07-14.
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
        GROUP BY
            Inventory6.Branch_Plant, Inventory6.Global_Bulk_Item, Inventory6.Bulk_Item,
            Inventory6.C_2nd_Item_Number, Inventory6.Commodity_Class, Inventory6.Sub_Class,
            Inventory6.Master_Planning_Family, Inventory6.Safety_Stock, Inventory6.Shelf_Life,
            Inventory6.Stock_Type, Inventory6.GL_Category, Inventory6.Leadtime_Level,
            Inventory6.Leadtime_MFG, Inventory6.Location, Inventory6.Lot_Number, Inventory6.Status,
            Inventory6.Primary_UOM, Quality7.Lot_Number, Quality7.Supplier_Lot_Number,
            Quality7.On_Hand_Date, Quality7.Expiration_Date_Month, Inventory6.TIME24
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Branch Plant", type text}, {"Global Bulk Item", type text}, {"Bulk Item", type text},
            {"2nd Item Number", type text}, {"Commodity Class", type text}, {"Sub Class", type text},
            {"Master Planning Family", type text}, {"Safety Stock", type number}, {"Shelf Life", type number},
            {"Stock Type", type text}, {"GL Category", type text}, {"Leadtime Level", type number},
            {"Leadtime MFG", type number}, {"Location", type text}, {"Lot Number", type text},
            {"Status", type text}, {"Quantity On Hand", type number}, {"Primary UOM", type text},
            {"Hard Commit", type number}, {"A1 Cost", type number}, {"B1 Cost", type number},
            {"C1 Cost", type number}, {"C2 Cost", type number}, {"Lot Number1", type text},
            {"Supplier Lot Number", type text}, {"On Hand Date", type date},
            {"Expiration Date Month", type date}, {"TIME", type date}
        },
        "en-US"
    )
in
    Typed
