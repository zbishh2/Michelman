/* probe10_line_splits.sql — decimal line numbers (1.001 = split?) and parent roll-up
   Run ONCE on the jumpbox (EDWPROD / EDW). Return all 8 result sets.

   CONTEXT: Ivan's concern is that split lines (1.000 / 1.001 / 1.002) inflate the OTIF
   line count and the late-line count when they are commercially one line. The proposed
   fix is "sum order qty across the family, take everything else from the parent".
   Three things must be true for that to be safe, and NONE of them is established yet:

     (a) the fractional lines are SPLITS, not KIT COMPONENTS (KitMasterLineNum exists on
         this fact — kit components also use decimal line numbers, and summing qty across
         a kit family is meaningless);
     (b) the children AGREE with the parent on the OTIF-relevant dates — if a split
         carries its own later promised date (the normal reason to split), taking the
         parent's dates would DELETE the late remainder OTIF is meant to catch;
     (c) children PARTITION the qty rather than duplicating it — i.e. the parent row's
         qty is its own share, not the family total. If the parent retains the full qty
         and children are additive, SUM double-counts.

   Probes 4, 5 and 6 are the make-or-break ones. Everything else is scale/impact.

   Family key throughout = (OrderCompany, OrderNum, OrderType, FLOOR(LineNum)),
   mirroring the 4-part OrderLineID format (which carries no OrderSuffix).
   Population matches the OTIF partition's own WHERE clause so counts tie to the report.
*/

------------------------------------------------------------------------------
-- 1. PREVALENCE — how common are fractional line numbers at all, by year?
--    If this is a fraction of a percent, the whole exercise may not be worth the
--    model surface. If it is material, it explains real inflation in Ivan's grid.
------------------------------------------------------------------------------
SELECT '1_prevalence' AS probe,
       YEAR(GLDate)                                                          AS GLYear,
       COUNT(*)                                                              AS Rows_,
       SUM(CASE WHEN LineNum <> FLOOR(LineNum) THEN 1 ELSE 0 END)            AS FractionalRows,
       CAST(100.0 * SUM(CASE WHEN LineNum <> FLOOR(LineNum) THEN 1 ELSE 0 END)
            / NULLIF(COUNT(*), 0) AS decimal(5,2))                           AS FractionalPct
FROM dbo.FactSalesDetail
WHERE GLDate >= '2024-01-01'
  AND (RecordType IS NULL OR RecordType <> 'GL Detail')
GROUP BY YEAR(GLDate)
ORDER BY GLYear;

------------------------------------------------------------------------------
-- 2. SPLIT vs KIT — the disambiguation. Fractional lines broken out by whether they
--    carry kit markers. Only the "no kit marker" bucket is a candidate for qty roll-up.
--    LineType is shown because kit components and freight carry distinctive types.
------------------------------------------------------------------------------
SELECT '2_split_vs_kit' AS probe,
       CASE WHEN ISNULL(KitMasterLineNum, 0) <> 0 OR ISNULL(KitIdentifier, 0) <> 0
            THEN 'kit-marked' ELSE 'no-kit-marker' END                       AS Bucket,
       LTRIM(RTRIM(LineType))                                                AS LineType,
       COUNT(*)                                                              AS FractionalRows,
       COUNT(DISTINCT OrderNum)                                              AS DistinctOrders
FROM dbo.FactSalesDetail
WHERE GLDate >= '2024-01-01'
  AND (RecordType IS NULL OR RecordType <> 'GL Detail')
  AND LineNum <> FLOOR(LineNum)
GROUP BY CASE WHEN ISNULL(KitMasterLineNum, 0) <> 0 OR ISNULL(KitIdentifier, 0) <> 0
              THEN 'kit-marked' ELSE 'no-kit-marker' END,
         LTRIM(RTRIM(LineType))
ORDER BY FractionalRows DESC;

------------------------------------------------------------------------------
-- 3. IS OriginalLineNum THE PARENT POINTER? If it reliably equals FLOOR(LineNum) on
--    fractional rows, it is a better (source-supplied) family key than FLOOR and we
--    should use it. If it is mostly NULL/0 or disagrees, FLOOR is the pragmatic key.
------------------------------------------------------------------------------
SELECT '3_originallinenum' AS probe,
       CASE WHEN OriginalLineNum IS NULL              THEN 'null'
            WHEN OriginalLineNum = 0                  THEN 'zero'
            WHEN OriginalLineNum = FLOOR(LineNum)     THEN 'equals FLOOR(LineNum)'
            WHEN OriginalLineNum = LineNum            THEN 'equals LineNum (self)'
            ELSE 'other' END                                                 AS Relationship,
       COUNT(*)                                                              AS FractionalRows
FROM dbo.FactSalesDetail
WHERE GLDate >= '2024-01-01'
  AND (RecordType IS NULL OR RecordType <> 'GL Detail')
  AND LineNum <> FLOOR(LineNum)
GROUP BY CASE WHEN OriginalLineNum IS NULL              THEN 'null'
              WHEN OriginalLineNum = 0                  THEN 'zero'
              WHEN OriginalLineNum = FLOOR(LineNum)     THEN 'equals FLOOR(LineNum)'
              WHEN OriginalLineNum = LineNum            THEN 'equals LineNum (self)'
              ELSE 'other' END
ORDER BY FractionalRows DESC;

------------------------------------------------------------------------------
-- 4. ★ DO CHILDREN AGREE WITH THE PARENT ON THE OTIF FIELDS? ★
--    THE decisive probe. For every multi-row family (kit-marked rows excluded), count
--    families where the children disagree on each field. High disagreement on the
--    promised/ship dates KILLS "everything else comes from the parent" — it would mean
--    splits carry their own schedule and collapsing hides real lateness.
------------------------------------------------------------------------------
WITH fam AS (
    SELECT OrderCompany, OrderNum, OrderType, FLOOR(LineNum) AS ParentLine,
           PromisedDeliveryDate, RequestedDate, OriginalPromisedDeliveryDate,
           ActualShipDate, ItemNumShort, ShipToCustomerSKey
    FROM dbo.FactSalesDetail
    WHERE GLDate >= '2024-01-01'
      AND (RecordType IS NULL OR RecordType <> 'GL Detail')
      AND ISNULL(KitMasterLineNum, 0) = 0
      AND ISNULL(KitIdentifier, 0)    = 0
)
SELECT '4_child_agreement' AS probe,
       COUNT(*)                                                                  AS MultiRowFamilies,
       SUM(CASE WHEN nPromised  > 1 THEN 1 ELSE 0 END)                           AS DisagreePromisedDelivery,
       SUM(CASE WHEN nRequested > 1 THEN 1 ELSE 0 END)                           AS DisagreeRequested,
       SUM(CASE WHEN nOrigProm  > 1 THEN 1 ELSE 0 END)                           AS DisagreeOrigPromised,
       SUM(CASE WHEN nShip      > 1 THEN 1 ELSE 0 END)                           AS DisagreeActualShip,
       SUM(CASE WHEN nItem      > 1 THEN 1 ELSE 0 END)                           AS DisagreeItem,
       SUM(CASE WHEN nShipTo    > 1 THEN 1 ELSE 0 END)                           AS DisagreeShipTo
FROM (
    SELECT COUNT(*)                                        AS nRows,
           COUNT(DISTINCT PromisedDeliveryDate)            AS nPromised,
           COUNT(DISTINCT RequestedDate)                   AS nRequested,
           COUNT(DISTINCT OriginalPromisedDeliveryDate)    AS nOrigProm,
           COUNT(DISTINCT ActualShipDate)                  AS nShip,
           COUNT(DISTINCT ItemNumShort)                    AS nItem,
           COUNT(DISTINCT ShipToCustomerSKey)              AS nShipTo
    FROM fam
    GROUP BY OrderCompany, OrderNum, OrderType, ParentLine
    HAVING COUNT(*) > 1
) d;

------------------------------------------------------------------------------
-- 5. ★ QTY SEMANTICS ★ — do children PARTITION the qty or DUPLICATE it?
--    Sample of 30 multi-row families showing each row's qty. Eyeball: if the .000 row
--    already equals the family total, children are additive detail and SUM double-counts.
--    If the rows look like shares of a sensible order size, SUM is correct.
------------------------------------------------------------------------------
SELECT TOP 100 '5_qty_semantics' AS probe,
       f.OrderCompany, f.OrderNum, f.OrderType, f.LineNum,
       f.QuantityOrdered, f.QuantityShipped, f.QuantityOpen, f.QuantityCanceledScrapped,
       f.UOMTransaction, f.ItemNumShort,
       f.PromisedDeliveryDate, f.ActualShipDate, f.StatusCodeLast
FROM dbo.FactSalesDetail f
JOIN (
    SELECT TOP 30 OrderCompany, OrderNum, OrderType, FLOOR(LineNum) AS ParentLine
    FROM dbo.FactSalesDetail
    WHERE GLDate >= '2024-01-01'
      AND (RecordType IS NULL OR RecordType <> 'GL Detail')
      AND ISNULL(KitMasterLineNum, 0) = 0
      AND ISNULL(KitIdentifier, 0)    = 0
    GROUP BY OrderCompany, OrderNum, OrderType, FLOOR(LineNum)
    HAVING COUNT(*) > 1
    ORDER BY NEWID()
) d ON d.OrderCompany = f.OrderCompany AND d.OrderNum = f.OrderNum
   AND d.OrderType    = f.OrderType    AND d.ParentLine = FLOOR(f.LineNum)
WHERE f.GLDate >= '2024-01-01'
  AND (f.RecordType IS NULL OR f.RecordType <> 'GL Detail')
ORDER BY f.OrderCompany, f.OrderNum, f.LineNum;

------------------------------------------------------------------------------
-- 6. ★ DOES A .000 PARENT ROW ALWAYS EXIST? ★
--    "Everything else comes from the parent" presumes there IS a parent row in the
--    population. Families whose .000 row was filtered out (or never existed) need a
--    fallback rule — lowest LineNum in the family.
------------------------------------------------------------------------------
SELECT '6_parent_exists' AS probe,
       COUNT(*)                                                          AS MultiRowFamilies,
       SUM(CASE WHEN HasDotZero = 0 THEN 1 ELSE 0 END)                   AS FamiliesWithNoDotZeroRow
FROM (
    SELECT OrderCompany, OrderNum, OrderType, FLOOR(LineNum) AS ParentLine,
           MAX(CASE WHEN LineNum = FLOOR(LineNum) THEN 1 ELSE 0 END) AS HasDotZero
    FROM dbo.FactSalesDetail
    WHERE GLDate >= '2024-01-01'
      AND (RecordType IS NULL OR RecordType <> 'GL Detail')
      AND ISNULL(KitMasterLineNum, 0) = 0
      AND ISNULL(KitIdentifier, 0)    = 0
    GROUP BY OrderCompany, OrderNum, OrderType, FLOOR(LineNum)
    HAVING COUNT(*) > 1
) d;

------------------------------------------------------------------------------
-- 7. FAMILY SIZE DISTRIBUTION — how deep do splits go? Drives whether a 2-row special
--    case is enough or the roll-up must be general.
------------------------------------------------------------------------------
SELECT '7_family_size' AS probe,
       nRows                                                             AS RowsInFamily,
       COUNT(*)                                                          AS Families
FROM (
    SELECT OrderCompany, OrderNum, OrderType, FLOOR(LineNum) AS ParentLine, COUNT(*) AS nRows
    FROM dbo.FactSalesDetail
    WHERE GLDate >= '2024-01-01'
      AND (RecordType IS NULL OR RecordType <> 'GL Detail')
      AND ISNULL(KitMasterLineNum, 0) = 0
      AND ISNULL(KitIdentifier, 0)    = 0
    GROUP BY OrderCompany, OrderNum, OrderType, FLOOR(LineNum)
) d
GROUP BY nRows
ORDER BY nRows;

------------------------------------------------------------------------------
-- 8. IMPACT — the number to show Ivan. Line count as-is vs collapsed to parent grain.
--    (Lateness is NOT computed here: it lives in the DAX via FactScheduleChange, so the
--    late-line delta has to be measured in the model, not in SQL. This is the
--    denominator half of the story.)
------------------------------------------------------------------------------
SELECT '8_impact' AS probe,
       COUNT(*)                                                                    AS LineRows_AsIs,
       COUNT(DISTINCT CONCAT(OrderCompany, ',', OrderNum, ',', OrderType, ',',
                             FORMAT(FLOOR(LineNum), '0.000')))                     AS LineRows_ParentGrain,
       COUNT(*) - COUNT(DISTINCT CONCAT(OrderCompany, ',', OrderNum, ',', OrderType, ',',
                             FORMAT(FLOOR(LineNum), '0.000')))                     AS RowsRemoved,
       CAST(100.0 * (COUNT(*) - COUNT(DISTINCT CONCAT(OrderCompany, ',', OrderNum, ',', OrderType, ',',
                             FORMAT(FLOOR(LineNum), '0.000'))))
            / NULLIF(COUNT(*), 0) AS decimal(5,2))                                 AS PctRemoved
FROM dbo.FactSalesDetail
WHERE GLDate >= '2024-01-01'
  AND (RecordType IS NULL OR RecordType <> 'GL Detail')
  AND ISNULL(KitMasterLineNum, 0) = 0
  AND ISNULL(KitIdentifier, 0)    = 0;
