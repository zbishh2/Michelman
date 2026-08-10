// Report 12 lookup: 'UOM Conversions' - DEDUPED item UOM conversion factors.
// Source F41002; conv = UMCONV / 10^7 (report 17 sec 12.6 proven scale).
// DEDUPE REQUIRED: this ODS holds up to 18 rows per (item, from, to) triple
// (branch/historical dups) - a raw join fanned 17's SUM 2.3x (17 sec 12.7).
// MAX(UMCONV) is lossless for all but ~23 multi-variant triples (disclosed).
// [Conv Key] = ITM|From|To -> m:1 relationship from Sales_Orders_Static[Conv Key];
// [Sales Factor] on the fact reads it with RELATED().
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
