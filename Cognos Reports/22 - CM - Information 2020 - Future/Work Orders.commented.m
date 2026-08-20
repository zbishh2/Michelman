// ============================================================================
// Report 22 - "CM - Information 2020 - Future" - WORK ORDERS (sheet 4 of 6)
// COMMENTED MASTER. The shipped file is "Work Orders.m" (comment-free, repo
// rule CLAUDE.md). Maintain the two in parallel; the code must stay
// byte-identical.
//
// Cognos: WORK_ORDER_PARTS_LIST x WORK_ORDER x ITEM (joined on the COMPONENT
// item), 70-bulk list on the component, per-row QUANTITY_ORDERED+ISSUED_QTY>0,
// start OR completion since 2020-01-01, grouped on (WO, parts-list branch,
// component 2nd, UOM) summing Ordered and Issued. Source here is SSASPROD /
// BIQLTabular 'Work Order Parts List' with 'Work Order' / 'Work Order Detail'.
//
// Tie-out (PROBE/FINDINGS.md): 1,585 display keys, all matching Cognos on every
// attribute; Cognos has 7 more keys that do not exist in JDE/SSAS and 16 keys
// whose Ordered is inflated in the legacy DW while Issued matches. Issued
// 5,683,534 exact.
//
// The parent item comes through 'Work Order Detail' (WorkOrderSKey ->
// ItemBranchSKey / BranchSKey) because the parts-list row's own Item Branch
// relationship is the COMPONENT. Completion Date is blank while the WO is open;
// Cognos renders Year/Month 0 there, Power BI renders blank (flagged).
//
// GRAIN: parts-list rows (2,452), grouped by the visual on its displayed
// columns. Two column sets carry the same display caption on purpose - the
// parent item's Branch Plant / Global Bulk Item / Bulk Item / 2nd Item Number
// and the component's - exactly as the Cognos sheet does; the model columns are
// prefixed "Component" and the visual overrides the caption.
// ============================================================================
let
    Raw = AnalysisServices.Database(
        "SSASPROD",
        "BIQLTabular",
        [
            Query = "
EVALUATE
// The 70-bulk list, verbatim.
VAR Bulks = { ""161017CX"", ""161190PX"", ""171143PX"", ""171228PX.E"", ""181020CX.E"", ""181136IX"", ""181192IX"", ""181193EU.E"", ""191011CX"", ""191026CX.E"", ""191245PX"", ""23409A"", ""ABEX2525"", ""APT10"", ""APT11"", ""DMAEMA"", ""EMA3065"", ""ET2012.E"", ""ET2022.E"", ""ET4075.E"", ""ET440.E"", ""FERSUL7W"", ""HP1432AT"", ""HP1632"", ""MD4020"", ""MD4020C"", ""MD4020S"", ""MD4021"", ""MD4021C"", ""MD4021S"", ""MD4022"", ""MD4022C"", ""MD4023"", ""MD4023C"", ""MDU20"", ""MDU2012.E"", ""MDU2012B.E"", ""MDU4075.E"", ""MDU4075B.E"", ""MDU440.E"", ""MDU440B.E"", ""MPEG2000"", ""MW40504"", ""MW40514"", ""NP4LF"", ""NP4LF.S"", ""OMS"", ""PUD1.E"", ""STODSO"", ""U1001"", ""U101"", ""U201"", ""U2022"", ""U2022EU.E"", ""U2023"", ""U204"", ""U204EU.E"", ""U470"", ""U501"", ""U501B"", ""U502"", ""U502.E"", ""U502X1.E"", ""U601"", ""U701"", ""U802"", ""U802.E"", ""WAV501"", ""WD40"", ""WD40T"" }
VAR PartsLines =
    ADDCOLUMNS (
        FILTER (
            'Work Order Parts List',
            // Item Branch on the parts-list row is the COMPONENT item - Cognos joins ITEM on the component.
            TRIM ( RELATED ( 'Item Branch'[Item Bulk] ) ) IN Bulks
                // Per ROW, before the visual sums: reversal rows (+x/-x) must drop individually as in Cognos.
                && 'Work Order Parts List'[QuantityOrdered] + 'Work Order Parts List'[QuantityTransaction] > 0
                // Cognos start OR completion since 2020.
                && ( RELATED ( 'Work Order'[Start Date] ) >= DATE ( 2020, 1, 1 ) || RELATED ( 'Work Order'[Completed Date] ) >= DATE ( 2020, 1, 1 ) )
                // WB orders have no resolvable parent (??????); Cognos's ITEM join drops them.
                && RELATED ( 'Work Order'[Work Order Type] ) = ""WO""
        ),
        // Parent item via Work Order Detail, keyed on WorkOrderSKey (one detail row per WO).
        ""@ParentItemBranchSKey"", LOOKUPVALUE ( 'Work Order Detail'[ItemBranchSKey], 'Work Order Detail'[WorkOrderSKey], 'Work Order Parts List'[WorkOrderSKey] ),
        ""@ParentBranchSKey"", LOOKUPVALUE ( 'Work Order Detail'[BranchSKey], 'Work Order Detail'[WorkOrderSKey], 'Work Order Parts List'[WorkOrderSKey] ),
        // 1900 = open WO; blank here, Cognos prints Year/Month 0.
        ""@CompletionDate"", IF ( RELATED ( 'Work Order'[Completed Date] ) <= DATE ( 1900, 12, 31 ), BLANK (), RELATED ( 'Work Order'[Completed Date] ) )
    )
RETURN
    SELECTCOLUMNS (
        PartsLines,
        ""Branch Plant"", LOOKUPVALUE ( Branch[Branch Plant], Branch[BranchSKey], [@ParentBranchSKey] ),
        ""Global Bulk Item"", LOOKUPVALUE ( 'Item Branch'[Item Global Bulk], 'Item Branch'[ItemBranchSKey], [@ParentItemBranchSKey] ),
        ""Bulk Item"", LOOKUPVALUE ( 'Item Branch'[Item Bulk], 'Item Branch'[ItemBranchSKey], [@ParentItemBranchSKey] ),
        ""2nd Item Number"", RELATED ( 'Work Order'[Parent Item Num 2nd] ),
        ""WO Number"", RELATED ( 'Work Order'[Work Order Num] ),
        ""Start Date"", RELATED ( 'Work Order'[Start Date] ),
        ""Completion Date"", [@CompletionDate],
        ""Year"", YEAR ( [@CompletionDate] ),
        ""Month"", MONTH ( [@CompletionDate] ),
        ""WO Status"", RELATED ( 'Work Order'[Work Order Status] ),
        // Parts-list BusinessUnit, the WO's branch; displayed as 'Branch Plant' like the Cognos sheet.
        ""Component Branch Plant"", TRIM ( 'Work Order Parts List'[BusinessUnit] ),
        ""Component 2nd Item Number"", 'Work Order Parts List'[Component Item Num 2nd],
        ""Component UOM"", 'Work Order Parts List'[UOM],
        // ISSUED_QTY is the parts-list transaction quantity; QuantityShipped is the WO header repeated per row.
        ""Issued Quantity (Line)"", 'Work Order Parts List'[QuantityTransaction],
        ""Quantity Ordered (Line)"", 'Work Order Parts List'[QuantityOrdered],
        // Displayed as 'Global Bulk Item' / 'Bulk Item' / '2nd Item Number' - the visual overrides the captions.
        ""Component Global Bulk Item"", RELATED ( 'Item Branch'[Item Global Bulk] ),
        ""Component Bulk Item"", RELATED ( 'Item Branch'[Item Bulk] ),
        ""Component Item 2nd Item Number"", RELATED ( 'Item Branch'[Item Num 2nd] ),
        ""Stock Type Code"", RELATED ( 'Item Branch'[Stocking Type] )
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
