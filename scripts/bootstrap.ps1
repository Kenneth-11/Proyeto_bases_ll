param(
    [switch]$SkipWait
)

. "$PSScriptRoot\common.ps1"

$root = Get-ProjectRoot
Import-DotEnv (Join-Path $root '.env') | Out-Null

if (-not $SkipWait) {
    Write-Host '== Verificando disponibilidad de los motores =='
    Wait-ForHealthy -Containers @('medical_pg', 'medical_mssql', 'medical_mongo') -TimeoutSeconds 480
}

$mssqlVars = @{
    'DbName'      = $env:MSSQL_DB
    'FdwUser'     = $env:FDW_MSSQL_USER
    'FdwPassword' = $env:FDW_MSSQL_PASSWORD
}

$mongoEnv = @{
    'MONGO_DB'           = $env:MONGO_DB
    'FDW_MONGO_USER'     = $env:FDW_MONGO_USER
    'FDW_MONGO_PASSWORD' = $env:FDW_MONGO_PASSWORD
}

$pgVars = @{
    'db_name'            = $env:PG_DB
    'mssql_db'           = $env:MSSQL_DB
    'fdw_mssql_user'     = $env:FDW_MSSQL_USER
    'fdw_mssql_password' = $env:FDW_MSSQL_PASSWORD
    'fdw_mongo_user'     = $env:FDW_MONGO_USER
    'fdw_mongo_password' = $env:FDW_MONGO_PASSWORD
    'api_web_user'       = $env:API_WEB_USER
    'api_web_password'   = $env:API_WEB_PASSWORD
    'api_mobile_user'    = $env:API_MOBILE_USER
    'api_mobile_password'= $env:API_MOBILE_PASSWORD
}

Write-Host ''
Write-Host '== [1/3] SQL Server: base de integracion =='
Invoke-SqlcmdFile '00_database.sql' $mssqlVars
Invoke-SqlcmdFile '01_schema.sql'   $mssqlVars
Invoke-SqlcmdFile '02_procedures.sql' $mssqlVars
Invoke-SqlcmdFile '03_logins.sql'   $mssqlVars
Invoke-SqlcmdFile '04_seed.sql'     $mssqlVars

Write-Host ''
Write-Host '== [2/3] MongoDB: usuarios, colecciones e indices =='
Invoke-MongoScript '01_users.js' $mongoEnv
Invoke-MongoScript '02_seed.js'  $mongoEnv

Write-Host ''
Write-Host '== [3/3] PostgreSQL: esquemas, roles, FDW y capa API =='
Invoke-PsqlFile '00_extensions.sql'
Invoke-PsqlFile '01_catalogo.sql'
Invoke-PsqlFile '02_regiones.sql'
Invoke-PsqlFile '03_seed_local.sql'
Invoke-PsqlFile '04_roles.sql'      $pgVars
Invoke-PsqlFile '05_fdw_mssql.sql'  $pgVars
Invoke-PsqlFile '06_fdw_mongo.sql'  $pgVars
Invoke-PsqlFile '07_views_api.sql'  $pgVars
Invoke-PsqlFile '08_procedures.sql' $pgVars
Invoke-PsqlFile '09_export_mongo.sql'

Write-Host ''
Write-Host '== Bootstrap completado =='
Write-Host 'Ejecute .\scripts\verify.ps1 para validar la integracion.'
