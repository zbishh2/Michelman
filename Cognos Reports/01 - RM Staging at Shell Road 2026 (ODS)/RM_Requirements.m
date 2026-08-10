// ============================================================================
// Report 01 - RM Staging at Shell Road 2026 (ODS)
// QUERY: RM_Requirements  ->  top table "Raw Material requirements"
//        (Cognos query object "Summary Shortage")
//
// Columns: RM | QTY OH in CINC | Total RM Needed | QTY Required from CIN2
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//   Matches the house pattern in edw_model/JDE_Orders/Orders.m.
//
// NOTE: written with INLINE DERIVED TABLES (not a top-level WITH/CTE). With
//   [EnableFolding=true] Power BI wraps the query as "SELECT * FROM (<query>)",
//   and a leading CTE can't be wrapped -> "Incorrect syntax near 'WITH'". Derived
//   tables wrap fine and keep folding on.
//
// LOGIC (faithful to Cognos "Summary Shortage"):
//   p (Planned) = open CINC work-order PARTS whose part requested date (WMDRQJ)
//             falls in [today-7 .. today + N business days], item is a raw-material
//             MPF (IBPRP4 whitelist), open RM (ordered-issued) > 0. Aggregated to
//             the component item -> OpenRM = SUM((WMUORG-WMTRQT)/10000).
//   ioh (IOH) = CINC on-hand per (item, lot status) where LILOTS in (' ','-'), qty>0.
//   Output    = components classified SHORT (QOH null/0, or QOH < OpenRM).
//
// ⚠ PARITY QUIRKS reproduced on purpose (so numbers tie to the live Cognos report).
//   Corrected formulas are in BUILD.md ("Known Cognos quirks"):
//     1. Total RM Needed DOUBLE-COUNTS: the Cognos join fans Planned out by the #
//        of on-hand lot statuses, so SUM(OpenRM) is multiplied by that count when
//        an item has stock in both the ' ' and '-' statuses.
//     2. QTY OH uses AVG across lot statuses, not SUM.
//
// BUSINESS-DAY WINDOW: weekday normalized to Mon=1..Sun=7, then "2 business days"
//   forward: Thu/Fri -> +4, Sat -> +3, else +2. Lower bound today-7 (overdue parts).
//   sysdate -> CAST(GETDATE() AS date) = refresh day.
// JULIAN: JDE CYYDDD -> date via DATEADD/DATEFROMPARTS (1900+CYY, day-of-year).
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            p.Component2nd                                            AS [RM],
            AVG(ioh.QtyOnHand)                                        AS [Qty On Hand CINC],
            SUM(p.OpenRM)                                             AS [Total RM Needed],
            CASE WHEN AVG(ioh.QtyOnHand) IS NULL OR AVG(ioh.QtyOnHand) = 0
                 THEN SUM(p.OpenRM)
                 ELSE SUM(p.OpenRM) - AVG(ioh.QtyOnHand)
            END                                                       AS [Qty Required From CIN2]
        FROM (
            SELECT
                LTRIM(RTRIM(wp.WMCPIL))               AS Component2nd,
                SUM((wp.WMUORG - wp.WMTRQT) / 10000.0) AS OpenRM
            FROM PRODDTA.F4801 wo
            JOIN PRODDTA.F3111 wp ON wo.WADOCO = wp.WMDOCO
            JOIN PRODDTA.F4102 ib ON wp.WMMCU = ib.IBMCU AND wp.WMCPIT = ib.IBITM
            CROSS JOIN (SELECT CAST(GETDATE() AS date) AS Today) t
            CROSS APPLY (SELECT (((DATEDIFF(DAY, '2003-01-06', t.Today) % 7) + 7) % 7) + 1 AS DowMon1) dw
            CROSS APPLY (SELECT CASE WHEN dw.DowMon1 IN (4,5) THEN 4 WHEN dw.DowMon1 = 6 THEN 3 ELSE 2 END AS DaysFwd) fw
            WHERE LTRIM(RTRIM(wo.WAMMCU)) = 'CINC'
              AND wo.WASRST NOT IN ('93','94','95','97','99','MM','CD')
              AND ((wp.WMUORG - wp.WMTRQT) / 10000.0) > 0
              AND LTRIM(RTRIM(wo.WALITM)) NOT LIKE '%-%'
              AND LTRIM(RTRIM(wp.WMCPIL)) NOT LIKE '%H2O%'
              AND ib.IBPRP4 IN ('RRC','REC','RCB','TOL','PKG','RBW')
              AND (CASE WHEN wp.WMDRQJ > 0
                        THEN DATEADD(DAY, (wp.WMDRQJ % 1000) - 1, DATEFROMPARTS(1900 + (wp.WMDRQJ / 1000), 1, 1))
                   END)
                  BETWEEN DATEADD(DAY, -7, t.Today) AND DATEADD(DAY, fw.DaysFwd, t.Today)
            GROUP BY LTRIM(RTRIM(wp.WMCPIL))
        ) p
        LEFT JOIN (
            SELECT
                LTRIM(RTRIM(ib.IBLITM))  AS Component2nd,
                il.LILOTS                AS Status,
                SUM(il.LIPQOH / 10000.0) AS QtyOnHand
            FROM PRODDTA.F4102 ib
            JOIN PRODDTA.F41021 il ON ib.IBITM = il.LIITM AND ib.IBMCU = il.LIMCU
            WHERE (il.LIPQOH / 10000.0) > 0
              AND LTRIM(RTRIM(ib.IBMCU)) = 'CINC'
              AND LTRIM(RTRIM(ib.IBLITM)) NOT LIKE '%H2O%'
              AND il.LILOTS IN (' ','-')
            GROUP BY LTRIM(RTRIM(ib.IBLITM)), il.LILOTS
        ) ioh ON p.Component2nd = ioh.Component2nd
        WHERE p.Component2nd <> ' '
        GROUP BY p.Component2nd
        HAVING CASE WHEN AVG(ioh.QtyOnHand) IS NULL                    THEN 'SHORT'
                    WHEN AVG(ioh.QtyOnHand) = 0                        THEN 'SHORT'
                    WHEN AVG(ioh.QtyOnHand) < SUM(p.OpenRM)            THEN 'SHORT'
                    ELSE 'OK' END = 'SHORT'
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"RM", type text},
            {"Qty On Hand CINC", type number},
            {"Total RM Needed", type number},
            {"Qty Required From CIN2", type number}
        }
    )
in
    Typed
