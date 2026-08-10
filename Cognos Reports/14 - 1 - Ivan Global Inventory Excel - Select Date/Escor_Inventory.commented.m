// ============================================================================
// Report 14  ·  Query object: Escor Inventory   (feeds Escor Inventory list)
// Route: EDW  ·  dbo.FactInventorySnapshot_History (dated, SCD2 as-of — REPOINTED, FIX #6)
// Cognos origin: DW_LEGACY (Escor Inventory.2.sql) — ESC5200 global bulk item only.
//
// PARAMETER: AsOfDate (mirrors ?Date? / :PQ1). Collection value 2026-07-12.
// Differences from the Inventory query (parity — do NOT "harmonise"):
//   - KG/LB dim-factor tail is a PLAIN product (no x20/x44 sentinel guard).
//   - Lot Status comes from the LOT MASTER (lot.LotStatusCode), not the position.
//   - No USD/EUR cost columns (so no FX joins, no carrier-borrow).
//   - Filter is it.ItemGlobalBulk = 'ESC5200'.
// Sort (visual): Branch Plant, Last Receipt Date. Expect 48 rows @ 2026-07-12.
// FIX 2026-07-14: SELECT DISTINCT added — identical-row fan-out from the
//   History_Filtered view (2,778 loaded vs 48 expected), same as Inventory query.
//   [Superseded by FIX #6: dbo repoint kills the fan-out; DISTINCT → GROUP BY.]
// FIX 2026-07-14 #2 (refresh loaded 64 vs 48): DimItemUOMConversionLBKG holds one
//   row per FROM-unit (UOM col) — without pinning it, every UOM row of the item
//   joins and DISTINCT keeps them (KG/LB values differ per row). One factor row
//   per item/BU now; LB/KG = per-one-primary-unit factors
//   (validated on report data: the UOM='KG' row rendered 475 LB as 1,047 LBs).
// FIX 2026-07-14 #3: factors = LB/ConversionFactorSecToPrim from the item's best
//   conversion row (primary-UOM row preferred) — see Inventory.commented.m.
// FIX 2026-07-14 #4 (PERF): OUTER APPLY and inlined ROW_NUMBER derived tables both
//   re-evaluated per outer row and hung the refresh; factors now materialized into
//   #lbf (unique clustered index) in the same batch, joined twice (exact BU / BU=''
//   fallback). EnableFolding=false so the multi-statement batch is sent verbatim.
//   Full rationale in Inventory.commented.m FIX #4.
// FIX 2026-07-14 #5: KG/LB-primary rows use CONSTANTS (KG identity / x2.20462262,
//   LB identity / x0.45359237 — proven exact vs xlsx); dim factors kept only for
//   the non-KG/LB tail, PLAIN product (no sentinel guard — parity with the Escor
//   Cognos query, which has no CASE). See Inventory.commented.m FIX #5.
// FIX 2026-07-22 #6 (SWEEP OF REPORT 18's PROBED FINDINGS — full rationale in
//   Inventory.commented.m FIX #6):
//   (a) REPOINT BIQL.FactInventorySnapshot_History_Filtered → dbo.FactInventory-
//       Snapshot_History: the view's pruned calendar spine only covers current+
//       prior month daily (month-ends before that) — an arbitrary Select Date
//       older than ~2 months would silently return nothing/month-ends. The dbo
//       table has daily intervals back to 2021-06 (R18 probe P9).
//   (b) CompanySKey=2 +1-day interval shift ported verbatim (R18 probe P13).
//   (e) GRAIN: SELECT DISTINCT → GROUP BY + SUM(KGs/LBs/QOH) — exactly Cognos'
//       Escor Inventory.2.sql shape. No FX/cost changes here (no cost columns).
// ============================================================================
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

        -- FIX #6e: GROUP BY + SUM mirrors Cognos (Escor Inventory.2.sql).
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
                -- FIX #5: constants for KG/LB primary rows; dim factors for the rest.
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
            -- FIX #6a/#6b: dbo interval match with the CompanySKey=2 +1-day shift.
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
