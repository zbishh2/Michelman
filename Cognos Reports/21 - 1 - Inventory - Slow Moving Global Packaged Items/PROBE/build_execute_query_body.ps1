param(
    [Parameter(Mandatory = $true)][string] $QueryFile,
    [Parameter(Mandatory = $true)][string] $OutFile
)

$query = [IO.File]::ReadAllText($QueryFile)
$body = @{
    queries = @(@{ query = $query })
    serializerSettings = @{ includeNulls = $true }
} | ConvertTo-Json -Depth 8

[IO.File]::WriteAllText($OutFile, $body, [Text.UTF8Encoding]::new($false))
