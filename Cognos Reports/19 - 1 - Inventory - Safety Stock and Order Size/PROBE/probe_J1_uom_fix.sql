/* probe_J1_uom_fix.sql — report 19, jumpbox item J1
   DATABASE: EDWPROD / EDW.  Run in SSMS, return all result sets.

   REVISED 2026-08-06 after a first run failed with "Invalid column name 'FSDSKey'".
   Cause: FSDSKey exists ONLY on BIQL.FactSalesDetail_UOM_Fix and dbo.FactSalesHistory_UOM_Fix
   (nvarchar(255) on both). It is NOT a column on dbo.FactSalesDetail or BIQL.FactSalesDetail.
   It turns out not to matter: BIQL.FactSalesDetail already exposes the adjusted columns
   inline (Unit_Weight_Adj, UOM_Weight_Adj, [Fix U/M], [Fix Qty], [Fix Actual Qty]), so the
   fix table never needs to be joined. This version joins the two facts on their natural key
   instead - (OrderCompany, OrderType, OrderNum, LineNum) - all present on both.

   WHY: BUILD.md §0.5. With every other mapping correct, report 19 ties exactly on
   Ordered Quantity (5,674/5,674) but the two weight columns do not:
       Ordered Quantity LBs   3,295/5,674 exact   285 structurally wrong   +0.376% on the total
       Ordered Quantity KGs   5,385/5,674 exact   264 structurally wrong   +0.376% on the total
   Precision drift in the 6th-7th decimal is cosmetic and vanishes under the report's #,##0
   display format - ignore it. The STRUCTURAL group is different: EDW/Cognos is a clean
   item-specific multiple (2.0, 1/22, 60, 0.9072, 1.6787), i.e. EDW's stored factor is simply
   a different factor for those items.

   DECIDES: whether the shipped query's FROM stays dbo.FactSalesDetail (and we disclose
   +0.376%) or moves to BIQL.FactSalesDetail (and the report ties on all 19 columns).
   Everything else in the spec is column-for-column identical between the two, so this is a
   one-word change, not a redesign.

   TARGET ROW, from Intake\Cognos export - tight capture 2026-08-06.xlsx:
       Order 2585134, item DP680-B1  ->  Cognos LBs = 176, Cognos KGs = 79.833105264
*/

------------------------------------------------------------------------------
-- 1. WHAT DOES THE VIEW EXPOSE THAT THE TABLE DOES NOT?
--    Expect the five adjusted columns on BIQL only. If any name differs from the
--    column dump, use the real names in the sections below.
------------------------------------------------------------------------------
SELECT '1_columns' AS probe, TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE ((TABLE_SCHEMA = 'BIQL' AND TABLE_NAME IN ('FactSalesDetail', 'FactSalesDetail_UOM_Fix'))
       OR (TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'FactSalesDetail'))
  AND (COLUMN_NAME LIKE '%Conversion%' OR COLUMN_NAME LIKE '%Adj%'
       OR COLUMN_NAME LIKE 'Fix%'      OR COLUMN_NAME LIKE '%Weight%')
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;

------------------------------------------------------------------------------
-- 2. THE TARGET ROW FROM THE VIEW.
--    Single line, so no grouping needed. Compare CalcLB / CalcKG against the
--    Cognos values in the header. If the view's factors reproduce them, J1 is
--    answered YES and the FROM clause changes.
------------------------------------------------------------------------------
SELECT '2_target_biql' AS probe,
       b.OrderNum, b.LineNum, LTRIM(RTRIM(b.ItemNum2nd)) AS ItemNum2nd,
       b.QuantityOrdered, b.QuantityOrderedPrimaryUOM,
       LTRIM(RTRIM(b.UOMTransaction)) AS UOMTx, LTRIM(RTRIM(b.UOMPrimary)) AS UOMPrim,
       b.ConversionFactorLB, b.ConversionFactorKG,
       b.Unit_Weight_Adj, b.UOM_Weight_Adj, b.[Fix U/M], b.[Fix Qty], b.[Fix Actual Qty],
       b.QuantityOrderedPrimaryUOM * b.ConversionFactorLB AS CalcLB,   -- Cognos: 176
       b.QuantityOrderedPrimaryUOM * b.ConversionFactorKG AS CalcKG    -- Cognos: 79.833105264
FROM BIQL.FactSalesDetail b WITH (NOLOCK)
WHERE b.OrderNum = 2585134 AND LTRIM(RTRIM(b.ItemNum2nd)) = 'DP680-B1';

------------------------------------------------------------------------------
-- 3. THE SAME ROW FROM THE TABLE, for side-by-side reading.
--    This is what the build currently ships. Its CalcLB is expected to be wrong.
------------------------------------------------------------------------------
SELECT '3_target_dbo' AS probe,
       d.OrderNum, d.LineNum, LTRIM(RTRIM(d.ItemNum2nd)) AS ItemNum2nd,
       d.QuantityOrdered, d.QuantityOrderedPrimaryUOM,
       LTRIM(RTRIM(d.UOMTransaction)) AS UOMTx, LTRIM(RTRIM(d.UOMPrimary)) AS UOMPrim,
       d.ConversionFactorLB, d.ConversionFactorKG,
       d.QuantityOrderedPrimaryUOM * d.ConversionFactorLB AS CalcLB,
       d.QuantityOrderedPrimaryUOM * d.ConversionFactorKG AS CalcKG
FROM dbo.FactSalesDetail d WITH (NOLOCK)
WHERE d.OrderNum = 2585134 AND LTRIM(RTRIM(d.ItemNum2nd)) = 'DP680-B1';

------------------------------------------------------------------------------
-- 4. DO THE TWO FACTS DIFFER AT ALL, AND BY WHAT MULTIPLE?
--    Natural-key join. A tidy ratio distribution (2.0, 1/22, 60, ...) confirms the
--    view's adjustment is the explanation for the 285 structural rows.
--    An empty result means the view and table carry identical factors and the
--    +0.376% has some other cause - report that rather than assuming.
------------------------------------------------------------------------------
SELECT '4_ratio' AS probe,
       LTRIM(RTRIM(d.BusinessUnit))            AS BU,
       LTRIM(RTRIM(d.UOMTransaction))          AS UOMTx,
       LTRIM(RTRIM(d.UOMPrimary))              AS UOMPrim,
       d.ConversionFactorLB                    AS dbo_LB,
       b.ConversionFactorLB                    AS biql_LB,
       CAST(b.ConversionFactorLB / NULLIF(d.ConversionFactorLB, 0) AS decimal(18,6)) AS RatioLB,
       COUNT_BIG(*)                            AS Lines
FROM dbo.FactSalesDetail d WITH (NOLOCK)
JOIN BIQL.FactSalesDetail b WITH (NOLOCK)
       ON  b.OrderNum    = d.OrderNum
       AND b.LineNum     = d.LineNum
       AND LTRIM(RTRIM(b.OrderCompany)) = LTRIM(RTRIM(d.OrderCompany))
       AND LTRIM(RTRIM(b.OrderType))    = LTRIM(RTRIM(d.OrderType))
WHERE d.PromisedShipmentDate >= DATEADD(DAY, -183, CAST(GETDATE() AS date))
  AND LTRIM(RTRIM(d.BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND ABS(ISNULL(b.ConversionFactorLB, 0) - ISNULL(d.ConversionFactorLB, 0)) > 1e-6
GROUP BY LTRIM(RTRIM(d.BusinessUnit)),
         LTRIM(RTRIM(d.UOMTransaction)), LTRIM(RTRIM(d.UOMPrimary)),
         d.ConversionFactorLB, b.ConversionFactorLB
ORDER BY Lines DESC;

------------------------------------------------------------------------------
-- 5. HOW MUCH OF REPORT 19'S SCOPE CARRIES AN ADJUSTMENT AT ALL?
--    Report 19's window is PromisedShipmentDate >= today-183 at the six branch plants.
--    If almost nothing in scope has a populated [Fix U/M], the adjustment is not the
--    explanation and section 4 will already have shown that.
------------------------------------------------------------------------------
SELECT '5_fix_scope' AS probe,
       COUNT_BIG(*)                                                             AS InScopeLines,
       SUM(CASE WHEN NULLIF(LTRIM(RTRIM(b.[Fix U/M])), '') IS NOT NULL
                THEN 1 ELSE 0 END)                                              AS WithFixUM,
       SUM(CASE WHEN b.Unit_Weight_Adj IS NOT NULL THEN 1 ELSE 0 END)           AS WithWeightAdj,
       COUNT(DISTINCT LTRIM(RTRIM(b.ItemNum2nd)))                               AS DistinctItems
FROM BIQL.FactSalesDetail b WITH (NOLOCK)
WHERE b.PromisedShipmentDate >= DATEADD(DAY, -183, CAST(GETDATE() AS date))
  AND LTRIM(RTRIM(b.BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4');

/* ----------------------------------------------------------------------------
   J2 is a SEPARATE connection - Analysis Services, not SQL Server. Connect SSMS to
   SSASPROD, database BIQLTabular_v2, new MDX/DAX query window:

       SELECT * FROM $SYSTEM.TMSCHEMA_PERSPECTIVE_COLUMNS

   Looking for: does ANY perspective expose [Lead Time MFG_BP] on Item Branch?
   Everything we concluded about SSAS came off the local ssasprod.bim, which is a dump
   of the STALE BIQLTabular. If v2 exposes that column in a perspective that also
   carries Sales, an SSAS live connection becomes the mandated route (CLAUDE.md §1)
   and report 19 collapses to two tables with zero Power Query - a rewrite, not a patch.
   Does not block the build.
   ---------------------------------------------------------------------------- */
