/* probe_J1b_unit_weight_adj.sql — report 19, follow-up to J1
   DATABASE: EDWPROD / EDW.  Run in SSMS. Export result set 2 to xlsx.

   WHAT J1 ESTABLISHED (2026-08-06):
     - BIQL.FactSalesDetail and dbo.FactSalesDetail carry IDENTICAL conversion factors.
       Section 4 returned zero rows. Switching the FROM clause fixes nothing, so
       BUILD.md §0.5's recommendation is DISPROVED. Ship dbo; the choice is moot.
     - On the target row (order 2585134 / DP680-B1): qty 4 EA, UOMTx B1,
       ConversionFactorLB = 88 -> CalcLB = 352, but Cognos says 176.
       EDW's factor is EXACTLY 2x the correct one (88 vs 44; KG 39.9165526 vs 19.958276).
     - Unit_Weight_Adj = 176 with UOM_Weight_Adj = 'LB' — i.e. the column already holds
       Cognos's answer for that row.
     - [Fix U/M] is populated on ZERO of 15,823 in-scope lines; Unit_Weight_Adj is
       populated on ALL 15,823 (1,315 distinct items).

   THE ONE OPEN QUESTION: is Unit_Weight_Adj a LINE TOTAL or a PER-UNIT weight?
   On the target row qty = 4 and the value is 176, which is the line total (per-unit
   would be 44). One row cannot settle it - the quantity might simply be 1 elsewhere.

   Section 1 answers it structurally. Section 2 produces the file to compare against
   Intake\Cognos export - tight capture 2026-08-06.xlsx (5,675 rows) end to end.
*/

------------------------------------------------------------------------------
-- 1. LINE TOTAL OR PER UNIT?
--    If Unit_Weight_Adj is a LINE TOTAL, then Unit_Weight_Adj / QuantityOrderedPrimaryUOM
--    should look like a sane per-unit weight and RatioToFactor should cluster at 0.5
--    (because EDW's factor is 2x). If it is PER UNIT, Unit_Weight_Adj itself is the
--    per-unit weight and the ratio clusters differently.
--    Read the distribution, do not read one row.
------------------------------------------------------------------------------
SELECT '1_semantics' AS probe,
       LTRIM(RTRIM(b.UOMTransaction))                               AS UOMTx,
       LTRIM(RTRIM(b.UOMPrimary))                                   AS UOMPrim,
       LTRIM(RTRIM(b.UOM_Weight_Adj))                               AS UOMWeightAdj,
       COUNT_BIG(*)                                                 AS Lines,
       -- if Unit_Weight_Adj is a line total, this is the implied per-unit weight
       CAST(AVG(b.Unit_Weight_Adj / NULLIF(b.QuantityOrderedPrimaryUOM, 0))
            AS decimal(18,6))                                       AS AvgAdjPerUnit,
       -- EDW's own stored per-unit factor, for comparison
       CAST(AVG(b.ConversionFactorLB) AS decimal(18,6))             AS AvgFactorLB,
       -- ratio of the two: 0.5 across the board = "EDW factor is 2x, adj is a line total"
       CAST(AVG((b.Unit_Weight_Adj / NULLIF(b.QuantityOrderedPrimaryUOM, 0))
                / NULLIF(b.ConversionFactorLB, 0)) AS decimal(18,6)) AS AvgRatio,
       MIN(b.Unit_Weight_Adj) AS MinAdj, MAX(b.Unit_Weight_Adj) AS MaxAdj
FROM BIQL.FactSalesDetail b WITH (NOLOCK)
WHERE b.PromisedShipmentDate >= DATEADD(DAY, -183, CAST(GETDATE() AS date))
  AND LTRIM(RTRIM(b.BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND b.QuantityOrderedPrimaryUOM > 0
GROUP BY LTRIM(RTRIM(b.UOMTransaction)), LTRIM(RTRIM(b.UOMPrimary)),
         LTRIM(RTRIM(b.UOM_Weight_Adj))
ORDER BY Lines DESC;

------------------------------------------------------------------------------
-- 2. THE COMPARISON FILE — export this sheet to xlsx and send it back.
--    Line grain, deliberately: it will be aggregated to the report's 15-key grain
--    locally and compared against all 5,675 export rows at once. That settles the
--    semantics empirically rather than by argument, and closes the +0.376%.
--    Filters mirror BUILD.md §4.5 exactly; do not "tidy" them.
------------------------------------------------------------------------------
SELECT '2_compare' AS probe,
       LTRIM(RTRIM(b.OrderCompany))            AS OrderCompany,
       LTRIM(RTRIM(b.BusinessUnit))            AS BranchPlant,
       b.OrderNum,
       b.LineNum,
       LTRIM(RTRIM(b.ItemNum2nd))              AS ItemNum2nd,
       b.OrderDate,
       b.PromisedShipmentDate,
       b.QuantityOrdered,
       b.QuantityOrderedPrimaryUOM,
       LTRIM(RTRIM(b.UOMTransaction))          AS UOMTx,
       LTRIM(RTRIM(b.UOMPrimary))              AS UOMPrim,
       b.ConversionFactorLB,
       b.ConversionFactorKG,
       b.Unit_Weight_Adj,
       LTRIM(RTRIM(b.UOM_Weight_Adj))          AS UOMWeightAdj,
       b.UnitWeight,
       LTRIM(RTRIM(b.UOMWeight))               AS UOMWeight,
       LTRIM(RTRIM(b.StatusCodeLast))          AS StatusCodeLast,
       b.SalesTableSource
FROM BIQL.FactSalesDetail b WITH (NOLOCK)
JOIN BIQL.TbItemBranch ib WITH (NOLOCK) ON ib.ItemBranchSKey = b.ItemBranchSKey
WHERE b.PromisedShipmentDate >= DATEADD(DAY, -183, CAST(GETDATE() AS date))
  AND LTRIM(RTRIM(b.BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND b.QuantityOrderedPrimaryUOM > 0
  AND LTRIM(RTRIM(b.LineType)) NOT LIKE '%F%'
  AND LTRIM(RTRIM(b.OrderType)) NOT IN ('S5','ST')
  AND LTRIM(RTRIM(b.StatusCodeLast)) NOT IN ('980','984')
  AND LTRIM(RTRIM(ib.[Master Planning Family])) LIKE '%F%'
  AND b.SalesTableSource <> 1
ORDER BY b.OrderNum, b.LineNum;
