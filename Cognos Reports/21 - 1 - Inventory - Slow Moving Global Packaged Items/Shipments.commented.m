// ============================================================================
// Report 21  ·  1 - Inventory - Slow Moving Global Packaged Items  ·  page table: Shipments
// Cognos query object: Shipments  (DW_LEGACY "Order Activity" star)
// Route: EDW  ·  dbo.FactSalesDetail  (BUILD.md 1, 3.2, 4.2)
//
// ---------------------------------------------------------------------------
// *** DELIBERATE REPRODUCTION OF A COGNOS DEFECT — READ THIS FIRST ***
// ---------------------------------------------------------------------------
// The [Line Number] projection wraps the rendered line number in LEFT(..., 5) and
// then GROUPs BY the truncated string. That truncation is NOT a porting artifact
// and NOT an accident. It is a defect in the Cognos report that we are copying on
// purpose, on Zack's instruction of 2026-08-06 ("build for parity").
//
// WHAT COGNOS DOES: its SQL is
//     substr(ORDER_LINE_ID, 1 + instr(ORDER_LINE_ID, ',', -1), 5)
// i.e. take everything after the last comma of company,order,type,line and keep the
// first FIVE characters. The DW renders a whole line as '10' and a sub-line as
// '10.001', so five characters turns '10.001' into '10.00'. Cognos then groups by
// that truncated string, so lines 10.000 / 10.001 / 10.002 / 10.003 collapse into
// ONE row labelled '10.00' with their quantities SUMMED. Any line number >= 10 that
// has sub-lines loses its line-level detail this way.
//
// MEASURED (BUILD.md 3.4 and 7 #6): exactly 8 rows of the 2026-08-06 tight capture
// are produced by this truncation. Emulating it is what lifts the local match from
// 17,251 to 17,259 of 17,259 export rows — it is the sole cause of every otherwise
// unmatched export row, so parity and the tie-out agree here.
//
// TO SHIP THE CORRECT (UNMERGED) FORM INSTEAD: delete the LEFT(..., 5) wrapper from
// BOTH the SELECT list and the GROUP BY, leaving the bare CASE expression:
//     CASE WHEN f.LineNum = FLOOR(f.LineNum)
//          THEN CAST(CAST(f.LineNum AS int) AS varchar(12))
//          ELSE CAST(CAST(f.LineNum AS decimal(9,3)) AS varchar(12))
//     END                                          AS [Line Number]
// That is a two-line edit, nothing else in the query changes, and it is the form
// BUILD.md 9 D-21a recommends putting to the requester. Measured against the same
// capture the unmerged form scores 17,245 matched / 15 EDW-only / 14 export-only.
// Do not "fix" the truncation silently in either direction — it is a decision.
//
// WHY substr CANNOT BE PORTED LITERALLY (BUILD.md 3.4): EDW's OrderLineID always
// renders the line to 3 decimals ('00020,26001384,CO,2.000') while the Cognos DW
// renders '2' for a whole line. A literal substr against EDW's string would give
// '2.000', which matches nothing. The line number is therefore rebuilt from the
// typed f.LineNum column and only then truncated.
//
// ---------------------------------------------------------------------------
// THE OTHER FOUR SETTLED CORRECTIONS (all measured — do not re-derive)
// ---------------------------------------------------------------------------
// 1. ORDERED QUANTITY = f.QuantityOrderedPrimaryUOM, NOT QuantityOrdered*SalesFactor.
//    EDW's SalesFactor is a sign/credit factor (+/-1), not Cognos's SALES_FACTOR (the
//    line-UOM -> primary-UOM conversion). QuantityOrdered * SalesFactor returns the
//    TRANSACTION quantity and is wrong by the pack size: order 26001236 line 1 comes
//    out 1.0 (one drum) against the export's 200. BUILD.md 2.5.1.
//
// 2. NET-OF-CANCEL IS REQUIRED — and it stays in SQL (BUILD.md 2.5.2, 5.2).
//    A fully-cancelled line has ORDERED_QTY = 0 in Cognos and is dropped by its > 0
//    filter; EDW keeps the gross quantity and books the cancellation separately.
//    (f.QuantityOrdered - f.QuantityCanceledScrapped) > 0 removes 1,427 of 1,432
//    spurious rows and costs 6 of 17,261 genuine ones (lines Cognos itself renders as
//    1e-10 — float residue that rounds to 0 on both sides). Without it the sheet is
//    8.3% over-populated. This is business logic living in SQL by exception, because
//    it is row-SCOPING: applied in DAX it would import 8.3% more rows and every visual
//    would need a filter. Both quantities are in the transaction UOM and so are
//    directly comparable — do not mix QuantityOrderedPrimaryUOM into this predicate.
//
// 3. THE INDIA-TAX EXCLUSION IS BUSINESS LOGIC AND THE LITERAL PORT IS DEAD CODE.
//    Cognos writes decode(GLOBAL_BULK_ITEM,'-',ITEM_NUMBER_2ND,GLOBAL_BULK_ITEM), i.e.
//    "identify the item by its global bulk, falling back to the 2nd item number when
//    the global bulk is MISSING". '-' is how the Cognos DW represents missing; EDW
//    stores NULL (17 rows table-wide on [Item Global Bulk]) or blank, and never a
//    literal '-' (BUILD.md 4.5, 7 #11). A literal port testing = '-' would never match
//    in EDW, the fallback would be unreachable, and the exclusion would under-fire on
//    exactly the rows it was written for. Hence the NULLIF/NULLIF/COALESCE form, which
//    treats NULL, empty, whitespace and a literal '-' alike and is therefore correct
//    against either warehouse. Also stays in SQL because it is row-scoping.
//    Measured: it removes ZERO rows and the fallback fires on ZERO rows, because
//    IGST/CGST/SGST/CVD/ADD exist in EDW only at branches MUM2/MUM3/HARY, which the
//    branch list already excludes. Ship it anyway — it costs nothing and will fire
//    correctly the day an India branch is added. BUILD.md 4.5 case 3, 7 #9.
//
// 4. GL CLASS COMES FROM THE ITEM HERE, NOT THE FACT (BUILD.md 0.1). This query and
//    the Items - Active query filter ib.[Category GL F4101]; the Inventory query
//    filters snap.CategoryGLF41021. They are genuinely different populations and must
//    NOT be unified — the fact-level column carries the water/utility items whose
//    on-hand quantities run to 99.98 billion. Unifying them silently changes every
//    number on the affected sheet.
//
// ---------------------------------------------------------------------------
// BRANCH LIST — SIX PLANTS, AND THE DUPLICATE IS INTENTIONAL
// ---------------------------------------------------------------------------
// Cognos lists CINC twice and omits CIN4 here, while queries 1 and 3 list seven plants
// including CIN4. The duplicate is harmless inside an IN list. The omission is a real
// inconsistency in the source report, but measured inert: CIN4 holds no IN32
// item-branches at all and contributes zero rows to all three queries. Ported exactly
// as written and raised as D-21b rather than silently corrected. BUILD.md 4.4.
//
// ORDER TYPE: this report excludes only 'ST'. Report 19 runs over the same fact and
// also excludes 'S5' — deliberately different scope. Do not reuse a query between the
// two reports. BUILD.md 4.6.
//
// ---------------------------------------------------------------------------
// COLUMNS CARRIED FOR DAX, NOT FOR DISPLAY (hidden in the model)
// ---------------------------------------------------------------------------
// [Primary Unit of Measure]  drives the KG/LB rule in DAX (BUILD.md 2.4). MIN() rather
//     than a GROUP BY term so that adding it can never split a Cognos display row.
// [KG Factor] = f.ConversionFactorKG, the per-item EDW weight per primary unit. Used
//     ONLY by the ELSE branch of the KG/LB rule (primary UOM neither KG nor LB).
//
// OPEN INDICATOR (D-21d) — RESOLVED BY PROBE P1 ON THE JUMPBOX, 2026-08-06.
//     dbo.FactSalesDetail has no column of that name. The answer is NEXT STATUS:
//         Open Indicator = IF ( TRIM( [Next Status] ) = "999", "N", "Y" )
//     Measured over all 17,259 export rows: 'N' <-> Next Status 999 on 16,363 rows and
//     'Y' <-> 540/530/560/535/580/525/550/570 on 896. Zero exceptions either way.
//     [Next Status] is already in the projection above, so no extra column is needed —
//     the rule itself lives in DAX, because it is a derived business value and business
//     rules do not belong in Power Query (root CLAUDE.md memory note). StatusCodeNext is
//     nchar and is trimmed both here and again in the DAX; without a trim the = '999'
//     test silently fails.
//
//     *** SalesTableSource IS DISPROVED — DO NOT RE-ADOPT IT. ***
//     BUILD.md 3.5 named SalesTableSource = 1 as the closest structural analog (JDE
//     F4211 = open order file, F42119 = history), and on the 17,253 rows that matched
//     the tight capture it looked like a perfect partition. It is not correct in
//     general: the jumpbox probe found 252 lines with SalesTableSource = 1 AND
//     StatusCodeNext = 999 — rows the status rule calls 'N' and the source rule calls
//     'Y'. Those 252 fall outside the export-matched set, which is exactly why the local
//     cross-tab could not see them. The column has been REMOVED from this projection so
//     it cannot be quietly reinstated. BUILD.md 7 #18.
//
//     This column is DISPLAYED, not filtered, on report 21 — do not let it narrow the
//     population, and do not copy report 19's Open Indicator <> 'Y' carve-out here.
//
// DATE ARITHMETIC: the 365-day bound is DATEADD(DAY, -365, CAST(GETDATE() AS date)),
//     NOT CAST(GETDATE() AS date) - 365 as BUILD.md 4.2 originally specified. The T-SQL
//     `date` type does not support the arithmetic operators — the spec's form raises
//     "Msg 206 ... Operand type clash: date is incompatible with int" at refresh.
//     BUILD.md 7 #19.
//
// SHIP-TO JOIN: BIQL.TbCustomerShipTo does not exist in EDW; ShipToCustomerSKey ->
//     dbo.DimCustomer -> dbo.DimAddress is the reachable equivalent and is measured
//     clean — 25,993 of 25,993 in-window lines resolve, zero drops, zero fan-out.
//     Customer Name = AddressDesc reproduces the export on 17,251 of 17,259 rows; the
//     8 misses are one Vietnamese customer differing only in letter CASE. BUILD.md 3.2.
//
// WITH (NOLOCK) on every source object per root CLAUDE.md 9 — a scan this size would
// otherwise escalate to a table-level shared lock and block the ETL writers.
// No CTEs, no ORDER BY, no temp tables, no OUTER APPLY / ROW_NUMBER inside the wrapper
// (BUILD.md 5.3). Sorting lives in the visual.
// ============================================================================
let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        SELECT
            f.OrderCompany                               AS [Order Company],
            LTRIM(RTRIM(f.BusinessUnit))                 AS [Branch Plant],
            ib.[Item Global Bulk]                        AS [Global Bulk Item],
            ib.[Item Bulk]                               AS [Bulk Item],
            f.ItemNum2nd                                 AS [2nd Item Number],
            CAST(f.OrderNum AS varchar(12))              AS [Order Number],
            LEFT(CASE WHEN f.LineNum = FLOOR(f.LineNum)
                      THEN CAST(CAST(f.LineNum AS int) AS varchar(12))
                      ELSE CAST(CAST(f.LineNum AS decimal(9,3)) AS varchar(12))
                 END, 5)                                 AS [Line Number],
            LTRIM(RTRIM(f.StatusCodeLast))               AS [Last Status],
            LTRIM(RTRIM(f.StatusCodeNext))               AS [Next Status],
            f.PromisedShipmentDate                       AS [Promised Ship Date],
            SUM(f.QuantityOrderedPrimaryUOM)             AS [Ordered Quantity],
            LTRIM(RTRIM(f.UOMTransaction))               AS [Ordering Unit of Measure],
            LTRIM(RTRIM(f.LineType))                     AS [Line Type],
            CAST(f.AddressNumShipTo AS varchar(12))      AS [Customer Code],
            a.AddressDesc                                AS [Customer Name],
            LTRIM(RTRIM(f.OrderType))                    AS [Order Type Code],
            LTRIM(RTRIM(MIN(f.UOMPrimary)))              AS [Primary Unit of Measure],
            MIN(f.ConversionFactorKG)                    AS [KG Factor]
        FROM dbo.FactSalesDetail f WITH (NOLOCK)
            INNER JOIN BIQL.TbItemBranch ib WITH (NOLOCK)
                    ON ib.ItemBranchSKey = f.ItemBranchSKey
            INNER JOIN dbo.DimCustomer c WITH (NOLOCK)
                    ON c.CustomerSKey = f.ShipToCustomerSKey
            INNER JOIN dbo.DimAddress a WITH (NOLOCK)
                    ON a.AddressSKey = c.AddressSKey
        WHERE f.QuantityOrderedPrimaryUOM > 0
          AND (f.QuantityOrdered - f.QuantityCanceledScrapped) > 0
          AND f.PromisedShipmentDate >= DATEADD(DAY, -365, CAST(GETDATE() AS date))
          AND LTRIM(RTRIM(f.LineType)) = 'S'
          AND LTRIM(RTRIM(f.OrderType)) NOT IN ('ST')
          AND LTRIM(RTRIM(f.BusinessUnit)) IN ('CINC', 'CIN2', 'CINC', 'AUBA', 'AUB2', 'SING', 'SNG4')
          AND LTRIM(RTRIM(ib.[Category GL F4101])) = 'IN32'
          AND COALESCE( NULLIF( NULLIF( LTRIM(RTRIM(ISNULL(ib.[Item Global Bulk], ''))), '' ), '-' ),
                        LTRIM(RTRIM(f.ItemNum2nd)) )
              NOT IN ('IGST', 'CGST', 'SGST', 'CVD', 'ADD')
        GROUP BY
            f.OrderCompany,
            LTRIM(RTRIM(f.BusinessUnit)),
            ib.[Item Global Bulk],
            ib.[Item Bulk],
            f.ItemNum2nd,
            CAST(f.OrderNum AS varchar(12)),
            LEFT(CASE WHEN f.LineNum = FLOOR(f.LineNum)
                      THEN CAST(CAST(f.LineNum AS int) AS varchar(12))
                      ELSE CAST(CAST(f.LineNum AS decimal(9,3)) AS varchar(12))
                 END, 5),
            LTRIM(RTRIM(f.StatusCodeLast)),
            LTRIM(RTRIM(f.StatusCodeNext)),
            f.PromisedShipmentDate,
            LTRIM(RTRIM(f.UOMTransaction)),
            LTRIM(RTRIM(f.LineType)),
            CAST(f.AddressNumShipTo AS varchar(12)),
            a.AddressDesc,
            LTRIM(RTRIM(f.OrderType))
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
