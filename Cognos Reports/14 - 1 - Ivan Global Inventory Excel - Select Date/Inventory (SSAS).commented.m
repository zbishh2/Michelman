// Commented master. The production copy of this query lives in the SSAS Import
// PBIP's SemanticModel and ships comment-free; the two are otherwise identical.
//
// Page 1 (Summary matrix) and page 2 (Inventory Data). One row per inventory
// position: snapshot date x branch plant x item x location x lot.
//
// Source is BIQLTabular_ISH on SSASPROD, the production inventory-history model.
// The query is native DAX so SSAS applies the row-eligibility predicates before
// transfer; interactive filtering (the Select Date slicer) stays in Power BI.
let
    // AnalysisServices.Database with a Query record issues the DAX verbatim.
    Raw = AnalysisServices.Database(
        "SSASPROD",
        "BIQLTabular_ISH",
        [
            Query = "
// Every snapshot date the model retains is imported. The report's date picker
// is a slicer over these rows, not a query predicate.
EVALUATE
SELECTCOLUMNS (
    FILTER (
        'Inventory Snapshot',
        // The fact carries one row per JDE cost method, so omitting this multiplies
        // every quantity. 07 is Standard cost, the report's basis.
        //
        // The alternative predicate is CostingSelectionInventory = "I", the flag for
        // whichever method the item elects. The two return identical results here --
        // same rows, same quantity, same cost -- because AmountValueAtCost carries the
        // elected value on every cost-method row rather than that row's own method.
        // 07 is the explicit basis and the one the report names.
        TRIM ( 'Inventory Snapshot'[CostMethod] ) = ""07""
            // Positions with no stock on hand are not inventory.
            && 'Inventory Snapshot'[QuantityOnHandPrimaryUOM] > 0
            // The nine reporting plants.
            && TRIM ( RELATED ( 'Branch'[Branch Plant] ) ) IN { ""CINC"", ""CIN2"", ""CIN4"", ""AUBA"", ""AUB2"", ""SING"", ""SNG4"", ""MUM3"", ""SHAN"" }
            // The fourteen packaged-goods planning families. Master Planning Family is read
            // at item-branch grain, which is the grain the position lives at.
            && TRIM ( RELATED ( 'Item Branch'[Master Planning Family] ) )
                IN { ""ATP"", ""ETP"", ""FBW"", ""FCB"", ""FEC"", ""FRC"", ""RAW"",
                    ""RBW"", ""RCB"", ""REC"", ""RRC"", ""RWW"", ""TOL"", ""WAG"" }
    ),
    ""Inventory Date"", 'Inventory Snapshot'[Calendar Date],
    // Branch plant decoded to the five reporting regions. This is the only value
    // derived in the report rather than read from the cube.
    ""REGION"", SWITCH (
            TRIM ( RELATED ( 'Branch'[Branch Plant] ) ),
            ""CINC"", ""Americas"",
            ""CIN2"", ""Americas"",
            ""CIN4"", ""Americas"",
            ""AUBA"", ""Aubange"",
            ""AUB2"", ""Aubange"",
            ""SING"", ""Singapore"",
            ""SNG4"", ""Singapore"",
            ""MUM3"", ""India"",
            ""SHAN"", ""China"",
            ""ERROR""
        ),
    ""Branch Plant"", TRIM ( RELATED ( 'Branch'[Branch Plant] ) ),
    // Bulk and global-bulk identity from the F554101 pair.
    ""Global Bulk Item"", TRIM ( RELATED ( 'Item Branch'[Item Num Global Bulk] ) ),
    ""Bulk Item"", TRIM ( RELATED ( 'Item Branch'[Item Num Bulk] ) ),
    ""2nd Item Number"", TRIM ( RELATED ( 'Item Branch'[Item Num 2nd] ) ),
    ""Stock Type Code"", TRIM ( RELATED ( 'Item Branch'[Stocking Type] ) ),
    // GL class is the position's own F41021 class, not the item's.
    ""GL Class Code"", TRIM ( 'Inventory Snapshot'[CategoryGLF41021] ),
    ""Location"", TRIM ( 'Inventory Snapshot'[Location] ),
    ""Lot Number"", TRIM ( 'Inventory Snapshot'[LotNum] ),
    ""Supplier Lot Number"", TRIM ( RELATED ( 'Lot'[Supplier Lot Num] ) ),
    // Position-level lot status. The Escor page reads the lot master instead.
    ""Lot Status"", TRIM ( 'Inventory Snapshot'[Lot Status Code] ),
    ""Master Planning Family"", TRIM ( RELATED ( 'Item Branch'[Master Planning Family] ) ),
    ""On Hand"", 'Inventory Snapshot'[QuantityOnHandPrimaryUOM],
    ""UOM"", TRIM ( 'Inventory Snapshot'[UOMPrimary] ),
    // The model's own weight and cost measures, evaluated at the position row.
    // CALCULATE converts the row into a filter context so each measure returns the
    // value for that single position.
    ""OH KGs"", CALCULATE ( [Qty On Hand KG] ),
    ""OH LBs"", CALCULATE ( [Qty On Hand LB] ),
    // USD comes from the cube's own measure so every report carries one number. The
    // measure reads 'Selected UOM Filter', and both its unit cost and its quantity
    // scale by the UOM conversion rate, so extended cost carries that rate squared —
    // Primary makes the rate 1. The cube's default is LB, so an unpinned query reads
    // $536.3M against a true $40.08M. The + 0 is parity: 74 of the 4,286 positions
    // carry quantity at zero cost, where the measure returns BLANK and Cognos prints 0.
    //
    // EUR has no cube route — every costed measure returns blank under
    // 'Selected Currency Filter' = EUR, and there is no EUR-named cost measure. So EUR
    // reads the column: AmountValueAtCost is quantity at the elected cost, already
    // extended and already in the position's local currency, needing only the currency
    // carry. Currency Rates holds the local-to-EUR leg on CurrencyBSKey, keyed per day,
    // so the conversion is a single hop with no triangulation.
    //
    // LOOKUPVALUE rather than RELATED because the cube's currency relationships are
    // inactive: a relationship-based read returns the other currency's rate, silently.
    // CurrencySKey is unique across all 191,751 rate rows, so the lookup is
    // unambiguous.
    ""OH USD"",
        CALCULATE (
            [Total Ext Cost IC USD],
            'Selected UOM Filter'[Selected UOM Code] = 1
        ) + 0,
    ""OH EUR"",
        'Inventory Snapshot'[AmountValueAtCost]
            * LOOKUPVALUE (
                'Currency Rates'[ToRateDaily],
                'Currency Rates'[CurrencySKey], 'Inventory Snapshot'[CurrencyBSKey]
            ),
    ""On Hand Date"", RELATED ( 'Lot'[On Hand Date] ),
    ""Lot Expiry Date"", RELATED ( 'Lot'[Lot Expiration Date] ),
    ""Memo Lot 1"", RELATED ( 'Lot'[Memo Lot 1] ),
    ""Memo Lot 2"", RELATED ( 'Lot'[Memo Lot 2] ),
    ""Commodity Class Description"", RELATED ( 'Item Branch'[Commodity Class Codes Desc] ),
    ""Commodity Sub Class Description"", RELATED ( 'Item Branch'[Commodity Sub Class Codes Desc] ),
    // The F4102 bulk pair, imported hidden so the two lineages can be compared.
    ""Global Bulk Item (F4102)"", TRIM ( RELATED ( 'Item Branch'[Item Global Bulk] ) ),
    ""Bulk Item (F4102)"", TRIM ( RELATED ( 'Item Branch'[Item Bulk] ) )
)
// Cognos list order.
ORDER BY [REGION], [Global Bulk Item], [Bulk Item], [2nd Item Number]
"
        ]
    ),
    // DAX returns column names wrapped in square brackets; this strips them so the
    // loaded names match the SELECTCOLUMNS labels.
    Data = Table.TransformColumnNames(
        Raw,
        each if Text.StartsWith(_, "[") and Text.EndsWith(_, "]")
            then Text.Middle(_, 1, Text.Length(_) - 2)
            else _
    )
in
    Data
