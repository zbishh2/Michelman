/* probe_residuals.sql — report 20, the residual jumpbox probes
   Run ONCE on the jumpbox in SSMS against EDWPROD / EDW. Return all result sets.

   MOST OF THIS REPORT'S PROBE SURFACE IS ALREADY CLOSED. BUILD.md §8 listed P1-P7;
   P1, P2, P3 and P6 were answered locally against the SQL mirror (validation log
   V1-V26), and P4, P5 and P7 were answered on 2026-08-06 from the Cognos export
   that arrived after the spec was written
   (Intake\Cognos export - 2020 full year (filed 2026-08-06).xlsx, 499,227 rows).

   ---------------------------------------------------------------------------
   P5 — "does the Cognos output contain H2O?"  BUILD.md called this the highest-value
   open question. ANSWERED FROM THE EXPORT, 2026-08-06:  YES, and decisively.
       7,390 rows, 16 distinct H2O items (SH2O, SH2OF, SH2OD, SH2OH, TAPH2O, TAPH2OH,
       TH2OF, DIH2O ...), each appearing on 614 of the 313 snapshot dates.
       Master Planning Family 'H2O' is a first-class family in the domain.
       Water is 99.9938% of the report's total Quantity on Hand LBs
       (62,270,525,162,585 lbs total; largest single row CINC / SH2OF = 99,991,509,518.95).
   ⇒ The build MUST NOT filter water out. Any "sanity" filter on magnitude would
     delete essentially the whole measure. Do not re-open this.

   P4 — "do zero-quantity rows appear in Cognos?"  The export carries no zero rows,
     consistent with the shipped WHERE clause. No further probe needed.

   P7 — the KG->LB constant on this report's own data: the export's Quantity on Hand
     LBs renders as INTEGERS (numberFormat decimalSize="0"), so it cannot re-derive
     the constant to 7 digits. The constant stays pinned from report 21's export,
     where both KG and LB columns are present at full precision (K = 2.2045992).
     Round half-up on BOTH sides before any comparison (CLAUDE.md §7).
   ---------------------------------------------------------------------------

   ⚠ The export is 2020 data (313 dates, 2020-01-01 -> 2020-12-31). EDW's inventory
     history begins 2021-06-30, so NOT ONE of those dates exists in EDW. The export is
     CALIBRATION EVIDENCE ONLY - it can never be a row-count tie-out target for this
     rebuild. Do not attempt one.

   What is left below genuinely needs live data.
*/

------------------------------------------------------------------------------
-- 1. FRESHNESS — is the mirror's picture still the live picture?
--    The mirror was loaded 2026-08-05. Confirm the spine and the fact still agree
--    on the same date range, and that the daily window still starts where we think.
--    Expect: max date advances; the month-end-only stretch before 2026-06 is unchanged.
------------------------------------------------------------------------------
SELECT '1_spine' AS probe,
       COUNT(*)          AS SpineRows,
       MIN(CalendarDate) AS MinDate,
       MAX(CalendarDate) AS MaxDate
FROM BIQL.DimCalendarInventorySnapshot WITH (NOLOCK);

SELECT '2_fact_range' AS probe,
       MIN(StartDate) AS MinStart,
       MAX(StartDate) AS MaxStart,
       MAX(StopDate)  AS MaxStop,
       COUNT_BIG(*)   AS IntervalRows
FROM dbo.FactInventorySnapshot_History WITH (NOLOCK);

------------------------------------------------------------------------------
-- 3. THE COMPANY-2 +1-DAY SHIFT — re-confirm on live data.
--    This governs 100% of report 20's rows (both CINC and CIN2 are CompanySKey = 2).
--    Omitting it returns the PREVIOUS day's position under the current day's label,
--    and it will not look wrong. Verified on the mirror @ 2026-08-04:
--        view = 34,351   dbo + shift = 34,351   dbo without shift = 34,177
--    The two shifted figures must still agree; the unshifted one must still differ.
------------------------------------------------------------------------------
DECLARE @d date = (SELECT MAX(CalendarDate)
                   FROM BIQL.FactInventorySnapshot_History_Filtered WITH (NOLOCK));

SELECT '3_view' AS probe, @d AS TestDate, COUNT_BIG(*) AS Rows_
FROM BIQL.FactInventorySnapshot_History_Filtered WITH (NOLOCK)
WHERE CalendarDate = @d
  AND LTRIM(RTRIM(BusinessUnit)) IN ('CINC','CIN2');

SELECT '3_dbo_shifted' AS probe, @d AS TestDate, COUNT_BIG(*) AS Rows_
FROM dbo.FactInventorySnapshot_History s WITH (NOLOCK)
WHERE LTRIM(RTRIM(s.BusinessUnit)) IN ('CINC','CIN2')
  AND (CASE WHEN s.CompanySKey = 2 THEN DATEADD(DAY, 1, @d) ELSE @d END)
      BETWEEN s.StartDate AND ISNULL(s.StopDate, '9999-12-31');

SELECT '3_dbo_unshifted' AS probe, @d AS TestDate, COUNT_BIG(*) AS Rows_
FROM dbo.FactInventorySnapshot_History s WITH (NOLOCK)
WHERE LTRIM(RTRIM(s.BusinessUnit)) IN ('CINC','CIN2')
  AND @d BETWEEN s.StartDate AND ISNULL(s.StopDate, '9999-12-31');

------------------------------------------------------------------------------
-- 4. THE IDENTITY GUARD — the conversion-table trap (BUILD.md §4.3).
--    161 rows carry UOM = UOMPrimary = 'KG' with a bogus ConversionFactorSecToPrim
--    of 2.2046. Dividing by it unconditionally yields 1.000009 lbs per kg instead of
--    2.2046 - a 2.2x error. Report 18's formula divides unconditionally and would
--    ship the bug. Confirm the population is still there and still in scope.
------------------------------------------------------------------------------
SELECT '4_identity_guard' AS probe,
       COUNT_BIG(*)                                                        AS IdentityRowsBadFactor,
       SUM(CASE WHEN LTRIM(RTRIM(BusinessUnit)) IN ('CINC','CIN2')
                THEN 1 ELSE 0 END)                                         AS InScope
FROM BIQL.DimItemUOMConversionLBKG WITH (NOLOCK)
WHERE LTRIM(RTRIM(UOM)) = LTRIM(RTRIM(UOMPrimary))
  AND ConversionFactorSecToPrim <> 1.0;

------------------------------------------------------------------------------
-- 5. GENERATED DAILY SPINE — sizing check for the design change.
--    The export proves users picked arbitrary DAILY dates (313 distinct dates in one
--    calendar year), so the picker binds to a generated daily list bounded by the
--    fact's own range, not to the 127-row prebuilt calendar (which is month-ends only
--    before 2026-06 and would silently remove a capability they use today).
--    This returns the row count the import table will carry. If it is very large,
--    consider bounding the generated range to a trailing window and say so.
------------------------------------------------------------------------------
SELECT '5_daily_sizing' AS probe,
       DATEDIFF(DAY, MIN(s.StartDate), MAX(ISNULL(s.StopDate, CAST(GETDATE() AS date)))) + 1
                                                     AS DaysInRange,
       COUNT_BIG(*)                                  AS IntervalRowsCINCCIN2
FROM dbo.FactInventorySnapshot_History s WITH (NOLOCK)
WHERE LTRIM(RTRIM(s.BusinessUnit)) IN ('CINC','CIN2');

/* ----------------------------------------------------------------------------
   NOT SQL, and still open for Tim Bath (BUILD.md §11.1):
     - What does "tier 2" mean? It appears nowhere in the query. Do not invent a
       tier dimension.
     - Should held / quarantined / rejected lots be excluded? The Cognos query has
       no lot-status filter, so the port includes them all, deliberately.
     - Is the HTML-in-Viewer output the delivered form, or does everyone export it?
   ---------------------------------------------------------------------------- */
