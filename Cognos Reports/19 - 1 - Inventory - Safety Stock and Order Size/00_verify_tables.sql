/* ============================================================================
   Report 19 - 1 - Inventory - Safety Stock and Order Size
   Pre-flight / re-runnable verification for the EDWPROD / "EDW" route
   (plus one ODSPROD / "ODS" block for the planner-name lookup).

   These are the BUILD.md §12 probes, folded into one re-runnable script.
   Every block below was run against the LOCAL SQL MIRROR (localhost / EDW +
   ODS, snapshot loaded 2026-08-05) on 2026-08-06 and produced the expected
   values recorded in each comment - see BUILD.md V31/V32.

   The mirror proves the SQL CORRECT. It proves nothing about freshness or
   performance, so blocks 8-10 are the ones to re-run on EDWPROD/ODSPROD
   before a tie-out.

   HOW TO RUN
     - blocks 0-9   : against EDWPROD / EDW   (locally: localhost / EDW)
     - block 10     : against ODSPROD / ODS   (locally: localhost / ODS)
     - block 11     : jumpbox only - the two open items J1 and J2

   NOTE ON DATES: both queries are refresh-time-relative. Every block that
   filters on a date does so through @Boundary, set in block 0. Change it in
   ONE place. Against the 2026-08-06 tight capture the correct value is
   2026-02-05 (an afternoon Cognos run = D-182); the SHIPPED .m uses
   D-183, which is 51 output rows / +0.90% wider by design - BUILD.md §4.5
   trap 1 / V17.
   ============================================================================ */

/* ---- 0. Server / database sanity + the window boundary ----------------- */
SELECT @@SERVERNAME AS ServerName, DB_NAME() AS DbName;   -- expect EDWPROD / EDW

DECLARE @Boundary date = DATEADD(DAY, -183, CAST(GETDATE() AS date));
-- To reproduce the 2026-08-06 capture exactly, use:  SET @Boundary = '2026-02-05';
SELECT @Boundary AS WindowLowerBound,
       DATEADD(DAY, -182, CAST(GETDATE() AS date)) AS IfCognosRanAfternoon,
       DATEADD(DAY, -183, CAST(GETDATE() AS date)) AS IfCognosRanMorning;


/* ---- 1. Core objects reachable (row counts sane) ----------------------- */
SELECT 'BIQL.TbItemBranch'       AS TableName, COUNT_BIG(*) AS Rows FROM BIQL.TbItemBranch       WITH (NOLOCK);  -- 116,002
SELECT 'dbo.FactSalesDetail'     AS TableName, COUNT_BIG(*) AS Rows FROM dbo.FactSalesDetail     WITH (NOLOCK);  -- 979,343
SELECT 'BIQL.DimCustomer'        AS TableName, COUNT_BIG(*) AS Rows FROM BIQL.DimCustomer        WITH (NOLOCK);  --  22,227
SELECT 'BIQL.DimAddress'         AS TableName, COUNT_BIG(*) AS Rows FROM BIQL.DimAddress         WITH (NOLOCK);  --  37,339
SELECT 'BIQL.TbTerritoryManager' AS TableName, COUNT_BIG(*) AS Rows FROM BIQL.TbTerritoryManager WITH (NOLOCK);  --  19,321


/* ---- 2. Every column the two .m files name actually exists ------------- */
/* Expect 11 rows for TbItemBranch, 21 for FactSalesDetail, 3 / 6 / 2 for the dims. */
SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE (TABLE_NAME = 'TbItemBranch' AND COLUMN_NAME IN
          ('Business Unit','Item Bulk','Item Num 2nd','Stocking Type','Master Planning Family',
           'Lead Time MFG_BP','Planner Num','Planner Name','SafetyStock','UOM Primary',
           'ItemBranchSKey','Item Global Bulk'))
   OR (TABLE_NAME = 'FactSalesDetail' AND COLUMN_NAME IN
          ('OrderCompany','BusinessUnit','OrderNum','ItemNum2nd','OrderDate',
           'QuantityOrderedPrimaryUOM','UOMTransaction','ConversionFactorLB','ConversionFactorKG',
           'PromisedShipmentDate','ScheduledPickDate','AddressNumShipTo','ItemBranchSKey',
           'ShipToCustomerSKey','ShipToAddressSKey','TerritoryManagerSKey','RecordType',
           'SalesTableSource','OrderType','LineType','StatusCodeLast'))
   OR (TABLE_NAME = 'DimCustomer' AND TABLE_SCHEMA = 'BIQL' AND COLUMN_NAME IN
          ('CustomerSKey','SalesBusinessUnit','CustomerSegmentationDesc'))
   OR (TABLE_NAME = 'DimAddress' AND TABLE_SCHEMA = 'BIQL' AND COLUMN_NAME IN
          ('AddressSKey','AddressDesc','AddressNum','AddressNum5th','DWIsCurrent','MailAddressCountryDesc'))
   OR (TABLE_NAME = 'TbTerritoryManager' AND COLUMN_NAME IN ('TerritoryManagerSKey','Mailing Name'))
ORDER BY TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME;

/* The BIQL VIEW and its UOM-fix table are the J1 open item. On EDWPROD these
   should return 1 row each; in the local mirror they return ZERO, which is
   exactly why the shipped query sources dbo.FactSalesDetail - BUILD.md §0.5. */
SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME IN ('FactSalesDetail', 'FactSalesDetail_UOM_Fix')
ORDER BY TABLE_SCHEMA, TABLE_NAME;


/* ---- 3. Fan-out: every dimension unique on its SKey -------------------- */
/* Rows must equal Distinct on all four, or a join fans out. V8. */
SELECT 'TbItemBranch'       AS Dim, COUNT_BIG(*) AS Rows, COUNT(DISTINCT ItemBranchSKey)       AS Distinct_ FROM BIQL.TbItemBranch       WITH (NOLOCK)
UNION ALL SELECT 'DimCustomer',        COUNT_BIG(*), COUNT(DISTINCT CustomerSKey)              FROM BIQL.DimCustomer        WITH (NOLOCK)
UNION ALL SELECT 'DimAddress',         COUNT_BIG(*), COUNT(DISTINCT AddressSKey)               FROM BIQL.DimAddress         WITH (NOLOCK)
UNION ALL SELECT 'TbTerritoryManager', COUNT_BIG(*), COUNT(DISTINCT TerritoryManagerSKey)      FROM BIQL.TbTerritoryManager WITH (NOLOCK);

/* ItemBranchSKey is the correct pairing key; ItemSKey + Business Unit is NOT
   unique (115,989 distinct for 116,002 rows = 13 collisions). V8. */
SELECT COUNT_BIG(*) AS Rows,
       COUNT(DISTINCT CONCAT(CAST(ItemSKey AS varchar(20)), '|', LTRIM(RTRIM([Business Unit])))) AS DistinctItemPlusBU
FROM BIQL.TbItemBranch WITH (NOLOCK);


/* ---- 4. QUERY 1 stepwise counts ---------------------------------------- */
/* Expect 116,002 -> 44,330 -> 509 -> 502 -> 177.  V4 / V31. */
SELECT 'A all'                     AS Step, COUNT_BIG(*) AS Rows FROM BIQL.TbItemBranch WITH (NOLOCK)
UNION ALL
SELECT 'B + 6 branch plants', COUNT_BIG(*) FROM BIQL.TbItemBranch WITH (NOLOCK)
 WHERE LTRIM(RTRIM([Business Unit])) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
UNION ALL
SELECT 'C + SafetyStock > 1', COUNT_BIG(*) FROM BIQL.TbItemBranch WITH (NOLOCK)
 WHERE LTRIM(RTRIM([Business Unit])) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
   AND SafetyStock > 1
UNION ALL
SELECT 'D + Stocking Type <> O', COUNT_BIG(*) FROM BIQL.TbItemBranch WITH (NOLOCK)
 WHERE LTRIM(RTRIM([Business Unit])) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
   AND SafetyStock > 1 AND LTRIM(RTRIM([Stocking Type])) NOT IN ('O')
UNION ALL
SELECT 'E + MPF LIKE %F%  (TARGET 177)', COUNT_BIG(*) FROM BIQL.TbItemBranch WITH (NOLOCK)
 WHERE LTRIM(RTRIM([Business Unit])) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
   AND SafetyStock > 1 AND LTRIM(RTRIM([Stocking Type])) NOT IN ('O')
   AND [Master Planning Family] LIKE '%F%';

/* Branch split - expect CIN2 129, AUBA 24, SNG4 11, AUB2 9, CINC 4, SING 0. */
SELECT LTRIM(RTRIM([Business Unit])) AS BranchPlant, COUNT_BIG(*) AS Rows
FROM BIQL.TbItemBranch WITH (NOLOCK)
WHERE LTRIM(RTRIM([Business Unit])) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND SafetyStock > 1 AND LTRIM(RTRIM([Stocking Type])) NOT IN ('O')
  AND [Master Planning Family] LIKE '%F%'
GROUP BY LTRIM(RTRIM([Business Unit])) ORDER BY Rows DESC;

/* Threshold sensitivity: '> 1' -> 177, '> 0' -> 178. Do NOT add ISNULL -
   EDW writes NULL where IBSAFE = 0, and '> 1' excludes NULL exactly as
   Oracle does. V2. */
SELECT SUM(CASE WHEN SafetyStock > 1 THEN 1 ELSE 0 END) AS GT1,
       SUM(CASE WHEN SafetyStock > 0 THEN 1 ELSE 0 END) AS GT0
FROM BIQL.TbItemBranch WITH (NOLOCK)
WHERE LTRIM(RTRIM([Business Unit])) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND LTRIM(RTRIM([Stocking Type])) NOT IN ('O')
  AND [Master Planning Family] LIKE '%F%';

/* The two safety-stock columns are IDENTICAL - the choice is free. Expect
   693 non-null each, 0 differing. V2. */
SELECT COUNT_BIG(*) AS Rows,
       SUM(CASE WHEN SafetyStock IS NOT NULL THEN 1 ELSE 0 END)          AS SafetyStock_NotNull,
       SUM(CASE WHEN [Safety Stock SAFE] IS NOT NULL THEN 1 ELSE 0 END)  AS SAFE_NotNull,
       SUM(CASE WHEN ISNULL(SafetyStock, -1) <> ISNULL([Safety Stock SAFE], -1) THEN 1 ELSE 0 END) AS Differ
FROM BIQL.TbItemBranch WITH (NOLOCK);

/* Relationship key: must be 177 / 177 / 0 nulls, or the §2 relationship fails. */
SELECT COUNT_BIG(*) AS Rows, COUNT(DISTINCT ItemBranchSKey) AS Distinct_,
       SUM(CASE WHEN ItemBranchSKey IS NULL THEN 1 ELSE 0 END) AS Nulls
FROM BIQL.TbItemBranch WITH (NOLOCK)
WHERE LTRIM(RTRIM([Business Unit])) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND SafetyStock > 1 AND LTRIM(RTRIM([Stocking Type])) NOT IN ('O')
  AND [Master Planning Family] LIKE '%F%';


/* ---- 5. Code decodes -------------------------------------------------- */
/* MPF LIKE '%F%' must admit exactly FBW / FCB / FEC / FRC, summing to 177.
   No current code carries an EMBEDDED F, so '%F%' == 'F%' today - but keep
   '%F%' verbatim, and watch for a future code such as 'TFL'. V6. */
SELECT LTRIM(RTRIM([Master Planning Family])) AS MPF, COUNT_BIG(*) AS Rows
FROM BIQL.TbItemBranch WITH (NOLOCK)
WHERE LTRIM(RTRIM([Business Unit])) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND SafetyStock > 1 AND LTRIM(RTRIM([Stocking Type])) NOT IN ('O')
  AND [Master Planning Family] LIKE '%F%'
GROUP BY LTRIM(RTRIM([Master Planning Family])) ORDER BY Rows DESC;

/* LineType NOT LIKE '%F%' is the freight carve-out and ADMITS AN EMBEDDED F.
   'CF' (Credit on Freight) must appear in this list - a LIKE 'F%'
   "simplification" would wrongly KEEP it. V10. */
SELECT LTRIM(RTRIM(LineType)) AS LineType, COUNT_BIG(*) AS Rows
FROM dbo.FactSalesDetail WITH (NOLOCK)
WHERE LineType LIKE '%F%'
GROUP BY LTRIM(RTRIM(LineType)) ORDER BY Rows DESC;

/* OPEN_INDICATOR background. SalesTableSource is a stored discriminator -
   value 5 is GL Detail, which is why RecordType = 'Sales Detail' is the real
   budget carve-out. V3. NOTE: SalesTableSource is NOT the OPEN_INDICATOR port
   any more - see the equivalence block below and V39. */
SELECT SalesTableSource, RecordType, COUNT_BIG(*) AS Rows,
       MIN(OrderDate) AS MinOrderDate, MAX(OrderDate) AS MaxOrderDate,
       COUNT(DISTINCT StatusCodeNext) AS DistinctNextStatus
FROM dbo.FactSalesDetail WITH (NOLOCK)
GROUP BY SalesTableSource, RecordType ORDER BY SalesTableSource;

/* OPEN_INDICATOR <> 'Y' ports to StatusCodeNext = '999' (V39). Report 21's
   jumpbox probe cross-tabbed OPEN_INDICATOR against its own Cognos export over
   17,259 rows with zero exceptions: 'N' <=> StatusCodeNext = '999'.
   In REPORT 19's window the retired SalesTableSource <> 1 predicate happens to
   agree exactly - BOTH cells below must be 0. They will NOT stay 0 if the
   window or branch list widens, which is precisely why the predicate changed
   while the row count did not. StatusCodeNext is nchar(3): the TRIM is
   load-bearing, and without it the whole table loads empty. */
SELECT 'agree?' AS chk,
       SUM(CASE WHEN f.SalesTableSource =  1 AND LTRIM(RTRIM(f.StatusCodeNext)) =  '999' THEN 1 ELSE 0 END) AS Src1_But_999,
       SUM(CASE WHEN f.SalesTableSource <> 1 AND LTRIM(RTRIM(f.StatusCodeNext)) <> '999' THEN 1 ELSE 0 END) AS NotSrc1_But_Open,
       COUNT_BIG(*) AS LinesInWindow
FROM dbo.FactSalesDetail f WITH (NOLOCK)
    INNER JOIN BIQL.TbItemBranch ib WITH (NOLOCK) ON ib.ItemBranchSKey = f.ItemBranchSKey
    INNER JOIN BIQL.DimCustomer  sc WITH (NOLOCK) ON sc.CustomerSKey   = f.ShipToCustomerSKey
WHERE f.RecordType = 'Sales Detail'
  AND LTRIM(RTRIM(f.BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND f.PromisedShipmentDate >= DATEADD(DAY, -183, CAST(GETDATE() AS date))
  AND LTRIM(RTRIM(f.OrderType)) NOT IN ('S5','ST')
  AND f.LineType NOT LIKE '%F%'
  AND f.StatusCodeLast NOT IN ('980','984')
  AND f.QuantityOrderedPrimaryUOM > 0
  AND LTRIM(RTRIM(ISNULL(sc.SalesBusinessUnit,''))) <> 'INT'
  AND ib.[Master Planning Family] LIKE '%F%';

/* CANCELLED_INDICATOR: statuses 980 and 984 must show QuantityShipped = 0,
   QuantityCanceledScrapped <> 0 and AmountExtendedPrice = 0 on 100% of rows,
   and every other status the reverse. This is why Cancelled_Flag is the wrong
   port (it catches only 118 of 486). V23. */
SELECT LTRIM(RTRIM(StatusCodeLast)) AS StatusCodeLast, COUNT_BIG(*) AS Rows,
       SUM(CASE WHEN QuantityShipped = 0 THEN 1 ELSE 0 END)             AS ShippedZero,
       SUM(CASE WHEN QuantityCanceledScrapped <> 0 THEN 1 ELSE 0 END)   AS CancelledNonZero,
       SUM(CASE WHEN AmountExtendedPrice = 0 THEN 1 ELSE 0 END)         AS PriceZero
FROM dbo.FactSalesDetail WITH (NOLOCK)
WHERE RecordType = 'Sales Detail' AND LTRIM(RTRIM(StatusCodeNext)) = '999'
  AND LTRIM(RTRIM(BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND PromisedShipmentDate >= DATEADD(DAY, -183, CAST(GETDATE() AS date))
  AND LTRIM(RTRIM(OrderType)) NOT IN ('S5','ST')
  AND LineType NOT LIKE '%F%'
GROUP BY LTRIM(RTRIM(StatusCodeLast)) ORDER BY Rows DESC;

/* BUDGET_FACTOR <> 1 is a NO-OP: BudgetFactor is 0.0000 on every row, so
   porting it INSTEAD of RecordType = 'Sales Detail' would let 109,602
   GL/budget rows in. V10. */
SELECT COUNT_BIG(*) AS Rows, MIN(BudgetFactor) AS MinBF, MAX(BudgetFactor) AS MaxBF
FROM dbo.FactSalesDetail WITH (NOLOCK);

/* '-' is COGNOS RENDERING A NULL, not a stored sentinel: expect 0 literal
   dashes and 0 empty strings, with the missing values held as NULL. V27. */
SELECT SUM(CASE WHEN [Item Bulk] IS NULL THEN 1 ELSE 0 END)         AS BulkNull,
       SUM(CASE WHEN [Item Bulk] = '' THEN 1 ELSE 0 END)            AS BulkEmpty,
       SUM(CASE WHEN [Item Bulk] = '-' THEN 1 ELSE 0 END)           AS BulkDash,
       SUM(CASE WHEN [Item Global Bulk] IS NULL THEN 1 ELSE 0 END)  AS GBINull,
       SUM(CASE WHEN [Item Global Bulk] = '' THEN 1 ELSE 0 END)     AS GBIEmpty,
       SUM(CASE WHEN [Item Global Bulk] = '-' THEN 1 ELSE 0 END)    AS GBIDash
FROM BIQL.TbItemBranch WITH (NOLOCK);

/* AC01 / AC06 identity - both must be 0 mismatches over all 22,227 rows.
   Do NOT re-derive AC01 from the plausible-looking 'InternationalCustomer'. V9. */
SELECT SUM(CASE WHEN ISNULL(b.SalesBusinessUnit,'#') <> ISNULL(d.AddressCode01,'#') THEN 1 ELSE 0 END) AS AC01_Mismatches,
       SUM(CASE WHEN ISNULL(b.CustomerSegmentation,'#') <> ISNULL(d.AddressCode06,'#') THEN 1 ELSE 0 END) AS AC06_Mismatches,
       COUNT_BIG(*) AS Rows
FROM BIQL.DimCustomer b WITH (NOLOCK)
    INNER JOIN dbo.DimCustomer d WITH (NOLOCK) ON d.CustomerSKey = b.CustomerSKey;


/* ---- 6. The measure mapping (GATE) ------------------------------------ */
/* SalesFactor is NOT a UOM conversion: expect it to be 1.0000 on ~977,203
   rows and 0.0000 on ~2,140 - every row, no other value. V11. */
SELECT SalesFactor, COUNT_BIG(*) AS Rows
FROM dbo.FactSalesDetail WITH (NOLOCK)
GROUP BY SalesFactor ORDER BY Rows DESC;

/* The real conversion: QuantityOrderedPrimaryUOM / QuantityOrdered reproduces
   F41002.UMCONV (TO->LB 2500, TO->KG 1000, DR->KG 200, B1->LB 44,
   KG->LB 2.204619) and differs from QuantityOrdered on ~65.7% of in-window
   lines. V11 / V20. */
SELECT LTRIM(RTRIM(UOMTransaction)) AS UOMTx, LTRIM(RTRIM(UOMPrimary)) AS UOMPrim,
       COUNT_BIG(*) AS Rows,
       COUNT(DISTINCT CAST(ROUND(QuantityOrderedPrimaryUOM / NULLIF(QuantityOrdered,0), 6) AS decimal(20,6))) AS DistinctRatios,
       MIN(CAST(ROUND(QuantityOrderedPrimaryUOM / NULLIF(QuantityOrdered,0), 6) AS decimal(20,6))) AS Ratio
FROM dbo.FactSalesDetail WITH (NOLOCK)
WHERE RecordType = 'Sales Detail'
  AND LTRIM(RTRIM(BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND PromisedShipmentDate >= DATEADD(DAY, -183, CAST(GETDATE() AS date))
  AND QuantityOrdered <> 0
GROUP BY LTRIM(RTRIM(UOMTransaction)), LTRIM(RTRIM(UOMPrimary))
ORDER BY Rows DESC;


/* ---- 7. QUERY 2 join drops -------------------------------------------- */
/* Item-branch / ship-to customer / ship-to address / parent must all be 0.
   Territory Manager will NOT be - which is why it is LEFT-joined. V5 / V22. */
DECLARE @B date = DATEADD(DAY, -183, CAST(GETDATE() AS date));

SELECT COUNT_BIG(*)                                                      AS BaseLines,
       SUM(CASE WHEN ib.ItemBranchSKey       IS NULL THEN 1 ELSE 0 END)  AS Drop_ItemBranch,
       SUM(CASE WHEN sc.CustomerSKey         IS NULL THEN 1 ELSE 0 END)  AS Drop_ShipToCustomer,
       SUM(CASE WHEN sa.AddressSKey          IS NULL THEN 1 ELSE 0 END)  AS Drop_ShipToAddress,
       SUM(CASE WHEN p5.AddressSKey          IS NULL THEN 1 ELSE 0 END)  AS Drop_GlobalParent,
       SUM(CASE WHEN tm.TerritoryManagerSKey IS NULL THEN 1 ELSE 0 END)  AS Drop_TerritoryManager
FROM dbo.FactSalesDetail f WITH (NOLOCK)
    LEFT JOIN BIQL.TbItemBranch       ib WITH (NOLOCK) ON ib.ItemBranchSKey       = f.ItemBranchSKey
    LEFT JOIN BIQL.DimCustomer        sc WITH (NOLOCK) ON sc.CustomerSKey         = f.ShipToCustomerSKey
    LEFT JOIN BIQL.DimAddress         sa WITH (NOLOCK) ON sa.AddressSKey          = f.ShipToAddressSKey
    LEFT JOIN BIQL.DimAddress         p5 WITH (NOLOCK) ON p5.AddressNum           = sa.AddressNum5th AND p5.DWIsCurrent = 1
    LEFT JOIN BIQL.TbTerritoryManager tm WITH (NOLOCK) ON tm.TerritoryManagerSKey = f.TerritoryManagerSKey
WHERE f.RecordType = 'Sales Detail'
  AND LTRIM(RTRIM(f.StatusCodeNext)) = '999'
  AND LTRIM(RTRIM(f.BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND f.PromisedShipmentDate >= @B;

/* How many TerritoryManagerSKey values the EDW dimension cannot resolve.
   Expect ~22 distinct, INCLUDING the -1 unknown member. V22. */
SELECT COUNT(DISTINCT f.TerritoryManagerSKey) AS UnresolvableSKeys
FROM dbo.FactSalesDetail f WITH (NOLOCK)
WHERE f.RecordType = 'Sales Detail'
  AND NOT EXISTS (SELECT 1 FROM BIQL.TbTerritoryManager tm WITH (NOLOCK)
                  WHERE tm.TerritoryManagerSKey = f.TerritoryManagerSKey);


/* ---- 8. QUERY 2 stepwise counts + the tie-out --------------------------
   ⚠ ONE DELIBERATE SUBSTITUTION vs the shipped Shipments.m, so this block can
   run against the LOCAL MIRROR as well as EDWPROD:

       shipped:  FROM BIQL.FactSalesDetail f ... f.Unit_Weight_Adj, f.UOM_Weight_Adj
       here:     FROM dbo.FactSalesDetail  f ... f.UnitWeight,      f.UOMWeight

   That is not a shortcut - it is measured equivalence. Unit_Weight_Adj is
   byte-identical to UnitWeight, and UOM_Weight_Adj to UOMWeight, on ALL 7,663
   probe lines, and the substitution reproduces the shipped weights EXACTLY:
   same 98.96% / 99.00% of groups exact, same -0.0021% column totals (V40).
   The BIQL view is absent from the mirror; the shipped query reads it anyway
   because that is where a future item-weight correction will land.
   Running this block on EDWPROD? Swap the two lines back and it still ties. */
/* Against boundary 2026-02-05 expect: 869,741 -> 725,224 -> 15,704 ->
   14,471 -> 10,332 -> 8,723 -> ~8,204 -> 8,133 -> 7,909 -> 7,209 lines,
   and 5,675 rows after the 15-key group-by. §4.5 / V19 / V31. */
DECLARE @B2 date = DATEADD(DAY, -183, CAST(GETDATE() AS date));
-- SET @B2 = '2026-02-05';   -- to reproduce the 2026-08-06 capture exactly

SELECT
    f.OrderCompany                              AS [Order Company],
    LTRIM(RTRIM(f.BusinessUnit))                AS [Branch Plant],
    f.OrderNum                                  AS [Order Number],
    ib.[Item Bulk]                              AS [Bulk Item],
    f.ItemNum2nd                                AS [2nd Item Number],
    f.OrderDate                                 AS [Ordered Date],
    f.QuantityOrderedPrimaryUOM                 AS [Ordered Quantity Primary UOM],
    LTRIM(RTRIM(f.UOMTransaction))              AS [Ordering Unit of Measure],
    f.UnitWeight                                AS [Line Weight Adj],       -- = Unit_Weight_Adj
    LTRIM(RTRIM(f.UOMWeight))                   AS [Line Weight Adj UOM],   -- = UOM_Weight_Adj
    f.ConversionFactorLB                        AS [Conversion Factor LB],
    f.ConversionFactorKG                        AS [Conversion Factor KG],
    f.PromisedShipmentDate                      AS [Promised Ship Date],
    f.ScheduledPickDate                         AS [Scheduled Pick Date],
    f.AddressNumShipTo                          AS [Customer Code],
    LTRIM(RTRIM(sa.AddressDesc))                AS [Customer Name],
    LTRIM(RTRIM(p5.AddressDesc))                AS [Global Parent Name],
    sc.CustomerSegmentationDesc                 AS [Customer Segmentation Description],
    ISNULL(tm.[Mailing Name], 'Not Available')  AS [TM Name],
    sa.MailAddressCountryDesc                   AS [Country Name],
    ib.[Item Global Bulk]                       AS [Item Global Bulk]
INTO #ship
FROM dbo.FactSalesDetail f WITH (NOLOCK)
    INNER JOIN BIQL.TbItemBranch       ib WITH (NOLOCK) ON ib.ItemBranchSKey       = f.ItemBranchSKey
    INNER JOIN BIQL.DimCustomer        sc WITH (NOLOCK) ON sc.CustomerSKey         = f.ShipToCustomerSKey
    INNER JOIN BIQL.DimAddress         sa WITH (NOLOCK) ON sa.AddressSKey          = f.ShipToAddressSKey
    LEFT  JOIN BIQL.DimAddress         p5 WITH (NOLOCK) ON p5.AddressNum           = sa.AddressNum5th AND p5.DWIsCurrent = 1
    LEFT  JOIN BIQL.TbTerritoryManager tm WITH (NOLOCK) ON tm.TerritoryManagerSKey = f.TerritoryManagerSKey
WHERE f.RecordType = 'Sales Detail'
  AND LTRIM(RTRIM(f.StatusCodeNext)) = '999'
  AND LTRIM(RTRIM(f.BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
  AND f.PromisedShipmentDate >= @B2
  AND LTRIM(RTRIM(f.OrderType)) NOT IN ('S5','ST')
  AND f.LineType NOT LIKE '%F%'
  AND f.StatusCodeLast NOT IN ('980','984')
  AND f.QuantityOrderedPrimaryUOM > 0
  AND LTRIM(RTRIM(ISNULL(sc.SalesBusinessUnit,''))) <> 'INT'
  AND ib.[Master Planning Family] LIKE '%F%';

SELECT 'Lines imported by Shipments.m' AS Metric, COUNT_BIG(*) AS Value FROM #ship;

/* The 15-key group-by the TABLE VISUAL reproduces. TARGET 5,675 at -182. */
SELECT 'Output rows after the 15-key group-by' AS Metric, COUNT_BIG(*) AS Value FROM (
    SELECT [Order Company],[Branch Plant],[Order Number],[Bulk Item],[2nd Item Number],[Ordered Date],
           [Ordering Unit of Measure],[Promised Ship Date],[Scheduled Pick Date],[Customer Code],
           [Customer Name],[Global Parent Name],[Customer Segmentation Description],[TM Name],[Country Name]
    FROM #ship
    GROUP BY [Order Company],[Branch Plant],[Order Number],[Bulk Item],[2nd Item Number],[Ordered Date],
             [Ordering Unit of Measure],[Promised Ship Date],[Scheduled Pick Date],[Customer Code],
             [Customer Name],[Global Parent Name],[Customer Segmentation Description],[TM Name],[Country Name]
) g;

/* Column totals. At -182 expect Qty 39,590,713.21 (capture: identical) and
   4,155 orders. The two weight columns are computed the way the DAX does it -
   [Line Weight Adj] is a LINE TOTAL in [Line Weight Adj UOM], so there is NO
   multiplication by quantity, only a unit conversion. 2.2045992 is the pinned
   KG->LB constant; in the model it lives in exactly one place, the hidden
   measure [K KG to LB]. Expect both weight totals within -0.0021% of the
   capture's 48,307,620.74 LBs / 21,912,200.98 KGs. V38 / V40.
   SumLBs_OLD / SumKGs_OLD reproduce the SUPERSEDED qty x factor basis, which
   lands +0.376% high - kept so the improvement stays visible. */
SELECT CAST(SUM([Ordered Quantity Primary UOM]) AS decimal(20,2))                                AS SumQty,
       CAST(SUM(CASE WHEN [Line Weight Adj UOM] = 'LB' THEN [Line Weight Adj]
                     ELSE [Line Weight Adj] * 2.2045992 END) AS decimal(20,2))                   AS SumLBs,
       CAST(SUM(CASE WHEN [Line Weight Adj UOM] = 'KG' THEN [Line Weight Adj]
                     ELSE [Line Weight Adj] / 2.2045992 END) AS decimal(20,2))                   AS SumKGs,
       CAST(SUM([Ordered Quantity Primary UOM] * [Conversion Factor LB]) AS decimal(20,2))       AS SumLBs_OLD,
       CAST(SUM([Ordered Quantity Primary UOM] * [Conversion Factor KG]) AS decimal(20,2))       AS SumKGs_OLD,
       COUNT(DISTINCT [Order Number])                                                            AS DistinctOrders,
       MIN([Promised Ship Date]) AS MinPromised, MAX([Promised Ship Date]) AS MaxPromised
FROM #ship;

/* The weight-basis guard. [Line Weight Adj UOM] must be exactly {LB, KG} with
   no NULLs, blanks or third value - the DAX IF() has no else-branch for one,
   and a stray value would be silently treated as KG by the LBs column and as
   LB by the KGs column. Measured: LB 4,352 / KG 2,857, 0 nulls, 0 zeros. */
SELECT ISNULL(NULLIF(LTRIM(RTRIM([Line Weight Adj UOM])), ''), '(blank/null)') AS WeightUOM,
       COUNT_BIG(*) AS Lines,
       SUM(CASE WHEN [Line Weight Adj] IS NULL THEN 1 ELSE 0 END) AS NullWeights,
       SUM(CASE WHEN [Line Weight Adj] = 0 THEN 1 ELSE 0 END)     AS ZeroWeights
FROM #ship
GROUP BY ISNULL(NULLIF(LTRIM(RTRIM([Line Weight Adj UOM])), ''), '(blank/null)')
ORDER BY Lines DESC;

/* Branch split of the grouped output - at -182 expect CIN2 3,229 / AUBA 1,567
   / SNG4 653 / CINC 209 / SING 17 / AUB2 0. */
SELECT [Branch Plant], COUNT_BIG(*) AS Rows FROM (
    SELECT DISTINCT [Order Company],[Branch Plant],[Order Number],[Bulk Item],[2nd Item Number],[Ordered Date],
           [Ordering Unit of Measure],[Promised Ship Date],[Scheduled Pick Date],[Customer Code],
           [Customer Name],[Global Parent Name],[Customer Segmentation Description],[TM Name],[Country Name]
    FROM #ship
) g GROUP BY [Branch Plant] ORDER BY Rows DESC;


/* ---- 9. The India-tax exclusion (DAX rule, verified here) -------------- */
/* The rule lives in DAX; this block only confirms it still removes 0 rows.
   If it ever removes more than 0, add a numbered BUILD.md validation-log
   entry with the count. V28 / V29. */
SELECT 'Lines the India-tax rule would remove' AS Metric, COUNT_BIG(*) AS Value
FROM #ship
WHERE (CASE WHEN LTRIM(RTRIM(ISNULL([Item Global Bulk],''))) IN ('','-')
            THEN LTRIM(RTRIM([2nd Item Number]))
            ELSE LTRIM(RTRIM([Item Global Bulk])) END)
      IN ('IGST','CGST','SGST','CVD','ADD');

/* Why it removes zero: the tax pseudo-items exist, but only in Indian plants
   (MUM3 / MUM2 / HARY) with a blank Master Planning Family - so both the
   six-plant filter AND the finished-goods filter already exclude them. V28. */
SELECT LTRIM(RTRIM(f.BusinessUnit)) AS BranchPlant, LTRIM(RTRIM(f.ItemNum2nd)) AS TaxItem,
       COUNT_BIG(*) AS Lines
FROM dbo.FactSalesDetail f WITH (NOLOCK)
WHERE LTRIM(RTRIM(f.ItemNum2nd)) IN ('IGST','CGST','SGST','CVD','ADD')
GROUP BY LTRIM(RTRIM(f.BusinessUnit)), LTRIM(RTRIM(f.ItemNum2nd))
ORDER BY Lines DESC;

DROP TABLE #ship;


/* ============================================================================
   ---- 10. RUN THIS BLOCK AGAINST ODSPROD / ODS -----------------------------
   The planner-name lookup behind the 'Planner Names' table. EDW and ODS are
   DIFFERENT SERVERS, which is why this is a separate .m and a model
   relationship rather than a join. BUILD.md §3.4 trap 3 / V32.
   ============================================================================ */
/*
SELECT @@SERVERNAME AS ServerName, DB_NAME() AS DbName;   -- expect ODSPROD / ODS

-- ABAN8 must be unique or the relationship fans out. Expect Rows = Distinct.
SELECT COUNT_BIG(*) AS Rows, COUNT(DISTINCT ABAN8) AS Distinct_
FROM PRODDTA.F0101 WITH (NOLOCK);

-- The shipped lookup. Small result (57 rows against the mirror).
SELECT ab.ABAN8 AS [Planner Number], LTRIM(RTRIM(ab.ABALPH)) AS [Planner Name (JDE)]
FROM PRODDTA.F0101 ab WITH (NOLOCK)
WHERE ab.ABAN8 IN (
          SELECT ibp.IBANPL
          FROM PRODDTA.F4102 ibp WITH (NOLOCK)
          WHERE LTRIM(RTRIM(ibp.IBMCU)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
      )
ORDER BY 2;
-- Expect the Cognos spellings, 'Last, First' and ASCII:
--   Bertrand, Joel / Desjardin, Laurent / Hanlon, Tammy / Howe, Dave /
--   Jacquet, Lise / Lee, Wen Wei / Murphy, Lance
*/


/* ============================================================================
   ---- 11. JUMPBOX ONLY - the two open items --------------------------------
   Neither blocks the build. J1 should be answered before publish.
   ============================================================================ */
/*
-- J1: the UOM-fix weight factors (BUILD.md §0.5 / §9.3 / V25).
-- Worth +0.376% on both weight totals and ~285 structurally-wrong rows.
-- Reconcile against the export's 176 LBs / 79.833105264 KGs for this row;
-- Cognos's factor is exactly HALF EDW's (UnitWeight 176, ConversionFactorLB 88).
SELECT TOP 50 f.FSDSKey, f.ConversionFactorLB, f.ConversionFactorKG,
       f.[Unit_Weight_Adj], f.[UOM_Weight_Adj], f.[Fix U/M], f.[Fix Qty], f.[Fix Actual Qty]
FROM BIQL.FactSalesDetail f WITH (NOLOCK)
WHERE f.OrderNum IN (2585134) AND f.ItemNum2nd = 'DP680-B1';
-- If the adjusted factor reproduces Cognos: change Shipments.m's FROM clause
-- from dbo.FactSalesDetail to BIQL.FactSalesDetail and use the adjusted
-- factor. Every other column is identical between the two, so it is a
-- one-word change, and the report then ties on all 19 columns.

-- J2: does BIQLTabular_v2 expose 'Lead Time MFG_BP'? (BUILD.md §1.1 / §9.3)
-- ssasprod.bim is a dump of the STALE BIQLTabular. If v2 exposes this column
-- on Item Branch in the 'Supply and Demand' perspective, the SSAS live route
-- becomes mandated and the report collapses to two tables with zero Power
-- Query - a rewrite, not a patch.
-- Run against SSASPROD / BIQLTabular_v2:
SELECT * FROM $SYSTEM.TMSCHEMA_PERSPECTIVE_COLUMNS;
*/
