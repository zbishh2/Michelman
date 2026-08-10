// ============================================================================
// 08 - Ivan SK 2023 Forecast   ->   PAGE "Forecast"
// REDEVELOPED 2026-07-13 on EDW (BIQL.FactForecast_v2) per Rohit's 2026-07-09
// review: ODS/F3460 cannot derive TM Name. The Forecast Perspective
// (SSASPROD BIQLTabular_v2, perspective "Forecast") sources the same view, so
// this satisfies both of Rohit's rebuild options at once.
//
// SOURCE: EDWPROD / EDW, schema BIQL. Native T-SQL, folds. Import mode
//   (DQ flip 2026-07-13 REVERTED same day - the team ask was SSAS LIVE, not DQ).
//   BIQL.FactForecast_v2      - forecast fact (v2 adds TerritoryManagerSKey,
//                               ConversionFactorKG/LB, UOM Primary)
//   BIQL.TbAddress            - customer name / global parent
//   BIQL.TbTerritoryManager   - TM Name (Cognos DW VENDOR_ALIAS_TM equivalent)
//
// COLUMN NOTES:
//   TM Name       tm.[Mailing Name]; alternative candidate = tm.[Territory Manager]
//                 - eyeball against Cognos on first jumpbox render and swap if wrong.
//   KG / LB       QuantityForecast * ConversionFactorKG/LB - exactly how the
//                 Perspective's calculated columns compute them (v2.xmla). The old
//                 UOM CASE fallback is gone; Cognos defect C6 is moot here.
//   Revenue Business Unit = BusinessUnit, still a PLACEHOLDER (open decision D6).
//                 FactForecast_v2 carries no RBU key; BIQL.TbRevenueBusinessUnit
//                 exists but nothing joins it to forecast rows.
//   Company Code  ff.Company (was an F0006 guess on ODS - now a real column).
//
// FILTERS (Cognos parity, except where prompts take over):
//   ForecastType = 'SA'; QuantityForecast > 0; Company NOT IN 00024/00025;
//   branch filter kept in SQL (clone difference vs twin preserved).
//   ITEM whitelist REMOVED from SQL -> now the item slicer's preset default
//     (Rohit 2026-07-09: prompt with preselected filters, user-editable).
//   DATE window REMOVED from SQL -> now the Requested Date range slicer
//     (Rohit 2026-07-09 / Zack 2026-07-13: keep the date filter as a prompt).
//     Import floor: 12 months back from the first of the current month, no
//     ceiling, so the prompt has history + all future forecasts to select from.
//
// The 12 old '-- TODO verify' markers are all RESOLVED by FactForecast_v2:
//   requested date = RequestedDate (no MFDRQJ/MFRQDJ ambiguity), quantity =
//   QuantityForecast (no /10000 question), customer = AddressNum/AddressSKey.
// ============================================================================
let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            ISNULL(LTRIM(RTRIM(ff.Company)), '')                    AS [Company Code],
            LTRIM(RTRIM(ff.BusinessUnit))                           AS [Branch Plant],
            LTRIM(RTRIM(ff.[Global Bulk]))                          AS [Global Bulk Item],
            LTRIM(RTRIM(ff.[Bulk Item]))                            AS [Bulk Item],
            LTRIM(RTRIM(ff.ItemNum2nd))                             AS [2nd Item Number],
            DATEPART(YEAR,     ff.RequestedDate)                    AS [Year],
            DATEPART(MONTH,    ff.RequestedDate)                    AS [Month],
            DATEPART(ISO_WEEK, ff.RequestedDate)                    AS [Week],
            CAST(ff.RequestedDate AS date)                          AS [Requested Date],
            SUM(ff.QuantityForecast * ff.ConversionFactorKG)        AS [Current Forecast KG],
            LTRIM(RTRIM(ff.BusinessUnit))                           AS [Revenue Business Unit],
            LTRIM(RTRIM(CAST(ff.AddressNum AS varchar(20))))        AS [Customer Code],
            LTRIM(RTRIM(a.[Address Name]))                          AS [Customer Name],
            a.[Global Parent]                                       AS [Global Parent],
            LTRIM(RTRIM(a.[Global Parent Desc]))                    AS [Global Parent Name],
            ISNULL(NULLIF(LTRIM(RTRIM(tm.[Mailing Name])), ''), 'Not Available') AS [TM Name],
            SUM(ff.QuantityForecast)                                AS [Current Forecast],
            LTRIM(RTRIM(ff.[UOM Primary]))                          AS [Primary UOM],
            SUM(ff.QuantityForecast * ff.ConversionFactorLB)        AS [Current Forecast LB]
        FROM BIQL.FactForecast_v2 ff
        LEFT JOIN BIQL.TbAddress a
               ON a.AddressSKey = ff.AddressSKey
        LEFT JOIN BIQL.TbTerritoryManager tm
               ON tm.TerritoryManagerSKey = ff.TerritoryManagerSKey
        WHERE LTRIM(RTRIM(ff.ForecastType)) = 'SA'
          AND ff.QuantityForecast > 0
          AND ISNULL(LTRIM(RTRIM(ff.Company)), '') NOT IN ('00024', '00025')
          AND LTRIM(RTRIM(ff.BusinessUnit)) IN ('AUBA', 'AUB2', 'SING', 'SNG4', 'MUM3', 'SHAN', 'CINC', 'CIN2', 'CIN4')
          AND ff.RequestedDate >= DATEADD(MONTH, -12, DATEADD(DAY, 1, EOMONTH(CAST(GETDATE() AS date), -1)))
        GROUP BY
            ISNULL(LTRIM(RTRIM(ff.Company)), ''),
            LTRIM(RTRIM(ff.BusinessUnit)),
            LTRIM(RTRIM(ff.[Global Bulk])),
            LTRIM(RTRIM(ff.[Bulk Item])),
            LTRIM(RTRIM(ff.ItemNum2nd)),
            DATEPART(YEAR,     ff.RequestedDate),
            DATEPART(MONTH,    ff.RequestedDate),
            DATEPART(ISO_WEEK, ff.RequestedDate),
            CAST(ff.RequestedDate AS date),
            LTRIM(RTRIM(CAST(ff.AddressNum AS varchar(20)))),
            LTRIM(RTRIM(a.[Address Name])),
            a.[Global Parent],
            LTRIM(RTRIM(a.[Global Parent Desc])),
            ISNULL(NULLIF(LTRIM(RTRIM(tm.[Mailing Name])), ''), 'Not Available'),
            LTRIM(RTRIM(ff.[UOM Primary]))
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
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
