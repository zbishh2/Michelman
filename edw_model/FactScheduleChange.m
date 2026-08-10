// FactScheduleChange — promised-date REVISION ledger (one row per revision EVENT),
// the backbone of the revision-based OTIF model.
//
// Source: ODSPROD / ODS / PRODDTA.F42199 (JDE Sales Order Ledger).
//
// GRAIN / TRIGGER: a row is emitted for each promised-date REVISION EVENT on a
// line, where an event is EITHER
//   (a) a NEW reason-code episode — SLRFRV (RFRV / UDC 42/RR) is non-blank and
//       differs from the immediately preceding ledger row's reason, OR
//   (b) an actual row-to-row change in the promised delivery date (SLPDDJ).
// ⚠ THE REASON-CODE LEG IS LOAD-BEARING. A trigger on row-to-row SLPDDJ change
// alone silently drops any line whose OTIF-relevant reason was logged WITHOUT a
// date delta — a slip before the first captured ledger snapshot (visible only as
// original SLOPDJ <> final SLPDDJ), or a reason logged while the date held. Those
// are real OTIF misses the business scores by reason code.
//
// A line is an OTIF "miss" if it has >=1 revision whose reason code is flagged
// OTIF in the reason dimension (ReasonCodes.m, [OTIF]='X'). OTIF-relevance is NOT
// filtered here — every reason episode is brought in and
// FactScheduleChange[Is OTIF Relevant] decides. Consequence: Orders[Revision
// Count] / [Net Days Moved] (ALL reasons) also count the baseline/original reason
// episode per line; the OTIF measures read the OTIF-filtered Relevant* rollups and
// are unaffected.
//
// DaysMoved is seeded from the ORIGINAL promised date (SLOPDJ, constant per line)
// when there is no preceding ledger row, so a pre-window slip (original vs first
// snapshot) is captured. Across a line the per-row DaysMoved telescopes to
// (final SLPDDJ − original SLOPDJ) because every SLPDDJ transition is also kept.
//
// LAG runs server-side (EnableFolding=true).
// ⚠ Uses derived tables, NOT WITH/CTEs — Power Query wraps native queries in a
//   subquery when folding, which a CTE cannot survive.
// Returns/credits (CM/CO) excluded; 2024+ window (widen in the WHERE).
//
// Joins (see ExecutiveDashboard_Model.dax "RELATIONSHIPS"):
//   FactScheduleChange[OrderLineID]    * -> 1  Orders[Order Line ID]   (calc col)
//   FactScheduleChange[RevisionReason] * -> 1  'Code (Reason Codes 20181017)'[Code]
//
// WRITEBACK FOLD: user overwrites from the Revision Log Editor custom visual
// (Cloudflare Worker + D1, see writeback/ARCHITECTURE.md) are left-joined below on
// [RevisionKey] at refresh. [RevisionReason] is the EFFECTIVE code (override ??
// as-reported), so the dim relationship and [Is OTIF Relevant] pick up overwrites
// with no DAX changes; the as-reported code stays in [RevisionReasonOriginal].
// [Excluded] voids an event.
// ⚠ [RevisionKey] = Order-Line-ID string & "|" & ChangeDate yyyy-MM-dd & "|" &
// ChangeTime, culture-pinned. The visual binds this column and treats it as
// opaque, so the expression below is the ONLY place the key is defined.
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
            CASE WHEN base.PromisedBefore IS NULL OR base.PromisedBefore=0 THEN NULL ELSE DATEADD(DAY,(base.PromisedBefore%1000)-1,DATEFROMPARTS(1900+(base.PromisedBefore/1000),1,1)) END AS FromPromisedDate,
            CASE WHEN base.SLPDDJ =0 THEN NULL ELSE DATEADD(DAY,(base.SLPDDJ %1000)-1,DATEFROMPARTS(1900+(base.SLPDDJ /1000),1,1)) END AS ToPromisedDate,
            CASE WHEN base.PromisedBefore>0 AND base.SLPDDJ>0
                 THEN DATEDIFF(DAY,
                        DATEADD(DAY,(base.PromisedBefore%1000)-1,DATEFROMPARTS(1900+(base.PromisedBefore/1000),1,1)),
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
                w.SLKCOO, w.SLDOCO, w.SLDCTO, w.SLSFXO, w.SLLNID, w.SLMCU, w.SLLITM,
                w.SLPDDJ, w.SLOPDJ, w.SLRFRV, w.SLUSER, w.SLPID, w.SLUPMJ, w.SLTDAY, w.SLNXTR, w.SLLTTR,
                w.PrevPDDJ, w.PrevRFRV,
                CASE WHEN w.PrevPDDJ IS NOT NULL AND w.PrevPDDJ>0 THEN w.PrevPDDJ
                     WHEN w.SLOPDJ>0 THEN w.SLOPDJ ELSE NULL END AS PromisedBefore
            FROM (
                SELECT
                    SLKCOO, SLDOCO, SLDCTO, SLSFXO, SLLNID, SLMCU, SLLITM,
                    SLPDDJ, SLOPDJ, SLRFRV, SLUSER, SLPID, SLUPMJ, SLTDAY, SLNXTR, SLLTTR,
                    LAG(SLPDDJ) OVER (
                        PARTITION BY SLKCOO, SLDOCO, SLDCTO, SLSFXO, SLLNID
                        ORDER BY SLUPMJ, SLTDAY
                    ) AS PrevPDDJ,
                    LAG(SLRFRV) OVER (
                        PARTITION BY SLKCOO, SLDOCO, SLDCTO, SLSFXO, SLLNID
                        ORDER BY SLUPMJ, SLTDAY
                    ) AS PrevRFRV
                FROM PRODDTA.F42199
                WHERE SLDCTO NOT IN ('CM','CO')
                  AND SLUPMJ >= 124001
            ) AS w
        ) AS base
        WHERE
            ( LTRIM(RTRIM(base.SLRFRV)) <> ''
              AND ( base.PrevRFRV IS NULL OR LTRIM(RTRIM(base.PrevRFRV)) <> LTRIM(RTRIM(base.SLRFRV)) ) )
            OR ( base.PrevPDDJ IS NOT NULL AND base.SLPDDJ <> base.PrevPDDJ )",
        null,
        [EnableFolding = true]
    ),

    // ── Writeback fold: RevisionOverrides (connection-only query → Worker/D1) ──
    Overrides = Table.Buffer(RevisionOverrides),
    AddKey = Table.AddColumn(
        Fact,
        "RevisionKey",
        each [OrderCompany] & "," & Number.ToText([OrderNumber], "0", "en-US") & "," & [OrderType] & ","
            & Number.ToText([LineNumber] / 1000, "0.000", "en-US")
            & "|" & Date.ToText(DateTime.Date([ChangeDate]), "yyyy-MM-dd")
            & "|" & Number.ToText([ChangeTime], "0", "en-US"),
        type text
    ),
    JoinedOvr = Table.NestedJoin(AddKey, {"RevisionKey"}, Overrides, {"RevisionKey"}, "_ovr", JoinKind.LeftOuter),
    ExpandedOvr = Table.ExpandTableColumn(JoinedOvr, "_ovr", {"RevisionReasonOverride", "OverrideNote", "Excluded"}),
    KeepOriginal = Table.RenameColumns(ExpandedOvr, {{"RevisionReason", "RevisionReasonOriginal"}}),
    EffectiveReason = Table.AddColumn(
        KeepOriginal,
        "RevisionReason",
        each if [RevisionReasonOverride] <> null and Text.Trim([RevisionReasonOverride]) <> ""
             then Text.Trim([RevisionReasonOverride])
             else [RevisionReasonOriginal],
        type text
    ),
    ExcludedFlagged = Table.ReplaceValue(EffectiveReason, null, false, Replacer.ReplaceValue, {"Excluded"})
in
    ExcludedFlagged
