. "$PSScriptRoot\common.ps1"

$root = Get-ProjectRoot
Import-DotEnv (Join-Path $root '.env') | Out-Null

function Get-IntResult {
    param([string]$Text)
    $line = ($Text -split "`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -Last 1)
    return [int]$line.Trim()
}

function Remove-DemoData {
    Invoke-PsqlQuery @'
DO $$
DECLARE r record;
BEGIN
    FOR r IN
        SELECT e.id_estudio, e.id_orden
        FROM san_jose.estudios e
        JOIN san_jose.diagnosticos d ON d.id_estudio = e.id_estudio
        WHERE d.descripcion = 'Estudio creado durante la demostracion'
    LOOP
        DELETE FROM auditoria.bitacora_sincronizacion WHERE id_estudio = r.id_estudio;
        DELETE FROM auditoria.outbox_eventos WHERE id_estudio = r.id_estudio;
        DELETE FROM reportes_ext.resultados_estudios WHERE id_estudio = r.id_estudio;
        DELETE FROM san_jose.diagnosticos WHERE id_estudio = r.id_estudio;
        DELETE FROM san_jose.estudios WHERE id_estudio = r.id_estudio;
        DELETE FROM san_jose.ordenes WHERE id_orden = r.id_orden;
    END LOOP;
END $$;
'@
}

Write-Host '====================================================================='
Write-Host ' SISTEMA DE GESTION DE ESTUDIOS MEDICOS DISTRIBUIDO - DEMO'
Write-Host '====================================================================='
Write-Host ''
Write-Host 'Mapa de conexiones:'
Write-Host '  PostgreSQL (OLTP, 3 regiones) --tds_fdw--> SQL Server (integracion)'
Write-Host '  PostgreSQL (OLTP, 3 regiones) --mongo_fdw--> MongoDB (analitica)'
Write-Host ''

Remove-DemoData | Out-Null

Write-Host '--- 1. Segmentacion horizontal en PostgreSQL ---'
Write-Host (Invoke-PsqlQuery @'
SELECT region, count(*) AS pacientes
FROM operativo.v_pacientes_todos
GROUP BY region
ORDER BY region;
'@)

Write-Host ''
Write-Host '--- 2. Consulta distribuida: paciente + estado de facturacion (SQL Server) ---'
Write-Host (Invoke-PsqlQuery @'
SELECT id_paciente, region, nombre || ' ' || apellidos AS paciente,
       estado_facturacion, total_facturado, facturas_pendientes
FROM api_web.v_paciente_facturacion
ORDER BY id_paciente
LIMIT 10;
'@)

Write-Host ''
Write-Host '--- 3. Consulta distribuida: estudios locales + resumen MongoDB ---'
Write-Host (Invoke-PsqlQuery @'
SELECT region, id_estudio, paciente, tipo,
       diagnostico_analitico, ingresos
FROM api_web.v_estudios_analitica
ORDER BY id_estudio
LIMIT 10;
'@)

Write-Host ''
Write-Host '--- 4. Insercion en PostgreSQL + sincronizacion a MongoDB tras COMMIT (outbox) ---'
$insertOutput = Invoke-PsqlQuery -TupleOnly -Sql @'
CALL operativo.sp_registrar_estudio(
    'san_jose',
    10001,
    3,
    501,
    jsonb_build_object('hallazgo', 'Estudio de demostracion', 'medida', '10 mm', 'conclusion', 'Normal'),
    'R10.4',
    'Estudio creado durante la demostracion',
    NULL
);
'@

$newId = Get-IntResult $insertOutput
Write-Host "Nuevo id_estudio generado: $newId"

Write-Host (Invoke-PsqlQuery "SELECT id_estudio, region, paciente, tipo, medico, estado, diagnostico FROM operativo.v_estudios_todos WHERE id_estudio = $newId;")

Write-Host ''
Write-Host 'Documento equivalente en MongoDB:'
$expr = "JSON.stringify(db.getSiblingDB('reportes_medicos').resultados_estudios.findOne({id_estudio: $newId}))"
Write-Host (Invoke-MongoEval $expr)

Write-Host ''
Write-Host 'Estado del outbox y bitacora de sincronizacion:'
Write-Host (Invoke-PsqlQuery "SELECT id_evento, id_estudio, region, estado, intentos, ultimo_error FROM auditoria.outbox_eventos WHERE id_estudio = $newId ORDER BY id_evento;")
Write-Host (Invoke-PsqlQuery "SELECT id_estudio, region, operacion, resultado, detalle FROM auditoria.bitacora_sincronizacion WHERE id_estudio = $newId ORDER BY id_bitacora;")

Write-Host ''
Write-Host 'Actualizacion de un documento existente (conserva el subdocumento resultado):'
Invoke-PsqlQuery "SELECT operativo.fn_sincronizar_estudio(11001, 'san_jose');" | Out-Null
$exprExistente = "JSON.stringify(db.getSiblingDB('reportes_medicos').resultados_estudios.findOne({id_estudio: 11001}, {_id: 0, estado: 1, resultado: 1}))"
Write-Host (Invoke-MongoEval $exprExistente)

Write-Host ''
Write-Host '--- 5. Agregaciones analiticas en MongoDB ---'
Invoke-MongoScript '03_aggregations.js' @{
    'MONGO_DB' = $env:MONGO_DB
}

Write-Host ''
Write-Host 'Documento nuevo despues de normalizar resultado_json -> resultado:'
$exprNormalizado = "JSON.stringify(db.getSiblingDB('reportes_medicos').resultados_estudios.findOne({id_estudio: $newId}, {_id: 0, id_estudio: 1, paciente: 1, tipo: 1, resultado: 1}))"
Write-Host (Invoke-MongoEval $exprNormalizado)

Write-Host ''
Write-Host '--- 5b. Exportacion de reportes agregados PostgreSQL -> MongoDB ---'
Write-Host (Invoke-PsqlQuery 'SELECT operativo.sp_exportar_indicadores() AS indicadores_exportados;')
Write-Host (Invoke-PsqlQuery 'SELECT periodo, sucursal, total_estudios, ingresos, ticket_promedio FROM reportes_ext.indicadores_mensuales ORDER BY periodo, sucursal;')

Write-Host ''
Write-Host '--- 6. Roles configurados ---'
Write-Host (Invoke-PsqlQuery @'
SELECT rolname, rolcanlogin, rolsuper
FROM pg_roles
WHERE rolname IN ('usr_fdw_pg_mssql', 'usr_fdw_pg_mongo', 'usr_api_web', 'usr_api_mobile')
ORDER BY rolname;
'@)

Write-Host ''
Write-Host '--- 7. Privilegios minimos de los roles externos ---'
Write-Host (Invoke-PsqlQuery @'
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('usr_api_web', 'usr_api_mobile')
ORDER BY grantee, table_schema, table_name, privilege_type;
'@)

Write-Host ''
Write-Host '--- 8. Limpieza de los datos creados por la demostracion ---'
Remove-DemoData | Out-Null
Invoke-PsqlQuery 'SELECT operativo.sp_exportar_indicadores();' | Out-Null
Write-Host 'Datos de demostracion eliminados e indicadores recalculados; el dataset base queda intacto.'

Write-Host ''
Write-Host 'Demo finalizada.'
