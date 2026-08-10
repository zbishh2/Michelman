// ============================================================================
// Report 13 - 1 - Ivan LIVE Global Inventory Excel   (page 5 of 6: "WO Parts List")
// QUERY: WO Parts List  ->  Cognos list "List5", query object "WO Parts List"
// SOURCE SQL: "WO Parts List.4.sql"
//
// Columns (RENDERED order, 18 - headers verbatim):
//   Branch Plant | Global Bulk Item | Bulk Item | 2nd Item Number | WO Number |
//   WO Status | Order Date | Start Date | Completed Date | Quantity Requested |
//   Quantity Completed | Unit of Measure | Component Branch | Component 2nd Item Number |
//   Ordered Quantity | Issued Quantity | Component UOM | Requested Date
//
// SOURCE: ODSPROD / "ODS" / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//
// LOGIC (faithful to "WO Parts List.4.sql"): F4801 work-order header joined to F3111
//   work-order PARTS (WADOCO=WMDOCO) and the item dimension, at the WO+component grain.
//   Filters: WO Status NOT IN ('95'..'99','MM','CD'), Start Date >= today-30,
//   (Ordered+Issued component qty) > 0, HAVING avg(WO Completed qty)=0.
//   Ordered Quantity = SUM(WMUORG/10000); Issued Quantity = SUM(WMTRQT/10000).
//
//   Quantity Requested / Quantity Completed are the WO-HEADER quantities spread across
//   the parts rows exactly as Cognos does it: a two-layer aggregation.
//     inner (derived "m"): GROUP BY the WO+component grain, producing per-group
//       SUM/COUNT of WAUORG and WASOQS plus the component sums.
//     outer: re-aggregate those SUM/COUNT back to the WO grain with window functions:
//       Quantity Requested = SUM(sumReq) OVER (WO grain) / NULLIF(SUM(cntReq) OVER (WO grain),0)
//       Quantity Completed = SUM(sumComp) OVER (WO grain) / NULLIF(SUM(cntComp) OVER (WO grain),0)
//     -> the WO-level average is repeated on every parts row of that WO (Cognos behavior).
//   Cognos's third, redundant first_value(...) OVER wrapper is dropped: its partition is
//   the WO grain and every row in it already carries the same value.
//
// PARITY DETAIL: Bulk Item = tag.IMBULK WITHOUT trim (matches the generated SQL, as in
//   Work_Orders.m). Global Bulk Item IS trimmed.
//
// Oracle -> T-SQL: trim(both from x) -> LTRIM(RTRIM(x)); JUL2DATE guarded by >0 ->
//   CASE WHEN x>0 THEN DATEADD(DAY,(x%1000)-1,DATEFROMPARTS(1900+(x/1000),1,1)) ELSE NULL END;
//   x/10000 -> x/10000.0; a/nullif(b,0) kept; to_date(sysdate)-30 ->
//   DATEADD(DAY,-30,CAST(GETDATE() AS date)); no ORDER BY (folded). Cognos sort:
//   Global Bulk Item, Bulk Item, 2nd Item Number, Start Date -> set in the visual.
//   WO Number -> summarizeBy:none. See BUILD.md.
// Expected rows to xlsx "WO Parts List_5": 1,676 (as-of capture; live counts drift).
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            m.C0  AS [Branch Plant],
            m.C1  AS [Global Bulk Item],
            m.C2  AS [Bulk Item],
            m.C3  AS [2nd Item Number],
            m.C4  AS [WO Number],
            m.C5  AS [WO Status],
            m.C6  AS [Order Date],
            m.C7  AS [Start Date],
            m.C8  AS [Completed Date],
            SUM(m.sumReq)  OVER (PARTITION BY m.C0,m.C1,m.C2,m.C3,m.C4,m.C5,m.C6,m.C7,m.C8,m.C11)
                / NULLIF(SUM(m.cntReq) OVER (PARTITION BY m.C0,m.C1,m.C2,m.C3,m.C4,m.C5,m.C6,m.C7,m.C8,m.C11),0)  AS [Quantity Requested],
            SUM(m.sumComp) OVER (PARTITION BY m.C0,m.C1,m.C2,m.C3,m.C4,m.C5,m.C6,m.C7,m.C8,m.C11)
                / NULLIF(SUM(m.cntComp) OVER (PARTITION BY m.C0,m.C1,m.C2,m.C3,m.C4,m.C5,m.C6,m.C7,m.C8,m.C11),0) AS [Quantity Completed],
            m.C11 AS [Unit of Measure],
            m.C12 AS [Component Branch],
            m.C13 AS [Component 2nd Item Number],
            m.OrderedQty AS [Ordered Quantity],
            m.IssuedQty  AS [Issued Quantity],
            m.C14 AS [Component UOM],
            m.C15 AS [Requested Date]
        FROM
        (
            SELECT
                LTRIM(RTRIM(wo.WAMMCU))  AS C0,
                LTRIM(RTRIM(tag.IMGBLK)) AS C1,
                tag.IMBULK               AS C2,
                LTRIM(RTRIM(wo.WALITM))  AS C3,
                wo.WADOCO                AS C4,
                wo.WASRST                AS C5,
                wo.WATRDJ                AS C6,
                wo.WASTRT                AS C7,
                wo.WASTRX                AS C8,
                wo.WAUOM                 AS C11,
                wp.WMCMCU                AS C12,
                LTRIM(RTRIM(wp.WMCPIL))  AS C13,
                wp.WMUM                  AS C14,
                wp.WMDRQJ                AS C15,
                SUM(wo.WAUORG/10000.0)   AS sumReq,
                COUNT(wo.WAUORG/10000.0) AS cntReq,
                SUM(wo.WASOQS/10000.0)   AS sumComp,
                COUNT(wo.WASOQS/10000.0) AS cntComp,
                SUM(wp.WMUORG/10000.0)   AS OrderedQty,
                SUM(wp.WMTRQT/10000.0)   AS IssuedQty
            FROM
            (
                SELECT
                    WADOCO, WAMMCU, WASRST, WAITM, WALITM, WAUORG, WASOQS, WAUOM,
                    CASE WHEN WATRDJ>0 THEN DATEADD(DAY,(WATRDJ%1000)-1,DATEFROMPARTS(1900+(WATRDJ/1000),1,1)) ELSE NULL END AS WATRDJ,
                    CASE WHEN WASTRT>0 THEN DATEADD(DAY,(WASTRT%1000)-1,DATEFROMPARTS(1900+(WASTRT/1000),1,1)) ELSE NULL END AS WASTRT,
                    CASE WHEN WASTRX>0 THEN DATEADD(DAY,(WASTRX%1000)-1,DATEFROMPARTS(1900+(WASTRX/1000),1,1)) ELSE NULL END AS WASTRX
                FROM PRODDTA.F4801
            ) wo
            JOIN
            (
                SELECT
                    WMDOCO, WMCPIL, WMCMCU, WMUORG, WMTRQT, WMUM,
                    CASE WHEN WMDRQJ>0 THEN DATEADD(DAY,(WMDRQJ%1000)-1,DATEFROMPARTS(1900+(WMDRQJ/1000),1,1)) ELSE NULL END AS WMDRQJ
                FROM PRODDTA.F3111
            ) wp ON wo.WADOCO = wp.WMDOCO
            JOIN PRODDTA.F4102 ib  ON wo.WAITM = ib.IBITM AND wo.WAMMCU = ib.IBMCU
            JOIN PRODDTA.F4101 im  ON ib.IBITM = im.IMITM
            JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
            WHERE wo.WASRST NOT IN ('95','96','97','98','99','MM','CD')
              AND wo.WASTRT >= DATEADD(DAY,-30,CAST(GETDATE() AS date))
              AND (wp.WMUORG/10000.0 + wp.WMTRQT/10000.0) > 0
            GROUP BY
                LTRIM(RTRIM(wo.WAMMCU)), LTRIM(RTRIM(tag.IMGBLK)), tag.IMBULK, LTRIM(RTRIM(wo.WALITM)),
                wo.WADOCO, wo.WASRST, wo.WATRDJ, wo.WASTRT, wo.WASTRX, wo.WAUOM,
                wp.WMCMCU, LTRIM(RTRIM(wp.WMCPIL)), wp.WMUM, wp.WMDRQJ
            HAVING AVG(wo.WASOQS/10000.0) = 0
        ) m
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Branch Plant", type text}, {"Global Bulk Item", type text}, {"Bulk Item", type text},
            {"2nd Item Number", type text}, {"WO Number", Int64.Type}, {"WO Status", type text},
            {"Order Date", type date}, {"Start Date", type date}, {"Completed Date", type date},
            {"Quantity Requested", type number}, {"Quantity Completed", type number},
            {"Unit of Measure", type text}, {"Component Branch", type text},
            {"Component 2nd Item Number", type text}, {"Ordered Quantity", type number},
            {"Issued Quantity", type number}, {"Component UOM", type text}, {"Requested Date", type date}
        },
        "en-US"
    )
in
    Typed
