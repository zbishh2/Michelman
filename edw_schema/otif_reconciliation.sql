/* =============================================================================
   OTIF / Reliability & Flexibility — EDW vs Cognos-fed spreadsheet reconciliation
   -----------------------------------------------------------------------------
   PURPOSE
     The business measures on-time today in
       "Reliability and Flexibility Global Branch Plant - New Logic.xlsx"
     which is fed by a MANUAL Cognos export ("Reliability and Flexibility Global
     Branch Plant Data Report", Production Moves, run by Tim Bath). That report is
     being sunset, and we do NOT know whether Cognos filters/transforms between
     JDE and the export. These queries pull the same fields straight from EDW so
     we can reconcile field-by-field and number-by-number against the workbook.

   WHAT THE SPREADSHEET ACTUALLY DOES (so the SQL below mirrors it):
     - Reliability  = REASON-CODE driven. A line is a MISS if it carries a counted
                      JDE Revision Reason (UDC 42/RR = RFRV); else "OnTime".
                      It never compares ship date to promised date.
     - Flexibility  = IF(Shipped <= Requested, 1, 0), with an MTO carve-out:
                      if requested INSIDE standard lead time
                      (NETWORKDAYS(Order, Request) <= F4102 lead time) it's excused.
     - No in-full / quantity component at all.
     - Grain: order-level (Order Count tab deduped by order #); the Reliabilty
       Count tab deduped by order#+line#+reason, line 1 only.
     - Month bucket = "Order Line Last Updated" (EDW UpdatedDate), NOT GL/ship date.

   TARGET: SSMS against EDWPROD / EDW, schema dbo (matches the Orders.m PBI model).
           Dates in dbo.FactSalesDetail are already real DATE types (no Julian math).

   ⚠ DO NOT FILTER ON GLDate. Open orders have GLDate = 1900-01-01 and the Cognos
     report includes open orders (its "Open Indicator" = Y). Filtering on GL date
     would drop exactly the open lines whose promised dates are being revised.
     Window on OrderDate / UpdatedDate instead (see @FromDate below).

   ⚠ OPEN QUESTIONS to settle with the team (drive the WHERE clauses):
       Q-a  Which Order Types does the Cognos report include? (left open below)
       Q-b  Which Revision Reason codes count as a "miss"? The workbook lookup lists
            C5,C6,F1,L1-L5,P3-P9,PD1-3,Q1,Q2,SS,T1,T3,T4 (T0/OnTime excluded), but
            live data shows codes NOT in that list (e.g. C2) and the instructions
            mention T2 — the set has drifted. Q3 surfaces the real set.
       Q-c  "Branch Plant" join: confirm BusinessUnit (MCU) vs Location.
       Q-d  Lead time field: F4102 col used by the sheet is unknown; candidates are
            DimItemBranch.LeadtimeLevel / LeadtimeMFG (see Q5).
   ============================================================================= */

DECLARE @FromDate date = '2024-01-01';   -- analysis floor; widen/narrow as needed
DECLARE @ToDate   date = '2026-12-31';

-- Counted "miss" revision-reason codes (workbook lookup; EDIT after Q-b is settled)
DECLARE @FaultReasons TABLE (Code nchar(3) PRIMARY KEY);
INSERT INTO @FaultReasons (Code) VALUES
 ('C5'),('C6'),('F1'),('L1'),('L2'),('L3'),('L4'),('L5'),
 ('P3'),('P4'),('P5'),('P6'),('P7'),('P8'),('P9'),
 ('PD1'),('PD2'),('PD3'),('Q1'),('Q2'),('SS'),('T1'),('T3'),('T4');


/* -----------------------------------------------------------------------------
   Q0 — Coverage sanity. Rows / distinct orders by year, open vs closed, so we
        know the population before reconciling. Bucketed on UpdatedDate (their axis).
   ----------------------------------------------------------------------------- */
SELECT
    [Year]        = YEAR(f.UpdatedDate),
    OpenClosed    = CASE WHEN f.GLDate <= '1900-01-02' THEN 'Open (no GL)' ELSE 'Closed' END,
    Lines         = COUNT(*),
    DistinctOrders= COUNT(DISTINCT f.OrderNum),
    WithRevReason = SUM(CASE WHEN LTRIM(RTRIM(f.RevisionReason)) <> '' THEN 1 ELSE 0 END),
    Shipped       = SUM(CASE WHEN f.ActualShipDate IS NOT NULL THEN 1 ELSE 0 END)
FROM dbo.FactSalesDetail f
WHERE (f.RecordType IS NULL OR f.RecordType <> 'GL Detail')
  AND f.UpdatedDate BETWEEN @FromDate AND @ToDate
GROUP BY YEAR(f.UpdatedDate),
         CASE WHEN f.GLDate <= '1900-01-02' THEN 'Open (no GL)' ELSE 'Closed' END
ORDER BY 1, 2;


/* -----------------------------------------------------------------------------
   Q1 — COGNOS-MIRROR line-level extract. One row per sales-order line with every
        column the Cognos report carries, mapped to EDW. Use this to reconcile
        field-by-field against the workbook's "Order Count" / "Reliabilty Count"
        tabs (match on Order Company + Order Number + Line Number).
        Export to CSV and diff against a weekly pull (e.g. "Week of March 16.xlsx").
   ----------------------------------------------------------------------------- */
SELECT
    [Order Company]                = f.OrderCompany,
    [Order Number]                 = f.OrderNum,
    [Line Number]                  = f.LineNum,
    [Order Type]                   = f.OrderType,          -- not on the sheet; for filtering
    [Line Type]                    = f.LineType,           -- not on the sheet; for filtering
    [2nd Item Number]              = f.ItemNum2nd,
    [Freight Handling Code]        = f.FreightHandlingCode,
    [Order Line Last Updated By]   = f.UserID,             -- confirm vs OrderTakenBy
    [Last Status]                  = f.StatusCodeLast,
    [Next Status]                  = f.StatusCodeNext,
    [Ordered Date]                 = f.OrderDate,
    [Branch Plant]                 = LTRIM(RTRIM(f.BusinessUnit)),   -- MCU; confirm Q-c
    [Promised Ship Date]           = f.PromisedShipmentDate,
    [Promised Date - Original]     = f.OriginalPromisedDeliveryDate,
    [Promised Delivery Date]       = f.PromisedDeliveryDate,         -- extra, for our DAX compare
    [Revision Reason]              = LTRIM(RTRIM(f.RevisionReason)),
    [Revision Reason Desc (UDC)]   = rr.UDCDesc01,
    [Revenue Business Unit]        = f.BusinessUnitRevenue,
    [Reason Code (line)]           = f.ReasonCode,         -- SDRCD, distinct from RevisionReason
    [Shipped Date]                 = f.ActualShipDate,
    [Requested Date]               = f.RequestedDate,
    [Scheduled Pick Date]          = f.ScheduledPickDate,
    [Order Line Last Updated]      = f.UpdatedDate,
    [Cancel Date]                  = f.CancelDate,
    [Hold Code]                    = f.HoldOrdersCode,
    [Cancelled Flag]               = f.Cancelled_Flag,
    [Qty Ordered]                  = f.QuantityOrdered,
    [Qty Shipped]                  = f.QuantityShipped,
    [Qty Cancelled]                = f.QuantityCanceledScrapped,
    [Open Indicator]               = CASE WHEN f.GLDate <= '1900-01-02' THEN 'Y' ELSE 'N' END
FROM dbo.FactSalesDetail f
LEFT JOIN dbo.DimUDC rr
       ON rr.ProductCode = '42' AND rr.SystemCode = 'RR'   -- ⚠ confirm 42/RR encoding via Q3a
      AND rr.UDC = f.RevisionReason
      AND rr.IsCurrent = 1
WHERE (f.RecordType IS NULL OR f.RecordType <> 'GL Detail')
  AND f.UpdatedDate BETWEEN @FromDate AND @ToDate
  -- AND f.OrderType IN ('S4','SO','SI','SE','SZ','SC','SB','SD')  -- enable after Q-a
ORDER BY f.OrderCompany, f.OrderNum, f.LineNum;


/* -----------------------------------------------------------------------------
   Q2 — Denominator counts: distinct orders by Company x Month (their bucket =
        UpdatedDate). Compare to the workbook "Order Count All" / "Order Count" tab.
   ----------------------------------------------------------------------------- */
SELECT
    Company       = LEFT(f.OrderCompany, 5),
    [Year]        = YEAR(f.UpdatedDate),
    [Month]       = MONTH(f.UpdatedDate),
    DistinctOrders= COUNT(DISTINCT f.OrderNum),
    Lines         = COUNT(*)
FROM dbo.FactSalesDetail f
WHERE (f.RecordType IS NULL OR f.RecordType <> 'GL Detail')
  AND f.UpdatedDate BETWEEN @FromDate AND @ToDate
  -- AND f.OrderType IN (...)   -- match the Cognos population once Q-a is known
GROUP BY LEFT(f.OrderCompany,5), YEAR(f.UpdatedDate), MONTH(f.UpdatedDate)
ORDER BY 1,2,3;


/* -----------------------------------------------------------------------------
   Q3a — DISCOVERY: how is UDC 42/RR encoded in DimUDC? Run once, then fix the
         join in Q1/Q3 if ProductCode/SystemCode differ from ('42','RR').
   ----------------------------------------------------------------------------- */
SELECT DISTINCT ProductCode, SystemCode, UDC, UDCDesc01
FROM dbo.DimUDC
WHERE UDC IN ('L3','P6','PD1','Q1','C5','T1','SS')   -- known reason codes
ORDER BY ProductCode, SystemCode, UDC;

/* -----------------------------------------------------------------------------
   Q3 — Revision-reason frequency in EDW vs the workbook's counted set.
        Flags codes present in data but MISSING from the fault list (drift check).
   ----------------------------------------------------------------------------- */
SELECT
    RevisionReason = LTRIM(RTRIM(f.RevisionReason)),
    ReasonDesc     = rr.UDCDesc01,
    InFaultList    = CASE WHEN fr.Code IS NOT NULL THEN 'Y' ELSE 'N' END,
    Lines          = COUNT(*),
    DistinctOrders = COUNT(DISTINCT f.OrderNum)
FROM dbo.FactSalesDetail f
LEFT JOIN @FaultReasons fr ON fr.Code = LTRIM(RTRIM(f.RevisionReason))
LEFT JOIN dbo.DimUDC rr
       ON rr.ProductCode = '42' AND rr.SystemCode = 'RR'
      AND rr.UDC = f.RevisionReason AND rr.IsCurrent = 1
WHERE (f.RecordType IS NULL OR f.RecordType <> 'GL Detail')
  AND f.UpdatedDate BETWEEN @FromDate AND @ToDate
  AND LTRIM(RTRIM(f.RevisionReason)) <> ''
GROUP BY LTRIM(RTRIM(f.RevisionReason)), rr.UDCDesc01,
         CASE WHEN fr.Code IS NOT NULL THEN 'Y' ELSE 'N' END
ORDER BY Lines DESC;


/* -----------------------------------------------------------------------------
   Q5 — Standard lead time by item+branch (the "Lead Time-MTB.F4102" tab).
        ⚠ Q-d: confirm which field the sheet uses. Candidates exposed here.
        Keyed by 2nd Item Number + Branch Plant, matching the sheet's SUMIFS keys.
   ----------------------------------------------------------------------------- */
SELECT
    [2nd Item Number] = ib.ItemNum2nd,
    [Branch Plant]    = LTRIM(RTRIM(ib.BusinessUnit)),
    LeadtimeLevel     = ib.LeadtimeLevel,        -- IBLTLV (most likely)
    LeadtimeMFG       = ib.LeadtimeMFG,
    QtyMFGLeadtime    = ib.QuantityMFGLeadtime
FROM dbo.DimItemBranch ib
WHERE ib.ItemNum2nd IS NOT NULL;


/* -----------------------------------------------------------------------------
   Q4 — Reproduce Reliability & Flexibility in SQL, monthly % by company.
        Compare to the workbook "Reliability Percentage All" tab.
        - Reliability OnTime  = NOT in fault-reason set (their AA = "OnTime")
        - Flexibility OnTime  = ActualShipDate <= RequestedDate (their Z)
        - Flexibility w/ MTO  = excuse lines requested inside standard lead time
          NETWORKDAYS approximated as DATEDIFF(DAY)-2*DATEDIFF(WEEK) (weekends only,
          no holiday calendar — matches Excel NETWORKDAYS with no holiday arg).
   ----------------------------------------------------------------------------- */
WITH base AS (
    SELECT
        f.OrderCompany, f.OrderNum, f.LineNum,
        f.OrderDate, f.RequestedDate, f.ActualShipDate, f.UpdatedDate,
        RevReason = LTRIM(RTRIM(f.RevisionReason)),
        LeadStd   = ISNULL(ib.LeadtimeLevel, 0),
        ReqLeadBizDays = DATEDIFF(DAY, f.OrderDate, f.RequestedDate)
                       - 2 * DATEDIFF(WEEK, f.OrderDate, f.RequestedDate)
    FROM dbo.FactSalesDetail f
    LEFT JOIN dbo.DimItemBranch ib
           ON ib.ItemNum2nd = f.ItemNum2nd
          AND LTRIM(RTRIM(ib.BusinessUnit)) = LTRIM(RTRIM(f.BusinessUnit))
    WHERE (f.RecordType IS NULL OR f.RecordType <> 'GL Detail')
      AND f.UpdatedDate BETWEEN @FromDate AND @ToDate
      -- AND f.OrderType IN (...)   -- match Cognos population (Q-a)
), flagged AS (
    SELECT
        Company = LEFT(b.OrderCompany,5),
        [Year]  = YEAR(b.UpdatedDate),
        [Month] = MONTH(b.UpdatedDate),
        ReliabilityOnTime = CASE WHEN fr.Code IS NULL THEN 1 ELSE 0 END,
        FlexOnTime        = CASE WHEN b.ActualShipDate IS NOT NULL
                                  AND b.ActualShipDate <= b.RequestedDate THEN 1 ELSE 0 END,
        -- MTO carve-out: requested inside std lead time AND not shipped exactly on request = excused miss
        FlexMTOExcused    = CASE WHEN (b.ReqLeadBizDays - b.LeadStd) <= 0
                                  AND b.RequestedDate <> b.ActualShipDate THEN 1 ELSE 0 END
    FROM base b
    LEFT JOIN @FaultReasons fr ON fr.Code = b.RevReason
)
SELECT
    Company, [Year], [Month],
    Lines              = COUNT(*),
    [Reliability %]    = CAST(100.0 * SUM(ReliabilityOnTime) / NULLIF(COUNT(*),0) AS decimal(5,1)),
    [Flexibility %]    = CAST(100.0 * SUM(FlexOnTime)        / NULLIF(COUNT(*),0) AS decimal(5,1)),
    [Flexibility % (MTO-adj)] =
        CAST(100.0 * SUM(CASE WHEN FlexOnTime = 1 OR FlexMTOExcused = 1 THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*),0) AS decimal(5,1))
FROM flagged
GROUP BY Company, [Year], [Month]
ORDER BY Company, [Year], [Month];


/* -----------------------------------------------------------------------------
   NOTE — Reliability via the F42199 ledger (full promised-date change history)
   is already modeled in  dax queries/FactScheduleChange.m  (ODSPROD, SLRFRV).
   The fact's single RevisionReason (above) reflects the CURRENT line value; if the
   Cognos report is ledger-based (multiple reasons per line), reconcile against
   FactScheduleChange instead and dedup by order#+line#+reason as the workbook does.
   ============================================================================= */
