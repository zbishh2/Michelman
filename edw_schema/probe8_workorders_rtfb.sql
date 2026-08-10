/* ============================================================================
   PROBE 8 — WorkOrders table for the RTFB (Right Time First Batch) metric
   Run on: EDWPROD / EDW   (jumpbox — local is firewalled)
   Date:   2026-07-30
   Why:    We are porting SSAS BIQLTabular_v2's "Right Time First Batch" into the
           Executive Dashboard model. That metric's denominator is [WO Count] =
           DISTINCTCOUNT('Work Order Detail'[WorkOrderSKey]) based on Order Date,
           i.e. JDE F4801.WADOCO. Our model has no work-order table, so we are
           adding one from BIQL.TbWorkOrderDetail.

           The one hop I could NOT verify from the local schema dumps is
           BranchSKey -> TbBranch.CompanySKey -> TbCompany.Company, which is how
           we intend to derive Region (same 10/20/30/34/35 SWITCH that
           FactSalesDetail[Region] already uses on [Order Company]).

   Paste results back into BUILD/EDW_MODEL notes. Six standard categories.
   ============================================================================ */


/* --- 1. COLUMN EXISTENCE -------------------------------------------------
   Confirms the four objects exist with the columns the M query references.
   Expect: TbWorkOrderDetail has WorkOrderSKey, OrderDateSKey, StartDateSKey,
   CompletionDateSKey, BranchSKey, BusinessUnitSKey, LotSKey, QuantityOrdered.
   TbBranch has BranchSKey + CompanySKey. TbCompany has CompanySKey + Company. */
SELECT '1. columns' AS Probe, TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM   INFORMATION_SCHEMA.COLUMNS
WHERE  TABLE_SCHEMA = 'BIQL'
  AND  TABLE_NAME   IN ('TbWorkOrderDetail','TbBranch','TbCompany','TbDate')
  AND  COLUMN_NAME  IN ('WorkOrderSKey','OrderDateSKey','StartDateSKey',
                        'CompletionDateSKey','BranchSKey','BusinessUnitSKey',
                        'LotSKey','QuantityOrdered','CompanySKey','Company',
                        'Company Desc','DateSKey','CalendarDate')
ORDER BY TABLE_NAME, COLUMN_NAME;


/* --- 2. JOIN DROPS -------------------------------------------------------
   A LEFT JOIN that silently misses is the classic way a denominator inflates.
   Expect: DroppedDate ~ 0 for rows in our window; DroppedBranch / DroppedCompany
   should be small. If DroppedBranch is large, switch the region hop to
   BusinessUnitSKey -> TbBusinessUnit -> TbCompany instead (both dims carry
   CompanySKey; F0006 backs both).
   NOTE the -1 convention: EDW uses SKey = -1 for "unknown", so those are
   counted separately rather than as drops. */
SELECT '2. join drops' AS Probe,
       COUNT(*)                                                          AS WODRows,
       SUM(CASE WHEN wod.OrderDateSKey = -1  THEN 1 ELSE 0 END)          AS OrderDateUnknown,
       SUM(CASE WHEN wod.BranchSKey    = -1  THEN 1 ELSE 0 END)          AS BranchUnknown,
       SUM(CASE WHEN d.DateSKey  IS NULL AND wod.OrderDateSKey <> -1 THEN 1 ELSE 0 END) AS DroppedDate,
       SUM(CASE WHEN b.BranchSKey IS NULL AND wod.BranchSKey   <> -1 THEN 1 ELSE 0 END) AS DroppedBranch,
       SUM(CASE WHEN c.CompanySKey IS NULL THEN 1 ELSE 0 END)            AS DroppedCompany,
       SUM(CASE WHEN wod.BusinessUnitSKey = -1 THEN 1 ELSE 0 END)        AS BusinessUnitUnknown
FROM       BIQL.TbWorkOrderDetail wod
LEFT JOIN  BIQL.TbDate    d ON d.DateSKey    = wod.OrderDateSKey
LEFT JOIN  BIQL.TbBranch  b ON b.BranchSKey  = wod.BranchSKey
LEFT JOIN  BIQL.TbCompany c ON c.CompanySKey = b.CompanySKey;


/* --- 3. FAN-OUT ----------------------------------------------------------
   Is TbWorkOrderDetail one row per work order, or wider? The SSAS measure uses
   DISTINCTCOUNT, which tolerates fan-out -- but our table will also be sliced
   by Region and Date, so a WO appearing under two branches/dates would
   double-count in a by-region breakdown even though the global total is right.
   Expect: Rows = DistinctWO. If not, report MaxRowsPerWO and we add a
   ROW_NUMBER de-dupe (or accept DISTINCTCOUNT and document the region caveat). */
SELECT '3. fan-out' AS Probe,
       COUNT(*)                        AS Rows_,
       COUNT(DISTINCT wod.WorkOrderSKey) AS DistinctWO,
       MAX(rn.PerWO)                   AS MaxRowsPerWO
FROM       BIQL.TbWorkOrderDetail wod
CROSS APPLY (SELECT COUNT(*) AS PerWO
             FROM BIQL.TbWorkOrderDetail x
             WHERE x.WorkOrderSKey = wod.WorkOrderSKey) rn;
/* If the CROSS APPLY is slow (it re-evaluates per row -- the report-14 trap),
   run this cheaper form instead and ignore the one above:
     SELECT COUNT(*) AS Rows_, COUNT(DISTINCT WorkOrderSKey) AS DistinctWO
     FROM BIQL.TbWorkOrderDetail;
     SELECT TOP 10 WorkOrderSKey, COUNT(*) AS PerWO
     FROM BIQL.TbWorkOrderDetail GROUP BY WorkOrderSKey
     ORDER BY COUNT(*) DESC;                                                */


/* --- 4. CODE DECODES -----------------------------------------------------
   THE KEY PROBE. Does the branch->company hop actually yield the same company
   numbers FactSalesDetail[Order Company] uses? Our Region SWITCH maps
   10 -> Americas, 20 -> EMEA, 30/34/35 -> Asia, everything else -> Unmapped.
   Expect: the company list here is a subset of {10,20,30,34,35}. Any other
   value, or a large Unmapped bucket, means the mapping needs extending BEFORE
   we wire WorkOrders to 'Dim Region'. Note Company is CHAR in F0010 ('00010'),
   so it is reported both raw and as an int. */
SELECT '4. company decode' AS Probe,
       c.Company                                     AS CompanyRaw,
       TRY_CAST(c.Company AS int)                    AS CompanyInt,
       MAX(c.[Company Desc])                         AS CompanyDesc,
       CASE TRY_CAST(c.Company AS int)
            WHEN 10 THEN 'Americas'
            WHEN 20 THEN 'EMEA'
            WHEN 30 THEN 'Asia'
            WHEN 34 THEN 'Asia'
            WHEN 35 THEN 'Asia'
            ELSE 'Unmapped'  END                     AS RegionWouldBe,
       COUNT(DISTINCT wod.WorkOrderSKey)             AS WorkOrders
FROM       BIQL.TbWorkOrderDetail wod
LEFT JOIN  BIQL.TbDate    d ON d.DateSKey    = wod.OrderDateSKey
LEFT JOIN  BIQL.TbBranch  b ON b.BranchSKey  = wod.BranchSKey
LEFT JOIN  BIQL.TbCompany c ON c.CompanySKey = b.CompanySKey
WHERE  d.CalendarDate >= '2024-01-01'
GROUP BY c.Company, TRY_CAST(c.Company AS int)
ORDER BY WorkOrders DESC;


/* --- 5. COUNT PARITY -----------------------------------------------------
   The number that has to survive the port. This is [WO Count] by year on the
   Order Date basis -- the exact SSAS denominator, minus the fiscal-calendar-
   pattern wrapper (our DateTable is plain Gregorian, so there is no
   CalendarPatternSKey filter to apply).
   Compare these totals to the same years in SSAS BIQLTabular_v2 [WO Count].
   Also reports the Start/Completion bases so we can see how much the date
   choice moves the denominator. */
SELECT '5. WO count by year' AS Probe,
       YEAR(d.CalendarDate)              AS OrderYear,
       COUNT(DISTINCT wod.WorkOrderSKey) AS WOCount_OrderDate
FROM       BIQL.TbWorkOrderDetail wod
INNER JOIN BIQL.TbDate d ON d.DateSKey = wod.OrderDateSKey
WHERE  d.CalendarDate >= '2024-01-01'
GROUP BY YEAR(d.CalendarDate)
ORDER BY OrderYear;

SELECT '5b. date-basis sensitivity' AS Probe,
       YEAR(dc.CalendarDate)             AS CompletionYear,
       COUNT(DISTINCT wod.WorkOrderSKey) AS WOCount_CompletionDate
FROM       BIQL.TbWorkOrderDetail wod
INNER JOIN BIQL.TbDate dc ON dc.DateSKey = wod.CompletionDateSKey
WHERE  dc.CalendarDate >= '2024-01-01'
GROUP BY YEAR(dc.CalendarDate)
ORDER BY CompletionYear;

/* Freshness. EDWPROD is frozen for the Salesforce chain but current for JDE --
   confirm that holds for work orders. Expect a max order date within days of
   today (2026-07-30). If it stops in 2024, the WO feed is stale too and the
   denominator has to come from ODS instead. */
SELECT '5c. freshness' AS Probe,
       MIN(d.CalendarDate) AS MinOrderDate,
       MAX(d.CalendarDate) AS MaxOrderDate,
       COUNT(DISTINCT wod.WorkOrderSKey) AS WOTotal
FROM       BIQL.TbWorkOrderDetail wod
INNER JOIN BIQL.TbDate d ON d.DateSKey = wod.OrderDateSKey;


/* --- 6. FORMAT SPOT-CHECK ------------------------------------------------
   Eyeball 20 rows exactly as the M query will project them. Checks the date
   really is a date (not an int), Company really is the '000NN' char form, and
   the quantities are sane. */
SELECT TOP 20 '6. spot check' AS Probe,
       wod.WorkOrderSKey,
       d.CalendarDate        AS [Order Date],
       c.Company             AS [Order Company],
       b.[Branch Plant]      AS [Branch Plant],
       b.[Branch Plant Desc] AS [Branch Plant Desc],
       wod.LotSKey,
       wod.QuantityOrdered,
       wod.QuantityCanceledScrapped
FROM       BIQL.TbWorkOrderDetail wod
LEFT JOIN  BIQL.TbDate    d ON d.DateSKey    = wod.OrderDateSKey
LEFT JOIN  BIQL.TbBranch  b ON b.BranchSKey  = wod.BranchSKey
LEFT JOIN  BIQL.TbCompany c ON c.CompanySKey = b.CompanySKey
WHERE  d.CalendarDate >= '2026-01-01'
ORDER BY d.CalendarDate DESC;


/* --- 7. BONUS: the RTFB number itself, computed in SQL --------------------
   Not one of the six categories, but this is the tie-out. Case Count is
   UNFILTERED (all record types) per the client's definition, sourced from
   EDWDEV -- so this half has to run on EDWDEV, not here. Run it there and pair
   the two by year:
       RTFB % = 1 - (CaseCount / WOCount)

   -- ON EDWDEV / EDW:
   -- SELECT YEAR(Date_of_Occurance__c) AS OccurYear,
   --        COUNT(DISTINCT CaseNumber) AS CaseCount_All
   -- FROM   BIQL.TbSF_Case
   -- WHERE  Date_of_Occurance__c >= '2024-01-01'
   -- GROUP BY YEAR(Date_of_Occurance__c)
   -- ORDER BY OccurYear;
*/


/* =============================================================================
   §6  ROUTING HOURS + THE GLOBAL COMPLETION REPORT GAP   (added 2026-08-06)
   -----------------------------------------------------------------------------
   ⚠ PREFER THE SNAPSHOT. As of 2026-08-06 gen_snapshot_pbip.py pulls
   BIQL.TbWorkOrderRouting_Routing / _Time and PRODDTA.F3112 / F31122, so once the
   snapshot has been refreshed once, everything below is answerable locally in
   T-SQL against the mirror and none of this needs to run on the jumpbox. Keep
   this section for the case where an answer is needed before that refresh — and
   note that it doubles as the source-side cross-check on the EDW views, which the
   mirror cannot provide on its own.
   -----------------------------------------------------------------------------
   Everything above §6 has now been answered LOCALLY against the EDW-ODS snapshot
   mirror (CLAUDE.md §9) — grain, company domain, item resolution and the bulk
   test are all measured and written up in edw_model/WorkOrders.m. What could NOT
   be answered locally is anything touching ROUTING, because BIQL.TbWorkOrderRouting_*
   is not in the snapshot. That is what this section is for. Run it on EDWPROD.

   Context: WorkOrders.m now LEFT JOINs a GROUP BY derived table over
   BIQL.TbWorkOrderRouting_Routing to bring [Run Machine Actual Hours] onto the
   work order, and the DAX column WorkOrders[Has Machine Hours] tests it > 0.
   None of that is verified. Also open: our bulk work-order count for 2025 is
   ~7,384 against the client workbook's 6,107, and work-centre scope is the
   remaining suspect.
   ========================================================================== */

-- §6a  Is _Routing the right view, and is it one row per (WO, operation)?
--      _Time carries the same RunMachineActual column but looks like hours-
--      transaction grain (Type Of Hours / Shift Code / GL Date). Compare both.
SELECT 'Routing' AS src, COUNT(*) AS rows_, COUNT(DISTINCT WorkOrderSKey) AS wos,
       CAST(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT WorkOrderSKey),0) AS decimal(8,2)) AS rows_per_wo
FROM   BIQL.TbWorkOrderRouting_Routing WITH (NOLOCK)
UNION ALL
SELECT 'Time', COUNT(*), COUNT(DISTINCT WorkOrderSKey),
       CAST(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT WorkOrderSKey),0) AS decimal(8,2))
FROM   BIQL.TbWorkOrderRouting_Time WITH (NOLOCK);

-- §6b  Does the routing join resolve for substantially all work orders?
--      An unresolved join leaves the SUM NULL, and "NULL > 0" is false — those
--      work orders would silently vanish from any [Has Machine Hours] = 1 filter.
--      Report the unresolved count BEFORE trusting the flag.
WITH rt AS (
    SELECT WorkOrderSKey, SUM(RunMachineActual) AS RunMachineActual
    FROM   BIQL.TbWorkOrderRouting_Routing WITH (NOLOCK)
    GROUP BY WorkOrderSKey
)
SELECT COUNT(*)                                                        AS wo_total,
       SUM(CASE WHEN rt.WorkOrderSKey IS NULL THEN 1 ELSE 0 END)       AS no_routing_row,
       SUM(CASE WHEN rt.RunMachineActual IS NULL THEN 1 ELSE 0 END)    AS hours_null,
       SUM(CASE WHEN rt.RunMachineActual = 0 THEN 1 ELSE 0 END)        AS hours_zero,
       SUM(CASE WHEN rt.RunMachineActual > 0 THEN 1 ELSE 0 END)        AS hours_gt0,
       MIN(rt.RunMachineActual) AS min_hrs, MAX(rt.RunMachineActual) AS max_hrs,
       AVG(rt.RunMachineActual) AS avg_hrs   -- sanity: hours, or hundredths?
FROM       BIQL.TbWorkOrderDetail wod WITH (NOLOCK)
INNER JOIN BIQL.TbDate d WITH (NOLOCK) ON d.DateSKey = wod.OrderDateSKey
LEFT JOIN  rt ON rt.WorkOrderSKey = wod.WorkOrderSKey
WHERE      d.CalendarDate >= '2024-01-01';

-- §6c  THE GAP. The client workbook "Work Orders - Global Completion Report
--      2025.xlsm" reports 6,107 distinct bulk work orders for 2025 across CINC /
--      CIN2 / SING / AUBA, on its own date basis (completion date, or requested
--      date where completion is later). We get 7,384 on the same basis and
--      plants. WO status is not the difference (7,523 of 7,538 are status 99).
--      Suspect: the workbook rides a curated production work-centre list — 66 of
--      them, grouped Reactors / EC / Cold Blend / Small Batch / Big Batch /
--      Bluewave / Whites Group / K19 / Cowles, with Europe packaging split onto a
--      separate tab. Get the work-centre domain per plant and see whether
--      restricting to it closes the gap.
--      (BIQL.TbBranch[Bulk Production Work Center] is NOT the answer — measured
--       blank for all four plants.)
WITH rt AS (
    SELECT WorkOrderSKey,
           MIN(LTRIM(RTRIM([Work Center]))) AS FirstWorkCenter,
           COUNT(DISTINCT LTRIM(RTRIM([Work Center]))) AS WorkCenters,
           SUM(RunMachineActual) AS RunMachineActual
    FROM   BIQL.TbWorkOrderRouting_Routing WITH (NOLOCK)
    GROUP BY WorkOrderSKey
)
SELECT     LTRIM(RTRIM(b.[Branch Plant])) AS BranchPlant,
           rt.FirstWorkCenter,
           COUNT(DISTINCT wod.WorkOrderSKey) AS bulk_wos_2025
FROM       BIQL.TbWorkOrderDetail wod WITH (NOLOCK)
LEFT JOIN  BIQL.DimWorkOrder wo WITH (NOLOCK) ON wo.WorkOrderSKey  = wod.WorkOrderSKey
LEFT JOIN  BIQL.TbBranch     b  WITH (NOLOCK) ON b.BranchSKey      = wod.BranchSKey
LEFT JOIN  BIQL.TbItemBranch ib WITH (NOLOCK) ON ib.ItemBranchSKey = wod.ItemBranchSKey
LEFT JOIN  rt ON rt.WorkOrderSKey = wod.WorkOrderSKey
WHERE      LTRIM(RTRIM(b.[Branch Plant])) IN ('CINC','CIN2','SING','AUBA')
  AND      LTRIM(RTRIM(ib.[Item Bulk])) = LTRIM(RTRIM(ib.[Item Num 2nd]))   -- the bulk test
  AND      YEAR( CASE WHEN wo.CompletionDate IS NULL THEN NULL
                      WHEN wo.RequestedDate  IS NULL THEN wo.CompletionDate
                      WHEN wo.CompletionDate <= wo.RequestedDate THEN wo.CompletionDate
                      ELSE wo.RequestedDate END ) = 2025
GROUP BY   LTRIM(RTRIM(b.[Branch Plant])), rt.FirstWorkCenter
ORDER BY   BranchPlant, bulk_wos_2025 DESC;
-- Cross-check the resulting work-centre list against the workbook's
-- 'Work Order Report_1' column "Standard Work Center" (66 distinct values) and
-- 'Work Center Master_3'. If the excluded centres account for ~1,300 work orders,
-- the gap is explained and the filter belongs in a DAX column next to the others.
