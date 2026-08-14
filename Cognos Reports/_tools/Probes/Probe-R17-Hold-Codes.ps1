# ============================================================================
# Probe-R17-Hold-Codes.ps1 — resolves Nathalie's hold-code exclusion request
# (ticket #2131554) against live ODSPROD before any query change ships.
# Run on the jumpbox; results land in probe_results_r17holds.txt next to this
# script — send that file back.
#
# THE QUESTION: can "Orders within Goal and Stretch" exclude orders that carried
#   a CX (Held for Cash Advance) or C1 (Credit Hold) hold during the 525->540
#   window? The local ODS mirror says NO retroactively: holds are header-level
#   (F4201.SHHOLD) current-state only — F42199.SLHOLD and F4211.SDHOLD are blank
#   everywhere, F4209 is not replicated, and JDE clears SHHOLD on release.
#   Probes 1-3 confirm that on live prod (the mirror's ledger is windowed to
#   2023+, so blank-SLHOLD needs a full-table check). Probes 4-5 test whether
#   any hold survives into the purge/history files. Probes 6-7 size what a
#   current-hold exclusion would actually touch. Probe 8 decodes the codes
#   Nathalie names (incl. "PEN", which is not in UDC 42/HC).
# ============================================================================

$ErrorActionPreference = 'Continue'
$outFile = Join-Path $PSScriptRoot 'probe_results_r17holds.txt'

$probes = @(
    # ---- 1. Ledger hold stamps: does live F42199 EVER carry a hold code? ------
    @{ Name = 'ledger-slhold'; Server = 'ODSPROD'; Database = 'ODS'; Query = @'
SELECT ISNULL(NULLIF(LTRIM(RTRIM(SLHOLD)),''),'<blank>') AS HoldCode, COUNT(*) AS LedgerRows
FROM PRODDTA.F42199
GROUP BY ISNULL(NULLIF(LTRIM(RTRIM(SLHOLD)),''),'<blank>')
ORDER BY 2 DESC
'@ }
    # ---- 2. Line hold codes: F4211 + purged F42119 --------------------------
    @{ Name = 'line-sdhold'; Server = 'ODSPROD'; Database = 'ODS'; Query = @'
SELECT 'F4211' AS src, ISNULL(NULLIF(LTRIM(RTRIM(SDHOLD)),''),'<blank>') AS HoldCode, COUNT(*) AS Lines
FROM PRODDTA.F4211 GROUP BY ISNULL(NULLIF(LTRIM(RTRIM(SDHOLD)),''),'<blank>')
UNION ALL
SELECT 'F42119', ISNULL(NULLIF(LTRIM(RTRIM(SDHOLD)),''),'<blank>'), COUNT(*)
FROM PRODDTA.F42119 GROUP BY ISNULL(NULLIF(LTRIM(RTRIM(SDHOLD)),''),'<blank>')
ORDER BY 1, 3 DESC
'@ }
    # ---- 3. Is the Held Orders file (F4209) replicated to ODS at all? --------
    @{ Name = 'f4209-exists'; Server = 'ODSPROD'; Database = 'ODS'; Query = @'
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE 'F4209%'
'@ }
    # ---- 4. Current header holds: the live F4201 distribution ----------------
    @{ Name = 'header-holds-current'; Server = 'ODSPROD'; Database = 'ODS'; Query = @'
SELECT LTRIM(RTRIM(SHHOLD)) AS HoldCode, COUNT(*) AS Orders
FROM PRODDTA.F4201
WHERE LTRIM(RTRIM(SHHOLD)) <> ''
GROUP BY LTRIM(RTRIM(SHHOLD))
ORDER BY 2 DESC
'@ }
    # ---- 5. Purged headers: does any hold code survive into F42019? ----------
    #    (if ~0, hold history is truly unrecoverable from ODS)
    @{ Name = 'header-holds-purged'; Server = 'ODSPROD'; Database = 'ODS'; Query = @'
SELECT LTRIM(RTRIM(SHHOLD)) AS HoldCode, COUNT(*) AS PurgedOrders
FROM PRODDTA.F42019
WHERE LTRIM(RTRIM(SHHOLD)) <> ''
GROUP BY LTRIM(RTRIM(SHHOLD))
ORDER BY 2 DESC
'@ }
    # ---- 6. Where currently-held CX/C1/FM orders sit (open lines by next status)
    @{ Name = 'held-sit-status'; Server = 'ODSPROD'; Database = 'ODS'; Query = @'
SELECT LTRIM(RTRIM(h.SHHOLD)) AS HoldCode, LTRIM(RTRIM(d.SDNXTR)) AS NextStatus,
       COUNT(*) AS OpenLines, COUNT(DISTINCT d.SDDOCO) AS Orders
FROM PRODDTA.F4201 h
JOIN PRODDTA.F4211 d
  ON d.SDKCOO = h.SHKCOO AND d.SDDOCO = h.SHDOCO AND d.SDDCTO = h.SHDCTO
WHERE LTRIM(RTRIM(h.SHHOLD)) IN ('CX','C1','FM')
GROUP BY LTRIM(RTRIM(h.SHHOLD)), LTRIM(RTRIM(d.SDNXTR))
ORDER BY 1, 2
'@ }
    # ---- 7. Overlap: currently-held CX/C1 orders whose lines already scored --
    #    (both a 525 and a 540 ledger event => the line is in the report today)
    @{ Name = 'held-vs-scored'; Server = 'ODSPROD'; Database = 'ODS'; Query = @'
SELECT LTRIM(RTRIM(h.SHHOLD)) AS HoldCode,
       COUNT(DISTINCT CASE WHEN e525.SLDOCO IS NOT NULL AND e540.SLDOCO IS NOT NULL
             THEN CAST(d.SDDOCO AS varchar(20)) + '|' + CAST(d.SDLNID AS varchar(20)) END) AS ScoredLines,
       COUNT(DISTINCT CASE WHEN e525.SLDOCO IS NOT NULL AND e540.SLDOCO IS NOT NULL
             THEN d.SDDOCO END) AS OrdersWithScoredLines
FROM PRODDTA.F4201 h
JOIN PRODDTA.F4211 d
  ON d.SDKCOO = h.SHKCOO AND d.SDDOCO = h.SHDOCO AND d.SDDCTO = h.SHDCTO
LEFT JOIN (SELECT DISTINCT SLKCOO, SLDOCO, SLDCTO, SLLNID FROM PRODDTA.F42199 WHERE SLNXTR = '525' AND SLUPMJ > 0) e525
  ON e525.SLKCOO = d.SDKCOO AND e525.SLDOCO = d.SDDOCO AND e525.SLDCTO = d.SDDCTO AND e525.SLLNID = d.SDLNID
LEFT JOIN (SELECT DISTINCT SLKCOO, SLDOCO, SLDCTO, SLLNID FROM PRODDTA.F42199 WHERE SLNXTR = '540' AND SLUPMJ > 0) e540
  ON e540.SLKCOO = d.SDKCOO AND e540.SLDOCO = d.SDDOCO AND e540.SLDCTO = d.SDDCTO AND e540.SLLNID = d.SDLNID
WHERE LTRIM(RTRIM(h.SHHOLD)) IN ('CX','C1')
GROUP BY LTRIM(RTRIM(h.SHHOLD))
'@ }
    # ---- 8. Decode: the codes Nathalie names, and what 'PEN' actually is -----
    @{ Name = 'udc-decode'; Server = 'ODSPROD'; Database = 'ODS'; Query = @'
SELECT LTRIM(RTRIM(DRSY)) AS Sys, LTRIM(RTRIM(DRRT)) AS RT,
       LTRIM(RTRIM(DRKY)) AS Code, LTRIM(RTRIM(DRDL01)) AS Description
FROM PRODCTL.F0005
WHERE (LTRIM(RTRIM(DRSY)) = '42' AND LTRIM(RTRIM(DRRT)) = 'HC'
       AND LTRIM(RTRIM(DRKY)) IN ('C1','C2','CX','FM'))
   OR LTRIM(RTRIM(DRKY)) = 'PEN'
ORDER BY 1, 2, 3
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
