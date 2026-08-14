// Commented master. The production copy of this query lives in the SSAS Import
// PBIP's SemanticModel and ships comment-free; the two are otherwise identical.
//
// Page 3 (Escor Inventory). Same position grain as Inventory, scoped to the
// ESC5200 global bulk family and carrying the lot-master columns that page shows.
let
    // AnalysisServices.Database with a Query record issues the DAX verbatim.
    Raw = AnalysisServices.Database(
        "SSASPROD",
        "BIQLTabular_ISH",
        [
            Query = "
EVALUATE
SELECTCOLUMNS (
    FILTER (
        'Inventory Snapshot',
        // Cost method 07 is the single costing row per position.
        TRIM ( 'Inventory Snapshot'[CostMethod] ) = ""07""
            && 'Inventory Snapshot'[QuantityOnHandPrimaryUOM] > 0
            // The Escor family. The Cognos page carries no branch-plant and no
            // planning-family filter: an ESC5200 position at any plant qualifies.
            && TRIM ( RELATED ( 'Item Branch'[Item Num Global Bulk] ) ) = ""ESC5200""
    ),
    ""Inventory Date"", 'Inventory Snapshot'[Calendar Date],
    ""Branch Plant"", TRIM ( RELATED ( 'Branch'[Branch Plant] ) ),
    ""Global Bulk Item"", TRIM ( RELATED ( 'Item Branch'[Item Num Global Bulk] ) ),
    ""Bulk Item"", TRIM ( RELATED ( 'Item Branch'[Item Num Bulk] ) ),
    ""2nd Item Number"", TRIM ( RELATED ( 'Item Branch'[Item Num 2nd] ) ),
    // Receipt date is a property of the position, not the lot.
    ""Last Receipt Date"", 'Inventory Snapshot'[Last Receipt Date],
    ""Location"", TRIM ( 'Inventory Snapshot'[Location] ),
    ""Lot Number"", TRIM ( 'Inventory Snapshot'[LotNum] ),
    ""On Hand Date"", RELATED ( 'Lot'[On Hand Date] ),
    ""Lot Expiry Date"", RELATED ( 'Lot'[Lot Expiration Date] ),
    // Sell-by and the memo lots come from the lot master.
    ""Sell by Date"", RELATED ( 'Lot'[Sell By Date] ),
    ""Supplier Lot Number"", TRIM ( RELATED ( 'Lot'[Supplier Lot Num] ) ),
    ""Memo Lot 1"", RELATED ( 'Lot'[Memo Lot 1] ),
    ""Memo Lot 2"", RELATED ( 'Lot'[Memo Lot 2] ),
    // Lot-master status on this page, against position-level status on page 2.
    ""Lot Status"", TRIM ( RELATED ( 'Lot'[Lot Status Code] ) ),
    ""Master Planning Family"", TRIM ( RELATED ( 'Item Branch'[Master Planning Family] ) ),
    // Weights are the model's measures evaluated at the position row. No sentinel
    // conversion guard applies to this family.
    ""Quantity on Hand KGs"", CALCULATE ( [Qty On Hand KG] ),
    ""Quantity on Hand LBs"", CALCULATE ( [Qty On Hand LB] ),
    ""Quantity on Hand"", 'Inventory Snapshot'[QuantityOnHandPrimaryUOM],
    ""Primary Unit of Measure"", TRIM ( 'Inventory Snapshot'[UOMPrimary] )
)
// Cognos list order.
ORDER BY [Branch Plant], [Last Receipt Date]
"
        ]
    ),
    // DAX returns column names wrapped in square brackets; this strips them.
    Data = Table.TransformColumnNames(
        Raw,
        each if Text.StartsWith(_, "[") and Text.EndsWith(_, "]")
            then Text.Middle(_, 1, Text.Length(_) - 2)
            else _
    )
in
    Data
