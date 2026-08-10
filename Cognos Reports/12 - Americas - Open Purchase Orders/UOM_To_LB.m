let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            CAST(UMITM AS varchar(20)) + '|' + LTRIM(RTRIM(UMUM)) AS [LB Key],
            UMITM                       AS [Item Key],
            LTRIM(RTRIM(UMUM))          AS [From UOM],
            MAX(UMCONV) / 10000000.0    AS [Factor]
        FROM PRODDTA.F41002
        WHERE LTRIM(RTRIM(UMRUM)) = 'LB'
        GROUP BY UMITM, LTRIM(RTRIM(UMUM))
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"LB Key", type text},
            {"Item Key", Int64.Type},
            {"From UOM", type text},
            {"Factor", type number}
        },
        "en-US"
    )
in
    Typed
