// Report 12 lookup: 'UOM To LB' - deduped conversions whose TARGET UOM is LB.
// Same F41002 source/scale/dedupe as 'UOM Conversions', filtered To='LB'.
// [LB Key] = ITM|From -> m:1 relationships from PO[LB Key] and
// Sales_Orders_Static[LB Key]; [LB Factor] on each fact reads it with RELATED().
// Stands in for DW_LEGACY CONVERSION_FACTOR_LB (mechanics 17-proven; the LB
// source itself is the remaining TODO-verify vs the Cognos xlsx).
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
