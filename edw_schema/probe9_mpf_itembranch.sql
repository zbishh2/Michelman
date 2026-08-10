/* probe9_mpf_itembranch.sql — Master Planning Family fold onto FactSalesDetail
   Run ONCE on the jumpbox (EDWPROD / EDW) BEFORE the first refresh of the OTIF PBIP
   with the widened FactSalesDetail partition (edw_model/Orders.m).

   WHY: MPF lives on BIQL.TbItemBranch at (ItemSKey, Business Unit) grain — F4102.IBPRP4,
   decoded by UDC 41/P4. FactSalesDetail carries both keys, so the fold is a LEFT JOIN.
   The risk is FAN-OUT: if (ItemSKey, BU) is not unique in TbItemBranch, a naive join
   multiplies order lines and inflates every OTIF denominator. The shipped query defends
   against that with a GROUP BY derived table; probe 3 tells us whether that defense is
   actually doing work, and probe 4 whether it is silently picking between disagreeing rows.

   Paste the whole file into SSMS on the jumpbox and return all 7 result sets.
   Categories per CLAUDE.md §1: column existence, join drops, fan-out, code decodes,
   count parity, format spot-checks.
*/

------------------------------------------------------------------------------
-- 1. COLUMN EXISTENCE — the two BIQL columns and both join keys are really there.
--    Expect exactly 4 rows. Note the declared types: both BU columns should be nchar(12).
------------------------------------------------------------------------------
SELECT '1_columns' AS probe, TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE (TABLE_SCHEMA = 'BIQL' AND TABLE_NAME = 'TbItemBranch'
       AND COLUMN_NAME IN ('ItemSKey', 'Business Unit', 'Master Planning Family', 'Master Planning Family Desc'))
ORDER BY COLUMN_NAME;

------------------------------------------------------------------------------
-- 2. COUNT PARITY — baseline fact row count under the partition's own WHERE clause.
--    Every later count must tie to this. Widening the SELECT must not change it.
------------------------------------------------------------------------------
SELECT '2_baseline' AS probe,
       COUNT(*)                        AS FactRows,
       COUNT(DISTINCT OrderNum)        AS DistinctOrders,
       COUNT(DISTINCT OrderLineID)     AS DistinctOrderLines
FROM dbo.FactSalesDetail
WHERE GLDate >= '2024-01-01'
  AND (RecordType IS NULL OR RecordType <> 'GL Detail');

------------------------------------------------------------------------------
-- 3. FAN-OUT — is (ItemSKey, BU) unique in TbItemBranch?
--    DupPairs = 0 means the GROUP BY in the shipped query is a no-op safety net.
--    DupPairs > 0 means it is load-bearing — go read probe 4 carefully.
------------------------------------------------------------------------------
SELECT '3_fanout' AS probe,
       COUNT(*)                                          AS DistinctPairs,
       SUM(CASE WHEN n > 1 THEN 1 ELSE 0 END)            AS DupPairs,
       ISNULL(MAX(n), 0)                                 AS WorstPairRowCount
FROM (
    SELECT ItemSKey, LTRIM(RTRIM([Business Unit])) AS BU, COUNT(*) AS n
    FROM BIQL.TbItemBranch
    GROUP BY ItemSKey, LTRIM(RTRIM([Business Unit]))
) d;

------------------------------------------------------------------------------
-- 4. FAN-OUT, part 2 — of the duplicated pairs, do they DISAGREE on MPF?
--    Agreeing duplicates are harmless (MIN picks the same value either way).
--    DisagreeingPairs > 0 means MIN() is making an arbitrary choice and we need a
--    tie-break rule (report 14 used lowest ItemBranchSKey) before trusting the column.
------------------------------------------------------------------------------
SELECT '4_disagree' AS probe,
       COUNT(*) AS DisagreeingPairs
FROM (
    SELECT ItemSKey, LTRIM(RTRIM([Business Unit])) AS BU
    FROM BIQL.TbItemBranch
    GROUP BY ItemSKey, LTRIM(RTRIM([Business Unit]))
    HAVING COUNT(DISTINCT LTRIM(RTRIM([Master Planning Family]))) > 1
) d;

-- Sample the offenders (empty if probe 4 returned 0).
SELECT TOP 20 '4b_disagree_sample' AS probe,
       ib.ItemBranchSKey, ib.ItemSKey, LTRIM(RTRIM(ib.[Business Unit])) AS BU,
       LTRIM(RTRIM(ib.[Master Planning Family])) AS MPF,
       LTRIM(RTRIM(ib.[Master Planning Family Desc])) AS MPFDesc
FROM BIQL.TbItemBranch ib
JOIN (
    SELECT ItemSKey, LTRIM(RTRIM([Business Unit])) AS BU
    FROM BIQL.TbItemBranch
    GROUP BY ItemSKey, LTRIM(RTRIM([Business Unit]))
    HAVING COUNT(DISTINCT LTRIM(RTRIM([Master Planning Family]))) > 1
) d ON d.ItemSKey = ib.ItemSKey AND d.BU = LTRIM(RTRIM(ib.[Business Unit]))
ORDER BY ib.ItemSKey, ib.ItemBranchSKey;

------------------------------------------------------------------------------
-- 5. JOIN DROPS — how many fact rows get NO MPF, and does the join change the row count?
--    JoinedRows MUST equal probe 2's FactRows. If it is higher, fan-out leaked through.
--    NullMPFRows is the "(Blank)" bucket the slicer will show — it is expected to be
--    non-zero (freight/misc lines carry no item branch), but a large share is a red flag
--    that BU is the wrong pairing key.
------------------------------------------------------------------------------
SELECT '5_joindrops' AS probe,
       COUNT(*)                                                          AS JoinedRows,
       SUM(CASE WHEN ib.MPF IS NULL THEN 1 ELSE 0 END)                   AS NullMPFRows,
       CAST(100.0 * SUM(CASE WHEN ib.MPF IS NULL THEN 1 ELSE 0 END)
            / NULLIF(COUNT(*), 0) AS decimal(5,2))                       AS NullMPFPct,
       SUM(CASE WHEN f.ItemSKey IS NULL THEN 1 ELSE 0 END)               AS NullItemSKeyRows
FROM dbo.FactSalesDetail f
LEFT JOIN (
    SELECT ItemSKey,
           LTRIM(RTRIM([Business Unit]))                   AS BU,
           MIN(LTRIM(RTRIM([Master Planning Family])))     AS MPF
    FROM BIQL.TbItemBranch
    GROUP BY ItemSKey, LTRIM(RTRIM([Business Unit]))
) ib ON ib.ItemSKey = f.ItemSKey
    AND ib.BU       = LTRIM(RTRIM(f.BusinessUnit))
WHERE f.GLDate >= '2024-01-01'
  AND (f.RecordType IS NULL OR f.RecordType <> 'GL Detail');

------------------------------------------------------------------------------
-- 6. CODE DECODES + THE ACTUAL ASK — full MPF distribution over the fact population.
--    This is the list Bryan will slice on. Confirm 'PKG' exists, see what it is called,
--    and see how many order lines dropping it would remove (the quilts carve-out).
--    Also flags any code with a missing/blank decode (UDC 41/P4 coverage gap).
------------------------------------------------------------------------------
SELECT '6_mpf_dist' AS probe,
       ISNULL(ib.MPF, '(null)')                                  AS MPF,
       ISNULL(NULLIF(ib.MPFDesc, ''), '(no decode)')             AS MPFDesc,
       COUNT(*)                                                  AS OrderLines,
       COUNT(DISTINCT f.OrderNum)                                AS DistinctOrders,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS decimal(5,2)) AS PctOfLines
FROM dbo.FactSalesDetail f
LEFT JOIN (
    SELECT ItemSKey,
           LTRIM(RTRIM([Business Unit]))                       AS BU,
           MIN(LTRIM(RTRIM([Master Planning Family])))         AS MPF,
           MIN(LTRIM(RTRIM([Master Planning Family Desc])))    AS MPFDesc
    FROM BIQL.TbItemBranch
    GROUP BY ItemSKey, LTRIM(RTRIM([Business Unit]))
) ib ON ib.ItemSKey = f.ItemSKey
    AND ib.BU       = LTRIM(RTRIM(f.BusinessUnit))
WHERE f.GLDate >= '2024-01-01'
  AND (f.RecordType IS NULL OR f.RecordType <> 'GL Detail')
GROUP BY ib.MPF, ib.MPFDesc
ORDER BY OrderLines DESC;

------------------------------------------------------------------------------
-- 7. FORMAT SPOT-CHECK — 20 real order lines with their MPF, to eyeball that the
--    code is trimmed (3 chars, no nchar padding), the desc is populated, and the
--    item/branch pairing looks sane against the product description.
------------------------------------------------------------------------------
SELECT TOP 20 '7_spotcheck' AS probe,
       f.OrderNum, f.LineNum, f.ItemNum2nd, f.Description1,
       LTRIM(RTRIM(f.BusinessUnit)) AS BU,
       ib.MPF, ib.MPFDesc,
       LEN(ib.MPF) AS MPFLen
FROM dbo.FactSalesDetail f
LEFT JOIN (
    SELECT ItemSKey,
           LTRIM(RTRIM([Business Unit]))                       AS BU,
           MIN(LTRIM(RTRIM([Master Planning Family])))         AS MPF,
           MIN(LTRIM(RTRIM([Master Planning Family Desc])))    AS MPFDesc
    FROM BIQL.TbItemBranch
    GROUP BY ItemSKey, LTRIM(RTRIM([Business Unit]))
) ib ON ib.ItemSKey = f.ItemSKey
    AND ib.BU       = LTRIM(RTRIM(f.BusinessUnit))
WHERE f.GLDate >= '2024-01-01'
  AND (f.RecordType IS NULL OR f.RecordType <> 'GL Detail')
  AND ib.MPF IS NOT NULL
ORDER BY f.OrderNum DESC, f.LineNum;
