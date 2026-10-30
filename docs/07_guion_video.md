# Guion del video demostrativo

Duracion objetivo: **7 minutos** (el enunciado exige entre **5 y 8 minutos**).
Margen: cada bloque tiene un tiempo maximo; si se pasa, recortar la narracion,
no las demostraciones. No mostrar el `bootstrap` completo en camara: ya debe
estar ejecutado.

Cada integrante narra al menos un bloque (el enunciado pide que el video sea
narrado por los integrantes del grupo).

| Bloque | Tiempo | Duracion | Narra |
|--------|--------|----------|-------|
| 1. Presentacion y arquitectura | 0:00 - 1:15 | 1:15 | Integrante 1 |
| 2. Mapa de conexiones y configuracion FDW | 1:15 - 2:30 | 1:15 | Integrante 2 |
| 3. Consultas de integracion en los 3 servidores | 2:30 - 4:15 | 1:45 | Integrante 3 |
| 4. Transaccion distribuida (insercion + MongoDB) | 4:15 - 5:30 | 1:15 | Integrante 1 |
| 5. Roles y seguridad | 5:30 - 6:30 | 1:00 | Integrante 2 |
| 6. Cierre con verificacion | 6:30 - 7:00 | 0:30 | Integrante 3 |

## Preparacion previa (fuera de camara)

```powershell
.\scripts\up.ps1
.\scripts\bootstrap.ps1
.\scripts\verify.ps1      # todo debe salir [ok]
```

Dejar abiertos:

- Terminal 1 en la raiz del proyecto (PowerShell).
- Terminal 2 con `docker exec -it medical_pg psql -U postgres -d medical_oltp`.
- Terminal 3 con `sqlcmd -S localhost,51433 -U sa -P "SqlServer_Med_2026!" -C -d MedicalIntegration`.
- Terminal 4 con `docker exec -it medical_mongo mongosh -u root -p "Mongo_Med_2026!" --authenticationDatabase admin reportes_medicos`.
- Editor con `docs/01_arquitectura.md` (diagrama) y `docker/postgres/conf/`.

## 1. Presentacion y arquitectura (0:00 - 1:15)

**En pantalla:** diagrama de `README.md` / `docs/01_arquitectura.md`.

> Sistema de gestion de estudios medicos distribuido en tres motores.
> PostgreSQL es el nucleo transaccional, con segmentacion horizontal: un
> esquema por region (San Jose, Alajuela y Cartago) con pacientes, citas,
> ordenes, estudios y diagnosticos. SQL Server es la base de integracion con
> aseguradoras, con segmentacion vertical: solo guarda las columnas de
> interoperabilidad, como id_paciente, id_aseguradora, codigo_externo y
> estado_facturacion. MongoDB es la capa analitica con documentos
> desnormalizados para reportes. Los tres corren en Docker sobre una misma red.

## 2. Mapa de conexiones y configuracion FDW (1:15 - 2:30)

**En pantalla:** diagrama de conexiones, luego `postgresql.conf`, `pg_hba.conf`
y `sql/postgres/05_fdw_mssql.sql` / `06_fdw_mongo.sql`.

```sql
-- Terminal 2 (psql)
SHOW config_file;
SELECT srvname, srvoptions FROM pg_foreign_server;
SELECT umuser::regrole, srvname FROM pg_user_mappings;
```

> PostgreSQL se conecta a SQL Server con tds_fdw y a MongoDB con mongo_fdw. Cada
> canal tiene su CREATE SERVER, su user mapping con un usuario interno
> (usr_fdw_pg_mssql y usr_fdw_pg_mongo) y sus tablas foraneas. tds_fdw es de
> solo lectura; mongo_fdw permite insertar y actualizar.

## 3. Consultas de integracion en los 3 servidores (2:30 - 4:15)

```sql
-- Terminal 2 (PostgreSQL): segmentacion horizontal
SELECT region, count(*) FROM operativo.v_pacientes_todos GROUP BY region;

-- PostgreSQL + SQL Server: paciente con su estado de facturacion
SELECT id_paciente, region, nombre, estado_facturacion, total_facturado
FROM api_web.v_paciente_facturacion ORDER BY id_paciente LIMIT 5;
```

```sql
-- Terminal 3 (SQL Server): procedimiento que genera el resumen consumido por PostgreSQL
EXEC integracion.usp_ResumenFacturacionPaciente @id_paciente = 10001;
GO
```

```javascript
// Terminal 4 (MongoDB): agregacion por medico y tipo de estudio
db.resultados_estudios.aggregate([
  { $group: { _id: { medico: '$medico', tipo: '$tipo' },
              estudios: { $sum: 1 }, ingresos: { $sum: '$ingresos' } } },
  { $sort: { ingresos: -1 } }
])
```

> La vista web combina datos locales de PostgreSQL con datos remotos de SQL
> Server. SQL Server calcula el resumen con un procedimiento almacenado y
> PostgreSQL lo lee por FDW. MongoDB responde las agregaciones por medico y
> tipo de estudio.

## 4. Transaccion distribuida (4:15 - 5:30)

```powershell
# Terminal 1: secciones 4 y 5 de la demo
.\scripts\demo.ps1
```

Pausar o senalar la seccion 4 y la 5b.

> Se registra un estudio con CALL sp_registrar_estudio. El procedimiento
> inserta la orden, el estudio, el diagnostico y un evento en el outbox, hace
> COMMIT y solo despues escribe el documento en MongoDB. Aqui se ve el nuevo
> id, el documento en MongoDB con su resultado, el outbox en SINCRONIZADO y la
> bitacora. Luego sp_exportar_indicadores exporta los indicadores mensuales
> agregados desde PostgreSQL hacia MongoDB.

Si sobra tiempo (opcional, maximo 30 s): `docker stop medical_mongo`, registrar
un estudio, mostrar el outbox `PENDIENTE`, `docker start medical_mongo` y
`SELECT operativo.sp_reintentar_outbox();`.

## 5. Roles y seguridad (5:30 - 6:30)

**En pantalla:** `docker/postgres/conf/pg_hba.conf` y salida de `verify.ps1`
(seccion de autenticacion).

> Hay dos niveles de perfiles. Internos: usr_fdw_pg_mssql y usr_fdw_pg_mongo,
> que solo pueden entrar desde la red Docker, con permisos minimos. Externos:
> usr_api_web y usr_api_mobile, que solo leen sus vistas, con timeouts y
> search_path propios. Todos usan SCRAM. Si la API web intenta leer una tabla
> interna o conectarse a otra base, se rechaza.

## 6. Cierre (6:30 - 7:00)

```powershell
.\scripts\verify.ps1
```

> La verificacion confirma los conteos en los tres motores, las consultas
> remotas y los permisos. Con esto se demuestra la segmentacion horizontal y
> vertical, la integracion por FDW, las transacciones distribuidas y la
> seguridad por roles.

## Plan de contingencia

| Problema | Que hacer |
|----------|-----------|
| Un contenedor no esta `healthy` | Cortar la grabacion, esperar y retomar |
| SQL Server aun inicia | Repetir `bootstrap.ps1` (es idempotente) |
| MongoDB no responde | `docker restart medical_mongo` y `SELECT operativo.sp_reintentar_outbox();` |
| Se alteraron los conteos | `.\scripts\bootstrap.ps1` y luego `verify.ps1` |
| El video pasa de 8 minutos | Quitar la prueba opcional del bloque 4 y acortar la narracion del bloque 1 |
