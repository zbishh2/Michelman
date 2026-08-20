-- =====================================================================================
-- REPORT 14 — ESCOR LOT DETAILS  (tab: Escor Lot Details)
-- Source: ODSPROD / ODS, T-SQL through Value.NativeQuery, imported
-- =====================================================================================
--
-- The only query in this report that does not come from SSAS, and the only one that
-- reads ODS.
--
-- WHY ODS. This tab reports the JDE lot master itself — every lot ever created for the
-- Escor items, whether or not any stock remains. That is a master-data list, not an
-- inventory position, and it has no counterpart in EDW or in the ISH cube. Both of those
-- start from a snapshot fact, so a lot with no stock simply is not in them. F4108 on ODS
-- is the table Cognos is reading through its own path, so it is the like-for-like source.
-- Confirmed by Rohit.
--
-- There is no date and no quantity here. The tab is a lot register.
--
-- WHERE IT STANDS. 1,588 rows against Cognos's 1,668, and every row we return is in the
-- Cognos output — a strict subset, nothing spurious. The 80 Cognos has that we do not
-- are 79 lots dated 2011-2013, which ODS no longer retains, plus one 2025 lot F4108 does
-- not carry at all. Inside the 2024-onward window Rohit scoped for comparison it is
-- 476 of 477.
--
-- =====================================================================================

-- SELECT DISTINCT reproduces the Cognos query, which renders a distinct list.
SELECT DISTINCT
    LTRIM(RTRIM(lm.IOMCU))                    AS [Branch Plant],

    -- Bulk item from the item dimension, not from the lot master's own copy.
    -- See the WHERE clause below — this is the same distinction, and there it decides
    -- which rows exist at all.
    LTRIM(RTRIM(tag.IMBULK))                  AS [Bulk Item],

    LTRIM(RTRIM(lm.IOLITM))                   AS [2nd Item Number],
    lm.IOITM                                  AS [Item Short ID],
    LTRIM(RTRIM(lm.IOLOTN))                   AS [Lot Number],

    -- ODS stores the four-character STRING 'NULL' in IORLOT where JDE holds an empty
    -- value. Without NULLIF the report prints the word NULL; Cognos renders those lots
    -- blank.
    NULLIF(LTRIM(RTRIM(lm.IORLOT)), 'NULL')   AS [Supplier Lot Number],

    LTRIM(RTRIM(lm.IOLOT1))                   AS [Memo Lot 1],
    LTRIM(RTRIM(lm.IOLOT2))                   AS [Memo Lot 2],

    -- IOOHDJ is a JDE Julian date in CYYDDD form: the leading digits are years since
    -- 1900 and the last three are the day within that year. So 125280 is day 280 of
    -- 2025. The arithmetic below builds January 1 of the year and adds the day offset,
    -- less one because day 001 is January 1 itself.
    --
    -- The CASE returns NULL where IOOHDJ is 0, i.e. no date recorded. Oracle renders
    -- that same zero as 1900-01-01, so one lot shows blank for us and an epoch date in
    -- Cognos. Cosmetic, one row, and a parity decision rather than a defect.
    CASE
        WHEN lm.IOOHDJ > 0 THEN
            DATEADD(
                DAY,
                (lm.IOOHDJ % 1000) - 1,
                DATEFROMPARTS((lm.IOOHDJ / 1000) + 1900, 1, 1)
            )
    END                                       AS [On Hand Date],

    -- IOAITM carried alongside, hidden in the model, so the lot master's own bulk-item
    -- copy can be compared against the dimension's without running a second query.
    LTRIM(RTRIM(lm.IOAITM))                   AS [Bulk Item (F4108)]

FROM PRODDTA.F4108 lm

-- The item-to-bulk map, PRE-AGGREGATED to exactly one row per item.
--
-- F554101 can hold more than one row per item. Joined raw it would fan the lot grain
-- out and silently duplicate lots. MIN() collapses it to one row per item before the
-- join, so the join cannot change the row count no matter what the source does.
LEFT JOIN
(
    SELECT IMITM, MIN(IMBULK) AS IMBULK
    FROM PRODDTA.F554101
    GROUP BY IMITM
) tag
    ON tag.IMITM = lm.IOITM

-- SCOPE ON THE DIMENSION'S BULK ITEM, NOT ON IOAITM.
--
-- This is the subtle one, and it is worth understanding because the wrong version looks
-- correct under testing.
--
-- IOAITM is the item's own third item number. It happens to agree with the dimension's
-- IMBULK on every row it selects — so comparing the two columns across the returned
-- rows shows zero mismatches and the two look interchangeable. That test cannot fail,
-- because it only ever sees rows IOAITM already chose.
--
-- What IOAITM misses is child items that roll up to an Escor bulk under a DIFFERENT
-- code. Item 1117041 is 'ESC5200-BG', whose bulk parent is ESC5200; it carries 4 lots
-- and Cognos reports them. Filtering on IOAITM drops all four.
--
-- Scoping on IMBULK selects everything IOAITM did, plus those four. That is what
-- "get it from the dimension (standard approach)" means, and it is the difference
-- between 1,584 rows and 1,588.
WHERE LTRIM(RTRIM(tag.IMBULK)) IN ('ESC5200', 'ESC5200.E', 'ESC5200.S')

-- =====================================================================================
-- NOTE ON THE M WRAPPER
--
-- This runs through Value.NativeQuery with EnableFolding = true, which wraps the text in
-- a subselect. Two consequences worth knowing:
--
--   * A leading WITH common table expression fails to parse. Use derived tables, as the
--     F554101 aggregate above does.
--   * Column types are set explicitly in the M step afterwards rather than inferred.
-- =====================================================================================
