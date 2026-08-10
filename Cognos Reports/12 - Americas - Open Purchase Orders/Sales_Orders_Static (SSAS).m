// ============================================================================
// Report 12 - Americas - Open Purchase Orders  |  PAGE 2 : "Sales Order Static"
// SSAS-SOURCED VARIANT (team semantic model BIQLTabular_v2). Twin of
// Sales_Orders_Static.m (ODS). IMPORT via one DAX EVALUATE; cube relationships
// supply the joins. Validated round 1 (2026-07-22 tight capture, BUILD.md sec 12):
// Cognos was a perfect subset (0 missing keys); fixes below from that round.
//
// VALIDATION-DRIVEN RULES (all from the 2026-07-22 Cognos compare):
//   Ordered Quantity LBs = SUM(QuantityOrderedLB) (transaction qty x LB factor).
//     The cube's QuantityOrderedPrimaryUOMLB DOUBLE-APPLIES the container factor
//     for lines sold in container UOMs (primary-UOM qty x per-container LBs;
//     8,228 rows off by exactly the container weight, e.g. x2200 per tote) -
//     cube defect reported to the team, do not map that column.
//   Lead Time Order to Ship = 'Item Branch'[Lead Time MFG_BP] (F4102.IBLTMF) -
//     the exact lineage of Cognos LEADTIME_MFG. [Lead time Level] (IBLTLV) is a
//     different field (page 1 uses it; page 2 must not).
//   CSR Name reformatted "Last, First" -> "First Last" (cube stores comma form,
//     Cognos DW stores display form; 100% of rows differed on format alone).
//   CSR INNER-join parity: Base keeps only lines with a related CSR row
//     (RELATED CSRNum not blank) - Cognos INNER joins the type-9 rep, and 112 of
//     113 extra cube rows in round 1 had no CSR. Blank NAMES still render "-".
//   Factor-null zeroing (Cognos semantics): Ordered Quantity = 0 when the sales
//     factor is unresolvable (UOM <> primary and the cube passed raw qty through);
//     Ordered LBs additionally 0 when no real LB conversion exists. 882 zero-qty
//     and 2,977 zero-LB Cognos rows in round 1, all non-stock items.
//   Sentinels matched to Cognos: blank delivery instructions -> "-",
//     blank TM -> "Not Available".
// KNOWN RESIDUALS (accepted): live-cube-vs-nightly-DW drift (status/date
//   progressions); cube nulls Item Num 2nd for text-only lines (RESTOCK etc.);
//   scattered case differences in free-text columns.
// FILTERS: Scheduled Pick in [today-365, today+30]; Branch CINC/CIN2/CIN4;
//   GST/duty exclusion via Item Num Global Bulk fallback to 2nd item.
//   NO cancelled-line (980) filter - the Cognos SQL has none; do not add one.
// ============================================================================
let
    Source = AnalysisServices.Database(
        "SSASPROD",
        "BIQLTabular_v2",
        [Query = "
        EVALUATE
        VAR Base =
            FILTER(
                'Sales',
                NOT ISBLANK('Sales'[Scheduled Pick Date])
                    && 'Sales'[Scheduled Pick Date] >= TODAY() - 365
                    && 'Sales'[Scheduled Pick Date] <= TODAY() + 30
                    && RELATED('Branch'[Branch Plant]) IN {""CINC"", ""CIN2"", ""CIN4""}
                    && NOT ISBLANK(RELATED('CSR for Sales Orders'[CSRNum]))
                    && NOT (
                        IF(
                            RELATED('Item Branch'[Item Num Global Bulk]) = ""-""
                                || ISBLANK(RELATED('Item Branch'[Item Num Global Bulk])),
                            'Sales'[Item Num 2nd],
                            RELATED('Item Branch'[Item Num Global Bulk])
                        ) IN {""IGST"", ""CGST"", ""SGST"", ""CVD"", ""ADD""}
                    )
            )
        RETURN
        SELECTCOLUMNS(
            SUMMARIZE(
                Base,
                'Sales'[Order Num],
                'Sales'[Line Num],
                'Sales'[Order Date],
                'Sales'[Scheduled Pick Date],
                'CSR for Sales Orders'[CSRName],
                'Customer Ship To'[Customer Ship To Name],
                'Sales'[Item Num 2nd],
                'Sales'[Description 1],
                'Sales'[Delivery Instructions Line 1],
                'Sales'[Delivery Instructions Line 2],
                'Sales'[Status Code Next],
                'Customer Ship To'[Customer Segmentation],
                'Territory Manager'[Mailing Name],
                'Branch'[Branch Plant],
                'Item Branch'[Stocking Type],
                'Item Branch'[Lead Time MFG_BP],
                'Sales'[UOM],
                'Sales'[UOM Primary],
                'Sales'[Carrier Name],
                'Sales'[Freight Handling Code],
                ""@RawQty"", SUM('Sales'[QuantityOrdered]),
                ""@Qty"", SUM('Sales'[QuantityOrderedPrimaryUOM]),
                ""@QtyLB"", SUM('Sales'[QuantityOrderedLB])
            ),
            ""Order Number"", 'Sales'[Order Num],
            ""Line Number"", 'Sales'[Line Num],
            ""Ordered Date"", 'Sales'[Order Date],
            ""Promised Ship Date"", 'Sales'[Scheduled Pick Date],
            ""CSR Name"",
                IF(
                    TRIM('CSR for Sales Orders'[CSRName]) = """", ""-"",
                    IF(
                        SEARCH("","", 'CSR for Sales Orders'[CSRName], 1, 0) = 0,
                        'CSR for Sales Orders'[CSRName],
                        TRIM(MID('CSR for Sales Orders'[CSRName], SEARCH("","", 'CSR for Sales Orders'[CSRName], 1, 0) + 1, 200))
                            & "" ""
                            & TRIM(LEFT('CSR for Sales Orders'[CSRName], SEARCH("","", 'CSR for Sales Orders'[CSRName], 1, 0) - 1))
                    )
                ),
            ""Customer Name"", 'Customer Ship To'[Customer Ship To Name],
            ""2nd Item Number"", 'Sales'[Item Num 2nd],
            ""Description 1"", 'Sales'[Description 1],
            ""Description 1 (2)"", 'Sales'[Description 1],
            ""Delivery Instructions Line 1"", IF(TRIM('Sales'[Delivery Instructions Line 1]) = """", ""-"", 'Sales'[Delivery Instructions Line 1]),
            ""Delivery Instructions Line 2"", IF(TRIM('Sales'[Delivery Instructions Line 2]) = """", ""-"", 'Sales'[Delivery Instructions Line 2]),
            ""Next Status"", 'Sales'[Status Code Next],
            ""Ordered Quantity"", IF('Sales'[UOM] <> 'Sales'[UOM Primary] && [@Qty] = [@RawQty], 0, [@Qty]),
            ""Ordered Quantity LBs"",
                IF(
                    ('Sales'[UOM] <> 'Sales'[UOM Primary] && [@Qty] = [@RawQty])
                        || ('Sales'[UOM] <> ""LB"" && [@QtyLB] = [@RawQty]),
                    0,
                    [@QtyLB]
                ),
            ""Customer Segmentation"", 'Customer Ship To'[Customer Segmentation],
            ""TM Name"", IF(TRIM('Territory Manager'[Mailing Name]) = """", ""Not Available"", 'Territory Manager'[Mailing Name]),
            ""Make Site"", SWITCH(TRUE(),
                'Branch'[Branch Plant] = ""CIN2"" && 'Item Branch'[Stocking Type] IN {""S"", ""M"", ""Q"", ""P""}, ""Kemper"",
                'Branch'[Branch Plant] = ""CIN2"" && 'Item Branch'[Stocking Type] IN {""D""}, ""Shell"",
                'Branch'[Branch Plant] = ""CINC"" && 'Item Branch'[Stocking Type] IN {""S"", ""M"", ""Q"", ""P""}, ""Shell"",
                ""OTHER""),
            ""Lead Time Order to Ship"", 'Item Branch'[Lead Time MFG_BP],
            ""Ship Site"", SWITCH(TRUE(),
                'Branch'[Branch Plant] = ""CIN2"", ""Kemper"",
                'Branch'[Branch Plant] = ""CINC"", ""Shell"",
                ""OTHER""),
            ""Carrier Name"", 'Sales'[Carrier Name],
            ""Freight Handling Code"", 'Sales'[Freight Handling Code]
        )
        ", Implementation = "2.0"]
    ),
    Renamed = Table.TransformColumnNames(
        Source,
        each if Text.StartsWith(_, "[") then Text.BetweenDelimiters(_, "[", "]") else _
    ),
    Typed = Table.TransformColumnTypes(
        Renamed,
        {
            {"Order Number", Int64.Type},
            {"Line Number", type number},
            {"Ordered Date", type date},
            {"Promised Ship Date", type date},
            {"CSR Name", type text},
            {"Customer Name", type text},
            {"2nd Item Number", type text},
            {"Description 1", type text},
            {"Description 1 (2)", type text},
            {"Delivery Instructions Line 1", type text},
            {"Delivery Instructions Line 2", type text},
            {"Next Status", type text},
            {"Ordered Quantity", type number},
            {"Ordered Quantity LBs", type number},
            {"Customer Segmentation", type text},
            {"TM Name", type text},
            {"Make Site", type text},
            {"Lead Time Order to Ship", Int64.Type},
            {"Ship Site", type text},
            {"Carrier Name", type text},
            {"Freight Handling Code", type text}
        },
        "en-US"
    )
in
    Typed
