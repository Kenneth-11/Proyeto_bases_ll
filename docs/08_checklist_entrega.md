# Checklist de entrega

## 1. Datos de la entrega

| Campo | Valor |
|-------|-------|
| Curso | Bases de Datos II |
| Proyecto | Sistema distribuido de gestion de estudios medicos |
| Estudiantes | Mauro Alberto Zamora Arce<br>Kenneth Mauricio Fernandez Gomez<br>Sebastian Esquivel Gamboa |
| Fecha | 2026-10-28 |
| Repositorio | https://github.com/Kenneth-11/Proyeto_bases_ll.git |

## 2. Requisitos funcionales

- [x] Registro de pacientes por region.
- [x] Registro de citas, ordenes, estudios y diagnosticos.
- [x] Catalogo compartido de sucursales, tipos de estudio, medicos y aseguradoras.
- [x] Facturacion externa en SQL Server.
- [x] Proyeccion analitica en MongoDB.
- [x] Consultas que combinan PostgreSQL con SQL Server.
- [x] Consultas que combinan PostgreSQL con MongoDB.
- [x] Agregaciones analiticas en MongoDB.
- [x] Sincronizacion de estudios hacia MongoDB.
- [x] Reintento de sincronizacion con outbox.

## 3. Requisitos de diseno distribuido

- [x] Fragmentacion horizontal por region en PostgreSQL.
- [x] Fragmentacion vertical en SQL Server.
- [x] Identificadores unicos por rango regional.
- [x] Vistas que reconstruyen la vision global.
- [x] Integracion con dos motores heterogeneos mediante FDW.
- [x] Separacion entre datos operativos, de integracion y analiticos.
- [x] Documentacion de la topologia y del flujo de datos.

## 4. Requisitos de seguridad

- [x] Roles separados para FDW, API web y API movil.
- [x] Minimo privilegio sobre esquemas y tablas.
- [x] APIs sin acceso directo a tablas base.
- [x] Autenticacion SCRAM para conexiones TCP en PostgreSQL.
- [x] Login de solo lectura en SQL Server para el FDW.
- [x] Usuario MongoDB limitado a `readWrite` sobre `reportes_medicos`.
- [x] Secretos fuera del repositorio (`.env` ignorado).
- [x] Politicas de `search_path` y timeouts por rol.

## 5. Requisitos de consistencia

- [x] Transaccion local atomica para el registro del estudio.
- [x] Patron outbox para la sincronizacion analitica.
- [x] Reintento idempotente por `id_estudio`.
- [x] Bitacora de sincronizacion.
- [x] Documentacion de la ventana de inconsistencia.
- [x] Explicacion de por que no se usa 2PC.

## 6. Entregables

- [x] `README.md` con instrucciones reproducibles.
- [x] `docker-compose.yml` con los tres motores.
- [x] Imagen de PostgreSQL con `tds_fdw` y `mongo_fdw`.
- [x] Scripts SQL Server (`sql/sqlserver/00` a `04`).
- [x] Scripts MongoDB (`mongodb/01` a `03`).
- [x] Scripts PostgreSQL (`sql/postgres/00` a `09`).
- [x] Scripts PowerShell (`up`, `bootstrap`, `verify`, `demo`, `down`).
- [x] Documentacion `docs/01` a `08`.
- [x] Consultas y resultados esperados en `tests/`.
- [ ] Grabar el video de demostracion.
- [x] Completar nombres y fecha en este checklist.

## 7. Evidencia de validacion

Salida esperada de `.\scripts\verify.ps1`:

```text
== Conteos locales y remotos ==
[ok] Pacientes locales (3 regiones) = 15
[ok] Pacientes en SQL Server = 15
[ok] Facturas en SQL Server = 16
[ok] Estudios en MongoDB (FDW) = 15
[ok] Vista web paciente/facturacion = 15
[ok] Vista web estudios/analitica = 15
[ok] Outbox pendientes = 0

== Consulta distribuida de ejemplo (PostgreSQL + SQL Server) ==
... 8 filas ...

== Consulta distribuida de ejemplo (PostgreSQL + MongoDB) ==
... 8 filas ...

== MongoDB: documentos y campos anidados ==
[ok] Documentos en MongoDB = 15
[ok] Documentos con resultado anidado = 15

== Autenticacion y permisos externos (SCRAM) ==
[ok] API web autenticado = 15
[ok] API movil autenticado = 15
[ok] usr_api_web no puede leer operativo.v_pacientes_todos

Verificacion completada correctamente.
```

Salida esperada de `.\scripts\demo.ps1`:

- 3 regiones con 5 pacientes cada una.
- 10 filas en la vista de facturacion.
- 10 filas en la vista analitica.
- Nuevo estudio con id correlativo (por ejemplo `11006` en la primera
  ejecucion; aumenta si se repite la demo).
- Evento de outbox `SINCRONIZADO`.
- Documento equivalente en MongoDB.
- Agregaciones analiticas.
- Limpieza final del estudio de demostracion.

## 8. Mapeo con criterios de evaluacion

| Criterio | Donde se demuestra |
|----------|--------------------|
| Diseno distribuido | `docs/01_arquitectura.md`, `sql/postgres/02_regiones.sql` |
| Fragmentacion horizontal | Esquemas regionales y `UNION ALL` |
| Fragmentacion vertical | `sql/sqlserver/01_schema.sql` |
| Integracion heterogenea | `sql/postgres/05_fdw_mssql.sql`, `06_fdw_mongo.sql` |
| Consultas distribuidas | `sql/postgres/07_views_api.sql`, `verify.ps1` |
| Seguridad y roles | `sql/postgres/04_roles.sql`, `sql/sqlserver/03_logins.sql`, `mongodb/01_users.js` |
| Transacciones y consistencia | `sql/postgres/08_procedures.sql`, `docs/06_transacciones_distribuidas.md` |
| Reproducibilidad | `README.md`, `docker-compose.yml`, scripts PowerShell |
| Demostracion | `scripts/demo.ps1`, `docs/07_guion_video.md` |

## 9. Comandos de entrega

```powershell
# Desde cero
Copy-Item .env.example .env
.\scripts\up.ps1
.\scripts\bootstrap.ps1
.\scripts\verify.ps1
.\scripts\demo.ps1
```

## 10. Riesgos conocidos

| Riesgo | Mitigacion |
|--------|------------|
| Docker Desktop sin memoria suficiente | Ajustar `.wslconfig` a 5 GB y reiniciar WSL |
| SQL Server tarda en iniciar | Esperar el healthcheck y repetir bootstrap |
| `tds_fdw` sin mapping para un rol | Crear mapping para el usuario de la sesion |
| Conteos alterados por pruebas manuales | Reejecutar bootstrap y verificar |
| `psql` no instalado en el host | `verify.ps1` omite solo la prueba externa de SCRAM |

## 11. Archivos clave

```text
docker-compose.yml
docker/postgres/Dockerfile
sql/postgres/04_roles.sql
sql/postgres/05_fdw_mssql.sql
sql/postgres/06_fdw_mongo.sql
sql/postgres/07_views_api.sql
sql/postgres/08_procedures.sql
sql/sqlserver/02_procedures.sql
sql/sqlserver/03_logins.sql
mongodb/01_users.js
mongodb/03_aggregations.js
scripts/verify.ps1
scripts/demo.ps1
```
