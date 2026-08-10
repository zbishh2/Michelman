// ============================================================================
// Report 13 - 1 - Ivan LIVE Global Inventory Excel   (page 4 of 6: "Work Order")
// QUERY: Work Orders  ->  Cognos list "List4", query object "Work Orders"
// SOURCE SQL: "Work Orders.3.sql"
//
// Columns (RENDERED order, 12 - headers verbatim):
//   Branch Plant | Global Bulk Item | Bulk Item | 2nd Item Number | WO Number |
//   WO Status | Order Date | Start Date | Completed Date | Quantity Requested |
//   Quantity Completed | Unit of Measure
//
// SOURCE: ODSPROD / "ODS" / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//
// LOGIC (faithful to "Work Orders.3.sql"): F4801 work-order header joined to the item
//   dimension (F4102/F4101/F554101, all 1:1 per item so no fan-out), grouped to the
//   WO grain. Filters: WO Status NOT IN ('95','96','97','98','99','MM','CD'),
//   Start Date >= today-30, HAVING avg(Quantity Completed)=0 (open, unstarted WOs).
//   Quantity Requested = AVG(WAUORG/10000); Quantity Completed = AVG(WASOQS/10000).
//
// SIMPLIFICATION vs the generated SQL: Cognos wraps the grouped averages in a
//   redundant first_value(...) OVER (PARTITION BY <same grain>). Because the inner
//   GROUP BY already yields exactly one row per partition, first_value == that value,
//   so the window is dropped and the AVG selected directly. (T-SQL FIRST_VALUE would
//   also require an ORDER BY that Cognos omits.) Result rows are identical.
//
// PARITY DETAIL: Bulk Item here is tag.IMBULK WITHOUT trim (the generated SQL does not
//   trim IMBULK on the WO/WOPL queries, unlike the Inv/PO/Sales queries). Kept as-is.
//
// Oracle -> T-SQL: trim(both from x) -> LTRIM(RTRIM(x)); JUL2DATE guarded by >0 ->
//   CASE WHEN x>0 THEN DATEADD(DAY,(x%1000)-1,DATEFROMPARTS(1900+(x/1000),1,1)) ELSE NULL END;
//   x/10000 -> x/10000.0; to_date(sysdate)-30 -> DATEADD(DAY,-30,CAST(GETDATE() AS date));
//   no ORDER BY (folded). Cognos sort: Global Bulk Item, Bulk Item, 2nd Item Number,
//   Start Date -> set in the visual. WO Number -> summarizeBy:none. See BUILD.md.
// Expected rows to xlsx "Work Order_4": 460 (as-of capture; live counts drift).
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            LTRIM(RTRIM(wo.WAMMCU))     AS [Branch Plant],
            LTRIM(RTRIM(tag.IMGBLK))    AS [Global Bulk Item],
            tag.IMBULK                  AS [Bulk Item],
            LTRIM(RTRIM(wo.WALITM))     AS [2nd Item Number],
            wo.WADOCO                   AS [WO Number],
            wo.WASRST                   AS [WO Status],
            wo.WATRDJ                   AS [Order Date],
            wo.WASTRT                   AS [Start Date],
            wo.WASTRX                   AS [Completed Date],
            AVG(wo.WAUORG/10000.0)      AS [Quantity Requested],
            AVG(wo.WASOQS/10000.0)      AS [Quantity Completed],
            wo.WAUOM                    AS [Unit of Measure]
        FROM
        (
            SELECT
                WADOCO, WAMMCU, WASRST, WAITM, WALITM, WAUORG, WASOQS, WAUOM,
                CASE WHEN WATRDJ>0 THEN DATEADD(DAY,(WATRDJ%1000)-1,DATEFROMPARTS(1900+(WATRDJ/1000),1,1)) ELSE NULL END AS WATRDJ,
                CASE WHEN WASTRT>0 THEN DATEADD(DAY,(WASTRT%1000)-1,DATEFROMPARTS(1900+(WASTRT/1000),1,1)) ELSE NULL END AS WASTRT,
                CASE WHEN WASTRX>0 THEN DATEADD(DAY,(WASTRX%1000)-1,DATEFROMPARTS(1900+(WASTRX/1000),1,1)) ELSE NULL END AS WASTRX
            FROM PRODDTA.F4801
        ) wo
        JOIN PRODDTA.F4102 ib  ON wo.WAITM = ib.IBITM AND wo.WAMMCU = ib.IBMCU
        JOIN PRODDTA.F4101 im  ON ib.IBITM = im.IMITM
        JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
        WHERE wo.WASRST NOT IN ('95','96','97','98','99','MM','CD')
          AND wo.WASTRT >= DATEADD(DAY,-30,CAST(GETDATE() AS date))
        GROUP BY
            LTRIM(RTRIM(wo.WAMMCU)), LTRIM(RTRIM(tag.IMGBLK)), tag.IMBULK, LTRIM(RTRIM(wo.WALITM)),
            wo.WADOCO, wo.WASRST, wo.WATRDJ, wo.WASTRT, wo.WASTRX, wo.WAUOM
        HAVING AVG(wo.WASOQS/10000.0) = 0
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
            {"Unit of Measure", type text}
        },
        "en-US"
    )
in
    Typed
