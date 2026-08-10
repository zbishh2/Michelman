// FactScheduleChange — one row per ACTUAL promised-delivery-date change, with
// the revision reason (RFRV / UDC 42/RR). For the executive dashboard model.
// Source: ODSPROD / ODS / PRODDTA.F42199 (Sales Order Ledger).
// Paste into Power BI -> Get Data -> Blank Query -> Advanced Editor.
// Set the server if not "ODSPROD". LAG runs server-side (EnableFolding=true).
// NOTE: uses a derived table (NOT a WITH/CTE) — Power Query wraps native queries
//   in a subquery when folding, which a CTE can't survive.
// Returns/credits (CM/CO) excluded; 2024+ window (widen in the WHERE).
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Fact = Value.NativeQuery(
        Source,
        "SELECT
            base.SLKCOO AS OrderCompany,
            base.SLDOCO AS OrderNumber,
            base.SLDCTO AS OrderType,
            base.SLSFXO AS OrderSuffix,
            base.SLLNID AS LineNumber,
            base.SLMCU  AS BusinessUnit,
            base.SLLITM AS Item,
            DATEADD(DAY,(base.SLUPMJ%1000)-1,DATEFROMPARTS(1900+(base.SLUPMJ/1000),1,1)) AS ChangeDate,
            base.SLTDAY AS ChangeTime,
            CASE WHEN base.PrevPDDJ=0 THEN NULL ELSE DATEADD(DAY,(base.PrevPDDJ%1000)-1,DATEFROMPARTS(1900+(base.PrevPDDJ/1000),1,1)) END AS FromPromisedDate,
            CASE WHEN base.SLPDDJ =0 THEN NULL ELSE DATEADD(DAY,(base.SLPDDJ %1000)-1,DATEFROMPARTS(1900+(base.SLPDDJ /1000),1,1)) END AS ToPromisedDate,
            CASE WHEN base.PrevPDDJ>0 AND base.SLPDDJ>0
                 THEN DATEDIFF(DAY,
                        DATEADD(DAY,(base.PrevPDDJ%1000)-1,DATEFROMPARTS(1900+(base.PrevPDDJ/1000),1,1)),
                        DATEADD(DAY,(base.SLPDDJ %1000)-1,DATEFROMPARTS(1900+(base.SLPDDJ /1000),1,1)))
            END AS DaysMoved,
            LTRIM(RTRIM(base.SLRFRV)) AS RevisionReason,
            base.SLUSER AS ChangedByUser,
            base.SLPID  AS ProgramID,
            CASE WHEN base.SLPID = 'ER42950' OR base.SLUSER = 'SCHED' THEN 1 ELSE 0 END AS IsAutomatedBatch,
            base.SLNXTR AS NextStatus,
            base.SLLTTR AS LastStatus
        FROM (
            SELECT
                SLKCOO, SLDOCO, SLDCTO, SLSFXO, SLLNID, SLMCU, SLLITM,
                SLPDDJ, SLRFRV, SLUSER, SLPID, SLUPMJ, SLTDAY, SLNXTR, SLLTTR,
                LAG(SLPDDJ) OVER (
                    PARTITION BY SLKCOO, SLDOCO, SLDCTO, SLSFXO, SLLNID
                    ORDER BY SLUPMJ, SLTDAY
                ) AS PrevPDDJ
            FROM PRODDTA.F42199
            WHERE SLDCTO NOT IN ('CM','CO')
              AND SLUPMJ >= 124001
        ) AS base
        WHERE base.PrevPDDJ IS NOT NULL
          AND base.SLPDDJ <> base.PrevPDDJ",
        null,
        [EnableFolding = true]
    )
in
    Fact
