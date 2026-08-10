# ============================================================================
# Probe-R14-FX-Factors.ps1 — resolves report 14's two remaining parity gaps
# BEFORE another refresh burn. Run on the jumpbox; results land in
# probe_results_r14fx.txt next to this script — send that file back.
#
# GAP 1 (FX): Cognos joins FIN_CURRENCY_CONVERSION on the MEASURE's cost
#   CURRENCY_CODE with a FROM_TO_EXCHANGE_RATE MULTIPLIER (incl. same-currency
#   identity rows). Our BIQL.DimCurrencyExchangeRates join (company currency,
#   RateType '-', Divisor, DWEffective window) matches ZERO cross-currency rows.
#   Probes 1-5 find out why: schema, rate types, what rows exist for our pairs.
# GAP 2 (EA/GM factors): Cognos uses per-row CONVERSION_FACTOR_KG/LB with -1
#   sentinel -> x20/x44. Our dim pick is wrong for ~15 of 63 EA/GM rows and the
#   factor is branch-specific (DP680.S-B1: SING=1 lb/EA, SNG4=44 lb/EA).
#   Probes 6-8 check whether the FACT carries factor/currency columns natively
#   and dump the dim rows for the known-mismatched items.
# ============================================================================

$ErrorActionPreference = 'Continue'
$outFile = Join-Path $PSScriptRoot 'probe_results_r14fx.txt'

$probes = @(
    # ---- 1. Fact schema: does it carry factor / KG / LB / currency columns? ----
    @{ Name = 'fact-columns'; Server = 'EDWPROD'; Database = 'EDW'; Query = @'
SELECT c.name, t.name AS type_name
FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('BIQL.FactInventorySnapshot_History_Filtered')
ORDER BY c.column_id
'@ }
    # ---- 2. FX dim schema: is there a Multiplier column next to the Divisor? ----
    @{ Name = 'fxdim-columns'; Server = 'EDWPROD'; Database = 'EDW'; Query = @'
SELECT c.name, t.name AS type_name
FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('BIQL.DimCurrencyExchangeRates')
ORDER BY c.column_id
'@ }
    # ---- 3. FX dim contents: rate types + row counts + date coverage ----------
    @{ Name = 'fxdim-ratetypes'; Server = 'EDWPROD'; Database = 'EDW'; Query = @'
SELECT ISNULL(LTRIM(RTRIM(CurrencyRateType)), '<NULL>') AS RateType,
       COUNT(*) AS rows_total,
       SUM(CASE WHEN CAST('2026-07-12' AS date) BETWEEN DWEffectiveFromDate AND DWEffectiveThruDate THEN 1 ELSE 0 END) AS rows_effective_20260712
FROM BIQL.DimCurrencyExchangeRates
GROUP BY ISNULL(LTRIM(RTRIM(CurrencyRateType)), '<NULL>')
ORDER BY rows_total DESC
'@ }
    # ---- 4. Which currencies do our 9 branch plants actually use? -------------
    @{ Name = 'company-currencies'; Server = 'EDWPROD'; Database = 'EDW'; Query = @'
SELECT DISTINCT LTRIM(RTRIM(snap.BusinessUnit)) AS BU, co.CurrencyCode
FROM BIQL.FactInventorySnapshot_History_Filtered snap
JOIN BIQL.DimCompany co ON co.CompanySKey = snap.CompanySKey
WHERE CAST('2026-07-12' AS date) BETWEEN snap.StartDate AND ISNULL(snap.StopDate, '9999-12-31')
  AND snap.QuantityOnHandPrimaryUOM > 0
  AND LTRIM(RTRIM(snap.BusinessUnit)) IN ('CINC','CIN2','CIN4','AUBA','AUB2','SING','SNG4','MUM3','SHAN')
ORDER BY BU
'@ }
    # ---- 5. Every FX row for our pairs, ALL rate types, effective 2026-07-12 --
    # (SELECT * on purpose: we need to see divisor vs multiplier values to learn
    #  which one is the Oracle FROM_TO_EXCHANGE_RATE equivalent.)
    @{ Name = 'fxdim-candidate-rows'; Server = 'EDWPROD'; Database = 'EDW'; Query = @'
SELECT *
FROM BIQL.DimCurrencyExchangeRates
WHERE CurrencyCodeTo IN ('USD','EUR')
  AND CurrencyCodeFrom IN ('USD','EUR','SGD','INR','CNY','RMB','GBP')
  AND CAST('2026-07-12' AS date) BETWEEN DWEffectiveFromDate AND DWEffectiveThruDate
ORDER BY CurrencyCodeFrom, CurrencyCodeTo, CurrencyRateType
'@ }
    # ---- 6. UOM dim schema (any sentinel/default or per-primary factor col?) ---
    @{ Name = 'uomdim-columns'; Server = 'EDWPROD'; Database = 'EDW'; Query = @'
SELECT c.name, t.name AS type_name
FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('BIQL.DimItemUOMConversionLBKG')
ORDER BY c.column_id
'@ }
    # ---- 7. Negative/sentinel factors in the UOM dim ---------------------------
    @{ Name = 'uomdim-negative-factors'; Server = 'EDWPROD'; Database = 'EDW'; Query = @'
SELECT COUNT(*) AS rows_total,
       SUM(CASE WHEN LB < 0 THEN 1 ELSE 0 END) AS lb_negative,
       SUM(CASE WHEN KG < 0 THEN 1 ELSE 0 END) AS kg_negative,
       SUM(CASE WHEN ConversionFactorSecToPrim < 0 THEN 1 ELSE 0 END) AS conv_negative
FROM BIQL.DimItemUOMConversionLBKG
'@ }
    # ---- 8. Full dim rows for the known EA/GM mismatch items (+2 controls) -----
    # Mismatched vs xlsx: DF201-JG, FDCGN-QT, MI102-ML, Q4325A-B1, DG901.E-BX,
    # BROMOCRE, ETHAL.S, MI102.S-ML, DP680.S-B1 (branch-specific!), MCP,
    # NAOH025N, REAL.  Controls that matched: DP680-B1, MCL1188-B1.
    @{ Name = 'uomdim-eagm-item-rows'; Server = 'EDWPROD'; Database = 'EDW'; Query = @'
SELECT DISTINCT it.ItemNum2nd, snap.ItemNumShort, k.BusinessUnit, k.UOM, k.UOMPrimary,
       k.ConversionFactorSecToPrim, k.LB, k.KG, k.TM
FROM BIQL.FactInventorySnapshot_History_Filtered snap
JOIN BIQL.DimItem it ON it.ItemSKey = snap.ItemSKey
LEFT JOIN BIQL.DimItemUOMConversionLBKG k ON k.ItemNumShort = snap.ItemNumShort
WHERE CAST('2026-07-12' AS date) BETWEEN snap.StartDate AND ISNULL(snap.StopDate, '9999-12-31')
  AND snap.QuantityOnHandPrimaryUOM > 0
  AND it.ItemNum2nd IN ('DF201-JG','FDCGN-QT','MI102-ML','Q4325A-B1','DG901.E-BX',
                        'BROMOCRE','ETHAL.S','MI102.S-ML','DP680.S-B1','MCP',
                        'NAOH025N','REAL','DP680-B1','MCL1188-B1')
ORDER BY it.ItemNum2nd, k.BusinessUnit, k.UOM
'@ }
)

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("PROBE RUN $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  machine=$env:COMPUTERNAME  user=$env:USERNAME")

foreach ($p in $probes) {
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("===== $($p.Name)  [$($p.Server)/$($p.Database)] =====")
    $conn = $null
    try {
        $conn = [System.Data.SqlClient.SqlConnection]::new("Server=$($p.Server);Database=$($p.Database);Integrated Security=SSPI;Connection Timeout=30")
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $p.Query
        $cmd.CommandTimeout = 600
        $dt = [System.Data.DataTable]::new()
        [System.Data.SqlClient.SqlDataAdapter]::new($cmd).Fill($dt) | Out-Null
        [void]$sb.AppendLine("rows: $($dt.Rows.Count)")
        [void]$sb.AppendLine((($dt.Columns | ForEach-Object ColumnName) -join "`t"))
        foreach ($row in $dt.Rows) {
            [void]$sb.AppendLine((($dt.Columns | ForEach-Object { '' + $row[$_.ColumnName] }) -join "`t"))
        }
    } catch {
        [void]$sb.AppendLine("ERROR: $($_.Exception.Message)")
    } finally {
        if ($conn) { $conn.Dispose() }
    }
}

Set-Content -Path $outFile -Value $sb.ToString() -Encoding utf8
Write-Host "Wrote $outFile"
