// WorkOrderRouting — work order routing at OPERATION grain.
//
// ⚠ HOUSE RULE: RAW COLUMNS ONLY. Projection, mechanical joins, type casts and the
// date window. Every test that decides what counts as a batch is a DAX column or
// measure — see ExecutiveDashboard_Model.dax, section "BATCH DEFINITION". Nothing
// in this query classifies anything.
//
// WHY THIS TABLE EXISTS
// The batch definition rests on a WORK CENTRE test, and the work centre exists only
// in routing. The work order header has no idea whether the order was produced at a
// bulk production centre or merely repacked.
//
// GRAIN: one row per (work order, operation sequence, work centre). ~141k rows for
// the window below. Relates MANY-to-one to WorkOrders on WorkOrderSKey, single
// direction (WorkOrders filters routing, never the reverse).
//
// ⚠ _Routing ONLY, DELIBERATELY. BIQL.TbWorkOrderRouting_Time is the sibling view
// and has its own table, WorkOrderRoutingTime. _Routing carries routing STANDARDS,
// _Time carries hours ACTUALS; SSAS unions both into one 'Work Order Routing'
// table. NEVER union them here — the operation grain stops being one row per
// operation and every DISTINCTCOUNT-free measure silently doubles. The batch test
// is a work-centre attribute, which lives on _Routing.
// ⚠ RunMachineActual is near-empty on this view (> 0 on 45 of 141,383 rows) — the
// actuals are on _Time. It is kept with this warning rather than deleted.
//
// BUSINESS UNIT is the whole point of the join. BIQL.TbBusinessUnit carries
// [Bulk Production Work Center] and [Business Unit Type]; ssasprod.bim scopes its
// production measures on exactly
//     'Business Unit'[Bulk Production Work Center] = "BAT"
//     'Business Unit'[Business Unit Type]          = "WC"
// ⚠ NOT BIQL.TbBranch. TbBranch has an identically named column and it is BLANK
// for CINC / CIN2 / SING / AUBA, because a branch is a plant and the flag lives on
// the WC-type business units.
//
// WINDOW: Order Date >= 2024-01-01 OR Completed Date WO >= 2024-01-01, the
// routing-side twin of WorkOrders.m's window, so neither side carries rows the
// other cannot match. The order-date leg alone drops work orders ordered in 2023
// and completed in 2024. ⚠ If you change one of these two WHERE clauses, change
// the other.
let
    Source = Sql.Database(
        "EDWPROD",
        "EDW",
        [
            Query = "
SELECT
    r.WorkOrderSKey,
    r.[Sequence Num Operations]                    AS [Operation Seq],
    r.BusinessUnitSKey,
    r.[Order Date],
    r.[Completed Date WO],
    LTRIM(RTRIM(r.[Work Center]))                  AS [Work Center],
    LTRIM(RTRIM(r.[Work Center Type]))             AS [Work Center Type],
    LTRIM(RTRIM(r.[Type Of Routing]))              AS [Type Of Routing],
    LTRIM(RTRIM(r.[Operation Status Code]))        AS [Operation Status Code],
    r.FirstWCFlag,
    r.MaxStatusCodeWorkOrder,
    r.RunMachineStandard,
    r.RunMachineActual,
    LTRIM(RTRIM(bu.[Business Unit]))               AS [Business Unit],
    LTRIM(RTRIM(bu.[Business Unit Type]))          AS [Business Unit Type],
    LTRIM(RTRIM(bu.[Bulk Production Work Center])) AS [Bulk Production Work Center]
FROM       BIQL.TbWorkOrderRouting_Routing r  WITH (NOLOCK)
LEFT JOIN  BIQL.TbBusinessUnit             bu WITH (NOLOCK)
       ON  bu.BusinessUnitSKey = r.BusinessUnitSKey
WHERE      r.[Order Date] >= '2024-01-01' OR r.[Completed Date WO] >= '2024-01-01'
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
            {"Type Of Routing",              type text},
            {"Operation Status Code",        type text},
            {"FirstWCFlag",                  Int64.Type},
            {"MaxStatusCodeWorkOrder",       type number},
            {"RunMachineStandard",           type number},
            {"RunMachineActual",             type number},
            {"Business Unit",                type text},
            {"Business Unit Type",           type text},
            {"Bulk Production Work Center",  type text}
        }
    )
in
    Typed
