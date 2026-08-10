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
            [Inventory Date], [REGION], [Branch Plant], [Global Bulk Item], [Bulk Item],
            [2nd Item Number], [Stock Type Code], [GL Class Code], [Location], [Lot Number],
            [Supplier Lot Number], [Lot Status], [Master Planning Family],
            SUM([_QOH]) AS [Quantity on Hand],
            [Primary Unit of Measure],
            SUM([_KGs]) AS [Quantity on Hand KGs],
            SUM([_LBs]) AS [Quantity on Hand LBs],
            SUM([_USD]) AS [Extended Cost for Quantity On Hand USD],
            SUM([_EUR]) AS [Extended Cost for Quantity On Hand EUR],
            [On Hand Date], [Lot Expiry Date], [Memo Lot 1], [Memo Lot 2],
            [Commodity Class Description], [Commodity Sub Class Description]
        FROM (
            SELECT
                CAST('" & AsOf & "' AS date)                        AS [Inventory Date],
                CASE LTRIM(RTRIM(snap.BusinessUnit))
                    WHEN 'CINC' THEN 'Americas' WHEN 'CIN2' THEN 'Americas' WHEN 'CIN4' THEN 'Americas'
                    WHEN 'AUBA' THEN 'Aubange'  WHEN 'AUB2' THEN 'Aubange'
                    WHEN 'SING' THEN 'Singapore' WHEN 'SNG4' THEN 'Singapore'
                    WHEN 'MUM3' THEN 'India'    WHEN 'SHAN' THEN 'China' ELSE 'ERROR' END  AS [REGION],
                LTRIM(RTRIM(snap.BusinessUnit))                     AS [Branch Plant],
                it.ItemGlobalBulk                                   AS [Global Bulk Item],
                it.ItemBulk                                         AS [Bulk Item],
                it.ItemNum2nd                                       AS [2nd Item Number],
                ib.StockType                                        AS [Stock Type Code],
                snap.CategoryGLF41021                               AS [GL Class Code],
                LTRIM(RTRIM(snap.Location))                         AS [Location],
                LTRIM(RTRIM(snap.LotNum))                           AS [Lot Number],
                lot.SupplierLotNum                                  AS [Supplier Lot Number],
                snap.LotStatusCode                                  AS [Lot Status],
                ib.MPF                                              AS [Master Planning Family],
                snap.QuantityOnHandPrimaryUOM                       AS [_QOH],
                snap.UOMPrimary                                     AS [Primary Unit of Measure],
                CASE WHEN LTRIM(RTRIM(snap.UOMPrimary)) = 'KG' THEN snap.QuantityOnHandPrimaryUOM
                     WHEN LTRIM(RTRIM(snap.UOMPrimary)) = 'LB' THEN snap.QuantityOnHandPrimaryUOM * 0.45359237
                     WHEN snap.QuantityOnHandPrimaryUOM * COALESCE(lbx.KGperPrim, lbb.KGperPrim) < 0
                          THEN -(snap.QuantityOnHandPrimaryUOM * COALESCE(lbx.KGperPrim, lbb.KGperPrim)) * 20
                     ELSE  snap.QuantityOnHandPrimaryUOM * COALESCE(lbx.KGperPrim, lbb.KGperPrim) END   AS [_KGs],
                CASE WHEN LTRIM(RTRIM(snap.UOMPrimary)) = 'LB' THEN snap.QuantityOnHandPrimaryUOM
                     WHEN LTRIM(RTRIM(snap.UOMPrimary)) = 'KG' THEN snap.QuantityOnHandPrimaryUOM * 2.20462262
                     WHEN snap.QuantityOnHandPrimaryUOM * COALESCE(lbx.LBperPrim, lbb.LBperPrim) < 0
                          THEN -(snap.QuantityOnHandPrimaryUOM * COALESCE(lbx.LBperPrim, lbb.LBperPrim)) * 44
                     ELSE  snap.QuantityOnHandPrimaryUOM * COALESCE(lbx.LBperPrim, lbb.LBperPrim) END   AS [_LBs],
                snap.QuantityOnHandPrimaryUOM
                    * CASE WHEN ISNULL(snap.AmountUnitCost, 0) <> 0 THEN snap.AmountUnitCost
                           ELSE MAX(CASE WHEN snap.ItemCostSKey <> -1 THEN snap.AmountUnitCost END)
                                    OVER (PARTITION BY snap.ItemSKey, LTRIM(RTRIM(snap.BusinessUnit))) END
                    * CASE WHEN co.CurrencyCode = 'USD' THEN 1.0
                           ELSE fxUSD.[Exchange Rate] END            AS [_USD],
                snap.QuantityOnHandPrimaryUOM
                    * CASE WHEN ISNULL(snap.AmountUnitCost, 0) <> 0 THEN snap.AmountUnitCost
                           ELSE MAX(CASE WHEN snap.ItemCostSKey <> -1 THEN snap.AmountUnitCost END)
                                    OVER (PARTITION BY snap.ItemSKey, LTRIM(RTRIM(snap.BusinessUnit))) END
                    * CASE WHEN co.CurrencyCode = 'EUR' THEN 1.0
                           WHEN co.CurrencyCode = 'USD' THEN 1.0 / NULLIF(fxEUR.[Exchange Rate], 0)
                           ELSE fxUSD.[Exchange Rate] / NULLIF(fxEUR.[Exchange Rate], 0) END  AS [_EUR],
                lot.OnHandDate                                      AS [On Hand Date],
                lot.LotExpirationDate                               AS [Lot Expiry Date],
                lot.MemoLot1                                        AS [Memo Lot 1],
                lot.MemoLot2                                        AS [Memo Lot 2],
                ib.CommodityClassDesc                               AS [Commodity Class Description],
                ib.CommoditySubClassDesc                            AS [Commodity Sub Class Description]
            FROM dbo.FactInventorySnapshot_History snap
                INNER JOIN BIQL.DimItem it        ON it.ItemSKey    = snap.ItemSKey
                INNER JOIN BIQL.DimLot  lot       ON lot.LotSKey    = snap.LotSKey
                INNER JOIN BIQL.DimCompany co     ON co.CompanySKey = snap.CompanySKey
                LEFT  JOIN #ib ib ON ib.ItemSKey = snap.ItemSKey
                                 AND ib.BU = LTRIM(RTRIM(snap.BusinessUnit))
                LEFT  JOIN #lbf lbx ON lbx.ItemNumShort = snap.ItemNumShort
                                   AND lbx.BU = LTRIM(RTRIM(snap.BusinessUnit))
                LEFT  JOIN #lbf lbb ON lbb.ItemNumShort = snap.ItemNumShort
                                   AND lbb.BU = ''
                LEFT  JOIN BIQL.DimCurrencyExchangeRatesUSDDaily fxUSD
                       ON fxUSD.CurrencyCodeFrom = co.CurrencyCode
                      AND fxUSD.CalendarDate = CAST('" & AsOf & "' AS date)
                LEFT  JOIN BIQL.DimCurrencyExchangeRatesUSDDaily fxEUR
                       ON fxEUR.CurrencyCodeFrom = 'EUR'
                      AND fxEUR.CalendarDate = CAST('" & AsOf & "' AS date)
            WHERE (CASE WHEN snap.CompanySKey = 2 THEN DATEADD(DAY, 1, CAST('" & AsOf & "' AS date))
                        ELSE CAST('" & AsOf & "' AS date) END)
                      BETWEEN snap.StartDate AND ISNULL(snap.StopDate, '9999-12-31')
              AND (snap.QuantityOnHandPrimaryUOM > 0 OR snap.ItemCostSKey <> -1)
              AND LTRIM(RTRIM(snap.BusinessUnit)) IN ('CINC','CIN2','CIN4','AUBA','AUB2','SING','SNG4','MUM3','SHAN')
              AND ib.MPF IN ('ATP','ETP','FBW','FCB','FEC','FRC','RAW','RBW','RCB','REC','RRC','RWW','TOL','WAG')
        ) r
        WHERE r.[_QOH] > 0
        GROUP BY [Inventory Date], [REGION], [Branch Plant], [Global Bulk Item], [Bulk Item],
                 [2nd Item Number], [Stock Type Code], [GL Class Code], [Location], [Lot Number],
                 [Supplier Lot Number], [Lot Status], [Master Planning Family], [Primary Unit of Measure],
                 [On Hand Date], [Lot Expiry Date], [Memo Lot 1], [Memo Lot 2],
                 [Commodity Class Description], [Commodity Sub Class Description]
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
