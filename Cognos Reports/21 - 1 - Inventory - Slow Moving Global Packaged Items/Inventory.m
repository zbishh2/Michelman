let
    Raw = AnalysisServices.Database(
        "SSASPROD",
        "BIQLTabular_ISH",
        [
            Query = "
EVALUATE
VAR R21InventoryDate =
    CALCULATE (
        MAX ( 'Inventory Snapshot'[Calendar Date] ),
        'Inventory Snapshot'[Calendar Date] < TODAY ()
    )
RETURN
    SELECTCOLUMNS (
        FILTER (
            'Inventory Snapshot',
            'Inventory Snapshot'[Calendar Date] = R21InventoryDate
                && TRIM ( 'Inventory Snapshot'[CostMethod] ) = ""07""
                && 'Inventory Snapshot'[QuantityOnHandPrimaryUOM] > 0
                && TRIM ( 'Inventory Snapshot'[CategoryGLF41021] ) = ""IN32""
                && TRIM ( RELATED ( 'Branch'[Branch Plant] ) )
                    IN { ""CINC"", ""CIN2"", ""CIN4"", ""AUBA"", ""AUB2"", ""SING"", ""SNG4"" }
        ),
        ""Branch Plant"", TRIM ( RELATED ( 'Branch'[Branch Plant] ) ),
        ""Global Bulk Item"", TRIM ( RELATED ( 'Item Branch'[Item Global Bulk] ) ),
        ""Bulk Item"", TRIM ( RELATED ( 'Item Branch'[Item Bulk] ) ),
        ""2nd Item Number"", TRIM ( RELATED ( 'Item Branch'[Item Num 2nd] ) ),
        ""GL Class Code"", TRIM ( 'Inventory Snapshot'[CategoryGLF41021] ),
        ""Location"", TRIM ( 'Inventory Snapshot'[Location] ),
        ""Lot Number"", TRIM ( 'Inventory Snapshot'[LotNum] ),
        ""Lot Status"", TRIM ( 'Inventory Snapshot'[Lot Status Code] ),
        ""Master Planning Family"", TRIM ( RELATED ( 'Item Branch'[Master Planning Family] ) ),
        ""Quantity on Hand"", 'Inventory Snapshot'[QuantityOnHandPrimaryUOM],
        ""Primary Unit of Measure"", TRIM ( 'Inventory Snapshot'[UOMPrimary] ),
        ""Quantity on Hand KGs"", CALCULATE ( [Qty On Hand KG] ),
        ""Quantity on Hand LBs"", CALCULATE ( [Qty On Hand LB] ),
        ""Stock Type Code"", TRIM ( RELATED ( 'Item Branch'[Stocking Type] ) ),
        ""On Hand Date"", RELATED ( 'Lot'[On Hand Date] ),
        ""Lot Expiry Date"", RELATED ( 'Lot'[Lot Expiration Date] ),
        ""Inventory Date"", 'Inventory Snapshot'[Calendar Date],
        ""DATE"", TODAY ()
    )
ORDER BY [Global Bulk Item], [Bulk Item], [2nd Item Number], [Branch Plant]
"
        ]
    ),
    Data = Table.TransformColumnNames(
        Raw,
        each if Text.StartsWith(_, "[") and Text.EndsWith(_, "]")
            then Text.Middle(_, 1, Text.Length(_) - 2)
            else _
    )
in
    Data
