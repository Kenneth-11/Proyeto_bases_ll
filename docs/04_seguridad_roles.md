# Seguridad y roles

## 1. Principios aplicados

1. **Minimo privilegio**: cada rol accede solo a los objetos que necesita.
2. **Separacion de funciones**: administracion, integracion y aplicaciones usan
   roles distintos.
3. **Credenciales fuera del repositorio**: `.env` contiene las contrasenas y
   esta en `.gitignore`.
4. **Superficie minima**: las APIs no acceden a tablas base, solo a vistas.
5. **Defensa en profundidad**: reglas de red, autenticacion, privilegios y
   timeouts de sesion.

## 2. Roles de PostgreSQL

| Rol | Tipo | Acceso |
|-----|------|--------|
| `postgres` | Superusuario del contenedor | Administracion, bootstrap y pruebas |
| `usr_fdw_pg_mssql` | Login | Lectura de `integracion_ext` y uso de `catalogo`/`operativo` |
| `usr_fdw_pg_mongo` | Login | Lectura/escritura de `reportes_ext` y ejecucion de procedimientos de sincronizacion |
| `usr_api_web` | Login | `SELECT` sobre vistas de `api_web` |
| `usr_api_mobile` | Login | `SELECT` sobre vistas de `api_mobile` |

Todos los roles de aplicacion son `NOSUPERUSER NOCREATEDB NOCREATEROLE`.

### 2.1 Creacion sin secretos en el repositorio

```sql
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'api_web_user', :'api_web_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'api_web_user')
\gexec
```

Los valores llegan desde `bootstrap.ps1` con `-v`. El archivo SQL no contiene
contrasenas.

### 2.2 Politicas de sesion

| Rol | `search_path` | `statement_timeout` | `idle_in_transaction_session_timeout` |
|-----|---------------|---------------------|----------------------------------------|
| `usr_api_web` | `api_web, catalogo` | 30 s | 60 s |
| `usr_api_mobile` | `api_mobile` | 15 s | 30 s |
| `usr_fdw_pg_mssql` | `integracion_ext` | predeterminado | predeterminado |
| `usr_fdw_pg_mongo` | `reportes_ext` | predeterminado | predeterminado |

Esto evita que una consulta mal escrita de una API bloquee recursos y limita
transacciones inactivas.

## 3. Matriz de privilegios

| Objeto | `usr_fdw_pg_mssql` | `usr_fdw_pg_mongo` | `usr_api_web` | `usr_api_mobile` |
|--------|--------------------|--------------------|---------------|------------------|
| `catalogo.*` | USAGE de esquema | USAGE de esquema | No | No |
| `operativo.*` | USAGE de esquema | USAGE de esquema + EXECUTE de funciones de sincronizacion/exportacion (`SECURITY DEFINER`) | No | No |
| `integracion_ext.*` | USAGE + SELECT | No | No | No |
| `reportes_ext.*` | No | USAGE + SELECT/INSERT/UPDATE/DELETE | No | No |
| `api_web.*` | No | No | USAGE + SELECT | No |
| `api_mobile.*` | No | No | No | USAGE + SELECT |
| Servidor `mssql_integracion` | USAGE | No | USAGE (mapping propio) | USAGE (mapping propio) |
| Servidor `mongo_reportes` | No | USAGE | USAGE (mapping propio) | USAGE (mapping propio) |
| `auditoria.*` | No | No | No | No |

Los roles de API tienen mapping hacia ambos servidores porque las vistas
federadas se ejecutan con el usuario de la sesion. Aun asi, no pueden leer las
tablas foraneas directamente: no tienen `SELECT` sobre `integracion_ext` ni
`reportes_ext`.

### 3.1 Funciones SECURITY DEFINER

`fn_sincronizar_estudio`, `sp_reintentar_outbox`, `sp_exportar_todos_estudios`
y `sp_exportar_indicadores` son `SECURITY DEFINER` con
`SET search_path = pg_catalog, pg_temp`. Asi `usr_fdw_pg_mongo` puede
sincronizar y exportar hacia MongoDB sin recibir permisos sobre los esquemas
regionales. Se revoca `EXECUTE` a `PUBLIC` y se otorga solo a ese perfil.

`sp_registrar_estudio` es un `PROCEDURE` con `COMMIT` y PostgreSQL no permite
control de transacciones en procedimientos `SECURITY DEFINER`; por eso lo
ejecuta el rol administrador/operativo y no se otorga a perfiles de
integracion.

## 4. Autenticacion en PostgreSQL

`docker/postgres/conf/pg_hba.conf`:

```text
local   all            postgres                       trust
local   all            all                            reject
host    all            postgres          samenet      scram-sha-256
host    medical_oltp   usr_fdw_pg_mssql  samenet      scram-sha-256
host    medical_oltp   usr_fdw_pg_mongo  samenet      scram-sha-256
host    medical_oltp   usr_api_web       0.0.0.0/0    scram-sha-256
host    medical_oltp   usr_api_web       ::/0         scram-sha-256
host    medical_oltp   usr_api_mobile    0.0.0.0/0    scram-sha-256
host    medical_oltp   usr_api_mobile    ::/0         scram-sha-256
host    all            all               0.0.0.0/0    reject
host    all            all               ::/0         reject
```

- **Politica diferenciada por perfil**: cada rol tiene su propia regla de base
  y origen. Los perfiles internos (FDW) solo entran desde la red Docker
  (`samenet`); los perfiles externos (APIs) pueden entrar desde fuera, pero
  solo a `medical_oltp`.
- `trust` aplica unicamente a `postgres` por socket local dentro del
  contenedor (bootstrap). Cualquier otro rol por socket local se rechaza.
- Toda conexion TCP exige `scram-sha-256` (`password_encryption =
  scram-sha-256` en `postgresql.conf`).
- La ultima regla rechaza cualquier combinacion no listada.
- `log_connections = on` deja en la bitacora que perfil se conecto y desde
  donde.

Prueba de rechazo por `pg_hba.conf` (base no permitida):

```powershell
psql -h 127.0.0.1 -p 55432 -U usr_api_web -d postgres -c "SELECT 1;"
# FATAL: pg_hba.conf rejects connection for host "...", user "usr_api_web", database "postgres"
```

Prueba de autenticacion externa:

```powershell
$env:PGPASSWORD = "ApiWeb_2026!"
psql -h 127.0.0.1 -p 55432 -U usr_api_web -d medical_oltp `
  -c "SELECT count(*) FROM api_web.v_paciente_facturacion;"
```

Prueba de denegacion:

```powershell
psql -h 127.0.0.1 -p 55432 -U usr_api_web -d medical_oltp `
  -c "SELECT count(*) FROM operativo.v_pacientes_todos;"
# ERROR: permission denied for schema operativo
```

## 5. SQL Server

- El login `usr_fdw_pg_mssql` se crea en `master` y se mapea a un usuario en
  `MedicalIntegration`.
- Se agrega a `db_datareader` y recibe `EXECUTE` sobre el esquema
  `integracion`.
- No es `sysadmin` ni `db_owner`.
- La contrasena se pasa con `sqlcmd -v` y cumple la politica de complejidad.

```sql
CREATE LOGIN [usr_fdw_pg_mssql]
    WITH PASSWORD = N'...',
         CHECK_POLICY = ON,
         CHECK_EXPIRATION = OFF,
         DEFAULT_DATABASE = [MedicalIntegration];

ALTER ROLE db_datareader ADD MEMBER [usr_fdw_pg_mssql];
GRANT EXECUTE ON SCHEMA::integracion TO [usr_fdw_pg_mssql];
```

`tds_fdw` usa este login en modo lectura. Las escrituras a facturacion se
realizan con los procedimientos `usp_RegistrarFactura` y
`usp_ActualizarEstadoFacturacion`, ejecutados por el sistema externo o por un
proceso autorizado de SQL Server.

## 6. MongoDB

- El usuario `usr_fdw_pg_mongo` se crea en la base `reportes_medicos`.
- Solo tiene el rol `readWrite` sobre esa base.
- No es usuario administrativo ni tiene acceso a otras bases.
- La autenticacion se realiza contra `authentication_database =
  'reportes_medicos'`.

```javascript
target.createUser({
  user: 'usr_fdw_pg_mongo',
  pwd: '...',
  roles: [{ role: 'readWrite', db: 'reportes_medicos' }]
});
```

## 7. Proteccion de Secretos

- `.env` esta ignorado por Git.
- `.env.example` solo contiene valores de ejemplo del entorno academico.
- No se imprimen contrasenas en los logs de los scripts.
- En produccion se recomienda:
  - Docker secrets o un vault.
  - Rotacion periodica.
  - Contrasenas distintas por ambiente.
  - TLS para PostgreSQL, SQL Server y MongoDB.

## 8. Limitaciones y mejoras

- El entorno academico no configura TLS entre contenedores. En produccion es
  obligatorio para proteger credenciales y datos clinicos.
- `trust` en el socket local es aceptable dentro del contenedor, pero no debe
  replicarse en un servidor compartido.
- Las vistas no implementan row-level security por region. Si se requiriera
  aislamiento por sucursal, se agregaria una politica RLS sobre las vistas o
  sobre las tablas base.
- No se implementa auditoria de accesos a nivel de fila; la bitacora actual
  cubre la sincronizacion, no las lecturas de las APIs.
