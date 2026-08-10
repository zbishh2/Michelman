// ============================================================================
// Report 12 - Americas - Open Purchase Orders  |  PAGE 1 : "PO Static"
// SSAS-SOURCED VARIANT (team semantic model BIQLTabular_v2). Twin of PO.m (ODS).
// IMPORT via one DAX EVALUATE (AnalysisServices.Database); cube relationships
// supply every join. Validated round 1 (2026-07-22 tight capture, BUILD.md sec 12):
// 3,764/3,764 keys tie; fixes below came out of that round.
//
// VALIDATION-DRIVEN RULES (all from the 2026-07-22 Cognos compare):
//   Purchase Amount USD = AmountExtendedPrice, NOT AmountOpen - Cognos's
//     PURCHASE_AMOUNT is literally the same field as SPEND_AMOUNT (identical in
//     all 3,764 export rows). Both columns project [@Spend].
//   Quantity Cancelled  = OrderedLB - OpenLB - ReceivedLB, gated on Cancel Date
//     (F4311 explicit cancel). Ungated, 332 closed-short lines (received < ordered,
//     no cancel) over-flag; Cognos calls those 0. LB basis proven by ratio tails
//     (non-LB lines were off by exactly the container factor when unit-based).
//   PO Quantity Ordered LBs = QuantityOrderedLB - cancelled LB (Cognos nets
//     cancels out of ordered; fully-cancelled lines show 0).
//   Spend/Purchase zeroing: fully-cancelled lines (cancel date set, nothing open
//     or received) show 0 in Cognos, not the extended price.
//   Unknown-item zeroing: lines with no item (cube member "??????", Cognos
//     "Not Applicable") get 0 in every LB column; label mapped to Cognos's text.
// KNOWN RESIDUALS (accepted, see BUILD.md sec 12): 4 rows where the DW claims a
//   cancel F4311 doesn't show (e.g. PO 103151); 16 rows where LastReceivedDate
//   differs from DW PO_DETAIL_CLOSED_DATE (no closed-date col in the cube);
//   Cognos renders null Receipt Date as 1900-01-01, we render blank.
// FILTERS: Promised (Scheduled Pick) >= today-365 ; Branch CINC/CIN2/CIN4 ; type OP/OD.
// ============================================================================
let
    Source = AnalysisServices.Database(
        "SSASPROD",
        "BIQLTabular_v2",
        [Query = "
        EVALUATE
        SELECTCOLUMNS(
            SUMMARIZECOLUMNS(
                'Branch'[Branch Plant],
                'Purchase Order Detail'[Order Num],
                'Purchase Order Detail'[Line Num],
                'Item Branch'[Item Num 2nd],
                'Purchase Order Detail'[Order Date],
                'Purchase Order Detail'[Requested Date],
                'Purchase Order Detail'[Scheduled Pick Date],
                'Purchase Order Detail'[LastReceivedDate],
                'Purchase Order Detail'[Address Num PO],
                'Purchase Order Detail'[Vendor Name],
                'Item Branch'[Lead time Level],
                FILTER(ALL('Purchase Order Detail'[Scheduled Pick Date]), 'Purchase Order Detail'[Scheduled Pick Date] >= TODAY() - 365),
                FILTER(ALL('Branch'[Branch Plant]), 'Branch'[Branch Plant] IN {""CINC"", ""CIN2"", ""CIN4""}),
                FILTER(ALL('Purchase Order Detail'[Order Type]), 'Purchase Order Detail'[Order Type] IN {""OP"", ""OD""}),
                ""@Ord"", SUM('Purchase Order Detail'[QuantityOrdered]),
                ""@Open"", SUM('Purchase Order Detail'[QuantityOpen]),
                ""@Rec"", SUM('Purchase Order Detail'[QuantityReceived]),
                ""@OrdLB"", SUM('Purchase Order Detail'[QuantityOrderedLB]),
                ""@OpenLB"", SUM('Purchase Order Detail'[QuantityOpenLB]),
                ""@CxlU"", IF(NOT ISBLANK(MAX('Purchase Order Detail'[Cancel Date])), SUM('Purchase Order Detail'[QuantityOrdered]) - SUM('Purchase Order Detail'[QuantityOpen]) - SUM('Purchase Order Detail'[QuantityReceived]), 0),
                ""@CxlLB"", IF(NOT ISBLANK(MAX('Purchase Order Detail'[Cancel Date])), SUM('Purchase Order Detail'[QuantityOrderedLB]) - SUM('Purchase Order Detail'[QuantityOpenLB]) - SUM('Purchase Order Detail'[QuantityReceivedLB]), 0),
                ""@Spend"", SUM('Purchase Order Detail'[AmountExtendedPrice])
            ),
            ""Branch Plant"", 'Branch'[Branch Plant],
            ""PO Number"", 'Purchase Order Detail'[Order Num],
            ""Line Number"", 'Purchase Order Detail'[Line Num],
            ""2nd Item Number"", IF(ISBLANK('Item Branch'[Item Num 2nd]) || 'Item Branch'[Item Num 2nd] = ""??????"", ""Not Applicable"", 'Item Branch'[Item Num 2nd]),
            ""PO Date"", 'Purchase Order Detail'[Order Date],
            ""Requested Date"", 'Purchase Order Detail'[Requested Date],
            ""Promised Date"", 'Purchase Order Detail'[Scheduled Pick Date],
            ""Receipt Date"", 'Purchase Order Detail'[LastReceivedDate],
            ""Vendor ID"", 'Purchase Order Detail'[Address Num PO],
            ""Vendor Name"", 'Purchase Order Detail'[Vendor Name],
            ""Lead Time Level"", 'Item Branch'[Lead time Level],
            ""Quantity Cancelled"", IF(ISBLANK('Item Branch'[Item Num 2nd]) || 'Item Branch'[Item Num 2nd] = ""??????"", 0, [@CxlLB]),
            ""PO Quantity Ordered LBs"", IF(ISBLANK('Item Branch'[Item Num 2nd]) || 'Item Branch'[Item Num 2nd] = ""??????"", 0, [@OrdLB] - [@CxlLB]),
            ""Open Quantity"", [@Open],
            ""Open Quantity LBs"", IF(ISBLANK('Item Branch'[Item Num 2nd]) || 'Item Branch'[Item Num 2nd] = ""??????"", 0, [@OpenLB]),
            ""Spend Amount USD"", IF([@CxlU] > 0 && [@Open] + [@Rec] <= 0, 0, [@Spend]),
            ""Purchase Amount USD"", IF([@CxlU] > 0 && [@Open] + [@Rec] <= 0, 0, [@Spend])
        )
        ", Implementation = "2.0"]
    ),
    Renamed = Table.TransformColumnNames(
        Source,
        each if Text.StartsWith(_, "[") then Text.BetweenDelimiters(_, "[", "]") else _
    ),
    Typed = Table.TransformColumnTypes(
        Renamed,
        {
            {"Branch Plant", type text},
            {"PO Number", Int64.Type},
            {"Line Number", type number},
            {"2nd Item Number", type text},
            {"PO Date", type date},
            {"Requested Date", type date},
            {"Promised Date", type date},
            {"Receipt Date", type date},
            {"Vendor ID", Int64.Type},
            {"Vendor Name", type text},
            {"Lead Time Level", Int64.Type},
            {"Quantity Cancelled", type number},
            {"PO Quantity Ordered LBs", type number},
            {"Open Quantity", type number},
            {"Open Quantity LBs", type number},
            {"Spend Amount USD", type number},
            {"Purchase Amount USD", type number}
        },
        "en-US"
    )
in
    Typed
