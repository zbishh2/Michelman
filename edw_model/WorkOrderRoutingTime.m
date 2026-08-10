// WorkOrderRoutingTime — work order routing ACTUALS at time-transaction grain.
//
// ⚠ NOT CURRENTLY IN THE MODEL. This table was removed along with the BAT
// work-centre batch definition; the query is kept because it is the only way to make
// "run machine actual hours > 0" answerable, and that filter appears in the client's
// own KPIs_WO Counts report and in ssasprod.bim. Reinstate it if the question is
// asked again.
//
// ⚠ HOUSE RULE: RAW COLUMNS ONLY. Projection, mechanical joins, type casts and the
// date window. Every test that decides anything is a DAX column or measure — see
// ExecutiveDashboard_Model.dax, section "BATCH DEFINITION".
//
// ⚠ HOURS ARE NOT A BATCH TEST. They ask whether labour got booked against an
// operation. Any hours flag built on this table belongs BESIDE the batch definition,
// never inside it: the client's own hours-based filter set run properly against this
// view gives 13,213 work orders for 2025 against a ~6,100 target, because their page
// counts work CENTRES, not batches.
//
// GRAIN: one row per time transaction (work order, operation sequence, work centre,
// shift, hours type). ~274k rows for the window below — roughly double
// WorkOrderRouting, because a single operation accrues many time records.
// ⚠ Consequence: any measure over this table that is not a DISTINCTCOUNT
// double-counts relative to WorkOrderRouting. Relates MANY-to-one to WorkOrders on
// WorkOrderSKey, single direction.
//
// SIBLING, NOT REPLACEMENT. BIQL.TbWorkOrderRouting_Routing (WorkOrderRouting.m)
// carries routing STANDARDS; this view carries hours ACTUALS, and it is the only one
// where RunMachineActual is populated (> 0 on 59,593 of 274,474 rows, against 45 of
// 141,383 on _Routing). SSAS unions the two into one 'Work Order Routing' table.
// ⚠ Keep them SEPARATE — union them and the operation grain stops being one row per
// operation.
//
// BUSINESS UNIT is joined here for the same reason as in WorkOrderRouting: so "hours
// booked AT A BULK PRODUCTION CENTRE" is separable from "hours booked anywhere".
// BIQL.TbBusinessUnit carries [Bulk Production Work Center] and [Business Unit Type].
// ⚠ NOT BIQL.TbBranch — its identically named column is blank for all four plants,
// because a branch is a plant and the flag lives on the WC-type business units.
//
// WINDOW: Order Date >= 2024-01-01, matching WorkOrders.m and WorkOrderRouting.m, so
// no side carries rows the others cannot match.
let
    Source = Sql.Database(
        "EDWPROD",
        "EDW",
        [
            Query = "
SELECT
    t.WorkOrderSKey,
    t.[Sequence Num Operations]                    AS [Operation Seq],
    t.BusinessUnitSKey,
    t.[Order Date],
    t.[Completed Date WO],
    LTRIM(RTRIM(t.[Work Center]))                  AS [Work Center],
    LTRIM(RTRIM(t.[Work Center Type]))             AS [Work Center Type],
    LTRIM(RTRIM(t.[Operation Status Code]))        AS [Operation Status Code],
    LTRIM(RTRIM(t.[Type Of Hours Desc]))           AS [Type Of Hours],
    LTRIM(RTRIM(t.[Shift Code]))                   AS [Shift Code],
    t.FirstWCFlag,
    t.MaxStatusCodeWorkOrder,
    t.RunMachineActual,
    t.RunLaborActual,
    t.SetupLaborActual,
    t.WOTimeHoursWorked,
    LTRIM(RTRIM(bu.[Business Unit]))               AS [Business Unit],
    LTRIM(RTRIM(bu.[Business Unit Type]))          AS [Business Unit Type],
    LTRIM(RTRIM(bu.[Bulk Production Work Center])) AS [Bulk Production Work Center]
FROM       BIQL.TbWorkOrderRouting_Time t  WITH (NOLOCK)
LEFT JOIN  BIQL.TbBusinessUnit          bu WITH (NOLOCK)
       ON  bu.BusinessUnitSKey = t.BusinessUnitSKey
WHERE      t.[Order Date] >= '2024-01-01'
",
            CreateNavigationProperties = false
        ]
    ),
    Typed = Table.TransformColumnTypes(
        Source,
        {
            {"WorkOrderSKey",                Int64.Type},
            {"Operation Seq",                type number},
            {"BusinessUnitSKey",             Int64.Type},
            {"Order Date",                   type date},
            {"Completed Date WO",            type date},
            {"Work Center",                  type text},
            {"Work Center Type",             type text},
            {"Operation Status Code",        type text},
            {"Type Of Hours",                type text},
            {"Shift Code",                   type text},
            {"FirstWCFlag",                  Int64.Type},
            {"MaxStatusCodeWorkOrder",       type number},
            {"RunMachineActual",             type number},
            {"RunLaborActual",               type number},
            {"SetupLaborActual",             type number},
            {"WOTimeHoursWorked",            type number},
            {"Business Unit",                type text},
            {"Business Unit Type",           type text},
            {"Bulk Production Work Center",  type text}
        }
    )
in
    Typed
