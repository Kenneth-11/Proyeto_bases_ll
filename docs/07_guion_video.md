# Guion del video demostrativo

Duracion objetivo: **10 a 12 minutos**.

## Preparacion previa (fuera de camara)

1. Docker Desktop iniciado y con al menos 5 GB asignados a WSL 2.
2. Stack levantado y bootstrap ejecutado:

```powershell
docker ps --format "{{.Names}} {{.Status}}"
.\scripts\verify.ps1
```

3. Cerrar notificaciones y ventanas que no se usaran.
4. Tener abiertos:
   - Una terminal en la raiz del proyecto.
   - Un editor con `docker-compose.yml`.
   - Un editor con `sql/postgres/08_procedures.sql`.
   - Un navegador o visor con `docs/01_arquitectura.md`.

Si se quiere iniciar desde cero en camara, ejecutar antes de grabar:

```powershell
.\scripts\down.ps1 -Volumes
```

y dejar el arranque para el video.

## 0:00 - 0:40 | Presentacion

**Narracion:**

> Este proyecto implementa un sistema distribuido de gestion de estudios
> medicos usando PostgreSQL, SQL Server y MongoDB. PostgreSQL maneja el OLTP
> con fragmentacion horizontal por region; SQL Server concentra la facturacion
> externa con segmentacion vertical; y MongoDB almacena la proyeccion
> analitica. La integracion se hace con Foreign Data Wrappers.

**En pantalla:** `README.md` y el diagrama de arquitectura.

## 0:40 - 1:40 | Arquitectura

**En pantalla:** `docs/01_arquitectura.md`, seccion de topologia.

**Narracion:**

> Los tres motores corren en Docker sobre una red bridge. PostgreSQL expone el
> puerto 55432, SQL Server el 51433 y MongoDB el 52717. PostgreSQL tiene tres
> esquemas regionales: san_jose, alajuela y cartago. Cada region maneja sus
> propios pacientes, citas, ordenes y estudios. Las vistas operativas
> reconstruyen la vision global con UNION ALL.

Mostrar el diagrama y senalar:

- `tds_fdw` en modo lectura.
- `mongo_fdw` en lectura y escritura.
- Outbox en `auditoria`.

## 1:40 - 2:30 | Arranque del stack

```powershell
docker compose up -d
docker ps --format "{{.Names}} {{.Status}}"
```

**Narracion:**

> Los tres contenedores tienen healthchecks. PostgreSQL usa una imagen
> personalizada con tds_fdw y mongo_fdw compilados. SQL Server corre en
> edicion Developer con limite de memoria. MongoDB usa autenticacion y un
> usuario de solo lectura/escritura sobre reportes_medicos.

Esperar a ver los tres como `healthy`.

## 2:30 - 3:30 | Bootstrap

```powershell
.\scripts\bootstrap.ps1
```

**Narracion:**

> El bootstrap es idempotente. Primero crea la base de integracion en SQL
> Server, luego los usuarios y datos de MongoDB, y finalmente los esquemas,
> roles, FDW, vistas y procedimientos de PostgreSQL.

Mencionar el orden:

1. SQL Server: `00` a `04`.
2. MongoDB: usuarios y datos.
3. PostgreSQL: `00` a `09`.

## 3:30 - 4:30 | Validacion automatica

```powershell
.\scripts\verify.ps1
```

**Narracion:**

> La verificacion comprueba 15 pacientes locales, 15 pacientes en SQL Server,
> 16 facturas, 15 estudios en MongoDB, 15 filas en cada vista y cero eventos
> pendientes en el outbox. Tambien prueba la autenticacion SCRAM de los roles
> de API y confirma que no pueden leer las tablas internas.

Mostrar los `[ok]` y las dos consultas de ejemplo.

## 4:30 - 6:00 | Demostracion principal

```powershell
.\scripts\demo.ps1
```

**Narracion durante la seccion 1:**

> Esta es la fragmentacion horizontal: tres regiones, cinco pacientes cada una.

**Seccion 2:**

> Esta vista combina datos locales con facturacion que vive en SQL Server. El
> join lo hace PostgreSQL porque tds_fdw no empuja joins.

**Seccion 3:**

> Esta vista combina el estudio local con el documento analitico de MongoDB.
> El diagnostico y los ingresos vienen del FDW.

**Seccion 4:**

> Ahora se registra un estudio. El procedimiento escribe en la region, crea un
> evento en el outbox y sincroniza el documento a MongoDB. El resultado muestra
> el nuevo id, el estado del outbox y la bitacora.

**Seccion 5:**

> Las agregaciones de MongoDB calculan productividad por medico, indicadores
> mensuales, diagnosticos frecuentes y resumen global.

**Seccion 6 y 7:**

> Los roles de API solo tienen SELECT sobre sus vistas. No tienen acceso a las
> tablas base ni a las tablas foraneas.

**Seccion 8:**

> La demostracion elimina el estudio que creo para dejar el dataset base
> intacto.

## 6:00 - 7:00 | Modelo de datos

**En pantalla:** `docs/02_modelo_datos.md`.

**Narracion:**

> Los identificadores usan rangos por region: 10xxx para San Jose, 20xxx para
> Alajuela y 30xxx para Cartago. Eso evita colisiones sin coordinacion global.
> En SQL Server solo se guardan las columnas de facturacion. En MongoDB el
> resultado del estudio es un subdocumento con hallazgo, medida y conclusion.

Mostrar el ejemplo JSON del documento.

## 7:00 - 8:00 | FDW en detalle

**En pantalla:** `docs/03_fdw_configuracion.md`.

**Narracion:**

> tds_fdw se configura con tds_version 7.4 y match_column_names. Es de solo
> lectura: no permite INSERT, UPDATE ni DELETE. mongo_fdw si permite escritura
> y su UPDATE se traduce en $set, lo que conserva los campos anidados que no se
> actualizan. La primera columna de una tabla foranea de mongo_fdw debe ser
> _id de tipo name. El authentication_database es reportes_medicos porque el
> usuario se crea en esa base.

Si se quiere mostrar el error y la correccion, mencionar:

> Al principio aparecio el error "user mapping not found" porque tds_fdw usa el
> usuario de la sesion. Se corrigio creando mappings para los roles de API.

## 8:00 - 9:00 | Consistencia y outbox

**En pantalla:** `docs/06_transacciones_distribuidas.md` y
`sql/postgres/08_procedures.sql`.

**Narracion:**

> No usamos two-phase commit. La escritura local se confirma y la
> sincronizacion a MongoDB se maneja con outbox. Si MongoDB falla, el evento
> queda pendiente. El reintento es idempotente porque busca el documento por
> id_estudio: si existe hace UPDATE, si no existe hace INSERT.

Mostrar `fn_sincronizar_estudio` y `sp_reintentar_outbox`.

## 9:00 - 9:40 | Seguridad

**En pantalla:** `docs/04_seguridad_roles.md`.

**Narracion:**

> Las APIs usan roles separados con search_path y statement_timeout propios.
> La autenticacion de red usa SCRAM. SQL Server tiene un login de solo lectura
> para el FDW. MongoDB tiene un usuario readWrite limitado a reportes_medicos.
> Las contrasenas viven en .env, que esta fuera del repositorio.

## 9:40 - 10:30 | Cierre

**Narracion:**

> El proyecto demuestra fragmentacion horizontal y vertical, integracion
> heterogenea con FDW, exposicion controlada por vistas, seguridad por roles y
> consistencia eventual con outbox. La verificacion automatica y la demo son
> reproducibles con tres comandos.

Mostrar nuevamente:

```powershell
.\scripts\verify.ps1
```

y cerrar con el estado `Verificacion completada correctamente.`

## Plan de contingencia

| Problema | Que hacer en camara |
|----------|---------------------|
| Un contenedor no esta `healthy` | Mostrar `docker ps` y esperar; explicar el healthcheck |
| SQL Server aun inicia | Repetir `bootstrap.ps1`; es idempotente |
| Error de permisos en API | Mostrar el mensaje y explicar el minimo privilegio |
| MongoDB no responde | Reiniciar el contenedor y ejecutar `sp_reintentar_outbox()` |
| Se alteraron los conteos | Ejecutar `.\scripts\bootstrap.ps1` y luego `verify.ps1` |

## Comandos de respaldo

```powershell
# Estado
docker ps --format "{{.Names}} {{.Status}}"

# Logs
docker logs --tail 50 medical_pg
docker logs --tail 50 medical_mssql
docker logs --tail 50 medical_mongo

# Reinicio limpio
.\scripts\down.ps1 -Volumes
.\scripts\up.ps1
.\scripts\bootstrap.ps1
.\scripts\verify.ps1
```
