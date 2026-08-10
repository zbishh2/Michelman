// F4211 — JDE Sales Order Detail (CURRENT open orders). Import into Power BI.
// Paste into Power BI Desktop -> Get Data -> Blank Query -> Advanced Editor.
// Set the server to match your SSMS connection (likely "ODSPROD").
// Folds to SQL. Dates left as raw JDE Julian ints; Claude converts in DAX.
let
    Source = Sql.Database("ODSPROD", "ODS"),
    F4211 = Source{[Schema = "PRODDTA", Item = "F4211"]}[Data],
    Pruned = Table.SelectColumns(
        F4211,
        {
            "SDKCOO", "SDDOCO", "SDDCTO", "SDSFXO", "SDLNID", "SDMCU",
            "SDLITM", "SDLNTY", "SDNXTR", "SDLTTR", "SDRCD",
            "SDPDDJ", "SDOPDJ", "SDDRQJ", "SDRSDJ",
            "SDADDJ", "SDCNDJ", "SDDGL",
            "SDUPMJ", "SDTDAY", "SDUSER", "SDPID"
        }
    )
in
    Pruned
