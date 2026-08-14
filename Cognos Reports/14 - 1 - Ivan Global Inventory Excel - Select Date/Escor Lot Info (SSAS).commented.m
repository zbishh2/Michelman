// Commented master. The production copy of this query lives in the SSAS Import
// PBIP's SemanticModel and ships comment-free; the two are otherwise identical.
//
// Page 4 (Escor Lot Details). A distinct lot list for the ESC5200 bulk items,
// independent of any snapshot date and of whether stock is currently on hand.
let
    // AnalysisServices.Database with a Query record issues the DAX verbatim.
    Raw = AnalysisServices.Database(
        "SSASPROD",
        "BIQLTabular_ISH",
        [
            Query = "
EVALUATE
// The model has no Lot to Item Branch relationship, so the join is written here.
// Item Branch is a dated dimension: the same item-branch key repeats once per
// snapshot date, so the projection is made DISTINCT before the join to keep the
// lot list from fanning out.
VAR EscorItemBranch =
    // The outer projection drops the join key; DISTINCT then collapses lots that
    // differ only by the item-branch rows they matched.
    DISTINCT (
        SELECTCOLUMNS (
            FILTER (
                'Item Branch',
                TRIM ( 'Item Branch'[Item Num Bulk] )
                    IN { ""ESC5200"", ""ESC5200.E"", ""ESC5200.S"" }
            ),
            // Concatenating an empty string drops column lineage on both sides so
            // NATURALINNERJOIN matches them by name.
            ""@ItemBranchISKey"", 'Item Branch'[ItemBranchISKey] & """",
            ""Bulk Item"", TRIM ( 'Item Branch'[Item Num Bulk] ),
            ""2nd Item Number"", TRIM ( 'Item Branch'[Item Num 2nd] )
        )
    )
// Lot master columns the page shows.
VAR EscorLots =
    SELECTCOLUMNS (
        'Lot',
        ""@ItemBranchISKey"", 'Lot'[ItemBranchISKey] & """",
        ""Branch Plant"", TRIM ( 'Lot'[Business Unit] ),
        ""Item Short ID"", 'Lot'[Item Num Short],
        ""Lot Number"", TRIM ( 'Lot'[Lot Num] ),
        ""Supplier Lot Number"", TRIM ( 'Lot'[Supplier Lot Num] ),
        ""Memo Lot 1"", 'Lot'[Memo Lot 1],
        ""Memo Lot 2"", 'Lot'[Memo Lot 2],
        ""On Hand Date"", 'Lot'[On Hand Date]
    )
RETURN
    DISTINCT (
        SELECTCOLUMNS (
            NATURALINNERJOIN ( EscorItemBranch, EscorLots ),
            ""Branch Plant"", [Branch Plant],
            ""Bulk Item"", [Bulk Item],
            ""2nd Item Number"", [2nd Item Number],
            ""Item Short ID"", [Item Short ID],
            ""Lot Number"", [Lot Number],
            ""Supplier Lot Number"", [Supplier Lot Number],
            ""Memo Lot 1"", [Memo Lot 1],
            ""Memo Lot 2"", [Memo Lot 2],
            ""On Hand Date"", [On Hand Date]
        )
    )
// Cognos list order. Lots with no on-hand date sort first.
ORDER BY [On Hand Date]
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
