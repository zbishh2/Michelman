// F0005 — JDE User Defined Codes (UDC master). Small; grab all rows.
// Decodes reason codes / order types / line types into descriptions.
// Paste into Power BI Desktop -> Get Data -> Blank Query -> Advanced Editor.
// Set the server to match your SSMS connection (likely "ODSPROD").
let
    Source = Sql.Database("ODSPROD", "ODS"),
    F0005 = Source{[Schema = "PRODDTA", Item = "F0005"]}[Data],
    Pruned = Table.SelectColumns(
        F0005,
        {
            "DRSY",    // product/system code (e.g. 42)
            "DRRT",    // UDC type (e.g. RC)
            "DRKY",    // the code value
            "DRDL01",  // description 1
            "DRDL02",  // description 2
            "DRSPHD"   // special handling code
        }
    )
in
    Pruned


