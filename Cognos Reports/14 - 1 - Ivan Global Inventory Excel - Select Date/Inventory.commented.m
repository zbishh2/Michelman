// ============================================================================
// Report 14  ·  Query object: Inventory   (feeds Summary crosstab + Inventory Data list)
// Route: EDW  ·  dbo.FactInventorySnapshot_History (dated, SCD2 as-of — REPOINTED, FIX #6)
// Cognos origin: DW_LEGACY "Inventory On Hand Star Schema" (Inventory.0/.1.sql)
//
// PARAMETER: AsOfDate (type date) mirrors the Cognos ?Date? prompt (:PQ1).
//   Collection-day value was 2026-07-12. Do NOT hard-code it.
//
// No CTEs / no ORDER BY; with EnableFolding=false the text is sent verbatim as a
//   batch (see FIX #4). Sorts live in the visual.
//
// FIX 2026-07-14: SELECT DISTINCT added. First refresh returned ~71 byte-identical
//   copies per row (292,448 vs expected ~4,163; distinct grain = 4,119) — the
//   History_Filtered view emits multiple identical rows inside the as-of window
//   and Cognos deduped at render (repo gotcha #2). Same fix on Escor Inventory;
//   Escor Lot Info already had DISTINCT.  [Superseded by FIX #6: the dbo repoint
//   removes the view fan-out at the source, and DISTINCT is replaced by the
//   Cognos-faithful GROUP BY + SUM.]
// FIX 2026-07-14 #2 (post-DISTINCT refresh still 2x: 8,282 vs 4,119 distinct on
//   BP+Item+Loc+Lot, and both cost columns 100% blank):
//   (a) DimItemUOMConversionLBKG holds one row per FROM-unit (UOM col); without
//       pinning it every UOM row joins and survives DISTINCT because KG/LB differ
//       (a 475-LB lot also appeared converted as 475 KG etc.). Join now requires
//       one factor row per item/BU → LB/KG are per-one-primary-unit factors.
//   (b) DimCurrencyExchangeRates has no same-currency identity row, so USD
//       companies (all of Americas) never matched fxUSD and cost went NULL.
//       Cost expressions now use factor 1.0 when co.CurrencyCode is already the
//       target currency, else the FX divisor as before.  [FX source itself
//       replaced in FIX #6 — the dim only holds CHF→EUR.]
// FIX 2026-07-14 #3: pinning lbkg.UOM = UOMPrimary killed the fan-out but left LBs
//   on only 414/4,119 rows — the dim mostly stores SECONDARY-unit rows and rarely
//   an identity row for the primary unit. Robust form: per-primary-unit factors =
//   LB/ConversionFactorSecToPrim from the item's best conversion row (1 DR = 475 LB
//   and 1 DR = 475 primary-LB => ratio 1; algebra holds for any unit row).
// FIX 2026-07-14 #4 (PERF — the one that matters): both prior shapes of that lookup
//   hung the jumpbox refresh >15 min:
//     - v1: correlated OUTER APPLY TOP 1 → executed per ~292k pre-DISTINCT rows.
//     - v2: ROW_NUMBER()=1 derived tables → SQL Server INLINES derived tables (never
//       materializes them), so the optimizer re-evaluated the windowed subquery per
//       outer row — same correlated disaster, different syntax.
//   Fix: materialize the factors into a #temp table (#lbf, one row per item+BU,
//   unique clustered index) in the same batch, then two cheap indexed LEFT JOINs
//   (lbx = exact BU, lbb = BU='' fallback, factors = COALESCE(lbx, lbb)).
//   Requires EnableFolding=false so Value.NativeQuery sends the multi-statement
//   batch verbatim (proven pattern: R12 probe PBIP's dynamic-SQL table). SET
//   NOCOUNT ON keeps rowcount messages out of the result stream. No downstream
//   M steps exist, so losing folding costs nothing.
// FIX 2026-07-14 #5 (validated vs xlsx by UOM): KG/LB-primary rows (4,056 of
//   4,119) now use CONSTANTS — Cognos data proves LB rows are identity LBs
//   (sum LBs = sum QOH exactly) and KG rows are x2.20462262; the dim lookup was
//   missing 809 KG items + 10 LB items and is only kept for the ELSE branch
//   (EA/GM, 63 rows). ALSO: the Oracle CASE guard is NOT a negative-quantity
//   guard — DW stores CONVERSION_FACTOR_KG/LB = -1 as a "no conversion" sentinel
//   and the guard converts sentinel rows to 20 KG / 44 LB per unit (proven:
//   ETHAL.S 8,520 GM -> 170,400 KGs / 374,880 LBs in the xlsx = exactly x20/x44).
// FIX 2026-07-22 #6 (SWEEP OF REPORT 18's PROBED FINDINGS — R18 BUILD.md §14.4 +
//   round-6 cost fix; supersedes the old FX/coverage TODOs and the retired
//   Probe-R14-FX-Factors.ps1 reference):
//   (a) REPOINT BIQL.FactInventorySnapshot_History_Filtered → dbo.FactInventory-
//       Snapshot_History. The _Filtered view is just the dbo table joined to the
//       pruned calendar spine BIQL.DimCalendarInventorySnapshot (current+prior
//       month daily, month-ends before that) — an arbitrary "Select Date" would
//       silently miss daily positions older than ~2 months. The dbo table keeps
//       DAILY StartDate/StopDate intervals back to 2021-06 (R18 probe P9), and
//       R18 proved the direct interval join reproduces the view row-for-row on
//       shared dates. Interval match = @AsOf BETWEEN StartDate AND
//       ISNULL(StopDate,'9999-12-31'); intervals are non-overlapping, no fan-out.
//   (b) COMPANY-2 TIMEZONE SHIFT ported verbatim from the view definition (R18
//       probe P13): CompanySKey=2 rows match the interval at @AsOf + 1 day; the
//       OUTPUT date stays @AsOf. Do not remove.
//   (c) FX: BIQL.DimCurrencyExchangeRates holds ONLY CHF→EUR rows (R18 probes
//       P11/P12) — every non-USD company's USD cost was silently NULL. Live
//       source = BIQL.DimCurrencyExchangeRatesUSDDaily: ISO CurrencyCodeFrom,
//       per-day CalendarDate (weekend-flat), DIRECT MULTIPLIER
//       (local × [Exchange Rate] = USD). USD-functional companies (SING/SNG4/
//       CIN*, per R18) short-circuit to 1.0; Aubange is EUR-functional.
//       EUR cost (this report only — R18 had no EUR column) is TRIANGULATED:
//       local→EUR = (local→USD) / (EUR→USD), identity 1.0 for EUR companies.
//       VERIFY vs xlsx: Oracle used a direct local→EUR '-' rate; triangulation
//       through USD can differ in the 4th decimal. Also VERIFY MUM3/SHAN
//       (INR/CNY→USD) coverage in USDDaily — R18 only proved EUR + SGD.
//   (d) CARRIER-BORROW for ItemCostSKey = -1 lots (R18 round-6, validated to the
//       penny on Singapore): where the lot's embedded AmountUnitCost = 0, borrow
//       the item/branch standard cost from a sibling snapshot row (the zero-qty
//       blank-lot cost carrier) via MAX(...) OVER (PARTITION BY item, branch).
//       Inner filter widened QOH>0 → (QOH>0 OR ItemCostSKey<>-1) so carriers
//       enter the window; outer WHERE [_QOH] > 0 drops them again before
//       GROUP BY — rows/QOH/KGs/LBs unchanged, only cost columns move.
//   (e) GRAIN: SELECT DISTINCT → derived-table + GROUP BY + SUM of QOH/KGs/LBs/
//       USD/EUR — exactly Cognos' Inventory.1.sql shape (sum() over the same
//       group keys; the r17 RULE B lesson). DISTINCT kept multi-row groups as
//       separate rows (distinct 4,119 vs xlsx 4,163) and would have miscounted
//       any group Cognos sums. Group keys = every non-aggregated output column.
// ============================================================================
let
    Source = Sql.Database("EDWPROD", "EDW"),
    AsOf   = Date.ToText(AsOfDate, "yyyy-MM-dd"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        -- FIX #4: factors materialized ONCE. BU normalized NULL->'' so the blank-BU
        -- fallback rows form their own partition; rn=1 prefers the primary-UOM row.
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

        -- Branch-grain item attributes (F4102 grain). Cognos's Oracle warehouse stamps these on the
        -- inventory row / resolves ITEM per branch; EDW's DimItem is item-master grain and disagrees on
        -- ~2,200 rows (RRC/RCB/REC vs RAW, F-families vs ETP/ATP). BIQL.TbItemBranch = the branch-grain
        -- source (same object the BIQLTabular_v2 cube loads as 'Item Branch'). Deduped defensively;
        -- materialized as #temp per the report-14 rule (inline ROW_NUMBER derived tables hung this query).
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

        -- FIX #6e: outer GROUP BY + SUM mirrors Cognos (Inventory.1.sql sums QOH,
        -- KGs, LBs, USD, EUR over these exact group keys).
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
                -- FIX #5: constants for KG/LB primary rows (exact per Cognos); dim factors
                -- only for the EA/GM tail, with the ported x20/x44 sentinel guard.
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
                -- FIX #6c/#6d: unit cost = own AmountUnitCost, else the item/branch
                -- carrier cost (ItemCostSKey=-1 lots); FX = USDDaily direct multiplier.
                snap.QuantityOnHandPrimaryUOM
                    * CASE WHEN ISNULL(snap.AmountUnitCost, 0) <> 0 THEN snap.AmountUnitCost
                           ELSE MAX(CASE WHEN snap.ItemCostSKey <> -1 THEN snap.AmountUnitCost END)
                                    OVER (PARTITION BY snap.ItemSKey, LTRIM(RTRIM(snap.BusinessUnit))) END
                    * CASE WHEN co.CurrencyCode = 'USD' THEN 1.0
                           ELSE fxUSD.[Exchange Rate] END            AS [_USD],
                -- FIX #6c: EUR triangulated through USD (VERIFY vs xlsx — Oracle used
                -- a direct local->EUR rate).
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
            -- FIX #6a/#6b: dbo interval match with the CompanySKey=2 +1-day shift.
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
