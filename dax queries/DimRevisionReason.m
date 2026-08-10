// DimRevisionReason — the 47 schedule-revision reason codes (RFRV / UDC 42/RR)
// with descriptions + a DRAFT OTIF-impact grouping. Relates to
// FactScheduleChange[RevisionReason]. Source: ODSPROD / ODS / PRODCTL.F0005.
// ** ReasonCategory + CountsAgainstOTIF are a first draft — confirm with Greg. **
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Dim = Value.NativeQuery(
        Source,
        "SELECT
            LTRIM(RTRIM(DRKY)) AS RevisionReason,
            DRDL01             AS ReasonDescription,
            DRDL02             AS ReasonDescription2,
            CASE
                WHEN LTRIM(RTRIM(DRKY)) IN ('Q1','Q2')                              THEN 'Quality'
                WHEN LTRIM(RTRIM(DRKY)) IN ('L1','L2','L3','LCM','LFC','LIC','LQW') THEN 'Material / RM'
                WHEN LTRIM(RTRIM(DRKY)) IN ('P3','P4','P5','P6','P7','P8','P9','PD1','PD2','PD3','F1') THEN 'Production / Capacity'
                WHEN LTRIM(RTRIM(DRKY)) IN ('T0','T1','T2','T3','T4','SS','L4')     THEN 'Carrier / Logistics'
                WHEN LTRIM(RTRIM(DRKY)) IN ('C1','C2','C3','C4','C5','C6','C7')     THEN 'Customer / Commercial'
                WHEN LTRIM(RTRIM(DRKY)) IN ('A1','A2','A4','A5','A6','C0')          THEN 'Administrative / Scheduling'
                WHEN LTRIM(RTRIM(DRKY)) LIKE 'A3%'                                  THEN 'No Impact (flagged)'
                ELSE 'Other / Review'
            END AS ReasonCategory,
            CASE
                WHEN LTRIM(RTRIM(DRKY)) LIKE 'A3%'          THEN 0
                WHEN LTRIM(RTRIM(DRKY)) = 'C0'              THEN 0
                WHEN LTRIM(RTRIM(DRKY)) IN ('A1','A2','A6') THEN 0
                ELSE 1
            END AS CountsAgainstOTIF
        FROM PRODCTL.F0005
        WHERE LTRIM(RTRIM(DRSY)) = '42'
          AND LTRIM(RTRIM(DRRT)) = 'RR'",
        null,
        [EnableFolding = true]
    )
in
    Dim
