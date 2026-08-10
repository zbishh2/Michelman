// WorkOrders — JDE work order header; the batch denominator behind RTFT.
//
// ⚠ HOUSE RULE: THIS QUERY PROJECTS RAW COLUMNS ONLY. No CASE expressions, no
// derived flags, no business rules. Allowed: column projection, joins, type casts,
// and the date window. Anything that encodes a business decision is a DAX column or
// measure on WorkOrders, where it can be clicked on, traced and shown to the team —
// see edw_model/ExecutiveDashboard_Model.dax, "S&OP BATCH DEFINITION".
//
// SOURCE: EDWPROD / EDW / BIQL.DimWorkOrder (508,041 rows) -> JDE F4801 (WADOCO is
// the work order number behind WorkOrderSKey). The JDE feed on EDWPROD is current
// (through 2026); only the Salesforce chain is frozen there, which is why
// Complaints.m points at EDWDEV and this does not.
//
// ⚠ NOT BIQL.TbWorkOrderDetail, and this is not a free choice. TbWorkOrderDetail
// contains EXACT DUPLICATE ROWS (508,048 rows for 508,041 distinct WorkOrderSKey;
// the duplicates are byte-identical, so it is a double-load in the source, not a real
// grain). Power BI rejects it outright:
//     "Column 'WorkOrderSKey' in Table 'WorkOrders' contains a duplicate value
//      '506995' and this is not allowed for columns on the one side of a
//      many-to-one relationship"
// which is exactly what the WorkOrderRouting relationship needs. DimWorkOrder is
// unique, carries every column used here, and the key SETS are identical in both
// directions — so this is equivalence, not a compromise, and it needs no DISTINCT or
// ROW_NUMBER dedup. SSAS's own [WO Count] reads TbWorkOrderDetail, but it is a
// DISTINCTCOUNT, so the duplicates were invisible to it.
//
// GRAIN: exactly one row per work order, and it has to be — WorkOrders is the ONE
// side of the relationships to WorkOrderRouting, WO Parts List and Item Ledger.
//
// CONNECTION: native query (Sql.Database with [Query=...]), same pattern as Orders.m,
// so it folds and binds to the shared on-prem data gateway for scheduled refresh in
// the Service. SERVER is the short name "EDWPROD" to match the gateway's registered
// data source string. Gateway creds: Windows auth, UPN "ZackB@michem.com" (NOT the
// michelman.com mail address, NOT "Zack.bishop" — the AD account is ZackB and the AD
// domain is michem.com).
//
// REGION: the work-order fact is all surrogate keys, with no branch or company text,
// so the query walks BranchSKey -> BIQL.TbBranch (F0006) -> CompanySKey ->
// BIQL.TbCompany (F0010) and projects [Order Company]. That is deliberately the SAME
// column name and the same 10/20/30/34/35 domain FactSalesDetail[Order Company]
// carries, so the model-side Region calc column is a byte-for-byte copy of
// FactSalesDetail[Region] — one mapping, two facts. ⚠ If a company outside
// {10,20,30,34,35} ever appears with real volume, extend the SWITCH in BOTH places.
//
// DATE BASIS: three dates are projected, none of them the live one.
//   [Order Date]      — the client's SSAS [WO Count] default; kept as an INACTIVE
//                       DateTable relationship.
//   [Completion Date] — F4801 completion. ⚠ MUTABLE: JDE rewrites it as the work
//                       order status advances from 93 through 99.
//   [Requested Date]  — F4801 requested completion.
// The live S&OP date is [Completion Date (SOP Basis)], a DAX column sourced from the
// ITEM LEDGER (ItemLedger.m) — an event written once, not a mutable header field.
//
// WINDOW: CompletionDate >= 2024-01-01 OR RequestedDate >= 2024-01-01, matching
// Orders.m's GLDate floor and the dev complaint coverage. Keeping numerator and
// denominator on the same window matters: an unbounded denominator against a
// 2024-floored numerator quietly inflates RTFT toward 100%.
// ⚠ WINDOWING ON [Order Date] ALONE IS A DEFECT. We measure on the completion basis,
// so an order-date window silently drops every work order ordered in 2023 and
// completed in 2024 — they are never loaded at all. Consequence of the OR: some work
// orders carry junk requested dates (2101-07-10 and similar), so a tail of 2016-era
// orders comes in. They fail every batch test and cost nothing.
// ⚠ ItemLedger.m and WOPartsList.m carry the same clause. Change one, change them all.
//
// BULK / PACKED ITEM: [Item Bulk] and [Item Global Bulk] are JDE's own bulk-parent
// pointers off BIQL.TbItemBranch ([Item Bulk] equals the item itself for a bulk item).
// The shipped batch rule uses the client's own test instead — WO_2ND_ITEM NOT LIKE
// '%-%' — because that is what their Cognos report does; the hyphen suffixes are pack
// codes (-PL pail, -TO/-T2/-T3 tote, -QT quart, ...). Roughly half of all JDE work
// orders are packaging runs (item ME91735.S-TL packs bulk ME91735.S), and excluding
// them is what "batches" means.
// ⚠ DO NOT CONFLATE the two meanings of '-'. In GLOBAL_BULK_ITEM a lone '-' is a JDE
// sentinel meaning "no bulk item" — that is what Cognos's
// decode(GLOBAL_BULK_ITEM,'-',ITEM_NUMBER_2ND,GLOBAL_BULK_ITEM) tests (see Orders.m).
// It is a whole-field value, not a character inside an item number.
//
// PRODUCT STATUS: three candidates are projected because "product status" was never
// pinned down — [Stocking Type] / [Stocking Type Desc] (JDE IBSTKT, the usual
// meaning) and [Active Flag Status]. S/D are almost entirely the packed items and M/Q
// almost entirely the bulk ones, so "Stocking Type <> O" is close to a no-op once the
// bulk test is applied.
//
// ROUTING: [Type Routing] is F4801.WATRT. The domain is dominated by M (Standard
// Manufacturing Routing), with A1-A4 accounting for ~0.5%, so a routing-type filter is
// worth having for correctness but is not a meaningful driver of the count.
//
// NOT PORTED: the SSAS [WO Count] measure wraps its DISTINCTCOUNT in a
// CalendarPatternSKey filter (their multi-fiscal-calendar machinery). Our DateTable is
// plain Gregorian with a single calendar, so there is nothing to filter and the count
// is equivalent.
let
    Source = Sql.Database(
        "EDWPROD",
        "EDW",
        [
            Query = "
SELECT
    wo.WorkOrderSKey,
    wo.WorkOrderNum,
    wo.OrderDate              AS [Order Date],
    wo.CompletionDate         AS [Completion Date],
    wo.RequestedDate          AS [Requested Date],
    c.Company                 AS [Order Company],
    b.[Branch Plant]          AS [Branch Plant],
    b.[Branch Plant Desc]     AS [Branch Plant Desc],
    wo.BranchSKey,
    wo.LotSKey,
    wo.OrderDateSKey,
    wo.StartDateSKey,
    wo.CompletionDateSKey,
    wo.QuantityOrdered,
    wo.QuantityCanceledScrapped,
    wo.QuantityShipped,
    LTRIM(RTRIM(wo.TypeRouting))              AS [Type Routing],
    LTRIM(RTRIM(wo.TypeRoutingDesc))          AS [Type Routing Desc],
    LTRIM(RTRIM(wo.StatusCodeWorkOrder))      AS [WO Status],
    LTRIM(RTRIM(wo.StatusCodeWorkOrderDesc))  AS [WO Status Desc],
    LTRIM(RTRIM(ib.[Item Num 2nd]))           AS [Item Num],
    LTRIM(RTRIM(ib.[Item Num 2nd Desc]))      AS [Item Desc],
    LTRIM(RTRIM(ib.[Item Bulk]))              AS [Item Bulk],
    LTRIM(RTRIM(ib.[Item Global Bulk]))       AS [Item Global Bulk],
    LTRIM(RTRIM(ib.[Stocking Type]))          AS [Stocking Type],
    LTRIM(RTRIM(ib.[Stocking Type Desc]))     AS [Stocking Type Desc],
    LTRIM(RTRIM(ib.[Active Flag Status]))     AS [Active Flag Status]
FROM       BIQL.DimWorkOrder wo WITH (NOLOCK)
LEFT JOIN  BIQL.TbBranch     b  WITH (NOLOCK) ON b.BranchSKey      = wo.BranchSKey
LEFT JOIN  BIQL.TbCompany    c  WITH (NOLOCK) ON c.CompanySKey     = b.CompanySKey
LEFT JOIN  BIQL.TbItemBranch ib WITH (NOLOCK) ON ib.ItemBranchSKey = wo.ItemBranchSKey
WHERE      wo.CompletionDate >= '2024-01-01' OR wo.RequestedDate >= '2024-01-01'
",
            // No BIQL.TbDate join is needed: DimWorkOrder exposes OrderDate as a real
            // date, so ">= '2024-01-01'" excludes the unresolvable ones
            // (OrderDateSKey = -1 arrives as NULL) without a join to do it.
            CreateNavigationProperties = false
        ]
    ),
    Typed = Table.TransformColumnTypes(
        Source,
        {
            {"WorkOrderSKey",             Int64.Type},
            {"WorkOrderNum",              Int64.Type},
            {"Order Date",                type date},
            {"Completion Date",           type date},
            {"Requested Date",            type date},
            {"Order Company",             type text},
            {"Branch Plant",              type text},
            {"Branch Plant Desc",         type text},
            {"BranchSKey",                Int64.Type},
            {"LotSKey",                   Int64.Type},
            {"OrderDateSKey",             Int64.Type},
            {"StartDateSKey",             Int64.Type},
            {"CompletionDateSKey",        Int64.Type},
            {"QuantityOrdered",           type number},
            {"QuantityCanceledScrapped",  type number},
            {"QuantityShipped",           type number},
            {"Type Routing",              type text},
            {"Type Routing Desc",         type text},
            {"WO Status",                 type text},
            {"WO Status Desc",            type text},
            {"Item Num",                  type text},
            {"Item Desc",                 type text},
            {"Item Bulk",                 type text},
            {"Item Global Bulk",          type text},
            {"Stocking Type",             type text},
            {"Stocking Type Desc",        type text},
            {"Active Flag Status",        type text}
        }
    )
in
    Typed
