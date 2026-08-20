// ============================================================================
// Report 22 - "CM - Information 2020 - Future" - SHIPMENTS (sheet 2 of 6)
// COMMENTED MASTER. The shipped file is "Shipments.m" (comment-free, repo rule
// CLAUDE.md). Maintain the two in parallel; the code must stay byte-identical.
//
// Cognos: ORDER_ACTIVITY x PRICE_ORDER_SUMMARY x ITEM x customer/TM aliases,
// 70-bulk-item list, promised ship date since 2020-01-01, "Exclude Cancelled".
// Source here is SSASPROD / BIQLTabular 'Sales'.
//
// Tie-out (PROBE/FINDINGS.md): 2,864 display rows = Cognos 2,864, exact.
// Order Net Amount USD/EUR are the cube measures' numbers, not Cognos's: the
// legacy report re-converts at its own monthly rate and derives EUR for USD
// companies; this report matches [Order Net Amt SPD USD] / [Order Net Amt SPD
// EUR] so amounts agree across every cube-based report. 419 blank TMs
// = Cognos's 419 'Not Available'. Blanks stay blank - the '-' and
// 'Not Available' in Cognos are legacy-warehouse defaults, not cube values.
//
// Cognos's Raw Material Margin columns are not carried (Dave Bubash: the report
// consumers do not need them). The candidate definitions we tied out are written
// up in RAW_MATERIAL_MARGIN.md for Dave / Greg / Rohit to review as cube measures.
//
// GRAIN: SSAS sales lines; 24 order-lines appear twice in SSAS with different
// amounts/dates and Cognos shows them twice too. Measures over hidden "(Line)"
// columns, everything else summarizeBy none.
// ============================================================================
let
    Raw = AnalysisServices.Database(
        "SSASPROD",
        "BIQLTabular",
        [
            Query = "
EVALUATE
// The 70-bulk list, verbatim (COLLECTION_NOTES.md).
VAR Bulks = { ""161017CX"", ""161190PX"", ""171143PX"", ""171228PX.E"", ""181020CX.E"", ""181136IX"", ""181192IX"", ""181193EU.E"", ""191011CX"", ""191026CX.E"", ""191245PX"", ""23409A"", ""ABEX2525"", ""APT10"", ""APT11"", ""DMAEMA"", ""EMA3065"", ""ET2012.E"", ""ET2022.E"", ""ET4075.E"", ""ET440.E"", ""FERSUL7W"", ""HP1432AT"", ""HP1632"", ""MD4020"", ""MD4020C"", ""MD4020S"", ""MD4021"", ""MD4021C"", ""MD4021S"", ""MD4022"", ""MD4022C"", ""MD4023"", ""MD4023C"", ""MDU20"", ""MDU2012.E"", ""MDU2012B.E"", ""MDU4075.E"", ""MDU4075B.E"", ""MDU440.E"", ""MDU440B.E"", ""MPEG2000"", ""MW40504"", ""MW40514"", ""NP4LF"", ""NP4LF.S"", ""OMS"", ""PUD1.E"", ""STODSO"", ""U1001"", ""U101"", ""U201"", ""U2022"", ""U2022EU.E"", ""U2023"", ""U204"", ""U204EU.E"", ""U470"", ""U501"", ""U501B"", ""U502"", ""U502.E"", ""U502X1.E"", ""U601"", ""U701"", ""U802"", ""U802.E"", ""WAV501"", ""WD40"", ""WD40T"" }
VAR Lines =
    FILTER (
        Sales,
        TRIM ( RELATED ( 'Item Branch'[Item Bulk] ) ) IN Bulks
            && Sales[Promised Shipment Date] >= DATE ( 2020, 1, 1 )
            && Sales[Cancelled_Flag] = 0
            && NOT Sales[Order Type] IN { ""SB"", ""SR"" }
    )
RETURN
    SELECTCOLUMNS (
        Lines,
        // nchar with leading zeros ('00010'); stays text.
        ""Order Company"", Sales[Order Company],
        ""Branch Plant"", TRIM ( Sales[BusinessUnit] ),
        ""Order Number"", Sales[Order Num],
        ""Line Number"", Sales[Line Num],
        ""Open Indicator"", Sales[Open Order Flag],
        ""Global Bulk Item"", RELATED ( 'Item Branch'[Item Global Bulk] ),
        ""Bulk Item"", RELATED ( 'Item Branch'[Item Bulk] ),
        ""2nd Item Number"", Sales[Item Num 2nd],
        ""Description 1"", Sales[Description 1],
        // Cognos prints '-' for blank (2,617 rows).
        ""Description 2"", Sales[Description 2],
        ""Freight Handling Code"", Sales[Freight Handling Code],
        ""Next Status"", Sales[Status Code Next],
        // The base columns of the cube's [Order Net Amt SPD USD] / [Order Net Amt SPD EUR], so this
        // report shows the same numbers as every cube-based report. AmountOrderNetEUR is null for
        // USD-local companies (00010/00030) - the cube rates only EUR-local companies into EUR.
        ""Order Net Amount USD (Line)"", Sales[AmountOrderNetUSD],
        ""Order Net Amount EUR (Line)"", Sales[AmountOrderNetEUR],
        ""Ordered Quantity LBs (Line)"", Sales[QuantityOrderedLB],
        ""Ordered Quantity KGs (Line)"", Sales[QuantityOrderedKG],
        ""Revenue Business Unit"", RELATED ( 'Revenue Business Unit'[RBU] ),
        // Blank where the line has no TM (419 rows; the legacy warehouse shows 'Not Available').
        ""TM Name"", RELATED ( 'Territory Manager'[Mailing Name] ),
        ""Customer Name"", RELATED ( 'Customer Ship To'[Customer Ship To Name] ),
        ""Country Name"", RELATED ( 'Customer Ship To'[Country Desc] ),
        ""Global Parent Name"", RELATED ( Customer[Global Parent Name] ),
        // Cognos Date = promised ship date.
        ""Date"", Sales[Promised Shipment Date],
        ""Year"", YEAR ( Sales[Promised Shipment Date] ),
        ""Month"", MONTH ( Sales[Promised Shipment Date] ),
        ""Chemist Name"", RELATED ( 'Item Branch'[Chemist Name] )
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
