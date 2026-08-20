// ============================================================================
// Report 22 - "CM - Information 2020 - Future" - RECEIPTS (sheet 1 of 6)
// COMMENTED MASTER. The shipped file is "Receipts.m" (comment-free, repo rule
// CLAUDE.md). Maintain the two in parallel; the code must stay byte-identical.
//
// Cognos: RECEIPT_ACTIVITY x ITEM x VENDOR, hardcoded 15-vendor list, receipts
// since 2020-01-01, flat <list>. Source here is SSASPROD / BIQLTabular
// 'Purchase Order Receiver' (source ladder: SSAS Import).
//
// Tie-out (PROBE/FINDINGS.md, Cognos export 2026-08-19): 1,844 display rows vs
// Cognos 1,854. The 10 Cognos-only rows are 5 legacy-DW-only receipts that do
// not exist in JDE/SSAS (docs 228157/228158 line 4, 223259/223260 line 1,
// 26001558 line 1) and 5 non-stock lines Cognos shows as item "Not Applicable"
// via its item-master join; SSAS 'Item Branch' cannot resolve them (they are 5
// of 88 unresolved rows, with nothing in SSAS separating the 5 from the 83 that
// Cognos also drops). AmountReceived exact on every matched row; USD/EUR are
// SSAS's JDE transaction-rate values where Cognos converts at its own monthly
// rate M (~1% on 313 / 1,386 rows - accepted, documented).
//
// GRAIN: SSAS line rows (1,892), which the table visual groups on its displayed
// columns and sums the measures over - that reproduces Cognos's per-line rows
// (SSAS carries 2-3 receipt rows for 42 doc/line/date keys Cognos shows once).
// So every identifier/text/date column is summarizeBy none and every quantity
// and amount is surfaced as a MEASURE over a hidden "(Line)" column.
// ============================================================================
let
    Raw = AnalysisServices.Database(
        "SSASPROD",
        "BIQLTabular",
        [
            Query = "
EVALUATE
// Cognos's hardcoded VENDOR_ID list, verbatim (COLLECTION_NOTES.md).
VAR Vendors = { 292788, 324808, 328211, 322114, 331380, 317501, 327516, 292774, 301843, 328143, 322976, 326444, 324962, 327267, 326095 }
VAR Receipts =
    FILTER (
        'Purchase Order Receiver',
        // RECEIPT_ACTIVITY = match-type-1 receipt rows; 2/3/4 are voucher-match rows.
        'Purchase Order Receiver'[Match Record Type] = ""1""
            // VENDOR_ID is the PO address number, not Supplier[Supplier Num] (2 rows differ).
            && 'Purchase Order Receiver'[Address Num PO] IN Vendors
            // RECEIPT_TRANSACTION_DATE and Cognos's Date column are both the received date.
            && 'Purchase Order Receiver'[Received Date] >= DATE ( 2020, 1, 1 )
            // Cognos inner-joins ITEM; unresolved item branches drop.
            && RELATED ( 'Item Branch'[Item Num 2nd] ) <> ""??????""
    )
RETURN
    SELECTCOLUMNS (
        Receipts,
        ""Global Bulk Item"", RELATED ( 'Item Branch'[Item Num Global Bulk] ),
        ""Bulk Item"", RELATED ( 'Item Branch'[Item Num Bulk] ),
        ""2nd Item Number"", RELATED ( 'Item Branch'[Item Num 2nd] ),
        // Address-book fallback for the 2 rows whose SupplierSKey is unresolved; Address Num is unique.
        ""Vendor Name"", IF ( TRIM ( RELATED ( Supplier[Supplier Name] ) ) = """", LOOKUPVALUE ( 'Address'[Address Name], 'Address'[Address Num], 'Purchase Order Receiver'[Address Num PO] ), RELATED ( Supplier[Supplier Name] ) ),
        ""Vendor ID"", 'Purchase Order Receiver'[Address Num PO],
        // Cognos's quantity is in the item's PRIMARY UOM (WD40-UN: DR->LB x350).
        ""Received Quantity (Line)"", IF ( 'Purchase Order Receiver'[UOM Primary] = ""LB"", 'Purchase Order Receiver'[QuantityReceivedLB], IF ( 'Purchase Order Receiver'[UOM Primary] = ""KG"", 'Purchase Order Receiver'[QuantityReceivedKG], 'Purchase Order Receiver'[QuantityReceived] ) ),
        ""Received Quantity LBs (Line)"", 'Purchase Order Receiver'[QuantityReceivedLB],
        ""Received Quantity KGs (Line)"", 'Purchase Order Receiver'[QuantityReceivedKG],
        // Equals Document Type (OV receipt / OW return) on every row.
        ""Receipt Transaction Type"", 'Purchase Order Receiver'[Document Type],
        ""Receipt Transaction Date"", 'Purchase Order Receiver'[Received Date],
        ""Order Type"", 'Purchase Order Receiver'[Order Type],
        ""Document Number"", 'Purchase Order Receiver'[Document Num],
        ""Line Number"", 'Purchase Order Receiver'[Line Num],
        ""Document Type"", 'Purchase Order Receiver'[Document Type],
        ""Amount Received (Line)"", 'Purchase Order Receiver'[AmountReceived],
        // JDE transaction rate; Cognos converts at its monthly rate M (~1% on some rows).
        ""Amount Received USD (Line)"", 'Purchase Order Receiver'[AmountReceivedUSD],
        ""Amount Received EUR (Line)"", 'Purchase Order Receiver'[AmountReceivedEUR],
        ""Date"", 'Purchase Order Receiver'[Received Date],
        ""Year"", YEAR ( 'Purchase Order Receiver'[Received Date] ),
        ""Month"", MONTH ( 'Purchase Order Receiver'[Received Date] )
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
