// ============================================================================
// 08 - Ivan SK 2023 Forecast   ->   PAGE "Forecast"  --  SSAS-SOURCED VARIANT (team preference)
// Twin of Forecast.m (EDW): SAME 19 columns, SAME filters, SAME slicer design.
// Lives in `PBIP (SSAS)\` as "1 - Ivan SK 2023 Forecast (SSAS)" so both versions can be published
// side by side; the EDW version stays in `PBIP\`.
//
// SOURCE: SSASPROD tabular database BIQLTabular_v2 (the "Forecast" perspective's
//   model - the one Jim updated with TM Name). Import mode via a DAX EVALUATE:
//   SUMMARIZECOLUMNS groups FactForecast + Address + 'Territory Manager' and
//   sums QuantityForecast / KG / LB, then SELECTCOLUMNS renames to the exact
//   19 Cognos headers. The model's own relationships supply the joins
//   (FactForecast[TerritoryManagerSKey] -> 'Territory Manager', [AddressSKey]
//   -> Address), so no join logic is duplicated here.
//
// NOTES (same as the EDW twin unless stated):
//   TM Name  = 'Territory Manager'[Mailing Name]; alt candidate [Territory Manager].
//   KG / LB  = SUM of the model's OWN calculated columns QuantityForecastKG/LB.
//   Revenue Business Unit = BusinessUnit placeholder (open decision D6).
//   Date floor EOMONTH(TODAY(),-13)+1 = first of the month, 12 months back; no
//     ceiling - the Requested Date slicer is the user-facing window (prompt).
//   Item whitelist lives in the item slicer preset, not in this query.
//
// REFRESH REQUIREMENTS (differ from the EDW twin!):
//   - Desktop/jumpbox: needs read access on SSASPROD BIQLTabular_v2 (an SSAS
//     role membership, not a SQL grant).
//   - Service: the gateway must have an Analysis Services data source for
//     SSASPROD with EffectiveUserName mapping - different from the SQL Server
//     data source the other reports use.
// ============================================================================
let
    Source = AnalysisServices.Database(
        "SSASPROD",
        "BIQLTabular_v2",
        [Query = "
        EVALUATE
        SELECTCOLUMNS(
            SUMMARIZECOLUMNS(
                FactForecast[Company],
                FactForecast[BusinessUnit],
                FactForecast[Global Bulk],
                FactForecast[Bulk Item],
                FactForecast[ItemNum2nd],
                FactForecast[RequestedDate],
                FactForecast[AddressNum],
                Address[Address Name],
                Address[Global Parent],
                Address[Global Parent Desc],
                'Territory Manager'[Mailing Name],
                FactForecast[UOM Primary],
                FILTER(ALL(FactForecast[ForecastType]), FactForecast[ForecastType] = ""SA""),
                FILTER(ALL(FactForecast[Company]), NOT FactForecast[Company] IN {""00024"", ""00025""}),
                FILTER(ALL(FactForecast[BusinessUnit]), FactForecast[BusinessUnit] IN {""AUBA"", ""AUB2"", ""SING"", ""SNG4"", ""MUM3"", ""SHAN"", ""CINC"", ""CIN2"", ""CIN4""}),
                FILTER(ALL(FactForecast[QuantityForecast]), FactForecast[QuantityForecast] > 0),
                FILTER(ALL(FactForecast[RequestedDate]), FactForecast[RequestedDate] >= EOMONTH(TODAY(), -13) + 1),
                ""@CF"", SUM(FactForecast[QuantityForecast]),
                ""@CFKG"", SUM(FactForecast[QuantityForecastKG]),
                ""@CFLB"", SUM(FactForecast[QuantityForecastLB])
            ),
            ""Company Code"", FactForecast[Company],
            ""Branch Plant"", FactForecast[BusinessUnit],
            ""Global Bulk Item"", FactForecast[Global Bulk],
            ""Bulk Item"", FactForecast[Bulk Item],
            ""2nd Item Number"", FactForecast[ItemNum2nd],
            ""Year"", YEAR(FactForecast[RequestedDate]),
            ""Month"", MONTH(FactForecast[RequestedDate]),
            ""Week"", WEEKNUM(FactForecast[RequestedDate], 21),
            ""Requested Date"", FactForecast[RequestedDate],
            ""Current Forecast KG"", [@CFKG],
            ""Revenue Business Unit"", FactForecast[BusinessUnit],
            ""Customer Code"", FORMAT(FactForecast[AddressNum], ""0""),
            ""Customer Name"", Address[Address Name],
            ""Global Parent"", Address[Global Parent],
            ""Global Parent Name"", Address[Global Parent Desc],
            ""TM Name"", IF(ISBLANK('Territory Manager'[Mailing Name]) || 'Territory Manager'[Mailing Name] = """", ""Not Available"", 'Territory Manager'[Mailing Name]),
            ""Current Forecast"", [@CF],
            ""Primary UOM"", FactForecast[UOM Primary],
            ""Current Forecast LB"", [@CFLB]
        )
        ", Implementation = "2.0"]
    ),
    Renamed = Table.TransformColumnNames(
        Source,
        each if Text.StartsWith(_, "[") then Text.BetweenDelimiters(_, "[", "]") else _
    ),
    Typed = Table.TransformColumnTypes(
        Renamed,
        {
            {"Company Code", type text},
            {"Branch Plant", type text},
            {"Global Bulk Item", type text},
            {"Bulk Item", type text},
            {"2nd Item Number", type text},
            {"Year", Int64.Type},
            {"Month", Int64.Type},
            {"Week", Int64.Type},
            {"Requested Date", type date},
            {"Current Forecast KG", type number},
            {"Revenue Business Unit", type text},
            {"Customer Code", type text},
            {"Customer Name", type text},
            {"Global Parent", Int64.Type},
            {"Global Parent Name", type text},
            {"TM Name", type text},
            {"Current Forecast", type number},
            {"Primary UOM", type text},
            {"Current Forecast LB", type number}
        },
        "en-US"
    )
in
    Typed
