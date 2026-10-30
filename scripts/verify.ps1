. "$PSScriptRoot\common.ps1"

$root = Get-ProjectRoot
Import-DotEnv (Join-Path $root '.env') | Out-Null
$env:PGOPTIONS = '-c client_min_messages=error'

function Get-IntResult {
    param([string]$Text)
    $line = ($Text -split "`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -Last 1)
    return [int]$line.Trim()
}

function Assert-Equal {
    param([string]$Name, $Actual, $Expected)
    if ($Actual -ne $Expected) {
        throw "FALLO: $Name esperaba $Expected y obtuvo $Actual"
    }
    Write-Host "[ok] $Name = $Actual"
}

Write-Host '== Conteos locales y remotos =='
Assert-Equal 'Pacientes locales (3 regiones)' (Get-IntResult (Invoke-PsqlQuery 'SELECT count(*) FROM operativo.v_pacientes_todos;' -TupleOnly)) 15
Assert-Equal 'Pacientes en SQL Server'        (Get-IntResult (Invoke-PsqlQuery 'SELECT count(*) FROM integracion_ext.paciente_integracion;' -TupleOnly)) 15
Assert-Equal 'Facturas en SQL Server'         (Get-IntResult (Invoke-PsqlQuery 'SELECT count(*) FROM integracion_ext.facturas_externas;' -TupleOnly)) 16
Assert-Equal 'Estudios en MongoDB (FDW)'      (Get-IntResult (Invoke-PsqlQuery 'SELECT count(*) FROM reportes_ext.resultados_estudios;' -TupleOnly)) 15
Assert-Equal 'Vista web paciente/facturacion' (Get-IntResult (Invoke-PsqlQuery 'SELECT count(*) FROM api_web.v_paciente_facturacion;' -TupleOnly)) 15
Assert-Equal 'Vista web estudios/analitica'   (Get-IntResult (Invoke-PsqlQuery 'SELECT count(*) FROM api_web.v_estudios_analitica;' -TupleOnly)) 15
Assert-Equal 'Indicadores en MongoDB (FDW)'    (Get-IntResult (Invoke-PsqlQuery 'SELECT count(*) FROM reportes_ext.indicadores_mensuales;' -TupleOnly)) 3
Assert-Equal 'Outbox pendientes'             (Get-IntResult (Invoke-PsqlQuery "SELECT count(*) FROM auditoria.outbox_eventos WHERE estado = 'PENDIENTE';" -TupleOnly)) 0

Write-Host ''
Write-Host '== Consulta distribuida de ejemplo (PostgreSQL + SQL Server) =='
Write-Host (Invoke-PsqlQuery @'
SELECT id_paciente, region, nombre || ' ' || apellidos AS paciente,
       estado_facturacion, total_facturado
FROM api_web.v_paciente_facturacion
ORDER BY id_paciente
LIMIT 8;
'@)

Write-Host ''
Write-Host '== Consulta distribuida de ejemplo (PostgreSQL + MongoDB) =='
Write-Host (Invoke-PsqlQuery @'
SELECT region, id_estudio, paciente, tipo, ingresos
FROM api_web.v_estudios_analitica
ORDER BY id_estudio
LIMIT 8;
'@)

Write-Host ''
Write-Host '== MongoDB: documentos y campos anidados =='
$mongoCount = Get-IntResult (Invoke-MongoEval "db.getSiblingDB('reportes_medicos').resultados_estudios.countDocuments({})")
Assert-Equal 'Documentos en MongoDB' $mongoCount 15
$nested = Get-IntResult (Invoke-MongoEval "db.getSiblingDB('reportes_medicos').resultados_estudios.countDocuments({'resultado.hallazgo': {`$exists: true}})")
Assert-Equal 'Documentos con resultado anidado' $nested 15

Write-Host ''
Write-Host '== Autenticacion y permisos externos (SCRAM) =='
$psqlCommand = Get-Command psql -ErrorAction SilentlyContinue
if ($null -eq $psqlCommand) {
    Write-Host '[skip] psql no esta disponible en el host; no se prueba pg_hba desde fuera.'
} else {
    $previousPassword = $env:PGPASSWORD

    try {
        $env:PGPASSWORD = $env:API_WEB_PASSWORD
        $webOutput = & psql -h 127.0.0.1 -p $env:PG_PORT -U $env:API_WEB_USER -d $env:PG_DB -t -A -v ON_ERROR_STOP=1 -c 'SELECT count(*) FROM api_web.v_paciente_facturacion;'
        if ($LASTEXITCODE -ne 0) { throw 'usr_api_web no pudo consultar su vista.' }
        Assert-Equal 'API web autenticado' (Get-IntResult ($webOutput -join "`n")) 15

        $env:PGPASSWORD = $env:API_MOBILE_PASSWORD
        $mobileOutput = & psql -h 127.0.0.1 -p $env:PG_PORT -U $env:API_MOBILE_USER -d $env:PG_DB -t -A -v ON_ERROR_STOP=1 -c 'SELECT count(*) FROM api_mobile.v_paciente_resumen;'
        if ($LASTEXITCODE -ne 0) { throw 'usr_api_mobile no pudo consultar su vista.' }
        Assert-Equal 'API movil autenticado' (Get-IntResult ($mobileOutput -join "`n")) 15

        $env:PGPASSWORD = $env:API_WEB_PASSWORD
        & psql -h 127.0.0.1 -p $env:PG_PORT -U $env:API_WEB_USER -d $env:PG_DB -v ON_ERROR_STOP=1 -c 'SELECT count(*) FROM operativo.v_pacientes_todos;' 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            throw 'FALLO: usr_api_web pudo leer una vista interna sin privilegios.'
        }
        Write-Host '[ok] usr_api_web no puede leer operativo.v_pacientes_todos'

        # pg_hba.conf: usr_api_web solo puede conectarse a la base operativa.
        & psql -h 127.0.0.1 -p $env:PG_PORT -U $env:API_WEB_USER -d postgres -v ON_ERROR_STOP=1 -c 'SELECT 1;' 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            throw 'FALLO: pg_hba.conf permitio a usr_api_web conectarse a la base postgres.'
        }
        Write-Host '[ok] pg_hba.conf rechaza a usr_api_web fuera de medical_oltp'
    } finally {
        if ($null -eq $previousPassword) {
            Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
        } else {
            $env:PGPASSWORD = $previousPassword
        }
    }
}

Write-Host ''
Write-Host 'Verificacion completada correctamente.'
