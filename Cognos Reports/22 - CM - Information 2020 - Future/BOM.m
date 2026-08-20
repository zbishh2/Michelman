let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
SET NOCOUNT ON;
SELECT
    LTRIM(RTRIM(b.Branch))                      AS [Branch Plant],
    LTRIM(RTRIM(pib.ItemNum2nd))                AS [Parent Second Item Number],
    LTRIM(RTRIM(ib.ItemNum2nd))                 AS [2nd Item Number],
    LTRIM(RTRIM(ib.ItemBulk))                   AS [Bulk Item],
    LTRIM(RTRIM(ib.ItemGlobalBulk))             AS [Global Bulk Item],
    b.QuantityStandardRequired / 100.0          AS [Quantity (Line)]
FROM BIQL.DimBillOfMaterial b
JOIN BIQL.DimItemBranch ib
    ON ib.ItemBranchSKey = b.ComponentItemBranchSKey
LEFT JOIN BIQL.DimItemBranch pib
    ON pib.ItemBranchSKey = b.ParentItemBranchSKey
WHERE b.TypeBillofMaterial = N'M'
  AND b.EffectiveThruDate >= CAST(GETDATE() AS date)
  AND LTRIM(RTRIM(ib.ItemBulk)) IN (N'161017CX', N'161190PX', N'171143PX', N'171228PX.E', N'181020CX.E', N'181136IX', N'181192IX', N'181193EU.E', N'191011CX', N'191026CX.E', N'191245PX', N'23409A', N'ABEX2525', N'APT10', N'APT11', N'DMAEMA', N'EMA3065', N'ET2012.E', N'ET2022.E', N'ET4075.E', N'ET440.E', N'FERSUL7W', N'HP1432AT', N'HP1632', N'MD4020', N'MD4020C', N'MD4020S', N'MD4021', N'MD4021C', N'MD4021S', N'MD4022', N'MD4022C', N'MD4023', N'MD4023C', N'MDU20', N'MDU2012.E', N'MDU2012B.E', N'MDU4075.E', N'MDU4075B.E', N'MDU440.E', N'MDU440B.E', N'MPEG2000', N'MW40504', N'MW40514', N'NP4LF', N'NP4LF.S', N'OMS', N'PUD1.E', N'STODSO', N'U1001', N'U101', N'U201', N'U2022', N'U2022EU.E', N'U2023', N'U204', N'U204EU.E', N'U470', N'U501', N'U501B', N'U502', N'U502.E', N'U502X1.E', N'U601', N'U701', N'U802', N'U802.E', N'WAV501', N'WD40', N'WD40T')
  AND LTRIM(RTRIM(b.Branch)) NOT IN (N'LABO', N'LABS', N'LABA')
",
        null,
        [EnableFolding = false]
    )
in
    Data
