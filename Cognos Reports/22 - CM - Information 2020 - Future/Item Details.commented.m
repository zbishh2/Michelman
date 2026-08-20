// ============================================================================
// Report 22 - "CM - Information 2020 - Future" - ITEM DETAILS (sheet 6 of 6)
// COMMENTED MASTER. The shipped file is "Item Details.m" (comment-free, repo
// rule CLAUDE.md). Maintain the two in parallel; the code must stay
// byte-identical.
//
// Cognos: ITEM_BRANCH x ITEM, a separate 47-bulk list (not the 70), LAB branches
// excluded. Source here is SSASPROD / BIQLTabular 'Item Branch'.
//
// Tie-out (PROBE/FINDINGS.md): 615 rows = 607 Cognos item-branch rows (all
// matched on Branch + 2nd, every attribute agreeing) + 8 CINC item-branches
// that exist in JDE but not in the legacy DW. Cognos's other 147 rows are
// item-MASTER rows with branch 'N/A' and item-master defaults (MPF FEC, lead
// time 1, PTF 8, supplier '-', planner/buyer 0) - a legacy-DW join artefact,
// excluded here and raised with Dave. 46 SSAS rows with a blank branch are not
// in Cognos and are excluded.
//
// Planner Name is SSAS's "First Last"; Cognos prints "Last, First" and strips
// diacritics (Joel vs Joël) - format only. No measures: this sheet is attributes.
// ============================================================================
let
    Raw = AnalysisServices.Database(
        "SSASPROD",
        "BIQLTabular",
        [
            Query = "
EVALUATE
// The 47-bulk list - Item Details has its own list, not the 70.
VAR Bulks = { ""161017CX"", ""161190PX"", ""171143PX"", ""171228PX.E"", ""181193EU.E"", ""191245PX"", ""APT10"", ""APT11"", ""DMAEMA"", ""EMA3065"", ""FERSUL7W"", ""HP1432AT"", ""HP1632"", ""MD4020"", ""MD4020C"", ""MD4021"", ""MD4021C"", ""MD4022C"", ""MD4023"", ""MD4023C"", ""MDU20"", ""MDU2012.E"", ""MDU2012B.E"", ""MDU4075.E"", ""MDU4075B.E"", ""MDU440.E"", ""MDU440B.E"", ""MW40504"", ""MW40514"", ""NP4LF.S"", ""PUD1.E"", ""STODSO"", ""U1001"", ""U101"", ""U201"", ""U2022"", ""U204"", ""U470"", ""U501"", ""U501B"", ""U502"", ""U502.E"", ""U601"", ""U701"", ""U802.E"", ""WAV501"", ""WD40"" }
VAR ItemBranches =
    FILTER (
        'Item Branch',
        TRIM ( 'Item Branch'[Item Bulk] ) IN Bulks
            // 46 SSAS rows carry a blank branch; Cognos has none of them.
            && TRIM ( 'Item Branch'[Business Unit] ) <> """"
            // Cognos excludes LAB branches by pattern.
            && NOT CONTAINSSTRING ( 'Item Branch'[Business Unit], ""LAB"" )
    )
RETURN
    SELECTCOLUMNS (
        ItemBranches,
        ""Branch Plant"", TRIM ( 'Item Branch'[Business Unit] ),
        ""Global Bulk Item"", 'Item Branch'[Item Global Bulk],
        ""Bulk Item"", 'Item Branch'[Item Bulk],
        ""2nd Item Number"", 'Item Branch'[Item Num 2nd],
        ""Stock Type Code"", 'Item Branch'[Stocking Type],
        ""Master Planning Family"", 'Item Branch'[Master Planning Family],
        ""Lead Time Level"", 'Item Branch'[Lead time Level],
        // Cognos LEAD_TIME_ORDER_TO_SHIP = the item branch manufacturing lead time.
        ""Lead Time Order to Ship"", 'Item Branch'[Lead Time MFG_BP],
        ""Planning Code"", 'Item Branch'[Planning Code],
        ""Planning Time Fence Days"", 'Item Branch'[Planning Time Fence Days],
        // Cognos prints 0 for a blank safety stock (exact on the 4 non-zero rows).
        ""Safety Stock"", IF ( ISBLANK ( 'Item Branch'[SafetyStock] ), 0, 'Item Branch'[SafetyStock] ),
        ""Shelf Life Days"", 'Item Branch'[Shelf Life Days],
        ""Supplier Number"", 'Item Branch'[Branch Supplier Num],
        // Blank supplier / planner / buyer names stay blank (the legacy warehouse shows 'Not Available').
        ""Supplier Name"", 'Item Branch'[Branch Supplier Name],
        ""Planner Number"", 'Item Branch'[Planner Num],
        // SSAS 'First Last'; Cognos 'Last, First' without diacritics - format only.
        ""Planner Name"", 'Item Branch'[Planner Name],
        ""Buyer Number"", 'Item Branch'[Buyer Num],
        ""Buyer Name"", 'Item Branch'[Buyer Name]
    )
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
