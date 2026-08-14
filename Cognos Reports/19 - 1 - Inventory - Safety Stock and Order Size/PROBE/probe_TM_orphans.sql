/* probe_TM_orphans.sql - report 19, TM 'Not Available' rows (Rohit, 2026-08-12)
   DATABASE: EDWPROD / EDW.  Run in SSMS, return all result sets.

   WHY: BUILD.md §0.4. The shipped Shipments query LEFT-joins
   BIQL.TbTerritoryManager on TerritoryManagerSKey and renders 'Not Available'
   where the key does not resolve. Rohit's old-DW query resolves those same
   rows to real names (Schloerb / Fuka), so the question is whether EDW is
   populating correctly or the join is wrong. The join is right: the dim is
   unique on TerritoryManagerSKey (19,321 = 19,321), and the fact carries
   SKeys the dim does not contain - including SKeys for people who DO exist
   in the dim under other version rows (it is an SCD-style dim; Schloerb,
   Fuka, Jeffers each appear under hundreds of SKeys). The fact's only other
   TM columns derive from the same missing row (CustomerCommissionSKey is the
   SKey +/-1, TMSalesRepType is the PPG/CSG suffix), so there is NO key on the
   fact that resolves directly - the probe instead infers the intended TM
   from sibling fact rows of the same ship-to whose key DOES resolve.

   SHOWS: (1) every unresolved SKey on the fact with row counts, (2) the
   inferred TM per broken key where siblings exist, (3) the report's actual
   'Not Available' rows with a tiered inference - same ship-to + same rep
   type first, any rep type second (cross-type is weaker: PPG and CSG reps
   for one customer can be different people), else 'unresolvable in EDW'.
   Rows in tier 3 can only be named by the old DW / VENDOR dimension.

   DECIDES: nothing in the shipped query - the fix is upstream (backfill the
   missing dim version rows, or re-stamp the facts to current SKeys). The
   output is the work order: which SKeys to backfill and, where inferable,
   who they should resolve to. Verify inferred names against old DW before
   trusting them for backfill.

   Local-mirror expectations (snapshot, dbo.FactSalesDetail): 23 unresolved
   SKeys incl. -1 (-1 = 330,592 rows; the 22 named orphans ~ 960 rows);
   report scope holds 14 'Not Available' rows across 5 ship-tos, of which 3
   infer to Schloerb (338167) same-type, 5 infer cross-type only, 6 have no
   resolvable sibling at all (ship-to 280125's rows ALL carry broken key
   9931, and 351195's all carry -1). Live counts will drift.

   §2/§3 read TMSalesRepType off BIQL.FactSalesDetail; §0 confirms the view
   exposes it. If it does not, swap those two FROMs to dbo.FactSalesDetail -
   the TM key columns are identical between table and view (§0.5), only the
   five adjusted weight columns differ.
*/

------------------------------------------------------------------------------
-- 0. COLUMN EXISTENCE. The inference needs TMSalesRepType and
--    AddressNumShipTo on the BIQL view. Expect all four rows.
------------------------------------------------------------------------------
SELECT '0_columns' AS probe, TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'BIQL' AND TABLE_NAME = 'FactSalesDetail'
  AND COLUMN_NAME IN ('TerritoryManagerSKey', 'TMSalesRepType',
                      'CustomerCommissionSKey', 'AddressNumShipTo')
ORDER BY COLUMN_NAME;

------------------------------------------------------------------------------
-- 1. THE ORPHAN INVENTORY. Every TerritoryManagerSKey on the fact with no
--    row in the dim, whole-fact row count, and how many of those rows fall
--    inside report 19's window (183 days, six branch plants). -1 is the
--    unknown member; the rest are holes in an SCD dim that reaches past
--    39,000 - version rows the fact references but the dim does not hold.
------------------------------------------------------------------------------
SELECT '1_orphans' AS probe,
       f.TerritoryManagerSKey AS OrphanSKey,
       COUNT_BIG(*)           AS FactRows,
       SUM(CASE WHEN f.PromisedShipmentDate >= DATEADD(DAY, -183, CAST(GETDATE() AS date))
                 AND LTRIM(RTRIM(f.BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
                THEN 1 ELSE 0 END) AS InR19Window
FROM BIQL.FactSalesDetail f WITH (NOLOCK)
LEFT JOIN BIQL.TbTerritoryManager tm WITH (NOLOCK)
       ON tm.TerritoryManagerSKey = f.TerritoryManagerSKey
WHERE tm.TerritoryManagerSKey IS NULL
GROUP BY f.TerritoryManagerSKey
ORDER BY FactRows DESC;

------------------------------------------------------------------------------
-- 2. WHO EACH NAMED ORPHAN KEY SHOULD BE. For every orphan SKey except -1:
--    sibling fact rows on the same ship-to + same rep type whose key DOES
--    resolve name the TM. Candidates = 1 means the answer is unambiguous;
--    InferredTMNum landing on a person already in the dim proves the dim is
--    missing version rows, not people. Keys absent from this result have no
--    resolvable sibling anywhere on the fact - only the old DW names them.
------------------------------------------------------------------------------
WITH orphan_sites AS (
    SELECT DISTINCT f.TerritoryManagerSKey AS OrphanSKey,
                    f.AddressNumShipTo, f.TMSalesRepType
    FROM BIQL.FactSalesDetail f WITH (NOLOCK)
    LEFT JOIN BIQL.TbTerritoryManager tm WITH (NOLOCK)
           ON tm.TerritoryManagerSKey = f.TerritoryManagerSKey
    WHERE tm.TerritoryManagerSKey IS NULL
      AND f.TerritoryManagerSKey <> -1
)
SELECT '2_inferred' AS probe,
       o.OrphanSKey,
       o.AddressNumShipTo,
       o.TMSalesRepType,
       COUNT(DISTINCT tm2.[Territory Manager Num]) AS Candidates,
       MIN(tm2.[Territory Manager Num])            AS InferredTMNum,
       MIN(tm2.[Mailing Name])                     AS InferredName,
       MAX(tm2.[Mailing Name])                     AS InferredName_IfAmbiguous
FROM orphan_sites o
JOIN BIQL.FactSalesDetail f2 WITH (NOLOCK)
       ON  f2.AddressNumShipTo = o.AddressNumShipTo
       AND f2.TMSalesRepType   = o.TMSalesRepType
       AND f2.TerritoryManagerSKey <> o.OrphanSKey
JOIN BIQL.TbTerritoryManager tm2 WITH (NOLOCK)
       ON tm2.TerritoryManagerSKey = f2.TerritoryManagerSKey
GROUP BY o.OrphanSKey, o.AddressNumShipTo, o.TMSalesRepType
ORDER BY o.OrphanSKey, o.AddressNumShipTo;

------------------------------------------------------------------------------
-- 3. THE REPORT'S 'Not Available' ROWS, NAMED WHERE EDW CAN. The shipped
--    Shipments WHERE, restricted to unresolved TM keys (incl. -1), one row
--    per fact line, with the tiered inference:
--        same ship-to + rep type  -> the defensible answer
--        same ship-to, cross-type -> informative, verify against old DW
--        unresolvable in EDW      -> every sibling row is also broken;
--                                    only the old DW / VENDOR dim names it
------------------------------------------------------------------------------
WITH bad AS (
    SELECT f.OrderNum, f.ItemNum2nd, f.AddressNumShipTo,
           f.TMSalesRepType, f.TerritoryManagerSKey,
           LTRIM(RTRIM(sa.AddressDesc)) AS CustomerName
    FROM BIQL.FactSalesDetail f WITH (NOLOCK)
        INNER JOIN BIQL.TbItemBranch ib WITH (NOLOCK) ON ib.ItemBranchSKey = f.ItemBranchSKey
        INNER JOIN BIQL.DimCustomer  sc WITH (NOLOCK) ON sc.CustomerSKey   = f.ShipToCustomerSKey
        INNER JOIN BIQL.DimAddress   sa WITH (NOLOCK) ON sa.AddressSKey    = f.ShipToAddressSKey
        LEFT  JOIN BIQL.TbTerritoryManager tm WITH (NOLOCK)
               ON tm.TerritoryManagerSKey = f.TerritoryManagerSKey
    WHERE tm.TerritoryManagerSKey IS NULL
      AND f.RecordType = 'Sales Detail'
      AND LTRIM(RTRIM(f.StatusCodeNext)) = '999'
      AND LTRIM(RTRIM(f.BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
      AND f.PromisedShipmentDate >= DATEADD(DAY, -183, CAST(GETDATE() AS date))
      AND LTRIM(RTRIM(f.OrderType)) NOT IN ('S5','ST')
      AND f.LineType NOT LIKE '%F%'
      AND f.StatusCodeLast NOT IN ('980','984')
      AND f.QuantityOrderedPrimaryUOM > 0
      AND LTRIM(RTRIM(ISNULL(sc.SalesBusinessUnit,''))) <> 'INT'
      AND ib.[Master Planning Family] LIKE '%F%'
),
infer_same_type AS (
    SELECT b.AddressNumShipTo, b.TMSalesRepType,
           COUNT(DISTINCT tm2.[Territory Manager Num]) AS Candidates,
           MIN(tm2.[Territory Manager Num])            AS TMNum,
           MIN(tm2.[Mailing Name])                     AS TMName
    FROM (SELECT DISTINCT AddressNumShipTo, TMSalesRepType FROM bad) b
    JOIN BIQL.FactSalesDetail f2 WITH (NOLOCK)
           ON  f2.AddressNumShipTo = b.AddressNumShipTo
           AND f2.TMSalesRepType   = b.TMSalesRepType
    JOIN BIQL.TbTerritoryManager tm2 WITH (NOLOCK)
           ON tm2.TerritoryManagerSKey = f2.TerritoryManagerSKey
    GROUP BY b.AddressNumShipTo, b.TMSalesRepType
),
infer_any_type AS (
    SELECT b.AddressNumShipTo,
           COUNT(DISTINCT tm2.[Territory Manager Num]) AS Candidates,
           MIN(tm2.[Territory Manager Num])            AS TMNum,
           MIN(tm2.[Mailing Name])                     AS TMName,
           MIN(f2.TMSalesRepType)                      AS SiblingRepType
    FROM (SELECT DISTINCT AddressNumShipTo FROM bad) b
    JOIN BIQL.FactSalesDetail f2 WITH (NOLOCK)
           ON f2.AddressNumShipTo = b.AddressNumShipTo
    JOIN BIQL.TbTerritoryManager tm2 WITH (NOLOCK)
           ON tm2.TerritoryManagerSKey = f2.TerritoryManagerSKey
    GROUP BY b.AddressNumShipTo
)
SELECT '3_report_rows' AS probe,
       bad.OrderNum,
       LTRIM(RTRIM(bad.ItemNum2nd)) AS Item,
       bad.AddressNumShipTo         AS ShipTo,
       bad.CustomerName,
       bad.TerritoryManagerSKey     AS BrokenKey,
       bad.TMSalesRepType           AS RepType,
       COALESCE(st.TMName, at.TMName, '(unresolvable in EDW)') AS InferredName,
       COALESCE(st.TMNum, at.TMNum) AS InferredTMNum,
       CASE WHEN st.TMNum IS NOT NULL THEN 'same ship-to + rep type'
            WHEN at.TMNum IS NOT NULL THEN 'same ship-to, ' + at.SiblingRepType + ' only - verify vs old DW'
            ELSE 'no resolvable sibling - old DW only' END AS InferenceBasis,
       COALESCE(st.Candidates, at.Candidates, 0) AS Candidates
FROM bad
LEFT JOIN infer_same_type st
       ON  st.AddressNumShipTo = bad.AddressNumShipTo
       AND st.TMSalesRepType   = bad.TMSalesRepType
LEFT JOIN infer_any_type  at
       ON  at.AddressNumShipTo = bad.AddressNumShipTo
ORDER BY bad.AddressNumShipTo, bad.OrderNum;
