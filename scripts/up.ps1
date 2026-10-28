. "$PSScriptRoot\common.ps1"

$root = Get-ProjectRoot
$envFile = Join-Path $root '.env'

if (-not (Test-Path -LiteralPath $envFile)) {
    Copy-Item -LiteralPath (Join-Path $root '.env.example') -Destination $envFile
    Write-Host 'Se creo .env a partir de .env.example.'
}

Import-DotEnv $envFile | Out-Null

Write-Host '== Levantando PostgreSQL, SQL Server y MongoDB =='
Invoke-Compose @('up', '-d', '--build')

Write-Host '== Esperando healthchecks =='
Wait-ForHealthy -Containers @('medical_pg', 'medical_mssql', 'medical_mongo') -TimeoutSeconds 480

Write-Host ''
Write-Host 'Stack listo:'
Write-Host "  PostgreSQL : localhost:$($env:PG_PORT)  db=$($env:PG_DB)"
Write-Host "  SQL Server : localhost:$($env:MSSQL_PORT)  db=$($env:MSSQL_DB)"
Write-Host "  MongoDB    : localhost:$($env:MONGO_PORT)  db=$($env:MONGO_DB)"
Write-Host ''
Write-Host 'Siguiente paso: .\scripts\bootstrap.ps1'
