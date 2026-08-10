// ============================================================================
// Report 01 - RM Staging at Shell Road 2026 (ODS)
// QUERY: Shortage_Detail  ->  PAGE 2 "Shortage Details"
//        (Cognos query object "Summary Shortage", list "List5")
//
// Columns: RM | Short Qty | Item | Branch Plant | Status | Lot Number | Location | Qty On Hand
//
// PURPOSE: for every SHORT material, list all on-hand inventory lots at BOTH
//   CIN2 and CINC (by location / lot / status) so a planner can see where to pull
//   the material from. This is the "source" companion to page 1's "what's short".
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//
// LOGIC (faithful to Cognos "Summary Shortage" = IOH All INNER JOIN RM Shortage CINC):
//   IOH All = on-hand at CIN2 + CINC, qty>0, item not H2O, ALL lot statuses
//             (Cognos's status filter here is DISABLED / use="prohibited"), carrying
//             Location, Lot Number, Status. One row per (branch, item, location, lot,
//             status).
//   short   = the short-material summary (RM + Short Qty) = the same shortage logic
//             as RM_Requirements. Inner join keeps only short materials and brings
//             Short Qty onto every lot row.
//
// ⚠ DEPENDS on F41021 columns LILOCN (Location) and LILOTN (Lot/Serial). Run
//   00_verify_tables_page2.sql first. Parity quirks (double-count OpenRM, AVG on-hand)
//   carried in the short-list subquery so page 1 and page 2 agree on the short set.
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            short.RM                    AS [RM],
            short.ShortQty              AS [Short Qty],
            ioh.Item2nd                 AS [Item],
            ioh.BranchPlant             AS [Branch Plant],
            ioh.Status                  AS [Status],
            ioh.LotNumber               AS [Lot Number],
            ioh.Location                AS [Location],
            ioh.QtyOnHand               AS [Qty On Hand]
        FROM (
            SELECT
                LTRIM(RTRIM(ib.IBMCU))   AS BranchPlant,
                LTRIM(RTRIM(ib.IBLITM))  AS Item2nd,
                LTRIM(RTRIM(il.LILOCN))  AS Location,
                LTRIM(RTRIM(il.LILOTN))  AS LotNumber,
                il.LILOTS                AS Status,
                SUM(il.LIPQOH / 10000.0) AS QtyOnHand
            FROM PRODDTA.F4102 ib
            JOIN PRODDTA.F41021 il ON ib.IBITM = il.LIITM AND ib.IBMCU = il.LIMCU
            WHERE (il.LIPQOH / 10000.0) > 0
              AND LTRIM(RTRIM(ib.IBMCU)) IN ('CIN2','CINC')
              AND LTRIM(RTRIM(ib.IBLITM)) NOT LIKE '%H2O%'
            GROUP BY LTRIM(RTRIM(ib.IBMCU)), LTRIM(RTRIM(ib.IBLITM)),
                     LTRIM(RTRIM(il.LILOCN)), LTRIM(RTRIM(il.LILOTN)), il.LILOTS
        ) ioh
        JOIN (
            -- short-material summary: RM + Short Qty (same logic as RM_Requirements)
            SELECT
                p.Component2nd AS RM,
                CASE WHEN AVG(iohc.QtyOnHand) IS NULL OR AVG(iohc.QtyOnHand) = 0
                     THEN SUM(p.OpenRM)
                     ELSE SUM(p.OpenRM) - AVG(iohc.QtyOnHand)
                END AS ShortQty
            FROM (
                SELECT LTRIM(RTRIM(wp2.WMCPIL)) AS Component2nd,
                       SUM((wp2.WMUORG - wp2.WMTRQT) / 10000.0) AS OpenRM
                FROM PRODDTA.F4801 wo2
                JOIN PRODDTA.F3111 wp2 ON wo2.WADOCO = wp2.WMDOCO
                JOIN PRODDTA.F4102 ib2 ON wp2.WMMCU = ib2.IBMCU AND wp2.WMCPIT = ib2.IBITM
                CROSS JOIN (SELECT CAST(GETDATE() AS date) AS Today) t2
                CROSS APPLY (SELECT (((DATEDIFF(DAY, '2003-01-06', t2.Today) % 7) + 7) % 7) + 1 AS DowMon1) dw2
                CROSS APPLY (SELECT CASE WHEN dw2.DowMon1 IN (4,5) THEN 4 WHEN dw2.DowMon1 = 6 THEN 3 ELSE 2 END AS DaysFwd) fw2
                WHERE LTRIM(RTRIM(wo2.WAMMCU)) = 'CINC'
                  AND wo2.WASRST NOT IN ('93','94','95','97','99','MM','CD')
                  AND ((wp2.WMUORG - wp2.WMTRQT) / 10000.0) > 0
                  AND LTRIM(RTRIM(wo2.WALITM)) NOT LIKE '%-%'
                  AND LTRIM(RTRIM(wp2.WMCPIL)) NOT LIKE '%H2O%'
                  AND ib2.IBPRP4 IN ('RRC','REC','RCB','TOL','PKG','RBW')
                  AND (CASE WHEN wp2.WMDRQJ > 0
                            THEN DATEADD(DAY, (wp2.WMDRQJ % 1000) - 1, DATEFROMPARTS(1900 + (wp2.WMDRQJ / 1000), 1, 1))
                       END)
                      BETWEEN DATEADD(DAY, -7, t2.Today) AND DATEADD(DAY, fw2.DaysFwd, t2.Today)
                GROUP BY LTRIM(RTRIM(wp2.WMCPIL))
            ) p
            LEFT JOIN (
                SELECT LTRIM(RTRIM(ib3.IBLITM)) AS Component2nd, SUM(il3.LIPQOH / 10000.0) AS QtyOnHand
                FROM PRODDTA.F4102 ib3
                JOIN PRODDTA.F41021 il3 ON ib3.IBITM = il3.LIITM AND ib3.IBMCU = il3.LIMCU
                WHERE (il3.LIPQOH / 10000.0) > 0
                  AND LTRIM(RTRIM(ib3.IBMCU)) = 'CINC'
                  AND LTRIM(RTRIM(ib3.IBLITM)) NOT LIKE '%H2O%'
                  AND il3.LILOTS IN (' ','-')
                GROUP BY LTRIM(RTRIM(ib3.IBLITM)), il3.LILOTS
            ) iohc ON p.Component2nd = iohc.Component2nd
            WHERE p.Component2nd <> ' '
            GROUP BY p.Component2nd
            HAVING CASE WHEN AVG(iohc.QtyOnHand) IS NULL         THEN 'SHORT'
                        WHEN AVG(iohc.QtyOnHand) = 0             THEN 'SHORT'
                        WHEN AVG(iohc.QtyOnHand) < SUM(p.OpenRM) THEN 'SHORT'
                        ELSE 'OK' END = 'SHORT'
        ) short ON ioh.Item2nd = short.RM
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"RM", type text},
            {"Short Qty", type number},
            {"Item", type text},
            {"Branch Plant", type text},
            {"Status", type text},
            {"Lot Number", type text},
            {"Location", type text},
            {"Qty On Hand", type number}
        }
    )
in
    Typed
