// ============================================================================
// Report 21  ·  1 - Inventory - Slow Moving Global Packaged Items  ·  page table: Inventory
// Cognos query object: Inventory  (DW_LEGACY "Inventory On Hand" star)
// Route: EDW  ·  BIQL.FactInventorySnapshot_History_Filtered  (BUILD.md 1, 2.3, 3.1, 4.1)
//
// ---------------------------------------------------------------------------
// GL CLASS COMES FROM THE FACT ON THIS SHEET — THE SINGLE MOST IMPORTANT LINE
// ---------------------------------------------------------------------------
// snap.CategoryGLF41021, NOT ib.[Category GL F4101]. All three Cognos queries filter
// GL_CLASS_CODE = 'IN32' (that predicate IS the definition of "Global Packaged Items"),
// but query 1 takes it from INVENTORY_ON_HAND while queries 2 and 3 take it from ITEM.
// They are genuinely different populations. Measured (BUILD.md 0.1, 7 #2): the two
// columns disagree on 54 of 4,235 in-scope positions, and the disagreement is material
// — the fact-level column includes the water/utility items (SH2O, SH2OF, DIH2O*) whose
// on-hand quantities run to 99.98 billion. The export's largest single row is
// CINC / SH2OF at 99,979,021,880.0025. Switching to [Category GL F4101] drops that row
// and collapses this sheet's QOH total from 304 billion to 7.5 million. DO NOT UNIFY.
//
// ---------------------------------------------------------------------------
// WHICH INVENTORY OBJECT, AND THE TIMEZONE STAGGER
// ---------------------------------------------------------------------------
// BIQL.FactInventorySnapshot_History_Filtered is DimCalendarInventorySnapshot LEFT
// JOINed to dbo.FactInventorySnapshot_History over the SCD2 interval. Report 18 had to
// abandon this view because its calendar spine keeps only current+previous month daily
// and month-ends before that — fatal for a rolling multi-month history. Report 21 wants
// a SINGLE day (yesterday), which is always inside the daily window, so the retention
// gap is irrelevant here and we get the view's decoded columns and its per-company
// timezone handling for free. BIQL.FactInventorySnapshot (current-day) is rejected
// because today is a partial intraday load. BUILD.md 2.3.
//
// CalendarDate = yesterday is written DATEADD(DAY, -1, CAST(GETDATE() AS date)), NOT
// CAST(GETDATE() AS date) - 1 as BUILD.md 4.1 originally specified: the T-SQL `date` type
// does not support the arithmetic operators and the spec's form raises "Msg 206 ...
// Operand type clash: date is incompatible with int" at refresh. BUILD.md 7 #19.
//
// CalendarDate = yesterday is the correct port of Oracle to_date(sysdate) - 1. Note
// that the view advances CompanySKey = 2 (EMEA/Asia) by a day, so at the moment of a
// refresh "yesterday" for AUB2/AUBA/SING/SNG4 already reflects that branch's own next
// business day while CIN2/CIN4/CINC do not. This is exactly how Cognos behaves — DO NOT
// try to normalise it. It is also why the local tie-out had to be run at 2026-08-04,
// the latest mirror date carrying all seven branches, against an export whose
// INVENTORY_DATE is 2026-08-05: that sheet's local comparison is one business day stale
// by construction and its ~5% lot churn should be read in that light. BUILD.md 2.3, 7 #5.
//
// [DATE] is CAST(GETDATE() AS date) — the RUN stamp (sysdate, not sysdate-1). It reads
// one day later than the data and moves with every refresh. Cognos does the same.
// Cognos also selects INVENTORY_DATE but never displays it; not carried.
//
// ---------------------------------------------------------------------------
// LOT DATES — the flagged availability risk, closed
// ---------------------------------------------------------------------------
// ITEM_LOT_NUMBERS.ON_HAND_DATE / LOT_EXPIRY_DATE map to BIQL.DimLot.OnHandDate /
// LotExpirationDate, joined on snap.LotSKey. Measured non-NULL on all 2,072 in-scope
// positions: the join never drops and never blanks. LEFT JOIN anyway, defensively.
// Fidelity is good but not perfect and the gap runs in OUR favour (BUILD.md 2.2, 7 #5):
// OnHandDate agrees on 92.8% and LotExpirationDate on 87.3% of matched rows, and 137 of
// the disagreements are rows where COGNOS shows the JDE zero-date 1900-01-01 and EDW has
// a real date — recently-created lots the legacy DW's lot dimension has not picked up.
// This is a Cognos-side staleness gap, not a rebuild defect. Disclose (D-21g), do not fix.
//
// ---------------------------------------------------------------------------
// THE KG/LB FACTOR CARRIED FOR DAX  (BUILD.md 2.4)
// ---------------------------------------------------------------------------
// The conversion itself lives in DAX calculated columns, not here — it is the report's
// one real derivation, it encodes a contested constant, and it must be changeable in
// one place when D-21e resolves. SQL only DELIVERS the per-item factor the DAX ELSE
// branch needs:
//
//   [KG Factor] = BIQL.DimItemUOMConversionLBKG.KG for the row where UOM = UOMPrimary,
//   i.e. kilograms per one primary unit. Used ONLY when the primary UOM is neither KG
//   nor LB (42 of 2,072 in-scope rows, all EA). The (ItemNumShort, BusinessUnit,
//   UOM = UOMPrimary) row is unique — verified, no fan-out, no ROW_NUMBER needed, and
//   the join leaves the row count at 2,072 exactly.
//
//   CAVEAT, DISCLOSED: this dim does not reproduce the Cognos DW on EA-primary items.
//   Of the 38 EA rows comparable against the 2026-08-06 capture, 10 reproduce exactly,
//   22 disagree and 6 have no dim row at all (e.g. CIN2 / JUG, where Cognos itself
//   renders 0). Deriving the factor the other way (dim.LB * 0.453597189) scores 11/38 —
//   no better. This is the same EA-primary divergence the Shipments sheet hits on 676
//   rows and is recorded under D-21e, gated on probe P2. Rows with no dim row are left
//   BLANK rather than forced to 0: an honest missing value marks them for the probe,
//   whereas a fabricated 0 would look like a real answer. BUILD.md 2.4 does not name a
//   source for this branch on the Inventory sheet (the snapshot fact carries no
//   conversion column at all), so this is the build's choice and is flagged as such.
//
// ---------------------------------------------------------------------------
// LOCATION / LOT NUMBER / LOT STATUS — store missing, render '-' IN DAX
// ---------------------------------------------------------------------------
// '-' is not a value. It is how Cognos RENDERS a missing dimension attribute. The raw
// columns are carried here exactly as EDW stores them and the dash is applied by the
// "(Display)" calculated columns in the model, so the real distinction between missing,
// blank and a literal dash survives (root CLAUDE.md 9 — NULL vs empty string is
// preserved end to end and must not be collapsed). Never bake '-' into this query and
// never do it with a format string. BUILD.md 4.5 case 1, 5.2.
//
// Note EDW is NOT uniform about how it stores missing (BUILD.md 7 #11): the nvarchar
// item-branch columns use NULL, while the snapshot fact's columns use BLANK/spaces —
// in scope, 306 blank Location, 3 blank LotNum, 1,611 blank LotStatusCode and ZERO
// NULLs. A missing-test that only checks for NULL would therefore render nothing at all
// here, which is why the DAX display columns test trimmed LENGTH rather than BLANK.
// Parity evidence: the export's Lot Status distinct set is -,A,B,E,H,L,P,Q,R,T and EDW's
// is <blank>,A,B,E,H,L,P,Q,R,T — an exact 10-for-10 match once missing <-> '-'.
//
// ---------------------------------------------------------------------------
// HEADER TRAP, COLUMN 11
// ---------------------------------------------------------------------------
// The Cognos data item is named UOM but carries no label= override, so the export header
// falls back to the model item label and reads "Primary Unit of Measure". The model
// column is named accordingly. BUILD.md 3.1.
//
// Seven branch plants here (CIN4 included), against six on the Shipments query. Ported
// exactly as written; CIN4 is measured inert on all three queries. BUILD.md 4.4, D-21b.
// WITH (NOLOCK) on every source object per root CLAUDE.md 9. No CTEs, no ORDER BY, no
// temp tables — sorting lives in the visual.
// ============================================================================
let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        SELECT
            LTRIM(RTRIM(snap.BusinessUnit))              AS [Branch Plant],
            ib.[Item Global Bulk]                        AS [Global Bulk Item],
            ib.[Item Bulk]                               AS [Bulk Item],
            ib.[Item Num 2nd]                            AS [2nd Item Number],
            LTRIM(RTRIM(snap.CategoryGLF41021))          AS [GL Class Code],
            LTRIM(RTRIM(snap.Location))                  AS [Location],
            LTRIM(RTRIM(snap.LotNum))                    AS [Lot Number],
            LTRIM(RTRIM(snap.LotStatusCode))             AS [Lot Status],
            LTRIM(RTRIM(ib.[Master Planning Family]))    AS [Master Planning Family],
            SUM(snap.QuantityOnHandPrimaryUOM)           AS [Quantity on Hand],
            LTRIM(RTRIM(snap.UOMPrimary))                AS [Primary Unit of Measure],
            LTRIM(RTRIM(ib.[Stocking Type]))             AS [Stock Type Code],
            l.OnHandDate                                 AS [On Hand Date],
            l.LotExpirationDate                          AS [Lot Expiry Date],
            CAST(GETDATE() AS date)                      AS [DATE],
            MIN(k.KG)                                    AS [KG Factor]
        FROM BIQL.FactInventorySnapshot_History_Filtered snap WITH (NOLOCK)
            INNER JOIN BIQL.TbItemBranch ib WITH (NOLOCK)
                    ON ib.ItemBranchSKey = snap.ItemBranchSKey
            LEFT  JOIN BIQL.DimLot l WITH (NOLOCK)
                    ON l.LotSKey = snap.LotSKey
            LEFT  JOIN BIQL.DimItemUOMConversionLBKG k WITH (NOLOCK)
                    ON k.ItemNumShort = ib.[Item Num Short]
                   AND LTRIM(RTRIM(k.BusinessUnit)) = LTRIM(RTRIM(ib.[Business Unit]))
                   AND LTRIM(RTRIM(k.UOM))          = LTRIM(RTRIM(k.UOMPrimary))
        WHERE snap.CalendarDate = DATEADD(DAY, -1, CAST(GETDATE() AS date))
          AND snap.QuantityOnHandPrimaryUOM > 0
          AND LTRIM(RTRIM(snap.CategoryGLF41021)) = 'IN32'
          AND LTRIM(RTRIM(snap.BusinessUnit)) IN ('CINC', 'CIN2', 'CIN4', 'AUBA', 'AUB2', 'SING', 'SNG4')
        GROUP BY
            LTRIM(RTRIM(snap.BusinessUnit)),
            ib.[Item Global Bulk],
            ib.[Item Bulk],
            ib.[Item Num 2nd],
            LTRIM(RTRIM(snap.CategoryGLF41021)),
            LTRIM(RTRIM(snap.Location)),
            LTRIM(RTRIM(snap.LotNum)),
            LTRIM(RTRIM(snap.LotStatusCode)),
            LTRIM(RTRIM(ib.[Master Planning Family])),
            LTRIM(RTRIM(snap.UOMPrimary)),
            LTRIM(RTRIM(ib.[Stocking Type])),
            l.OnHandDate,
            l.LotExpirationDate
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
