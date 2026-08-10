// ============================================================================
// Report 21  ·  1 - Inventory - Slow Moving Global Packaged Items  ·  page table: Items - Active
// Cognos query object: Items  (DW_LEGACY "ITEM" — item-BRANCH grain)
// Route: EDW  ·  BIQL.TbItemBranch, single table  (BUILD.md 3.3, 4.3)
//
// This is the spine of the whole report: every active packaged item-branch. Sheet 1 is
// what is in stock, sheet 2 is what has moved in the last 365 days, and the requester
// assembles the slow-moving analysis from the three by hand in Excel.
//
// PAGE NAME vs QUERY NAME: the XML query is "Items", the page is "Items - Active". The
// "Active" is the page label and STOCK_TYPE_CODE not in ('O') is what it means
// (O = obsolete). The page name is used for the table. BUILD.md 3.3.
//
// GL CLASS COMES FROM THE ITEM HERE (ib.[Category GL F4101]), as it does on the
// Shipments query and unlike the Inventory query, which takes it from the fact. This is
// deliberate and load-bearing — see BUILD.md 0.1 and the header of Inventory.commented.m.
// Measured (BUILD.md 7 #1): [Category GL F4101] gives 5,282 distinct
// (Branch Plant, 2nd Item Number, Stock Type) triples, ALL 5,282 present in the export,
// zero extras, 4 export rows missing — and those 4 are item-branches created between the
// mirror refresh and the export. [Category GL F4102] was tested and REJECTED: it adds 36
// water/packaging item-branches (DIH2O*, SH2O*, JUG, QUART, DMEA45) the export does not
// have. Delta -0.08%, fully explained by one day of staleness.
//
// SELECT DISTINCT is required, not cosmetic: Cognos renders DISTINCT implicitly in list
// panels, and omitting it over-counts (root CLAUDE.md 7 — it over-counted Work Orders on
// an earlier report).
//
// ---------------------------------------------------------------------------
// THE ONE COLUMN THIS REPORT CANNOT MATCH — D-21c, disclose, do not chase
// ---------------------------------------------------------------------------
// 382 of the export's 5,286 rows (7.2%) show '-' in BOTH Global Bulk Item and Bulk Item
// while EDW carries a real derived item number — e.g. export ('CINC','-','-','191245PX','1')
// against EDW ('CINC','191245PX','191245PX','191245PX','1'). 382 dashes, 382
// disagreements, a perfect 1:1, and EVERY ONE is branch CINC; every affected item appears
// non-dashed at another branch.
//
// This is NOT the '-'-renders-missing issue that the Inventory sheet has, and it does NOT
// get a display column. Measured (BUILD.md 7 #8, #11): in the in-scope Items-Active
// population both bulk columns are NULL on zero rows, blank on zero rows and dash on zero
// rows — every one carries a real item number. (The 385 / 17 table-wide NULLs all sit in
// branches this report never selects: DALL, SANF, CIN3, CIN4, LABO.) So the Cognos DW's
// bulk-item attribute is branch-specific and genuinely ABSENT for a subset of CINC
// item-branches, while EDW's is item-master-derived and always populated. That is a source
// derivation difference, not a rendering mismatch and not a bug on either side.
// [Item Num Global Bulk], [Item Num Bulk], [GlobalBulkFilter], IGB_XFlag, ExperimentalFlag
// and DimItem.ItemGlobalBulk were all checked and every one returns the item number.
// It cannot be reproduced from EDW. Sheets 1 and 2 contain zero dashes in these columns
// and are unaffected.
//
// Seven branch plants here, as in the Cognos source; CIN4 is measured inert (BUILD.md 4.4,
// D-21b). WITH (NOLOCK) per root CLAUDE.md 9. No ORDER BY — sorting lives in the visual.
// ============================================================================
let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        SELECT DISTINCT
            LTRIM(RTRIM(ib.[Business Unit]))             AS [Branch Plant],
            ib.[Item Global Bulk]                        AS [Global Bulk Item],
            ib.[Item Bulk]                               AS [Bulk Item],
            ib.[Item Num 2nd]                            AS [2nd Item Number],
            LTRIM(RTRIM(ib.[Stocking Type]))             AS [Stock Type Code]
        FROM BIQL.TbItemBranch ib WITH (NOLOCK)
        WHERE LTRIM(RTRIM(ib.[Category GL F4101])) = 'IN32'
          AND LTRIM(RTRIM(ib.[Stocking Type])) NOT IN ('O')
          AND LTRIM(RTRIM(ib.[Business Unit])) IN ('CINC', 'CIN2', 'CIN4', 'AUBA', 'AUB2', 'SING', 'SNG4')
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
