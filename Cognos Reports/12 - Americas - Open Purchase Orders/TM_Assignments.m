let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            c.CMAN8                     AS [Ship To],
            LTRIM(RTRIM(c.CMCO))        AS [Company],
            LTRIM(RTRIM(c.CMRTYPE))     AS [Rep Type],
            c.CMSLSM                    AS [Rep AN8],
            LTRIM(RTRIM(w.WWMLNM))      AS [TM Name]
        FROM PRODDTA.F42140 c
        LEFT JOIN PRODDTA.F0111 w ON w.WWAN8 = c.CMSLSM AND w.WWIDLN = 0
        WHERE LTRIM(RTRIM(c.CMRTYPE)) LIKE '%TM'
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Ship To", Int64.Type},
            {"Company", type text},
            {"Rep Type", type text},
            {"Rep AN8", Int64.Type},
            {"TM Name", type text}
        },
        "en-US"
    )
in
    Typed
