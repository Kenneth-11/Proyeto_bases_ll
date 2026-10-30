# Sistema Distribuido de Gestion de Estudios Medicos

Proyecto del curso **Bases de Datos II**. Implementa un sistema de gestion de
estudios medicos con tres motores de bases de datos coordinados:

| Motor | Rol | Base de datos | Esquemas principales |
|-------|-----|---------------|----------------------|
| PostgreSQL 16 | OLTP con segmentacion horizontal por region | `medical_oltp` | `san_jose`, `alajuela`, `cartago`, `catalogo`, `operativo`, `auditoria`, `api_web`, `api_mobile` |
| SQL Server 2022 | Integracion con aseguradoras e instituciones (segmentacion vertical) | `MedicalIntegration` | `integracion` |
| MongoDB 7.0 | Analitica de estudios y agregaciones | `reportes_medicos` | colecciones `resultados_estudios`, `medicos`, `indicadores_mensuales`, `productividad_medicos` |

La integracion se realiza con **Foreign Data Wrappers** desde PostgreSQL:

- `tds_fdw` para leer SQL Server.
- `mongo_fdw` para leer y escribir en MongoDB.

## Autores

- Mauro Alberto Zamora Arce
- Kenneth Mauricio Fernandez Gomez
- Sebastian Esquivel Gamboa

Repositorio: <https://github.com/Kenneth-11/Proyeto_bases_ll>

## Arquitectura

```text
                         +---------------------------+
                         |   PostgreSQL 16 (OLTP)    |
                         |   medical_oltp            |
                         |                           |
   API web  -----------> | api_web                   |
   API movil ----------> | api_mobile                |
                         |                           |
                         | san_jose | alajuela | ... |  <- sharding horizontal
                         | catalogo | operativo | ... |
                         +-----------+---------------+
                                     |
                    +----------------+-----------------+
                    |                                  |
             tds_fdw (solo lectura)            mongo_fdw (lectura/escritura)
                    |                                  |
          +---------v----------+            +----------v-----------+
          | SQL Server 2022    |            | MongoDB 7.0          |
          | MedicalIntegration |            | reportes_medicos     |
          | integracion.*      |            | resultados_estudios  |
          +--------------------+            +----------------------+
```

Flujo principal:

1. La API escribe en el esquema regional correspondiente de PostgreSQL.
2. Un procedimiento local registra el estudio y un evento en el outbox.
3. `mongo_fdw` sincroniza el documento analitico en MongoDB.
4. Las vistas `api_web` y `api_mobile` combinan datos locales con SQL Server
   y MongoDB para responder consultas distribuidas.
5. SQL Server es la fuente de verdad de la facturacion externa; PostgreSQL solo
   la lee mediante `tds_fdw`.

## Requisitos

- Windows 10/11 con Docker Desktop (WSL 2).
- Docker Compose v2.
- PowerShell 5.1 o superior.
- `sqlcmd` en el host (mssql-tools18) para ejecutar el bootstrap de SQL Server.
- Opcional: `psql` en el host para la prueba de autenticacion externa de
  `verify.ps1`. Si no esta, esa seccion se omite.
- Al menos 8 GB de RAM en el host. Con Docker Desktop se recomienda asignar
  5-6 GB a WSL 2 (ver Solucion de problemas).

## Inicio rapido

```powershell
# 1. Crear el archivo de entorno
Copy-Item .env.example .env

# 2. Construir la imagen de PostgreSQL y levantar el stack
.\scripts\up.ps1

# 3. Crear esquemas, roles, FDW, datos y procedimientos
.\scripts\bootstrap.ps1

# 4. Validar la integracion de punta a punta
.\scripts\verify.ps1

# 5. Ejecutar la demostracion interactiva
.\scripts\demo.ps1
```

Para detener el stack conservando los datos:

```powershell
.\scripts\down.ps1
```

Para eliminar tambien los volumenes:

```powershell
.\scripts\down.ps1 -Volumes
```

## Puertos y credenciales

Los valores reales viven en `.env` (ignorado por Git). `.env.example` contiene
los valores por defecto del entorno academico.

| Servicio | Puerto host | Contenedor | Usuario principal |
|----------|-------------|------------|-------------------|
| PostgreSQL | 55432 | `medical_pg` | `postgres` |
| SQL Server | 51433 | `medical_mssql` | `sa` |
| MongoDB | 37017 | `medical_mongo` | `root` |

Usuarios de integracion y aplicacion:

| Usuario | Motor | Proposito |
|---------|-------|-----------|
| `usr_fdw_pg_mssql` | PostgreSQL / SQL Server | Lectura de SQL Server por FDW |
| `usr_fdw_pg_mongo` | PostgreSQL / MongoDB | Lectura y escritura en MongoDB por FDW |
| `usr_api_web` | PostgreSQL | Consumo de vistas `api_web` |
| `usr_api_mobile` | PostgreSQL | Consumo de vistas `api_mobile` |

## Estructura del repositorio

```text
.
|-- docker-compose.yml
|-- .env.example
|-- docker/postgres/          Imagen de PostgreSQL con tds_fdw y mongo_fdw
|-- sql/postgres/             00 a 09: extensiones, modelo, roles, FDW, vistas, procedimientos
|-- sql/sqlserver/            00 a 04: base, esquema, procedimientos, login, datos
|-- mongodb/                  Usuarios, datos y agregaciones
|-- scripts/                  up, bootstrap, verify, demo y utilidades
|-- docs/                     Documentacion tecnica y guion del video
|-- tests/                    Consultas y resultados esperados
```

## Datos de demostracion

- 3 sucursales: San Jose, Alajuela, Cartago.
- 9 medicos y 6 tipos de estudio.
- 15 pacientes (5 por region) con rangos de identificacion `10xxx`, `20xxx`,
  `30xxx`.
- 15 estudios y 15 documentos analiticos en MongoDB.
- 16 facturas externas en SQL Server, distribuidas entre 3 instituciones.
- 3 aseguradoras: INS, CCSS y MAPFRE.

`demo.ps1` crea un estudio adicional, muestra la sincronizacion al outbox y a
MongoDB, ejecuta las agregaciones y finalmente elimina los datos de la
demostracion para dejar el dataset base intacto.

## Documentacion

- [Arquitectura](docs/01_arquitectura.md)
- [Modelo de datos](docs/02_modelo_datos.md)
- [Configuracion de FDW](docs/03_fdw_configuracion.md)
- [Seguridad y roles](docs/04_seguridad_roles.md)
- [Consultas de integracion](docs/05_consultas_integracion.md)
- [Transacciones distribuidas](docs/06_transacciones_distribuidas.md)
- [Guion del video](docs/07_guion_video.md)
- [Checklist de entrega](docs/08_checklist_entrega.md)
- [Referencias bibliograficas](docs/09_referencias.md)

Configuracion del servidor PostgreSQL versionada en el repo:
`docker/postgres/conf/postgresql.conf`, `docker/postgres/conf/pg_hba.conf` y
`docker/postgres/conf/freetds.conf`.

## Limitaciones conocidas

- `tds_fdw` es de solo lectura: no permite INSERT/UPDATE/DELETE ni pushdown de
  JOIN. Las escrituras a SQL Server deben realizarse con T-SQL o con los
  procedimientos almacenados del sistema externo.
- No existe two-phase commit entre PostgreSQL y MongoDB. La consistencia se
  maneja con el patron **outbox** y sincronizacion idempotente.
- `mongo_fdw` resuelve el user mapping con el usuario de la sesion. Por eso se
  crean mappings tambien para los roles de las APIs que consumen vistas
  federadas.
- `mongo_fdw` no escribe subdocumentos. Los estudios nuevos viajan con el
  resultado como texto (`resultado_json`) y `mongodb/03_aggregations.js` lo
  convierte en el subdocumento `resultado`.
- `sp_registrar_estudio` es un `PROCEDURE` que hace `COMMIT` antes de escribir
  en MongoDB; debe invocarse con `CALL` fuera de un `BEGIN` explicito.
- `pg_hba.conf` tiene una regla por perfil: FDW solo desde la red Docker, APIs
  solo hacia `medical_oltp`, `trust` unicamente para `postgres` por socket
  local, y `reject` para todo lo demas. Si se cambia `PG_DB`, actualizar
  tambien `pg_hba.conf`.
- Si ya tenia el stack levantado con la version anterior, recrear el
  contenedor de PostgreSQL para que tome `postgresql.conf`:
  `docker compose up -d --force-recreate pg` y luego `.\scripts\bootstrap.ps1`.

## Solucion de problemas

### Docker Desktop se cierra o el build muere por falta de memoria

El build de las extensiones y los tres motores pueden superar la memoria por
defecto de WSL 2. Crear o editar `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
memory=5GB
swap=2GB
processors=8
```

Luego reiniciar WSL y Docker Desktop:

```powershell
wsl --shutdown
Start-Process "C:\Users\<usuario>\AppData\Local\Programs\DockerDesktop\Docker Desktop.exe"
```

### El bootstrap falla con "Named Pipes Provider: Could not open a connection"

Verificar que `medical_mssql` este `healthy`:

```powershell
docker ps --format "{{.Names}} {{.Status}}"
```

Si aun esta iniciando, esperar y repetir `.\scripts\bootstrap.ps1`. El script
es idempotente y puede ejecutarse varias veces.

### "ports are not available ... bind: An attempt was made to access a socket in a way forbidden"

Windows (Hyper-V/WSL) reserva rangos de puertos dinamicos. Ver cuales:

```powershell
netsh int ipv4 show excludedportrange protocol=tcp
```

Si `PG_PORT`, `MSSQL_PORT` o `MONGO_PORT` cae en uno de esos rangos, cambiarlo
en `.env` (por eso MongoDB usa `37017` y no `52717`).

### `psql` en el host no autentica

La prueba externa de `verify.ps1` usa el puerto `PG_PORT` (55432) y
`scram-sha-256`. Confirmar que el puerto no este ocupado y que el rol exista:

```powershell
docker exec -it medical_pg psql -U postgres -d medical_oltp -c "\du"
```

### Ver los logs de un motor

```powershell
docker logs --tail 100 medical_pg
docker logs --tail 100 medical_mssql
docker logs --tail 100 medical_mongo
```
