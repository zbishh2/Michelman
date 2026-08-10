let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            CAST(UMITM AS varchar(20)) + '|' + LTRIM(RTRIM(UMUM)) + '|' + LTRIM(RTRIM(UMRUM)) AS [Conv Key],
            UMITM                       AS [Item Key],
            LTRIM(RTRIM(UMUM))          AS [From UOM],
            LTRIM(RTRIM(UMRUM))         AS [To UOM],
            MAX(UMCONV) / 10000000.0    AS [Factor]
        FROM PRODDTA.F41002
        GROUP BY UMITM, LTRIM(RTRIM(UMUM)), LTRIM(RTRIM(UMRUM))
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Conv Key", type text},
            {"Item Key", Int64.Type},
            {"From UOM", type text},
            {"To UOM", type text},
            {"Factor", type number}
        },
        "en-US"
    )
in
    Typed
