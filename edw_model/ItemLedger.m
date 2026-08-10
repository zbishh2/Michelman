// ItemLedger — JDE item ledger (Cardex, F4111), inventory completions only.
//
// ⚠ HOUSE RULE: RAW COLUMNS ONLY. Projection, mechanical joins, type casts and
// the window. Nothing here classifies anything. The one piece of logic that
// consumes this table — the S&OP date — is a DAX column on WorkOrders. See
// ExecutiveDashboard_Model.dax, section "BATCH DEFINITION".
//
// WHY THIS TABLE EXISTS
// The month a batch counts in is the transaction date of the earliest inventory-
// completion row in this ledger, not a date off the work order header:
//   1. The header date is MUTABLE. F4801's completion date is rewritten as the
//      work order status advances. A ledger row is an EVENT — written once when
//      material physically hit inventory, never rewritten.
//   2. It is AUDITABLE. Click a work order and see the ledger transactions behind
//      it. The header date cannot support that, and the client walkthrough needs it.
//
// ⚠ DO NOT source this from ODS PRODDTA.F4111. EDW carries the same table as
// BIQL.FactInventoryDetail (its column names still carry _F4111 suffixes). Staying
// in EDW means one source, no second credential, no JUL2DATE (TransactionDate is
// already a real date), and a WorkOrderSKey that joins straight to DimWorkOrder.
// In raw F4111 the work order is ILDOCO, NOT ILDOC — ILDOC is the completion
// document, and getting those backwards is a silent wrong join. The surrogate key
// sidesteps it entirely.
//
// DOC TYPES: IC = inventory completion (the only one wanted), IB = lot status
// change, IM = inventory material issue. The IC filter is what keeps this table at
// ~66k rows instead of the whole Cardex. "What went INTO this batch" is the IM
// rows, and answering it means widening this filter.
//
// GRAIN: one row per ledger transaction — ~66k IC rows across ~40k work orders, so
// multi-completion is the norm. Relates MANY-to-one to WorkOrders on
// WorkOrderSKey, SINGLE DIRECTION (WorkOrders filters the ledger, never the
// reverse); same shape as WorkOrderRouting. ⚠ NEVER bidirectional — a
// bidirectional relationship supplies the return edge of a circular dependency all
// by itself, with zero reverse column references, and the model then fails to OPEN
// rather than failing to lint.
//
// WINDOW: bounded by the WORK ORDER population, not by a ledger date filter. 63
// ledger rows belonging to in-window work orders carry a transaction date before
// 2024-01-01, so a ledger-side date filter would make 63 completed work orders
// look uncompleted. ⚠ The WHERE below is the same clause as WorkOrders.m — change
// one and change the other.
//
// ⚠ REVERSALS ARE NEGATIVE QUANTITY ROWS, not ReverseOrVoid, which is never
// populated. Any quantity surfaced from this table must be the NET, not the sum of
// positives. The S&OP date column in DAX takes the earliest POSITIVE row for the
// same reason — otherwise a reversal can date the batch.
//
// ⚠ EDW RUNS A CASE-SENSITIVE COLLATION: the column is [UserId], not [UserID].
// Verify identifier casing against INFORMATION_SCHEMA, not against
// edw_schema/edw_columns_current.csv, which is stale for this view. String
// PREDICATES are case-sensitive here too.
//
// ⚠ TimeOfDay is a SQL `time`. Cast it to varchar in the SQL, as below. Power
// Query turns `time` into a duration, and it is the one type that cannot
// round-trip into the local SQL mirror (see CLAUDE.md §9 trap 8). A string is
// display-only, which is all it is for.
let
    Source = Sql.Database(
        "EDWPROD",
        "EDW",
        [
            Query = "
SELECT
    il.WorkOrderSKey,
    il.OrderNum                                    AS [WO Number],
    LTRIM(RTRIM(il.DocumentType))                  AS [Doc Type],
    il.DocumentNum                                 AS [Doc Num],
    il.TransactionDate                             AS [Transaction Date],
    il.GLDate                                      AS [GL Date],
    il.CreatedDate                                 AS [Created Date],
    CONVERT(varchar(8), il.TimeOfDay, 108)         AS [Time Of Day],
    il.QuantityTransactionUOM                      AS [Qty Transaction],
    LTRIM(RTRIM(il.UOMTransaction))                AS [UOM Transaction],
    il.QuantityPrimaryUOM                          AS [Qty Primary],
    LTRIM(RTRIM(il.UOMPrimary))                    AS [UOM Primary],
    LTRIM(RTRIM(il.Branch))                        AS [Branch Plant],
    LTRIM(RTRIM(il.Location))                      AS [Location],
    LTRIM(RTRIM(il.LotNum_F4111))                  AS [Lot Num],
    LTRIM(RTRIM(il.Explanation))                   AS [Explanation],
    LTRIM(RTRIM(il.UserId))                        AS [User ID],
    LTRIM(RTRIM(il.ProgramID))                     AS [Program ID],
    il.TransactionLineNum                          AS [Transaction Line Num],
    il.UniqueKeyID                                 AS [Unique Key ID]
FROM       BIQL.FactInventoryDetail il WITH (NOLOCK)
INNER JOIN BIQL.DimWorkOrder        wo WITH (NOLOCK)
       ON  wo.WorkOrderSKey = il.WorkOrderSKey
WHERE      il.DocumentType = 'IC'
  AND      (wo.CompletionDate >= '2024-01-01' OR wo.RequestedDate >= '2024-01-01')
",
            CreateNavigationProperties = false
        ]
    ),
    Typed = Table.TransformColumnTypes(
        Source,
        {
            {"WorkOrderSKey",         Int64.Type},
            // text, NOT Int64 — a number renders with thousands separators and
            // invites summing
            {"WO Number",             type text},
            {"Doc Type",              type text},
            {"Doc Num",               Int64.Type},
            {"Transaction Date",      type date},
            {"GL Date",               type date},
            {"Created Date",          type date},
            {"Time Of Day",           type text},
            {"Qty Transaction",       type number},
            {"UOM Transaction",       type text},
            {"Qty Primary",           type number},
            {"UOM Primary",           type text},
            {"Branch Plant",          type text},
            {"Location",              type text},
            {"Lot Num",               type text},
            {"Explanation",           type text},
            {"User ID",               type text},
            {"Program ID",            type text},
            {"Transaction Line Num",  type number},
            {"Unique Key ID",         type number}
        }
    )
in
    Typed
