/* probe_P1_P5_jumpbox.sql — report 21, the residual jumpbox probes
   Run ONCE on the jumpbox in SSMS against EDWPROD / EDW. Return all result sets.

   Most of report 21's probe surface is already closed locally against the SQL mirror
   (BUILD.md §7, 17,259/17,259 tie-out on the Shipments sheet). These are the residuals
   that genuinely need live data or a fresh Cognos run.

   Sections 1-2 are the GATE (P1, Open Indicator). Sections 3-4 are P2 (EA factors) and
   P5 (lot dates). P3 (the 2.2045992 constant) and P4 (same-day count parity) need a
   fresh Cognos export rather than SQL - see the tail comment.
*/

------------------------------------------------------------------------------
-- P1 / 1. OPEN INDICATOR — the one column with no local answer (BUILD.md §3.5).
--    Cognos DISPLAYS ORDER_ACTIVITY.OPEN_INDICATOR (Y/N); it does NOT filter on it here.
--    dbo.FactSalesDetail has no such column. Local measurements on in-window LineType='S':
--        SalesTableSource = 1  ->  3,603 rows, mixed next-status  (F4211 lineage = open)
--        SalesTableSource = 2  ->  424,423 rows, all next-status 999
--        SalesTableSource = 4  ->  440,759 rows, all next-status 999
--        StatusCodeNext = '999' separates closed from open but is not a literal Y/N
--        QuantityOpen > 0      ->  ZERO rows in the window
--    SalesTableSource = 1 is the closest structural analog (JDE F4211 open / F42119 history).
--    DO NOT GUESS - this cross-tab decides it.
--
--    HOW TO USE: run a fresh Cognos Shipments extract the same day, then match on
--    (Order Company, Order Number, Line Number) and cross-tab Cognos's Y/N against these
--    three columns. The right candidate is the one that partitions Y/N cleanly.
------------------------------------------------------------------------------
SELECT 'P1_candidates' AS probe,
       f.OrderCompany,
       f.OrderNum,
       f.LineNum,
       LTRIM(RTRIM(f.ItemNum2nd))     AS ItemNum2nd,
       f.SalesTableSource,
       f.Source,
       LTRIM(RTRIM(f.StatusCodeNext)) AS StatusCodeNext,
       LTRIM(RTRIM(f.StatusCodeLast)) AS StatusCodeLast,
       f.QuantityOpen,
       f.QuantityShipped,
       f.Cancelled_Flag
FROM dbo.FactSalesDetail f WITH (NOLOCK)
JOIN BIQL.TbItemBranch ib WITH (NOLOCK) ON ib.ItemBranchSKey = f.ItemBranchSKey
WHERE f.PromisedShipmentDate >= DATEADD(DAY, -365, CAST(GETDATE() AS date))
  AND LTRIM(RTRIM(f.LineType)) = 'S'
  AND LTRIM(RTRIM(f.OrderType)) <> 'ST'
  AND LTRIM(RTRIM(ib.[Category GL F4101])) = 'IN32'
  AND LTRIM(RTRIM(f.BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND f.QuantityOrderedPrimaryUOM > 0
ORDER BY f.OrderNum, f.LineNum;

------------------------------------------------------------------------------
-- P1 / 2. The same population collapsed, so the shape is readable without the detail.
--    If SalesTableSource is the answer, exactly one of its values should align with
--    Cognos's 'Y' count on the same-day export.
------------------------------------------------------------------------------
SELECT 'P1_crosstab' AS probe,
       f.SalesTableSource,
       LTRIM(RTRIM(f.StatusCodeNext)) AS StatusCodeNext,
       COUNT_BIG(*)                   AS Lines,
       SUM(CASE WHEN f.QuantityOpen > 0 THEN 1 ELSE 0 END) AS WithOpenQty
FROM dbo.FactSalesDetail f WITH (NOLOCK)
JOIN BIQL.TbItemBranch ib WITH (NOLOCK) ON ib.ItemBranchSKey = f.ItemBranchSKey
WHERE f.PromisedShipmentDate >= DATEADD(DAY, -365, CAST(GETDATE() AS date))
  AND LTRIM(RTRIM(f.LineType)) = 'S'
  AND LTRIM(RTRIM(f.OrderType)) <> 'ST'
  AND LTRIM(RTRIM(ib.[Category GL F4101])) = 'IN32'
  AND LTRIM(RTRIM(f.BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND f.QuantityOrderedPrimaryUOM > 0
GROUP BY f.SalesTableSource, LTRIM(RTRIM(f.StatusCodeNext))
ORDER BY Lines DESC;

------------------------------------------------------------------------------
-- P2 / 3. EA-PRIMARY CONVERSION FACTORS.  ** TWO SERVERS - RUN IN TWO WINDOWS **
--
--    CORRECTED 2026-08-06: the first version used a three-part name
--    `ODS.PRODDTA.F41002`, which failed with "Invalid object name". That naming only
--    works on the LOCAL SQL mirror, where EDW and ODS are two databases on one
--    instance. In PRODUCTION they are two SEPARATE SERVERS - EDWPROD/EDW and
--    ODSPROD/ODS - so they cannot be joined in one query without a linked server.
--
--    Run 3a on EDWPROD/EDW and 3b on ODSPROD/ODS, export both, and they will be
--    joined offline on (ItemNumShort, BusinessUnit, UOMTx, UOMPrim).
--
--    WHY: 'Each' has no intrinsic weight and EDW carries no factor for many of these
--    rows, while Cognos always shows a number because DW_LEGACY stores one inline.
--    The question is whether F41002.UMCONV/1e7 reproduces Cognos where EDW's own
--    fact column does not.
--
--    LOW PRIORITY - this affects the EA rows only. Skip it if short on time; the
--    gate is P1 above.
------------------------------------------------------------------------------
-- 3a.  >>> RUN ON EDWPROD / EDW <<<
SELECT 'P2a_ea_edw' AS probe,
       LTRIM(RTRIM(f.BusinessUnit))   AS BU,
       LTRIM(RTRIM(f.ItemNum2nd))     AS ItemNum2nd,
       f.ItemNumShort,
       LTRIM(RTRIM(f.UOMTransaction)) AS UOMTx,
       LTRIM(RTRIM(f.UOMPrimary))     AS UOMPrim,
       f.OrderNum, f.LineNum,
       f.QuantityOrdered,
       f.QuantityOrderedPrimaryUOM,
       f.ConversionFactorLB,
       f.ConversionFactorKG
FROM dbo.FactSalesDetail f WITH (NOLOCK)
WHERE f.PromisedShipmentDate >= DATEADD(DAY, -365, CAST(GETDATE() AS date))
  AND LTRIM(RTRIM(f.UOMPrimary)) = 'EA'
  AND LTRIM(RTRIM(f.BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND f.QuantityOrderedPrimaryUOM > 0
ORDER BY BU, ItemNum2nd;

/* 3b.  >>> RUN ON ODSPROD / ODS - SEPARATE CONNECTION <<<
        Paste this into a NEW query window connected to ODSPROD.

SELECT 'P2b_umconv_ods' AS probe,
       u.UMITM                                             AS ItemNumShort,
       LTRIM(RTRIM(u.UMMCU))                               AS BU,
       LTRIM(RTRIM(u.UMUM))                                AS UOMTx,
       LTRIM(RTRIM(u.UMRUM))                               AS UOMPrim,
       CAST(u.UMCONV AS decimal(38,10)) / 10000000.0        AS UMCONV_scaled
FROM PRODDTA.F41002 u WITH (NOLOCK)
WHERE LTRIM(RTRIM(u.UMMCU)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
ORDER BY BU, ItemNumShort;
*/

------------------------------------------------------------------------------
-- P5 / 4. LOT-DATE GAP.
--    Locally, BIQL.DimLot agreed with Cognos on OnHandDate 92.8% and LotExpirationDate
--    87.3%; of the disagreements, 137 were rows where COGNOS shows the JDE zero-date
--    1900-01-01 and EDW has a real date (recently-created lots the legacy DW has not
--    picked up). Confirm that direction still holds on live data - EDW MORE populated,
--    not less. If it reverses, the gap is ours and needs chasing.
------------------------------------------------------------------------------
SELECT 'P5_lotdates' AS probe,
       COUNT_BIG(*)                                                       AS InScopePositions,
       SUM(CASE WHEN l.LotSKey IS NULL THEN 1 ELSE 0 END)                 AS NoLotRow,
       SUM(CASE WHEN l.OnHandDate IS NULL THEN 1 ELSE 0 END)              AS NullOnHandDate,
       SUM(CASE WHEN l.LotExpirationDate IS NULL THEN 1 ELSE 0 END)       AS NullExpiryDate,
       SUM(CASE WHEN l.OnHandDate        <= '1900-01-01' THEN 1 ELSE 0 END) AS ZeroDateOnHand,
       SUM(CASE WHEN l.LotExpirationDate <= '1900-01-01' THEN 1 ELSE 0 END) AS ZeroDateExpiry,
       MIN(l.OnHandDate) AS MinOnHand, MAX(l.OnHandDate) AS MaxOnHand
FROM BIQL.FactInventorySnapshot_History_Filtered snap WITH (NOLOCK)
JOIN BIQL.TbItemBranch ib WITH (NOLOCK) ON ib.ItemBranchSKey = snap.ItemBranchSKey
LEFT JOIN BIQL.DimLot l WITH (NOLOCK)    ON l.LotSKey = snap.LotSKey
WHERE snap.CalendarDate = DATEADD(DAY, -1, CAST(GETDATE() AS date))
  AND snap.QuantityOnHandPrimaryUOM > 0
  AND LTRIM(RTRIM(snap.CategoryGLF41021)) = 'IN32'
  AND LTRIM(RTRIM(snap.BusinessUnit)) IN ('CINC','CIN2','CIN4','AUBA','AUB2','SING','SNG4');

/* ----------------------------------------------------------------------------
   P3 and P4 are NOT SQL - they need a fresh Cognos run on the same day:

   P3  Re-derive the KG->LB constant from the new export (Quantity on Hand LBs /
       Quantity on Hand KGs) and confirm it is still exactly 2.2045992. It is a
       DW-load constant so it should hold, but it is now load-bearing in four
       columns across two reports and deserves one live check.

   P4  Reproduce all three sheets on refresh day and compare row counts to the
       same-day Cognos export (tight capture, CLAUDE.md §7). The local deltas
       should shrink to near zero; anything that does not is a logic issue rather
       than staleness.

   ⚠ Report 14 §9.2 found DW_LEGACY had already purged a 10-day-old snapshot date.
      Pick a recent date and confirm Cognos still returns rows before planning the
      tie-out.
   ---------------------------------------------------------------------------- */
