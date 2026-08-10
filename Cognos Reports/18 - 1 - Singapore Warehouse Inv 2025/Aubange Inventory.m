let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        SELECT z.ItemNumShort, z.BU, z.KGperPrim
        INTO #lbf
        FROM (
            SELECT k.ItemNumShort,
                   ISNULL(LTRIM(RTRIM(k.BusinessUnit)), '') AS BU,
                   k.KG / NULLIF(k.ConversionFactorSecToPrim, 0) AS KGperPrim,
                   ROW_NUMBER() OVER (PARTITION BY k.ItemNumShort, ISNULL(LTRIM(RTRIM(k.BusinessUnit)), '')
                                      ORDER BY CASE WHEN LTRIM(RTRIM(k.UOM)) = LTRIM(RTRIM(k.UOMPrimary)) THEN 0 ELSE 1 END,
                                               k.UOM) AS rn
            FROM BIQL.DimItemUOMConversionLBKG k
        ) z
        WHERE z.rn = 1;

        CREATE UNIQUE CLUSTERED INDEX ix_lbf ON #lbf (ItemNumShort, BU);

        SELECT d.d
        INTO #dates
        FROM (
            SELECT CAST(DATEADD(DAY, -(v.num), CAST(GETDATE() AS date)) AS date) AS d
            FROM (SELECT TOP (400) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS num FROM sys.all_objects) v
        ) d
        WHERE d.d >= CAST(GETDATE() - (365.0/3) AS date)
          AND d.d <= CAST(DATEADD(DAY, -1, GETDATE()) AS date)
          AND (DATEDIFF(DAY, '1900-01-07', d.d) % 7) IN (0, 3)
          AND d.d <> '2025-05-07'
          AND d.d <> '2024-08-21';

        CREATE UNIQUE CLUSTERED INDEX ix_dates ON #dates (d);

        SELECT
            [Inventory Date], [Branch Plant], [Global Bulk Item], [Bulk Item], [2nd Item Number],
            [Stock Type Code], [Location], [Lot Number], [Lot Status], [Master Planning Family],
            SUM([_QOH])  AS [Quantity on Hand],
            [Primary Unit of Measure],
            SUM([_KGs])  AS [Quantity on Hand KGs],
            SUM([_USD])  AS [Extended Cost for Quantity On Hand USD],
            [Weekday], [MANUFACTURING REGION]
        FROM (
            SELECT
                CAST(dt.d AS date)                                 AS [Inventory Date],
                LTRIM(RTRIM(snap.BusinessUnit))                    AS [Branch Plant],
                it.ItemGlobalBulk                                  AS [Global Bulk Item],
                it.ItemBulk                                        AS [Bulk Item],
                it.ItemNum2nd                                      AS [2nd Item Number],
                it.StockingType                                    AS [Stock Type Code],
                LTRIM(RTRIM(snap.Location))                        AS [Location],
                LTRIM(RTRIM(snap.LotNum))                          AS [Lot Number],
                snap.LotStatusCode                                 AS [Lot Status],
                it.MasterPlanningFamily                            AS [Master Planning Family],
                snap.QuantityOnHandPrimaryUOM                      AS [_QOH],
                snap.UOMPrimary                                    AS [Primary Unit of Measure],
                CASE WHEN LTRIM(RTRIM(snap.UOMPrimary)) = 'KG' THEN snap.QuantityOnHandPrimaryUOM
                     WHEN snap.QuantityOnHandPrimaryUOM * COALESCE(lbx.KGperPrim, lbb.KGperPrim) < 0
                          THEN -(snap.QuantityOnHandPrimaryUOM * COALESCE(lbx.KGperPrim, lbb.KGperPrim)) * 20
                     WHEN lbx.KGperPrim IS NOT NULL OR lbb.KGperPrim IS NOT NULL
                          THEN snap.QuantityOnHandPrimaryUOM * COALESCE(lbx.KGperPrim, lbb.KGperPrim)
                     ELSE snap.QuantityOnHandPrimaryUOM * 0.45359237 END        AS [_KGs],
                snap.QuantityOnHandPrimaryUOM
                    * CASE WHEN ISNULL(snap.AmountUnitCost, 0) <> 0 THEN snap.AmountUnitCost
                           ELSE MAX(CASE WHEN snap.ItemCostSKey <> -1 THEN snap.AmountUnitCost END)
                                    OVER (PARTITION BY dt.d, snap.ItemSKey, LTRIM(RTRIM(snap.BusinessUnit))) END
                    * CASE WHEN co.CurrencyCode = 'USD' THEN 1.0
                           ELSE fxUSD.[Exchange Rate] END                       AS [_USD],
                CASE (DATEDIFF(DAY, '1900-01-07', dt.d) % 7)
                     WHEN 0 THEN 'SUNDAY' WHEN 2 THEN 'TUESDAY'
                     WHEN 3 THEN 'WEDNESDAY' WHEN 5 THEN 'FRIDAY' END            AS [Weekday],
                CASE LTRIM(RTRIM(snap.BusinessUnit))
                     WHEN 'SING' THEN 'Singapore' WHEN 'SNG4' THEN 'Singapore'
                     WHEN 'AUBA' THEN 'Aubange'   WHEN 'AUB2' THEN 'Aubange'
                     ELSE 'Americas' END                                         AS [MANUFACTURING REGION]
            FROM #dates dt
                INNER JOIN dbo.FactInventorySnapshot_History snap
                        ON (CASE WHEN snap.CompanySKey = 2 THEN DATEADD(DAY, 1, dt.d) ELSE dt.d END)
                           BETWEEN snap.StartDate AND ISNULL(snap.StopDate, '9999-12-31')
                INNER JOIN BIQL.DimItem it     ON it.ItemSKey    = snap.ItemSKey
                INNER JOIN BIQL.DimCompany co  ON co.CompanySKey = snap.CompanySKey
                LEFT  JOIN #lbf lbx ON lbx.ItemNumShort = snap.ItemNumShort
                                   AND lbx.BU = LTRIM(RTRIM(snap.BusinessUnit))
                LEFT  JOIN #lbf lbb ON lbb.ItemNumShort = snap.ItemNumShort
                                   AND lbb.BU = ''
                LEFT  JOIN BIQL.DimCurrencyExchangeRatesUSDDaily fxUSD
                       ON fxUSD.CurrencyCodeFrom = co.CurrencyCode
                      AND fxUSD.CalendarDate = dt.d
            WHERE (snap.QuantityOnHandPrimaryUOM > 0 OR snap.ItemCostSKey <> -1)
              AND LTRIM(RTRIM(snap.BusinessUnit)) IN ('AUBA', 'AUB2')
              AND it.MasterPlanningFamily NOT IN ('H2O', 'PKG')
        ) r
        WHERE r.[_QOH] > 0
        GROUP BY [Inventory Date], [Branch Plant], [Global Bulk Item], [Bulk Item], [2nd Item Number],
                 [Stock Type Code], [Location], [Lot Number], [Lot Status], [Master Planning Family],
                 [Primary Unit of Measure], [Weekday], [MANUFACTURING REGION]
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
