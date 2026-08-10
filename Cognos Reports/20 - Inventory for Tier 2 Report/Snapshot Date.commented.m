// =============================================================================
// Report 20 - Inventory for tier 2 report - table: Snapshot Date
// COMMENTED MASTER. The shipped copy is "Snapshot Date.m" (comment-free).
// =============================================================================
//
// WHAT THIS IS
//   The date dimension the slicer binds to. Marked as the model's date table,
//   1:* single-direction to Snapshot[Inventory Date].
//
// WHY A GENERATED DAILY LIST AND NOT BIQL.DimCalendarInventorySnapshot
//   The spec originally recommended the pre-built calendar (127 rows: one date
//   per month before 2026-06, daily after). The Cognos export filed 2026-08-06
//   overturned that: 499,227 rows spanning 313 DISTINCT DATES inside a single
//   calendar year. Users were picking arbitrary daily dates, not month-ends, so
//   shipping a month-end-only picker would silently remove a capability they
//   currently have and use.
//
//   dbo.FactInventorySnapshot_History is SCD2 over a continuous range, so ANY
//   date in that window is reconstructable - the 127-row calendar is a limitation
//   of the pre-built spine, not of the data.
//
// THE SELF-BOUNDING PROPERTY IS PRESERVED - that was the best property of the
//   original recommendation and it had to survive the change. The bounds are read
//   from the fact itself, so the slicer still cannot be dragged to a date the
//   fact cannot serve. No date literal appears anywhere in this query.
//
//   See "Snapshot.commented.m" for why the bound carries a -1 day: CompanySKey = 2
//   rows are stamped one day ahead of the position they describe.
//
// SIZE, MEASURED 2026-08-06 ON THE LOCAL MIRROR
//   1,890 dates, 2021-06-02 .. 2026-08-04. The fact materialises to 5,106,257
//   rows - 15.9x the spec's 320,657 estimate, not the ~3x it anticipated.
//
// KNOWN GAP, disclosed rather than hidden
//   2022-10-24 is in the spine but returns no rows: EDW holds only 189 interval
//   rows for that date at CINC/CIN2 and every one is zero-quantity. That is an
//   EDW load gap, not a modelling choice. The date is kept in the spine so the
//   column stays CONTIGUOUS, which "mark as date table" requires; dropping it
//   would change no number, because a range spanning it has no rows there either
//   way.
//
let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        DECLARE @lo date, @hi date;

        -- Same bounds expression as the Snapshot query, so the two agree by
        -- construction: the picker can never offer a date the fact cannot serve.
        SELECT @lo = MIN(CASE WHEN CompanySKey = 2 THEN DATEADD(DAY, -1, StartDate) ELSE StartDate END),
               @hi = MAX(CASE WHEN CompanySKey = 2 THEN DATEADD(DAY, -1, StartDate) ELSE StartDate END)
        FROM dbo.FactInventorySnapshot_History WITH (NOLOCK)
        WHERE LTRIM(RTRIM(BusinessUnit)) IN ('CINC', 'CIN2');

        -- One row per day across the whole window. TOP is bounded by the window
        -- width, so the cross join never materialises more than it needs. No
        -- ORDER BY in the outer statement - Power BI wraps native queries.
        SELECT CAST(DATEADD(DAY, v.n, @lo) AS date) AS [Date]
        FROM (SELECT TOP (DATEDIFF(DAY, @lo, @hi) + 1)
                     ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
              FROM sys.all_objects a WITH (NOLOCK)
                   CROSS JOIN sys.all_objects b WITH (NOLOCK)) v
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
