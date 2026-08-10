-- =====================================================================
-- Sales Orders — EDW export (size-bounded)
-- Target: SSMS against EDW dev, schema BIQL
-- Mirrors columns in dax queries/complaints_dashboard_queries.dax (query 2/3)
-- so the SQL pull and the SSAS/DAX pull line up 1:1 for reconciliation.
--
-- Bound: GL Date >= 2025-01-01 (export-size cap, NOT a business rule).
-- Grain: order LINE (one row per Sales Order Detail line).
-- Filters: NONE applied here — pull raw detail, filter report-side / in pandas
--          (Order Type exclude-list, Record Type <> GL Detail, Cancelled_Flag=0,
--           Line Type <> FS, Order Exclude = Show). Keeps this comparable to the
--           SSAS raw export.
--
-- TbSales_Detail  = JDE F4211  (open orders)
-- TbSales_History = JDE F42119 (closed orders)
-- The SSAS [Sales] fact = both UNIONed. Start with Detail only to keep the
-- export small; uncomment the UNION block for the full population.
-- =====================================================================

SELECT
    [Order Num],
    [Order Company],
    [Order Type],
    [Order Type Desc],
    [Record Type],
    [Line Type],
    [Exclude Freight Line Types],
    [Filter - Active Order Types],
    [Cancelled_Flag],
    [Order Exclude],
    [Status Code Last],
    [GL Date],
    [Actual Ship Date]
FROM BIQL.TbSales_Detail
WHERE [GL Date] >= '2025-01-01'

-- --- Full population: include closed-order history -------------------
-- UNION ALL
-- SELECT
--     [Order Num],
--     [Order Company],
--     [Order Type],
--     [Order Type Desc],
--     [Record Type],
--     [Line Type],
--     [Exclude Freight Line Types],
--     [Filter - Active Order Types],
--     [Cancelled_Flag],
--     [Order Exclude],
--     [Status Code Last],
--     [GL Date],
--     [Actual Ship Date]
-- FROM BIQL.TbSales_History
-- WHERE [GL Date] >= '2025-01-01'
-- --------------------------------------------------------------------
ORDER BY [Order Company], [Order Num];


-- ---------------------------------------------------------------------
-- Size check first (run this before exporting, so you know what you're pulling)
-- ---------------------------------------------------------------------
-- SELECT COUNT(*) AS Lines,
--        COUNT(DISTINCT [Order Num]) AS DistinctOrders,
--        MIN([GL Date]) AS MinGL, MAX([GL Date]) AS MaxGL
-- FROM BIQL.TbSales_Detail
-- WHERE [GL Date] >= '2025-01-01';
