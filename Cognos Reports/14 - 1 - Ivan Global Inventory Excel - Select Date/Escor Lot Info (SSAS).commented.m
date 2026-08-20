// Commented master. The production copy of this query lives in the SSAS Import
// PBIP's SemanticModel and ships comment-free; the two are otherwise identical.
//
// Page 4 (Escor Lot Details). One row per ESC5200-family lot.
//
// Source is the JDE lot master, PRODDTA.F4108 on ODSPROD. The lot master is a JDE
// table with no EDW or ISH counterpart, so this page reads ODS while the other
// three pages read BIQLTabular_ISH.
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        -- SELECT DISTINCT reproduces the Cognos query. The F554101 join is
        -- pre-aggregated to one row per item so it cannot fan the lot grain out.
        SELECT DISTINCT
            LTRIM(RTRIM(lm.IOMCU))                    AS [Branch Plant],
            -- Bulk item comes from the item dimension, not the lot master's own
            -- denormalised copy. F4108.IOAITM rides along hidden so the two can be
            -- compared.
            LTRIM(RTRIM(tag.IMBULK))                  AS [Bulk Item],
            LTRIM(RTRIM(lm.IOLITM))                   AS [2nd Item Number],
            lm.IOITM                                  AS [Item Short ID],
            LTRIM(RTRIM(lm.IOLOTN))                   AS [Lot Number],
            -- ODS returns the four-character string 'NULL' in IORLOT where JDE holds
            -- an empty value; Cognos renders those lots blank.
            NULLIF(LTRIM(RTRIM(lm.IORLOT)), 'NULL')   AS [Supplier Lot Number],
            LTRIM(RTRIM(lm.IOLOT1))                   AS [Memo Lot 1],
            LTRIM(RTRIM(lm.IOLOT2))                   AS [Memo Lot 2],
            -- IOOHDJ is a JDE Julian date: CYYDDD, where the leading digits are years
            -- since 1900 and the last three are the day of that year.
            CASE
                WHEN lm.IOOHDJ > 0 THEN
                    DATEADD(
                        DAY,
                        (lm.IOOHDJ % 1000) - 1,
                        DATEFROMPARTS((lm.IOOHDJ / 1000) + 1900, 1, 1)
                    )
            END                                       AS [On Hand Date],
            LTRIM(RTRIM(lm.IOAITM))                   AS [Bulk Item (F4108)]
        FROM PRODDTA.F4108 lm
        LEFT JOIN
        (
            SELECT IMITM, MIN(IMBULK) AS IMBULK
            FROM PRODDTA.F554101
            GROUP BY IMITM
        ) tag
            ON tag.IMITM = lm.IOITM
        -- Scope is the item dimension's bulk item, not the lot master's IOAITM. The
        -- two agree on every row IOAITM selects, but IOAITM is the item's own third
        -- item number rather than its bulk parent, so it misses child items that roll
        -- up to an Escor bulk under a different code -- ESC5200-BG rolls up to
        -- ESC5200 and is in the Cognos output.
        WHERE LTRIM(RTRIM(tag.IMBULK)) IN ('ESC5200', 'ESC5200.E', 'ESC5200.S')
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Branch Plant", type text}, {"Bulk Item", type text},
            {"2nd Item Number", type text}, {"Item Short ID", Int64.Type},
            {"Lot Number", type text}, {"Supplier Lot Number", type text},
            {"Memo Lot 1", type text}, {"Memo Lot 2", type text},
            {"On Hand Date", type date}, {"Bulk Item (F4108)", type text}
        },
        "en-US"
    )
in
    Typed
