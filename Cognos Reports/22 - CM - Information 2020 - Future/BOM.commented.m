// ============================================================================
// Report 22 - "CM - Information 2020 - Future" - BOM (sheet 5 of 6)
// COMMENTED MASTER. The shipped file is "BOM.m" (comment-free, repo rule
// CLAUDE.md). Maintain the two in parallel; the code must stay byte-identical.
//
// Cognos: BILL_OF_MATERIAL x ITEM (component) x ITEM (parent), type M, current
// effective rows, 70-bulk list on the component, LAB branches excluded,
// grouped on (branch, parent 2nd, component 2nd) summing QUANTITY.
//
// Source is EDWPROD / EDW BIQL.DimBillOfMaterial - the ONE table in this report
// that steps down the source ladder. BIQLTabular carries 'Bill Of Material
// Expanded' but it holds no rows in production (PROBE/13_bom_lines.dax: 0 rows;
// 13b/13c diagnostics). The EDW dependency is documented in BUILD.md and
// COLLECTION_NOTES.md.
//
// Tie-out (PROBE/FINDINGS.md): 160 keys = Cognos 160, Quantity 14,667.32 exact
// on every key. Quantity is QuantityStandardRequired / 100 (JDE's implied two
// decimals); 2 keys carry 2 rows each and Cognos sums them too.
//
// EDW traps: column names are case-sensitive (TypeBillofMaterial, lower-case
// 'of'); Branch is nchar and right-aligned so every code is LTRIM(RTRIM()).
// ============================================================================
let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
SET NOCOUNT ON;
SELECT
    -- nchar, right-aligned in EDW.
    LTRIM(RTRIM(b.Branch))                      AS [Branch Plant],
    LTRIM(RTRIM(pib.ItemNum2nd))                AS [Parent Second Item Number],
    LTRIM(RTRIM(ib.ItemNum2nd))                 AS [2nd Item Number],
    LTRIM(RTRIM(ib.ItemBulk))                   AS [Bulk Item],
    LTRIM(RTRIM(ib.ItemGlobalBulk))             AS [Global Bulk Item],
    -- JDE implied two decimals; Cognos QUANTITY.
    b.QuantityStandardRequired / 100.0          AS [Quantity (Line)]
FROM BIQL.DimBillOfMaterial b
JOIN BIQL.DimItemBranch ib
    ON ib.ItemBranchSKey = b.ComponentItemBranchSKey
-- Parent item; LEFT so a parent missing from the dimension does not drop the row.
LEFT JOIN BIQL.DimItemBranch pib
    ON pib.ItemBranchSKey = b.ParentItemBranchSKey
-- Manufacturing bills; column name is case-sensitive, lower-case 'of'.
WHERE b.TypeBillofMaterial = N'M'
  -- Current rows only, as Cognos's sysdate test.
  AND b.EffectiveThruDate >= CAST(GETDATE() AS date)
  -- The 70-bulk list on the COMPONENT item.
  AND LTRIM(RTRIM(ib.ItemBulk)) IN (N'161017CX', N'161190PX', N'171143PX', N'171228PX.E', N'181020CX.E', N'181136IX', N'181192IX', N'181193EU.E', N'191011CX', N'191026CX.E', N'191245PX', N'23409A', N'ABEX2525', N'APT10', N'APT11', N'DMAEMA', N'EMA3065', N'ET2012.E', N'ET2022.E', N'ET4075.E', N'ET440.E', N'FERSUL7W', N'HP1432AT', N'HP1632', N'MD4020', N'MD4020C', N'MD4020S', N'MD4021', N'MD4021C', N'MD4021S', N'MD4022', N'MD4022C', N'MD4023', N'MD4023C', N'MDU20', N'MDU2012.E', N'MDU2012B.E', N'MDU4075.E', N'MDU4075B.E', N'MDU440.E', N'MDU440B.E', N'MPEG2000', N'MW40504', N'MW40514', N'NP4LF', N'NP4LF.S', N'OMS', N'PUD1.E', N'STODSO', N'U1001', N'U101', N'U201', N'U2022', N'U2022EU.E', N'U2023', N'U204', N'U204EU.E', N'U470', N'U501', N'U501B', N'U502', N'U502.E', N'U502X1.E', N'U601', N'U701', N'U802', N'U802.E', N'WAV501', N'WD40', N'WD40T')
  -- Cognos excludes the three LAB branches.
  AND LTRIM(RTRIM(b.Branch)) NOT IN (N'LABO', N'LABS', N'LABA')
",
        null,
        [EnableFolding = false]
    )
in
    Data
