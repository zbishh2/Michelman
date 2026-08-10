// ============================================================================
// Report 03 - CM Sales Orders < 560 (Not Enough Inventory to Ship)
// QUERY: WorkOrder_Detail  ->  the WORK-ORDER detail (RIGHT block of the
//        master-detail panel). Cognos query object "Work Orders" (raw block C,
//        with the per-item window count/sum).
//
// Columns (rendered, right block): Item | Plant | WO # | Start | Requested |
//        Qty | Lot# | Status   (+ Bulk carried, not shown)
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//   Flat SELECT, no WITH/CTE, no ORDER BY (sort in the visual). See BUILD.md.
//
// LOGIC (faithful to Cognos "Work Orders"):
//   Open manufacturing work orders (F4801) in the Cincinnati plants whose WO status
//   is one of the active codes and whose REQUESTED date lands within the next 31
//   days. WALITM (2nd item number) JOINS this block to the sales orders. Item Tag /
//   Item Master supply the Bulk flag. NOT whitelist-filtered on item -- like Cognos,
//   left wide open; the PBI relationship to the SO list picks the relevant items.
//   The per-item SUM(Qty Requested) window feeds the group-footer subtotal.
//
// ORACLE -> T-SQL conversions:
//   PRODDTA.JUL2DATE(x) -> CASE WHEN x>0 THEN DATEADD(DAY,(x%1000)-1,
//                          DATEFROMPARTS(1900+(x/1000),1,1)) END      (JDE CYYDDD)
//   sysdate+31          -> DATEADD(DAY,31,CAST(GETDATE() AS date))    (flat +31 CAL days)
//   trim(both from x)   -> LTRIM(RTRIM(x));   x/10000 -> x/10000.0 (drop the numeric trim)
//
// QUIRK: Cognos "CALC_DAYS_FORWARD" (returns 5/5/4/3 by weekday) is VESTIGIAL --
//   computed but never referenced by a filter. The real look-ahead is the flat
//   sysdate+31 on the requested date. Omitted here.
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            LTRIM(RTRIM(wo.WALITM))                                  AS [Item],
            LTRIM(RTRIM(wo.WAMMCU))                                  AS [Plant],
            wo.WADOCO                                                AS [WO#],
            (CASE WHEN wo.WASTRT > 0
                  THEN DATEADD(DAY, (wo.WASTRT % 1000) - 1, DATEFROMPARTS(1900 + (wo.WASTRT / 1000), 1, 1))
             END)                                                    AS [Start],
            (CASE WHEN wo.WADRQJ > 0
                  THEN DATEADD(DAY, (wo.WADRQJ % 1000) - 1, DATEFROMPARTS(1900 + (wo.WADRQJ / 1000), 1, 1))
             END)                                                    AS [Requested],
            wo.WAUORG / 10000.0                                      AS [Qty],
            LTRIM(RTRIM(wo.WALOTN))                                  AS [Lot#],
            wo.WASRST                                                AS [Status],
            LTRIM(RTRIM(tag.IMBULK))                                 AS [Bulk],
            SUM(wo.WAUORG / 10000.0)
                OVER (PARTITION BY LTRIM(RTRIM(wo.WALITM)))          AS [Qty Requested Per Item]
        FROM PRODDTA.F4801 wo
        INNER JOIN PRODDTA.F4102 ib   ON wo.WAITM = ib.IBITM AND wo.WAMMCU = ib.IBMCU
        INNER JOIN PRODDTA.F4101 im   ON ib.IBITM = im.IMITM
        INNER JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
        WHERE wo.WASRST IN ('20','30','32','35','40','45','50','90')
          AND wo.WAUORG / 10000.0 > 0
          AND (CASE WHEN wo.WADRQJ > 0
                    THEN DATEADD(DAY, (wo.WADRQJ % 1000) - 1, DATEFROMPARTS(1900 + (wo.WADRQJ / 1000), 1, 1))
               END) <= DATEADD(DAY, 31, CAST(GETDATE() AS date))
          AND LTRIM(RTRIM(wo.WAMMCU)) IN ('CINC','CIN2','CIN4')
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Item", type text},
            {"Plant", type text},
            {"WO#", Int64.Type},
            {"Start", type date},
            {"Requested", type date},
            {"Qty", type number},
            {"Lot#", type text},
            {"Status", type text},
            {"Bulk", type text},
            {"Qty Requested Per Item", type number}
        }
    )
in
    Typed
