let
    Raw = AnalysisServices.Database(
        "SSASPROD",
        "BIQLTabular",
        [
            Query = "
EVALUATE
VAR R21EligibleSales =
    FILTER (
        Sales,
        TRIM ( Sales[Record Type] ) = ""Sales Detail""
            && Sales[QuantityOrderedPrimaryUOM] > 0
            && ( Sales[QuantityOrdered] - Sales[QuantityCanceledScrapped] ) > 0
            && Sales[Promised Shipment Date] >= TODAY () - 365
            && TRIM ( Sales[Line Type] ) = ""S""
            && TRIM ( Sales[Order Type] ) <> ""ST""
            && TRIM ( Sales[BusinessUnit] ) IN { ""CINC"", ""CIN2"", ""AUBA"", ""AUB2"", ""SING"", ""SNG4"" }
            && TRIM ( RELATED ( 'Item Branch'[Category GL F4101] ) ) = ""IN32""
            && VAR GlobalBulk = TRIM ( RELATED ( 'Item Branch'[Item Global Bulk] ) )
               VAR EffectiveItem =
                    IF (
                        ISBLANK ( GlobalBulk ) || GlobalBulk IN { """", ""-"" },
                        TRIM ( Sales[Item Num 2nd] ),
                        GlobalBulk
                    )
               RETURN NOT EffectiveItem IN { ""IGST"", ""CGST"", ""SGST"", ""CVD"", ""ADD"" }
    )
RETURN
    SELECTCOLUMNS (
        R21EligibleSales,
        ""Order Company"", TRIM ( Sales[Order Company] ),
        ""Branch Plant"", TRIM ( Sales[BusinessUnit] ),
        ""Global Bulk Item"", TRIM ( RELATED ( 'Item Branch'[Item Global Bulk] ) ),
        ""Bulk Item"", TRIM ( RELATED ( 'Item Branch'[Item Bulk] ) ),
        ""2nd Item Number"", TRIM ( Sales[Item Num 2nd] ),
        ""Order Number"", FORMAT ( Sales[Order Num], ""0"" ),
        ""Line Number"",
            VAR R21LineNumber = Sales[Line Num]
            RETURN
                IF (
                    R21LineNumber = INT ( R21LineNumber ),
                    FORMAT ( R21LineNumber, ""0"" ),
                    FORMAT ( R21LineNumber, ""0.###"" )
                ),
        ""Last Status"", TRIM ( Sales[Status Code Last] ),
        ""Next Status"", TRIM ( Sales[Status Code Next] ),
        ""Open Indicator"", TRIM ( Sales[Open Order Flag] ),
        ""Promised Ship Date"", Sales[Promised Shipment Date],
        ""Ordered Quantity"", Sales[QuantityOrderedPrimaryUOM],
        ""Ordering Unit of Measure"", TRIM ( Sales[UOM] ),
        ""Ordered Quantity LBs"", Sales[QuantityOrderedLB],
        ""Ordered Quantity KGs"", Sales[QuantityOrderedKG],
        ""Primary Unit of Measure"", TRIM ( RELATED ( 'Item Branch'[UOM Primary] ) ),
        ""Cancelled Flag"", Sales[Cancelled_Flag],
        ""Line Type"", TRIM ( Sales[Line Type] ),
        ""Customer Code"", FORMAT ( RELATED ( 'Customer Ship To'[Customer Ship To] ), ""0"" ),
        ""Customer Name"", TRIM ( RELATED ( 'Customer Ship To'[Customer Ship To Name] ) ),
        ""Order Type Code"", TRIM ( Sales[Order Type] )
    )
ORDER BY [Global Bulk Item], [Bulk Item], [2nd Item Number], [Branch Plant], [Order Number], [Line Number]
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
