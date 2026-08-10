-- 07e: OH USD cost-basis probe (run on jumpbox SSMS vs ODSPROD) — decides WHO is right on D-14a.
-- Every disagreeing item+branch carries ONE constant cognos/model cost ratio (325/325 groups),
-- i.e. two internally-consistent cost bases. JDE F4105 is the truth: list every cost method's
-- unit cost for the headline disagreeing items and see which method each side matches.
--   EDW model implied costs: ESC5200.S@SNG4 = 3.29/KG-ish (72,380/22,000); Cognos = 4.09 (89,980/22,000, ratio 1.2432)
--   TWN60NK@CIN2: Cognos 30,257.88, we 0 (no carrier to borrow?) | MFHS4200.S-PD@MUM3: we 33,293.19, Cognos 0
-- COUNCS has 4 implied decimals -> /10000.0. COLEDG = cost method ('01' last-in, '02' wtd avg, '07' std, ...).
SELECT  LTRIM(RTRIM(c.COMCU))  AS BranchPlant,
        LTRIM(RTRIM(im.IMLITM)) AS Item2nd,
        LTRIM(RTRIM(c.COLOTN)) AS LotNumber,      -- blank = item/branch-level cost row
        LTRIM(RTRIM(c.COLEDG)) AS CostMethod,
        c.COUNCS / 10000.0     AS UnitCost,
        LTRIM(RTRIM(ib.IBCSIN)) AS BranchSalesInvCostMethod   -- F4102: which method inventory uses here
FROM    PRODDTA.F4105 c
JOIN    PRODDTA.F4101 im ON im.IMITM = c.COITM
LEFT JOIN PRODDTA.F4102 ib ON ib.IBITM = c.COITM AND ib.IBMCU = c.COMCU
WHERE   LTRIM(RTRIM(im.IMLITM)) IN
        ('ESC5200.S','TWN60NK','MFHS4200.S-PD','CARN1.S','MFR1924A-KP','NYS2101-T2','PK265D-T3','BRIJS20US.S','DPV9200.E-B1','PHADAN05311.S')
ORDER BY Item2nd, BranchPlant, CostMethod, LotNumber;
-- Verdict key:
--   Our implied cost == the F4102.IBCSIN method's F4105 row  -> EDW is right, Cognos reads a stale/other method -> disclosure.
--   Cognos implied cost == that method                       -> EDW AmountUnitCost is wrong/stale -> escalate to DW owner.
--   Both match DIFFERENT methods                             -> basis choice, business decision which to show.
-- MUM3 FX subcase (all 90 MUM3 rows uniform ratio 0.998): local INR costs agree, only the INR->USD
-- rate differs by 0.2% — cross-check DimCurrencyExchangeRatesUSDDaily INR @7/21 vs the F4105 INR
-- cost x rate chain; this is rate-source/date, not unit cost.
