/* =============================================================================
   Schedule-Change model objects — promised delivery date changes + reason (RFRV)
   Source: ODSPROD / ODS / PRODDTA.F42199 (Sales Order Ledger) + PRODCTL.F0005 (UDC)

   PURPOSE: define ONCE, use twice —
     1. Paste each query into Power Query (your composite model) as a native SQL
        source now (Get Data -> SQL Server -> Advanced -> SQL statement).
     2. Hand the same SQL to Dave as the SSAS view/partition spec, then repoint.

   GRAIN:
     - DimRevisionReason : one row per 42/RR reason code.
     - FactScheduleChange: one row per ACTUAL promised-delivery-date change event
       (LAG detects SLPDDJ transitions; unchanged batch rewrites are dropped).

   Dates: JDE Julian (CYYDDD) -> real date inline.
   ============================================================================= */


/* ---- DimRevisionReason --------------------------------------------------------
   42/RR codes + description + proposed OTIF grouping. The CASE buckets are a
   FIRST-DRAFT classification from the code descriptions — confirm with Greg/
   business before locking, especially the CountsAgainstOTIF flag.            */
SELECT
    LTRIM(RTRIM(DRKY))                          AS RevisionReason,
    DRDL01                                       AS ReasonDescription,
    DRDL02                                       AS ReasonDescription2,
    CASE
        WHEN LTRIM(RTRIM(DRKY)) IN ('Q1','Q2')                               THEN 'Quality'
        WHEN LTRIM(RTRIM(DRKY)) IN ('L1','L2','L3','LCM','LFC','LIC','LQW')  THEN 'Material / RM'
        WHEN LTRIM(RTRIM(DRKY)) IN ('P3','P4','P5','P6','P7','P8','P9','PD1','PD2','PD3','F1') THEN 'Production / Capacity'
        WHEN LTRIM(RTRIM(DRKY)) IN ('T0','T1','T2','T3','T4','SS','L4')      THEN 'Carrier / Logistics'
        WHEN LTRIM(RTRIM(DRKY)) IN ('C1','C2','C3','C4','C5','C6','C7')      THEN 'Customer / Commercial'
        WHEN LTRIM(RTRIM(DRKY)) IN ('A1','A2','A4','A5','A6','C0')           THEN 'Administrative / Scheduling'
        WHEN LTRIM(RTRIM(DRKY)) LIKE 'A3%'                                   THEN 'No Impact (flagged)'
        ELSE 'Other / Review'
    END                                          AS ReasonCategory,
    -- "no impact / no effect" reasons should NOT count as an OTIF miss:
    CASE
        WHEN LTRIM(RTRIM(DRKY)) LIKE 'A3%' THEN 0     -- A31-A36 "no impact"
        WHEN LTRIM(RTRIM(DRKY)) = 'C0'     THEN 0     -- No effect / pas effet client
        WHEN LTRIM(RTRIM(DRKY)) IN ('A1','A2','A6') THEN 0  -- scheduler/admin (CONFIRM)
        ELSE 1
    END                                          AS CountsAgainstOTIF
FROM PRODCTL.F0005
WHERE LTRIM(RTRIM(DRSY)) = '42'
  AND LTRIM(RTRIM(DRRT)) = 'RR';


/* ---- FactScheduleChange -------------------------------------------------------
   One row per real promised-delivery-date change. Excludes returns/credits
   (CM/CO) and the GL-detail ledger rows. Widen the date window as needed.    */
WITH base AS (
    SELECT
        SLKCOO, SLDOCO, SLDCTO, SLSFXO, SLLNID, SLMCU, SLLITM,
        SLPDDJ, SLRFRV, SLUSER, SLPID, SLUPMJ, SLTDAY, SLNXTR, SLLTTR,
        LAG(SLPDDJ) OVER (
            PARTITION BY SLKCOO, SLDOCO, SLDCTO, SLSFXO, SLLNID
            ORDER BY SLUPMJ, SLTDAY
        ) AS PrevPDDJ
    FROM PRODDTA.F42199
    WHERE SLDCTO NOT IN ('CM','CO')      -- sales orders only (not returns/credits)
      AND SLUPMJ >= 124001               -- 2024+; widen as needed
)
SELECT
    SLKCOO AS OrderCompany,
    SLDOCO AS OrderNumber,
    SLDCTO AS OrderType,
    SLSFXO AS OrderSuffix,
    SLLNID AS LineNumber,
    SLMCU  AS BusinessUnit,
    SLLITM AS Item,
    -- when the change was written:
    DATEADD(DAY,(SLUPMJ%1000)-1,DATEFROMPARTS(1900+(SLUPMJ/1000),1,1)) AS ChangeDate,
    SLTDAY AS ChangeTime,
    -- date moved from -> to:
    CASE WHEN PrevPDDJ=0 THEN NULL ELSE DATEADD(DAY,(PrevPDDJ%1000)-1,DATEFROMPARTS(1900+(PrevPDDJ/1000),1,1)) END AS FromPromisedDate,
    CASE WHEN SLPDDJ =0 THEN NULL ELSE DATEADD(DAY,(SLPDDJ %1000)-1,DATEFROMPARTS(1900+(SLPDDJ /1000),1,1)) END AS ToPromisedDate,
    CASE WHEN PrevPDDJ>0 AND SLPDDJ>0
         THEN DATEDIFF(DAY,
                DATEADD(DAY,(PrevPDDJ%1000)-1,DATEFROMPARTS(1900+(PrevPDDJ/1000),1,1)),
                DATEADD(DAY,(SLPDDJ %1000)-1,DATEFROMPARTS(1900+(SLPDDJ /1000),1,1)))
    END AS DaysMoved,                       -- + = pushed out, - = pulled in
    LTRIM(RTRIM(SLRFRV)) AS RevisionReason, -- joins to DimRevisionReason
    SLUSER AS ChangedByUser,
    SLPID  AS ProgramID,
    CASE WHEN SLPID = 'ER42950' OR SLUSER = 'SCHED' THEN 1 ELSE 0 END AS IsAutomatedBatch,
    SLNXTR AS NextStatus,
    SLLTTR AS LastStatus
FROM base
WHERE PrevPDDJ IS NOT NULL          -- skip the very first ledger row of each line
  AND SLPDDJ <> PrevPDDJ;           -- keep only rows where the promised date moved


/* -----------------------------------------------------------------------------
   OPEN ITEMS before locking:
     - Confirm the OTIF-impact buckets + CountsAgainstOTIF flags with Greg.
     - Decide grain for the exec dashboard: keep line-event grain (above) and
       aggregate to order/month in measures, OR also expose a per-order rollup.
     - "First promised date" (the baseline before any change) can be captured as
       a separate column if OTIF wants original-vs-final slippage — say the word.
     - Relationships in the model: ChangeDate -> Date dim; (OrderCompany,
       OrderNumber,OrderType,OrderSuffix,LineNumber) -> the sales order line.
   ----------------------------------------------------------------------------- */
