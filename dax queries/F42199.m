// F42199 — JDE Sales Order Ledger (change history). Import into Power BI.
// ** FULL COLUMN SET ** — all 268 columns, to hunt for a date-change reason
// field that the pruned version may have dropped. Row filter kept to bound size.
// Paste into Power BI Desktop -> Get Data -> Blank Query -> Advanced Editor.
// SERVER/DB: schema PRODDTA, database ODS. Set the server to match your SSMS
//   connection (the one where `USE [ODS]` worked) — likely "ODSPROD".
// Dates are raw JDE Julian ints (CYYDDD); Claude converts them in DAX.
// NOTE: replacing the old 28-col F42199 — paste over that query (or delete it
//   and add this as a new Blank Query) so columns auto-detect on refresh.
//   ~3.6M rows x 268 cols => bigger/slower refresh than before; widen/narrow
//   the filter below (124001 = 2024-001) if needed.
let
    Source = Sql.Database("ODSPROD", "ODS"),
    F42199 = Source{[Schema = "PRODDTA", Item = "F42199"]}[Data],
    Filtered = Table.SelectRows(F42199, each [SLUPMJ] >= 124001)
in
    Filtered
