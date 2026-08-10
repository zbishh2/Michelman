// Report 12 lookup: 'CSR Assignments' - RAW F42140 type-'CSR' rep rows per
// ship-to, name via F0111 Who's Who (WWIDLN=0 mailing name). NOT deduped on
// purpose: the duplicate CMAN8s and their CMCO company codes stay VISIBLE for
// validation (Rohit's 4-dupe finding on report 17). The fact's [CSR Name] DAX
// column picks the rep with the LOWEST AN8 per ship-to = the probe-validated
// 2026-07-14 TOP 1 ORDER BY CMSLSM semantics. NOTE 2026-07-22: filtering
// CMCO<>'00000' was tried and DISPROVED - essentially ALL 'CSR' rows on this
// ODS are CMCO='00000' (it blanked every CSR Name); reconfirm any company
// predicate with Rohit before adding one.
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            c.CMAN8                     AS [Ship To],
            LTRIM(RTRIM(c.CMCO))        AS [Company],
            c.CMSLSM                    AS [Rep AN8],
            LTRIM(RTRIM(w.WWMLNM))      AS [CSR Name]
        FROM PRODDTA.F42140 c
        LEFT JOIN PRODDTA.F0111 w ON w.WWAN8 = c.CMSLSM AND w.WWIDLN = 0
        WHERE LTRIM(RTRIM(c.CMRTYPE)) = 'CSR'
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Ship To", Int64.Type},
            {"Company", type text},
            {"Rep AN8", Int64.Type},
            {"CSR Name", type text}
        },
        "en-US"
    )
in
    Typed
