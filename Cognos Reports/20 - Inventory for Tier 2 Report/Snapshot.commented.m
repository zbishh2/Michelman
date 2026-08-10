// =============================================================================
// Report 20 - Inventory for tier 2 report - table: Snapshot
// COMMENTED MASTER. The shipped copy is Snapshot.m (comment-free, CLAUDE.md 1).
// Maintain the two in parallel; the PBIP partition is generated from the same
// source text as Snapshot.m, so they cannot drift.
// =============================================================================
//
// WHAT THIS QUERY DOES
//   Materialises one row per (snapshot date x inventory position) for branch
//   plants CINC and CIN2, over the whole date range EDW can actually serve.
//   Cognos ran a BETWEEN filter that users hand-edited at run time; the Power BI
//   equivalent is a slicer over a real date column, which needs per-date rows.
//
// WHAT IT DELIBERATELY DOES NOT DO (CLAUDE.md, "no business logic in Power Query")
//   No LB conversion, no decode, no CASE carrying a business rule, no aggregation.
//   The projection carries INGREDIENTS ONLY - Quantity on Hand, Primary UOM and
//   KG per Primary Unit - and the LB rule is a DAX calculated column on the table.
//   BUILD.md 5.1 explains why: a conversion constant buried in a native query is
//   exactly how the 1e-5 drift in report 14 9.5 survived three validation rounds
//   without anyone being able to see it.
//
// WARNING - do NOT reformat this text casually once it has refreshed.
//   Power BI invalidates a partition when its M changes AS TEXT (CLAUDE.md 7),
//   and this table is ~5.1M rows. A cosmetic edit costs a full reload.
//
let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        -- ---------------------------------------------------------------------
        -- SPINE BOUNDS - derived from the fact, never hard-coded.
        --
        -- The picker must not be able to offer a date the fact cannot serve.
        -- Rather than bound the slicer with literals (which go stale) or with
        -- BIQL.DimCalendarInventorySnapshot (127 rows: month-ends only before
        -- 2026-06), we read the fact's own coverage and generate every day in it.
        --
        -- Why the -1 day: CompanySKey = 2 rows are stamped one day AHEAD of the
        -- position they describe, so to READ date D we must MATCH D+1. The last
        -- readable date is therefore MAX(StartDate) - 1, and the first is
        -- MIN(StartDate) - 1. Written as a general CASE so it stays correct if a
        -- non-company-2 branch is ever added - though today 100% of CINC/CIN2
        -- rows are CompanySKey = 2 (BUILD.md 1.2, V6).
        --
        -- Measured on the mirror 2026-08-06: 2021-06-02 .. 2026-08-04 = 1,890 days.
        -- ---------------------------------------------------------------------
        DECLARE @lo date, @hi date;

        SELECT @lo = MIN(CASE WHEN CompanySKey = 2 THEN DATEADD(DAY, -1, StartDate) ELSE StartDate END),
               @hi = MAX(CASE WHEN CompanySKey = 2 THEN DATEADD(DAY, -1, StartDate) ELSE StartDate END)
        FROM dbo.FactInventorySnapshot_History WITH (NOLOCK)
        WHERE LTRIM(RTRIM(BusinessUnit)) IN ('CINC', 'CIN2');

        -- Generated daily spine. Replaces the pre-built calendar dimension: the
        -- 2026-08-06 Cognos export showed users picking 313 distinct dates inside
        -- one calendar year, so a month-end-only picker would remove a capability
        -- they demonstrably use. FactInventorySnapshot_History is SCD2 over a
        -- continuous range, so any date in the window is reconstructable.
        SELECT CAST(DATEADD(DAY, v.n, @lo) AS date) AS CalendarDate
        INTO #dates
        FROM (SELECT TOP (DATEDIFF(DAY, @lo, @hi) + 1)
                     ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
              FROM sys.all_objects a WITH (NOLOCK)
                   CROSS JOIN sys.all_objects b WITH (NOLOCK)) v;
        CREATE UNIQUE CLUSTERED INDEX ix_dates ON #dates (CalendarDate);

        -- ---------------------------------------------------------------------
        -- KG PER PRIMARY UNIT, one row per (item, branch).
        --
        -- THE IDENTITY GUARD is the CASE in the divisor, and it is not optional.
        -- 161 conversion rows carry UOM = UOMPrimary = 'KG' with a bogus
        -- ConversionFactorSecToPrim of 2.2046 instead of 1.0. Dividing by it
        -- yields 1.000009 kg per kg instead of 2.2046 - a 2.2x error. 39 of those
        -- rows are at CINC/CIN2. Report 18's formula divides unconditionally and
        -- would ship the bug (BUILD.md 4.3, V26).
        --
        -- Measured over the full 1,890-day spine: the guard changes the factor on
        -- 11,788 rows. The spec expected 1 (it was sized against a 127-date spine);
        -- widening the spine widened the blast radius too.
        --
        -- The ROW_NUMBER tie-break is deterministic: 0 (item, branch) groups have
        -- more than one UOM = UOMPrimary candidate (V26).
        -- ---------------------------------------------------------------------
        SELECT z.ItemNumShort, z.BU, z.KGperPrim
        INTO #kgf
        FROM (SELECT k.ItemNumShort,
                     ISNULL(LTRIM(RTRIM(k.BusinessUnit)), '') AS BU,
                     k.KG / CASE WHEN LTRIM(RTRIM(k.UOM)) = LTRIM(RTRIM(k.UOMPrimary)) THEN 1.0
                                 ELSE NULLIF(k.ConversionFactorSecToPrim, 0) END AS KGperPrim,
                     ROW_NUMBER() OVER (PARTITION BY k.ItemNumShort, ISNULL(LTRIM(RTRIM(k.BusinessUnit)), '')
                                        ORDER BY CASE WHEN LTRIM(RTRIM(k.UOM)) = LTRIM(RTRIM(k.UOMPrimary))
                                                      THEN 0 ELSE 1 END, k.UOM) AS rn
              FROM BIQL.DimItemUOMConversionLBKG k WITH (NOLOCK)) z
        WHERE z.rn = 1;
        CREATE UNIQUE CLUSTERED INDEX ix_kgf ON #kgf (ItemNumShort, BU);

        SELECT
            -- The OUTPUT date is the spine date, never snap.StartDate. The shifted
            -- date is used only to MATCH the SCD2 interval, never to label the row.
            CAST(c.CalendarDate AS date)                AS [Inventory Date],
            LTRIM(RTRIM(snap.BusinessUnit))             AS [Branch Plant],

            -- Columns 2-5 all come from BIQL.TbItemBranch: the snapshot fact
            -- carries no item-descriptive columns at all (V2). TbItemBranch has
            -- 116,002 rows, one per ItemBranchSKey, so the join cannot fan out (V7).
            -- Its column names contain spaces - bracket them.
            ib.[Item Num 2nd]                           AS [2nd Item Number],

            -- Bulk Item / Global Bulk Item are left NULL on purpose. Cognos renders
            -- a missing value as '-'; that is a RENDERING, not a stored sentinel
            -- (BUILD.md 6.1, V16). The 2026-08-06 export confirms it: 3,402 rows
            -- show '-' in Bulk Item and there is no literal '-' anywhere in EDW.
            -- The '-' is applied in DAX display columns so the real distinction
            -- (missing vs blank) survives in the model.
            ib.[Item Bulk]                              AS [Bulk Item],
            ib.[Item Global Bulk]                       AS [Global Bulk Item],

            -- Master Planning Family MUST come from item-BRANCH grain, not item
            -- grain. Report 14 measured 2,209 mismatches on 4,129 shared keys (53%)
            -- from BIQL.DimItem, and 0 from TbItemBranch. The 2026-08-06 export
            -- confirms it independently: 41 items present at both CIN2 and CINC
            -- carry a DIFFERENT family at each - which an item-grain dimension
            -- physically cannot reproduce. Do not use BIQL.DimItem here.
            --
            -- MPF is nchar(3) and is never NULL in EDW (0 NULLs, 5,929 blanks), so
            -- unlike Bulk Item it can never render as '-'. It renders blank, which
            -- is what the export shows (993 rows of spaces, zero '-').
            LTRIM(RTRIM(ib.[Master Planning Family]))   AS [Master Planning Family],

            -- The three ingredients of the LB rule. The rule itself is in DAX.
            snap.QuantityOnHandPrimaryUOM               AS [Quantity on Hand],
            LTRIM(RTRIM(snap.UOMPrimary))               AS [Primary UOM],
            COALESCE(kx.KGperPrim, kb.KGperPrim)        AS [KG per Primary Unit],

            -- Carried for auditability, not display. Lot Status in particular
            -- records that NO status filter is applied (BUILD.md 6.3) - held,
            -- quarantined and test lots are all in the quantity, matching Cognos.
            -- A carve-out is one filter away if Tim wants one.
            LTRIM(RTRIM(snap.Location))                 AS [Location],
            LTRIM(RTRIM(snap.LotNum))                   AS [Lot Number],
            snap.LotStatusCode                          AS [Lot Status],
            snap.ItemBranchSKey                         AS [ItemBranchSKey]
        FROM #dates c
            -- THE +1-DAY SHIFT. This governs 100% of this report's rows (V6), and
            -- omitting it returns the PREVIOUS DAY'S position under the current
            -- day's label - which will not look wrong. Measured: 34,351 rows with
            -- the shift, 34,177 without (V5).
            INNER JOIN dbo.FactInventorySnapshot_History snap WITH (NOLOCK)
                    ON (CASE WHEN snap.CompanySKey = 2 THEN DATEADD(DAY, 1, c.CalendarDate)
                             ELSE c.CalendarDate END)
                       BETWEEN snap.StartDate AND ISNULL(snap.StopDate, '9999-12-31')
            INNER JOIN BIQL.TbItemBranch ib WITH (NOLOCK)
                    ON ib.ItemBranchSKey = snap.ItemBranchSKey
            -- Exact business-unit match first, blank-BU fallback second.
            LEFT  JOIN #kgf kx ON kx.ItemNumShort = snap.ItemNumShort
                              AND kx.BU = LTRIM(RTRIM(snap.BusinessUnit))
            LEFT  JOIN #kgf kb ON kb.ItemNumShort = snap.ItemNumShort
                              AND kb.BU = ''
        WHERE LTRIM(RTRIM(snap.BusinessUnit)) IN ('CINC', 'CIN2')
          -- Zero-quantity exclusion (BUILD.md 5.4). 93% of EDW snapshot rows are
          -- zero-quantity positions; a literal port would emit ~31,000 rows per
          -- date, ~30,000 of them showing 0.00 lbs, and change no reported number.
          --
          -- Note '<> 0', NOT '> 0': reports 14 and 18 used '> 0' but had no
          -- negative rows to lose. Here they exist, and the 2026-08-06 export
          -- proves Cognos shows them - 159 negative rows in 499,227.
          --
          -- The same export also shows Cognos emitting 987 zero rows (0.2%), so
          -- this is now a DISCLOSED difference rather than a neutral optimisation.
          -- It is nowhere near EDW's 93%, so the filter stands.
          AND snap.QuantityOnHandPrimaryUOM <> 0
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
