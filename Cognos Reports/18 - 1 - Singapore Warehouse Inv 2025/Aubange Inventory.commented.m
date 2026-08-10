// ============================================================================
// Report 18  ·  1 - Singapore Warehouse Inv 2025  ·  page table: Aubange Inventory
// Cognos query object: Aubange - Inventory  (DW_LEGACY "Inventory On Hand Star Schema")
// Route: EDW  ·  dbo.FactInventorySnapshot_History  (REPOINTED 2026-07-17, BUILD.md 14.4)
//
// WHY THE REPOINT: the earlier source BIQL.FactInventorySnapshot_History_Filtered is
//   just dbo.FactInventorySnapshot_History joined to the pruned calendar spine
//   BIQL.DimCalendarInventorySnapshot (only current+prior month daily + month-ends
//   before that). That spine is why daily snapshots vanished before 2026-05-01, so the
//   view could not supply the twice-weekly Wed/Sun (regional) / Sun+Tue+Fri (Lot Status)
//   dates the report needs back to ~2026-01. The underlying dbo table keeps DAILY
//   StartDate/StopDate intervals back to 2021-06 (probe P9). We reproduce the view's
//   own logic (obtained via OBJECT_DEFINITION, probe P13) but swap its calendar spine
//   for our own #dates list of exactly the weekday snapshots the report samples.
//
// GRAIN: one row per position PER SNAPSHOT DATE. #dates = the required snapshot dates;
//   each is matched to the SCD interval via  dt.d BETWEEN snap.StartDate AND
//   ISNULL(snap.StopDate,'9999-12-31').  Intervals are non-overlapping so no fan-out.
//   Inner derived table = row-level measures; outer = GROUP BY + SUM (mirrors the
//   Cognos GROUP BY + SUM(QOH / QOH*KGfactor / QOH*cost*FX)).
//
// COMPANY-2 TIMEZONE SHIFT (verbatim from the _Filtered view, P13): for CompanySKey=2
//   the interval is matched with dt.d + 1 day; the OUTPUT date stays dt.d. Do not remove.
//
// FX (resolved 2026-07-17, probes P11/P12): the old BIQL.DimCurrencyExchangeRates join
//   held only CHF->EUR, so every non-USD company's USD cost was silently NULL. Correct
//   live source = BIQL.DimCurrencyExchangeRatesUSDDaily: ISO CurrencyCodeFrom, per-day
//   CalendarDate (weekend-flat), DIRECT MULTIPLIER (local * [Exchange Rate] = USD).
//   USD-functional companies short-circuit to 1.0. 2026 coverage confirmed: EUR->USD to
//   7/16 (~1.1447), SGD->USD to 6/30 (~0.7725). AUD is not used (Aubange = Belgium/EUR).
//   OPEN: confirm each in-scope company's DimCompany.CurrencyCode at capture; only
//   non-USD companies (Aubange EUR) actually exercise the FX rate.
//
// KG factor: LB->KG uses the per-item DW factor from DimItemUOMConversionLBKG; the
//   physical 0.45359237 is only the ELSE fallback where the item is absent. Negative
//   QOH sentinel (* -1 * 20) preserved. Bad-snapshot blacklist dates ported verbatim.
// ============================================================================
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
