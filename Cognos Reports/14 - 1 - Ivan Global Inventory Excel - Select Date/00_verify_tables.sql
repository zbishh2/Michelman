/* ============================================================================
   Report 14 — Ivan Global Inventory Excel (Select Date) — EDW pre-flight
   Run on the EDW connection (database EDW) before the first refresh.
   REVISED 2026-07-22 for the report-18 sweep: dbo.FactInventorySnapshot_History
   spine (CompanySKey=2 +1-day shift), DimCurrencyExchangeRatesUSDDaily FX,
   carrier-borrow cost, Cognos group-and-sum grain.
   Delivery vehicle per project rule: fold these into a probe PBIP (report 12
   PROBE\ template) or run in jumpbox SSMS — local SQL is firewalled.
   ============================================================================ */

DECLARE @AsOf date = '2026-07-12';   -- the collection-day prompt value

/* 1. All source objects reachable? -------------------------------------- */
SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE (TABLE_SCHEMA = 'dbo'  AND TABLE_NAME = 'FactInventorySnapshot_History')
   OR (TABLE_SCHEMA = 'BIQL' AND TABLE_NAME IN
        ('DimItem','DimLot','DimCompany','DimItemUOMConversionLBKG',
         'DimCurrencyExchangeRatesUSDDaily'))
ORDER BY TABLE_SCHEMA, TABLE_NAME;
-- Expect 6 rows.

/* 2. Snapshot coverage at the as-of date (incl. CompanySKey=2 shift) ----- */
SELECT COUNT(*) AS rows_asof,
       SUM(CASE WHEN CompanySKey = 2 THEN 1 ELSE 0 END) AS company2_rows
FROM dbo.FactInventorySnapshot_History snap
WHERE (CASE WHEN snap.CompanySKey = 2 THEN DATEADD(DAY, 1, @AsOf) ELSE @AsOf END)
          BETWEEN snap.StartDate AND ISNULL(snap.StopDate, '9999-12-31')
  AND snap.QuantityOnHandPrimaryUOM > 0;
-- Should be > 0 (dbo keeps daily intervals back to 2021-06 per R18 probe P9).

/* 3. Grain reconciliation vs xlsx (targets: 4,163 / 48) ------------------ */
-- 3a. Inventory Data page: count at the Cognos GROUP BY grain (target 4,163).
SELECT COUNT(*) AS inventory_data_rows
FROM (
    SELECT LTRIM(RTRIM(snap.BusinessUnit)) bp, it.ItemGlobalBulk, it.ItemBulk, it.ItemNum2nd,
           it.StockingType, snap.CategoryGLF41021, LTRIM(RTRIM(snap.Location)) loc,
           LTRIM(RTRIM(snap.LotNum)) ln, lot.SupplierLotNum, snap.LotStatusCode,
           it.MasterPlanningFamily, snap.UOMPrimary, lot.OnHandDate, lot.LotExpirationDate,
           lot.MemoLot1, lot.MemoLot2, it.CommodityClassCodesDesc, it.CommoditySubClassCodesDesc
    FROM dbo.FactInventorySnapshot_History snap
        INNER JOIN BIQL.DimItem it ON it.ItemSKey = snap.ItemSKey
        INNER JOIN BIQL.DimLot  lot ON lot.LotSKey = snap.LotSKey
    WHERE (CASE WHEN snap.CompanySKey = 2 THEN DATEADD(DAY, 1, @AsOf) ELSE @AsOf END)
              BETWEEN snap.StartDate AND ISNULL(snap.StopDate, '9999-12-31')
      AND snap.QuantityOnHandPrimaryUOM > 0
      AND LTRIM(RTRIM(snap.BusinessUnit)) IN ('CINC','CIN2','CIN4','AUBA','AUB2','SING','SNG4','MUM3','SHAN')
      AND it.MasterPlanningFamily IN ('ATP','ETP','FBW','FCB','FEC','FRC','RAW','RBW','RCB','REC','RRC','RWW','TOL','WAG')
    GROUP BY LTRIM(RTRIM(snap.BusinessUnit)), it.ItemGlobalBulk, it.ItemBulk, it.ItemNum2nd,
           it.StockingType, snap.CategoryGLF41021, LTRIM(RTRIM(snap.Location)),
           LTRIM(RTRIM(snap.LotNum)), lot.SupplierLotNum, snap.LotStatusCode,
           it.MasterPlanningFamily, snap.UOMPrimary, lot.OnHandDate, lot.LotExpirationDate,
           lot.MemoLot1, lot.MemoLot2, it.CommodityClassCodesDesc, it.CommoditySubClassCodesDesc
) g;

-- 3b. Escor Inventory page (target 48) — Cognos grain incl. lot-master cols.
SELECT COUNT(*) AS escor_inventory_rows
FROM (
    SELECT LTRIM(RTRIM(snap.BusinessUnit)) bp, it.ItemGlobalBulk, it.ItemBulk, it.ItemNum2nd,
           snap.LastReceiptDate, LTRIM(RTRIM(snap.Location)) loc, LTRIM(RTRIM(snap.LotNum)) ln,
           lot.OnHandDate, lot.LotExpirationDate, lot.SellByDate, lot.SupplierLotNum,
           lot.MemoLot1, lot.MemoLot2, lot.LotStatusCode, it.MasterPlanningFamily, snap.UOMPrimary
    FROM dbo.FactInventorySnapshot_History snap
        INNER JOIN BIQL.DimItem it ON it.ItemSKey = snap.ItemSKey
        INNER JOIN BIQL.DimLot  lot ON lot.LotSKey = snap.LotSKey
    WHERE (CASE WHEN snap.CompanySKey = 2 THEN DATEADD(DAY, 1, @AsOf) ELSE @AsOf END)
              BETWEEN snap.StartDate AND ISNULL(snap.StopDate, '9999-12-31')
      AND snap.QuantityOnHandPrimaryUOM > 0
      AND it.ItemGlobalBulk = 'ESC5200'
    GROUP BY LTRIM(RTRIM(snap.BusinessUnit)), it.ItemGlobalBulk, it.ItemBulk, it.ItemNum2nd,
           snap.LastReceiptDate, LTRIM(RTRIM(snap.Location)), LTRIM(RTRIM(snap.LotNum)),
           lot.OnHandDate, lot.LotExpirationDate, lot.SellByDate, lot.SupplierLotNum,
           lot.MemoLot1, lot.MemoLot2, lot.LotStatusCode, it.MasterPlanningFamily, snap.UOMPrimary
) g;

-- 3c. Escor Lot Details page (target 1,663 — date-independent; unchanged route).
SELECT COUNT(*) AS escor_lot_rows
FROM (
    SELECT DISTINCT LTRIM(RTRIM(lot.BusinessUnit)) bu, it.ItemBulk, it.ItemNum2nd,
           lot.ItemNumShort, LTRIM(RTRIM(lot.LotNum)) ln, lot.SupplierLotNum,
           lot.MemoLot1, lot.MemoLot2, lot.OnHandDate
    FROM BIQL.DimLot lot INNER JOIN BIQL.DimItem it ON it.ItemSKey = lot.ItemSKey
    WHERE it.ItemBulk IN ('ESC5200','ESC5200.E','ESC5200.S')
) d;

/* 4. FX sanity — USDDaily coverage at @AsOf for every in-scope currency -- */
-- R18 proved EUR (Aubange) and SGD; MUM3 (India) / SHAN (China) are R14-specific.
-- Any in-scope non-USD company currency MISSING here ⇒ NULL cost in validation.
SELECT DISTINCT co.CurrencyCode,
       fx.[Exchange Rate] AS to_usd_at_asof,
       eur.[Exchange Rate] AS eur_to_usd_at_asof
FROM dbo.FactInventorySnapshot_History snap
    INNER JOIN BIQL.DimCompany co ON co.CompanySKey = snap.CompanySKey
    LEFT  JOIN BIQL.DimCurrencyExchangeRatesUSDDaily fx
           ON fx.CurrencyCodeFrom = co.CurrencyCode AND fx.CalendarDate = @AsOf
    LEFT  JOIN BIQL.DimCurrencyExchangeRatesUSDDaily eur
           ON eur.CurrencyCodeFrom = 'EUR' AND eur.CalendarDate = @AsOf
WHERE (CASE WHEN snap.CompanySKey = 2 THEN DATEADD(DAY, 1, @AsOf) ELSE @AsOf END)
          BETWEEN snap.StartDate AND ISNULL(snap.StopDate, '9999-12-31')
  AND LTRIM(RTRIM(snap.BusinessUnit)) IN ('CINC','CIN2','CIN4','AUBA','AUB2','SING','SNG4','MUM3','SHAN')
ORDER BY co.CurrencyCode;
-- to_usd_at_asof must be non-NULL for every non-USD currency; eur_to_usd_at_asof
-- must be non-NULL (it feeds the EUR triangulation for every company).

/* 5. Carrier-borrow sanity — how many as-of lots need the borrowed cost? - */
SELECT SUM(CASE WHEN snap.ItemCostSKey = -1 AND snap.QuantityOnHandPrimaryUOM > 0 THEN 1 ELSE 0 END) AS lots_needing_borrow,
       SUM(CASE WHEN snap.ItemCostSKey = -1 AND snap.QuantityOnHandPrimaryUOM > 0
                 AND carrier.ItemSKey IS NULL THEN 1 ELSE 0 END) AS lots_with_no_carrier
FROM dbo.FactInventorySnapshot_History snap
    LEFT JOIN (
        SELECT DISTINCT s2.ItemSKey, LTRIM(RTRIM(s2.BusinessUnit)) bu
        FROM dbo.FactInventorySnapshot_History s2
        WHERE (CASE WHEN s2.CompanySKey = 2 THEN DATEADD(DAY, 1, @AsOf) ELSE @AsOf END)
                  BETWEEN s2.StartDate AND ISNULL(s2.StopDate, '9999-12-31')
          AND s2.ItemCostSKey <> -1 AND ISNULL(s2.AmountUnitCost, 0) <> 0
    ) carrier ON carrier.ItemSKey = snap.ItemSKey
             AND carrier.bu = LTRIM(RTRIM(snap.BusinessUnit))
WHERE (CASE WHEN snap.CompanySKey = 2 THEN DATEADD(DAY, 1, @AsOf) ELSE @AsOf END)
          BETWEEN snap.StartDate AND ISNULL(snap.StopDate, '9999-12-31')
  AND LTRIM(RTRIM(snap.BusinessUnit)) IN ('CINC','CIN2','CIN4','AUBA','AUB2','SING','SNG4','MUM3','SHAN');
-- lots_with_no_carrier > 0 ⇒ those lots will show NULL cost (R18's Americas
-- 100FGK-style residual); list them before deciding whether to escalate.

/* 6. Escor Lot Info 80-row gap (ADDED 2026-07-22 after the tight capture) ---
   Fresh Cognos export has 1,663 DISTINCT rows (zero dups) vs our 1,583 — 80
   ESC5200-family lots genuinely missing, 79 of them ancient (On Hand Date
   2011-2013) + 1 recent (2025-12-03). Decide: (a) lots absent from DimLot
   entirely (retention gap → reroute this one table to ODS F4108), or
   (b) present but their ItemSKey maps to a DimItem row whose ItemBulk is no
   longer ESC5200* (join/filter gap → fix the join, e.g. match on ItemNumShort
   or ItemNum2nd instead). Run both and read the verdict off the counts.     */
DECLARE @missing TABLE (BU varchar(12), LotNum varchar(30));
INSERT INTO @missing VALUES
            ('AUB2','516152'),
            ('AUB2','516154'),
            ('AUB2','516403'),
            ('AUB2','516405'),
            ('AUB2','516548'),
            ('AUB2','516550'),
            ('AUB2','516608'),
            ('AUB2','R16572'),
            ('AUB2','R16573'),
            ('AUB2','R16628'),
            ('AUBA','13C518'),
            ('AUBA','516041'),
            ('AUBA','516043'),
            ('AUBA','516045'),
            ('AUBA','516047'),
            ('AUBA','516152'),
            ('AUBA','516154'),
            ('AUBA','516403'),
            ('AUBA','516405'),
            ('AUBA','516548'),
            ('AUBA','516550'),
            ('AUBA','516608'),
            ('AUBA','526025'),
            ('AUBA','526027'),
            ('AUBA','529001'),
            ('AUBA','R16062'),
            ('AUBA','R16349'),
            ('AUBA','R16504'),
            ('AUBA','R16572'),
            ('AUBA','R16573'),
            ('AUBA','R16628'),
            ('CIN2','514956'),
            ('CIN2','517379'),
            ('CIN2','616054'),
            ('CINC','514956'),
            ('CINC','517379'),
            ('CINC','R16349'),
            ('SING','13C515'),
            ('SING','515460'),
            ('SING','516496'),
            ('SING','516497'),
            ('SING','516498'),
            ('SING','516581'),
            ('SING','516582'),
            ('SING','516583'),
            ('SING','516584'),
            ('SING','516585'),
            ('SING','516586'),
            ('SING','516587'),
            ('SING','516588'),
            ('SING','517017'),
            ('SING','517236'),
            ('SING','517515'),
            ('SING','517516'),
            ('SING','517517'),
            ('SING','517518'),
            ('SING','517743'),
            ('SING','517744'),
            ('SING','518505'),
            ('SING','518506'),
            ('SING','518507'),
            ('SING','518508'),
            ('SING','519106'),
            ('SING','519107'),
            ('SING','519108'),
            ('SING','519109'),
            ('SING','519110'),
            ('SING','519111'),
            ('SING','520049'),
            ('SING','520050'),
            ('SING','520538'),
            ('SING','520539'),
            ('SING','522647'),
            ('SING','522886'),
            ('SING','523273'),
            ('SING','524160'),
            ('SING','524663'),
            ('SING','525235'),
            ('SING','526606'),
            ('SING','526607');

-- 6a. Verdict counts: how many of the 80 are in DimLot at all, and of those,
--     what ItemBulk does their ItemSKey resolve to?
SELECT COUNT(*)                                            AS in_dimlot,
       SUM(CASE WHEN it.ItemBulk IN ('ESC5200','ESC5200.E','ESC5200.S')
                THEN 1 ELSE 0 END)                         AS itembulk_still_esc,
       SUM(CASE WHEN it.ItemSKey IS NULL THEN 1 ELSE 0 END) AS itemskey_unresolved
FROM @missing m
    INNER JOIN BIQL.DimLot lot
        ON  LTRIM(RTRIM(lot.BusinessUnit)) = m.BU
        AND LTRIM(RTRIM(lot.LotNum))       = m.LotNum
    LEFT JOIN BIQL.DimItem it ON it.ItemSKey = lot.ItemSKey;
-- in_dimlot = 0            ⇒ retention gap: reroute Escor Lot Info to ODS F4108.
-- in_dimlot = 80, esc < 80 ⇒ join/filter gap: inspect 6b and re-key the join.

-- 6b. Detail for whatever resolves — what do these lots look like in EDW?
SELECT m.BU, m.LotNum, lot.ItemSKey, lot.ItemNumShort, lot.OnHandDate,
       it.ItemBulk, it.ItemNum2nd, it.ItemGlobalBulk
FROM @missing m
    INNER JOIN BIQL.DimLot lot
        ON  LTRIM(RTRIM(lot.BusinessUnit)) = m.BU
        AND LTRIM(RTRIM(lot.LotNum))       = m.LotNum
    LEFT JOIN BIQL.DimItem it ON it.ItemSKey = lot.ItemSKey
ORDER BY m.BU, m.LotNum;

-- ============================================================================
-- §7  SSAS-PERSPECTIVE ROUTING PROBES (2026-07-22) — can report 14 live on the
--     BIQLTabular_v2 "Inventory Snapshot" perspective instead of our dbo queries?
--     The SSAS fact = BIQL.TbInventorySnapshotFCR_Detail keyed to
--     BIQL.TbCalendarSnapshot; all sources are BIQL views on EDWPROD, so these
--     are plain T-SQL (SSMS on the jumpbox), no SSAS access needed.
-- ============================================================================

-- 7a. THE DECIDER — date coverage of the SSAS calendar spine.
--     R18 proved BIQL.DimCalendarInventorySnapshot keeps only current+prior
--     month daily (month-ends before that). If TbCalendarSnapshot is the same
--     prune, SSAS can only "Select Date" ~2 months back; older = month-ends.
SELECT TOP 5 * FROM BIQL.TbCalendarSnapshot;   -- confirm the date column name first
SELECT YEAR(CalendarDate) AS yr, MONTH(CalendarDate) AS mo,
       COUNT(DISTINCT CalendarDate) AS dates_in_month,
       MIN(CalendarDate) AS first_date, MAX(CalendarDate) AS last_date
FROM BIQL.TbCalendarSnapshot
GROUP BY YEAR(CalendarDate), MONTH(CalendarDate)
ORDER BY yr, mo;

-- 7b. Fact parity @ a RECENT date (pick yesterday; also answers the company-2
--     +1-day question for the SSAS route): row/QOH per BU, CostMethod fan-out.
DECLARE @d date = DATEADD(DAY, -1, CAST(GETDATE() AS date));
SELECT LTRIM(RTRIM(f.BusinessUnit)) AS bu,
       COUNT(*) AS rows_all_costmethods,
       COUNT(DISTINCT CONCAT(f.ItemNumShort,'|',f.Location,'|',f.LotNum)) AS positions,
       SUM(f.QuantityOnHandPrimaryUOM) AS qoh_summed_all_costmethods
FROM BIQL.TbInventorySnapshotFCR_Detail f
WHERE f.CalendarDate = @d
  AND LTRIM(RTRIM(f.BusinessUnit)) IN ('CINC','CIN2','CIN4','AUBA','AUB2','SING','SNG4','MUM3','SHAN')
GROUP BY LTRIM(RTRIM(f.BusinessUnit))
ORDER BY bu;
-- Compare positions/QOH against the dbo interval query at the same @d.
-- NOTE: FCR fact carries one row per CostMethod (SSAS measures divide by
-- DISTINCTCOUNT(CostMethod)) — 'positions' is the comparable number, not rows.

-- 7c. The 80 Cognos-only lots in the SSAS Lot view (F4108 lineage — may well
--     retain what BIQL.DimLot lost; if so, SSAS ALSO fixes the Lot Info gap).
--     Re-declare @missing from §6, then:
-- SELECT m.bu, m.lot,
--        (SELECT COUNT(*) FROM BIQL.TbLot t
--          WHERE LTRIM(RTRIM(t.LotNum)) = m.lot
--            AND LTRIM(RTRIM(t.BusinessUnit)) = m.bu) AS in_tblot
-- FROM @missing m ORDER BY m.bu, m.lot;
-- (check TbLot's actual column names with SELECT TOP 5 * first)

-- 7d. Region decode — does Branch's category code match the report's regions?
SELECT MCMCU, MCRP02, (SELECT DRDL01 FROM PRODCTL.F0005 u
                        WHERE LTRIM(RTRIM(u.DRSY))='01' AND LTRIM(RTRIM(u.DRRT))='02'
                          AND LTRIM(RTRIM(u.DRKY)) = LTRIM(RTRIM(b.MCRP02))) AS region_desc
FROM BIQL.TbBranch b   -- or query the Branch view; fallback: F0006 via ODS
WHERE LTRIM(RTRIM(MCMCU)) IN ('CINC','CIN2','CIN4','AUBA','AUB2','SING','SNG4','MUM3','SHAN');
-- Expected report values: Americas/Aubange/Singapore/India/China. If the DW
-- category codes differ, the region CASE stays report-side (fine either way).

-- 7e. EUR rate basis — SSAS uses TbCurrencyRates.ToRateDaily with a direct
--     local->EUR relationship (CurrencyBSKey), i.e. Oracle's approach, NOT our
--     USD triangulation. Spot-check a date both sources cover:
SELECT * FROM BIQL.TbCurrencyRates
WHERE CalendarDate = '2026-07-12'
  AND (CurrencyCodeTo IN ('EUR','USD') OR ToCode IN ('EUR','USD'));
-- Compare EUR rates vs BIQL.DimCurrencyExchangeRatesUSDDaily triangulation.
