let
    Source = Sql.Database("EDWPROD", "EDW"),
    AsOf   = Date.ToText(AsOfDate, "yyyy-MM-dd"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        SELECT z.ItemNumShort, z.BU, z.KGperPrim, z.LBperPrim
        INTO #lbf
        FROM (
            SELECT k.ItemNumShort,
                   ISNULL(LTRIM(RTRIM(k.BusinessUnit)), '') AS BU,
                   k.KG / NULLIF(k.ConversionFactorSecToPrim, 0) AS KGperPrim,
                   k.LB / NULLIF(k.ConversionFactorSecToPrim, 0) AS LBperPrim,
                   ROW_NUMBER() OVER (PARTITION BY k.ItemNumShort, ISNULL(LTRIM(RTRIM(k.BusinessUnit)), '')
                                      ORDER BY CASE WHEN LTRIM(RTRIM(k.UOM)) = LTRIM(RTRIM(k.UOMPrimary)) THEN 0 ELSE 1 END,
                                               k.UOM) AS rn
            FROM BIQL.DimItemUOMConversionLBKG k
        ) z
        WHERE z.rn = 1;

        CREATE UNIQUE CLUSTERED INDEX ix_lbf ON #lbf (ItemNumShort, BU);

        SELECT z.ItemSKey, z.BU, z.StockType, z.MPF, z.CommodityClassDesc, z.CommoditySubClassDesc
        INTO #ib
        FROM (
            SELECT ib.ItemSKey,
                   ISNULL(LTRIM(RTRIM(ib.[Business Unit])), '') AS BU,
                   ib.[Stocking Type]                  AS StockType,
                   ib.[Master Planning Family]         AS MPF,
                   ib.[Commodity Class Codes Desc]     AS CommodityClassDesc,
                   ib.[Commodity Sub Class Codes Desc] AS CommoditySubClassDesc,
                   ROW_NUMBER() OVER (PARTITION BY ib.ItemSKey, ISNULL(LTRIM(RTRIM(ib.[Business Unit])), '')
                                      ORDER BY ib.ItemBranchSKey) AS rn
            FROM BIQL.TbItemBranch ib
        ) z
        WHERE z.rn = 1;

        CREATE UNIQUE CLUSTERED INDEX ix_ib ON #ib (ItemSKey, BU);

        SELECT
            [Inventory Date], [Branch Plant], [Global Bulk Item], [Bulk Item], [2nd Item Number],
            [Last Receipt Date], [Location], [Lot Number], [On Hand Date], [Lot Expiry Date],
            [Sell by Date], [Supplier Lot Number], [Memo Lot 1], [Memo Lot 2], [Lot Status],
            [Master Planning Family],
            SUM([_KGs]) AS [Quantity on Hand KGs],
            SUM([_LBs]) AS [Quantity on Hand LBs],
            SUM([_QOH]) AS [Quantity on Hand],
            [Primary Unit of Measure]
        FROM (
            SELECT
                CAST('" & AsOf & "' AS date)                        AS [Inventory Date],
                LTRIM(RTRIM(snap.BusinessUnit))                     AS [Branch Plant],
                it.ItemGlobalBulk                                   AS [Global Bulk Item],
                it.ItemBulk                                         AS [Bulk Item],
                it.ItemNum2nd                                       AS [2nd Item Number],
                snap.LastReceiptDate                                AS [Last Receipt Date],
                LTRIM(RTRIM(snap.Location))                         AS [Location],
                LTRIM(RTRIM(snap.LotNum))                           AS [Lot Number],
                lot.OnHandDate                                      AS [On Hand Date],
                lot.LotExpirationDate                               AS [Lot Expiry Date],
                lot.SellByDate                                      AS [Sell by Date],
                lot.SupplierLotNum                                  AS [Supplier Lot Number],
                lot.MemoLot1                                        AS [Memo Lot 1],
                lot.MemoLot2                                        AS [Memo Lot 2],
                lot.LotStatusCode                                   AS [Lot Status],
                ib.MPF                                              AS [Master Planning Family],
                CASE WHEN LTRIM(RTRIM(snap.UOMPrimary)) = 'KG' THEN snap.QuantityOnHandPrimaryUOM
                     WHEN LTRIM(RTRIM(snap.UOMPrimary)) = 'LB' THEN snap.QuantityOnHandPrimaryUOM * 0.45359237
                     ELSE snap.QuantityOnHandPrimaryUOM * COALESCE(lbx.KGperPrim, lbb.KGperPrim) END  AS [_KGs],
                CASE WHEN LTRIM(RTRIM(snap.UOMPrimary)) = 'LB' THEN snap.QuantityOnHandPrimaryUOM
                     WHEN LTRIM(RTRIM(snap.UOMPrimary)) = 'KG' THEN snap.QuantityOnHandPrimaryUOM * 2.20462262
                     ELSE snap.QuantityOnHandPrimaryUOM * COALESCE(lbx.LBperPrim, lbb.LBperPrim) END  AS [_LBs],
                snap.QuantityOnHandPrimaryUOM                       AS [_QOH],
                snap.UOMPrimary                                     AS [Primary Unit of Measure]
            FROM dbo.FactInventorySnapshot_History snap
                INNER JOIN BIQL.DimItem it   ON it.ItemSKey = snap.ItemSKey
                INNER JOIN BIQL.DimLot  lot  ON lot.LotSKey = snap.LotSKey
                LEFT  JOIN #ib ib ON ib.ItemSKey = snap.ItemSKey
                                 AND ib.BU = LTRIM(RTRIM(snap.BusinessUnit))
                LEFT  JOIN #lbf lbx ON lbx.ItemNumShort = snap.ItemNumShort
                                   AND lbx.BU = LTRIM(RTRIM(snap.BusinessUnit))
                LEFT  JOIN #lbf lbb ON lbb.ItemNumShort = snap.ItemNumShort
                                   AND lbb.BU = ''
            WHERE (CASE WHEN snap.CompanySKey = 2 THEN DATEADD(DAY, 1, CAST('" & AsOf & "' AS date))
                        ELSE CAST('" & AsOf & "' AS date) END)
                      BETWEEN snap.StartDate AND ISNULL(snap.StopDate, '9999-12-31')
              AND snap.QuantityOnHandPrimaryUOM > 0
              AND it.ItemGlobalBulk = 'ESC5200'
        ) r
        GROUP BY [Inventory Date], [Branch Plant], [Global Bulk Item], [Bulk Item], [2nd Item Number],
                 [Last Receipt Date], [Location], [Lot Number], [On Hand Date], [Lot Expiry Date],
                 [Sell by Date], [Supplier Lot Number], [Memo Lot 1], [Memo Lot 2], [Lot Status],
                 [Master Planning Family], [Primary Unit of Measure]
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
