let
    Raw = AnalysisServices.Database(
        "SSASPROD",
        "BIQLTabular",
        [
            Query = "
EVALUATE
DISTINCT (
    SELECTCOLUMNS (
        FILTER (
            'Item Branch',
            TRIM ( 'Item Branch'[Category GL F4101] ) = ""IN32""
                && TRIM ( 'Item Branch'[Stocking Type] ) <> ""O""
                && TRIM ( 'Item Branch'[Business Unit] )
                    IN { ""CINC"", ""CIN2"", ""CIN4"", ""AUBA"", ""AUB2"", ""SING"", ""SNG4"" }
        ),
        ""Branch Plant"", TRIM ( 'Item Branch'[Business Unit] ),
        ""Global Bulk Item"", TRIM ( 'Item Branch'[Item Global Bulk] ),
        ""Bulk Item"", TRIM ( 'Item Branch'[Item Bulk] ),
        ""2nd Item Number"", TRIM ( 'Item Branch'[Item Num 2nd] ),
        ""Stock Type Code"", TRIM ( 'Item Branch'[Stocking Type] )
    )
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
