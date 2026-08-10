// WOPartsList — JDE work order parts list (F3111), the components issued to a work
// order. One row per component line.
//
// ⚠ HOUSE RULE: RAW COLUMNS ONLY. Projection, mechanical joins, type casts and the
// window. The rename rule that consumes this table is a DAX column on WorkOrders —
// see ExecutiveDashboard_Model.dax, "BATCH DEFINITION".
//
// WHY THIS TABLE EXISTS
// It feeds the RENAME test in the batch definition. A work order is a RENAME (a
// relabel, not a real batch) when its components collapse to exactly one distinct
// (component item, lot) pair carrying an issued quantity — one thing in, one thing
// out, under a different item number. The team specified this rule to stop
// maintaining a 95-entry work centre list by hand.
//
// ⚠ THE RENAME RULE ALONE IS NOT SUFFICIENT, and the batch definition does not use
// it alone. It catches only the simplest relabels: a REPACK issues the bulk PLUS
// drums, labels and packaging — two or more pairs — so the rule reads it as real
// production. That is why [SOP Flag - Counts As Batch] pairs it with the inverted
// work-centre test. Scoreboards for each variant are in ExecutiveDashboard_Model.dax,
// "RENAME RULE".
//
// ⚠ QuantityTransaction IS the issued quantity. Do NOT use QuantityCommited — it
// holds the sentinel 99999999999.9999 on ~88% of rows, meaning "no commitment", and
// would make every work order look like a real batch.
//
// ⚠ ComponentLineNum IS ZERO ON EVERY ROW. It looks like a line sequence and is not
// one. UniqueKeyID is the only row identifier, and it must be carried into any table
// visual — a work order with four identical SH2O.S / SOFT WATER / no-lot / 0.0000
// rows otherwise COLLAPSES to one row, because a table visual groups by what it
// displays, and the team sees 11 rows where JDE shows 14. Same trap as the Sheet Row
// ordinal on the tie-out page.
//
// ⚠ 27.6% of issued rows carry no lot, so the (item, lot) key degrades to item-only
// for those. Only five work orders model-wide collapse to a single blank-lot pair
// with more than one source row, so the false-rename risk is nil.
//
// GRAIN: one row per component line — ~361k rows over ~45k work orders (155 in the
// population have no parts list at all). Relates MANY-to-one to WorkOrders on
// WorkOrderSKey, SINGLE DIRECTION. ⚠ Never bidirectional — a bidirectional
// relationship supplies the return edge of a circular dependency by itself, and the
// model then fails to OPEN rather than failing to lint.
//
// WINDOW: bounded by the WORK ORDER population, same clause as WorkOrders.m. ⚠ If
// you change one, change the other.
//
// ⚠ EDW RUNS A CASE-SENSITIVE COLLATION. Verify identifier casing against
// INFORMATION_SCHEMA, not against edw_schema/edw_columns_current.csv, which is stale.
let
    Source = Sql.Database(
        "EDWPROD",
        "EDW",
        [
            Query = "
SELECT
    p.WorkOrderSKey,
    wo.WorkOrderNum,
    p.UniqueKeyID                                            AS [Unique Key ID],
    LTRIM(RTRIM(ISNULL(p.ComponentItemNum2nd,  '')))         AS [Component Item],
    LTRIM(RTRIM(ISNULL(p.ComponentItemDesc2nd, '')))         AS [Component Desc],
    LTRIM(RTRIM(ISNULL(p.LotNum, '')))                       AS [Lot Num],
    p.QuantityOrdered                                        AS [Qty Ordered],
    p.QuantityTransaction                                    AS [Qty Issued],
    LTRIM(RTRIM(ISNULL(p.UOM, '')))                          AS [UOM],
    LTRIM(RTRIM(ISNULL(p.ComponentBranch, '')))              AS [Component Branch],
    LTRIM(RTRIM(ISNULL(p.Location, '')))                     AS [Location],
    LTRIM(RTRIM(ISNULL(p.LineType, '')))                     AS [Line Type],
    LTRIM(RTRIM(ISNULL(p.ComponentType, '')))                AS [Component Type],
    LTRIM(RTRIM(ISNULL(p.IssueTypeCode, '')))                AS [Issue Type],
    LTRIM(RTRIM(ISNULL(p.MaterialStatusCode, '')))           AS [Material Status],
    p.RequestedDate                                          AS [Requested Date]
FROM       BIQL.FactWOPartsList p  WITH (NOLOCK)
INNER JOIN BIQL.DimWorkOrder    wo WITH (NOLOCK)
       ON  wo.WorkOrderSKey = p.WorkOrderSKey
WHERE      wo.CompletionDate >= '2024-01-01' OR wo.RequestedDate >= '2024-01-01'
",
            CreateNavigationProperties = false
        ]
    ),
    Typed = Table.TransformColumnTypes(
        Source,
        {
            {"WorkOrderSKey",     Int64.Type},
            // text, NOT Int64 — a number renders with thousands separators
            {"WorkOrderNum",      type text},
            {"Unique Key ID",     type number},
            {"Component Item",    type text},
            {"Component Desc",    type text},
            {"Lot Num",           type text},
            {"Qty Ordered",       type number},
            {"Qty Issued",        type number},
            {"UOM",               type text},
            {"Component Branch",  type text},
            {"Location",          type text},
            {"Line Type",         type text},
            {"Component Type",    type text},
            {"Issue Type",        type text},
            {"Material Status",   type text},
            {"Requested Date",    type date}
        }
    )
in
    Typed
