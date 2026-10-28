# Configuracion de Foreign Data Wrappers

## 1. Imagen de PostgreSQL

La imagen `medical/pg16-fdw:latest` se construye desde
`docker/postgres/Dockerfile` sobre `postgres:16-bookworm` e incluye:

| Componente | Version / origen | Proposito |
|------------|------------------|-----------|
| `freetds-bin` y `freetds-dev` | Debian bookworm | Driver TDS para SQL Server |
| `tds_fdw` | GitHub `tds-fdw/tds_fdw` | FDW hacia SQL Server |
| `mongo-c-driver` | 1.30.2 | Dependencia de `mongo_fdw` |
| `json-c` | 0.18-20240915 | Dependencia de `mongo_fdw` |
| `mongo_fdw` | GitHub `EnterpriseDB/mongo_fdw` | FDW hacia MongoDB |

El build usa paralelismo limitado (`-j2` o `-j4`) para no agotar la memoria de
WSL 2. Si el daemon se cae durante el build, revisar la seccion de memoria en
el README.

## 2. tds_fdw: PostgreSQL hacia SQL Server

### 2.1 Servidor

```sql
CREATE SERVER mssql_integracion
    FOREIGN DATA WRAPPER tds_fdw
    OPTIONS (
        servername 'mssql',
        port '1433',
        database :'mssql_db',
        tds_version '7.4',
        msg_handler 'notice'
    );
```

Notas:

- `servername` es el nombre del servicio en la red Docker (`mssql`), no
  `localhost`.
- `tds_version '7.4'` es compatible con SQL Server 2022.
- **No** se debe especificar `sqlserver_ansi_mode`: en esta version de
  `tds_fdw` es una opcion redundante y produce
  `ERROR: Redundant option: sqlserver_ansi_mode (true)`.
- `msg_handler 'notice'` muestra los mensajes del servidor como `NOTICE`. Para
  silenciarlos se puede usar `msg_handler 'blackhole'`, a costa de perder
  diagnostico.

### 2.2 User mapping

```sql
CREATE USER MAPPING FOR postgres
    SERVER mssql_integracion
    OPTIONS (username :'fdw_mssql_user', password :'fdw_mssql_password');

CREATE USER MAPPING FOR :"fdw_mssql_user"
    SERVER mssql_integracion
    OPTIONS (username :'fdw_mssql_user', password :'fdw_mssql_password');

CREATE USER MAPPING FOR :"api_web_user"
    SERVER mssql_integracion
    OPTIONS (username :'fdw_mssql_user', password :'fdw_mssql_password');

CREATE USER MAPPING FOR :"api_mobile_user"
    SERVER mssql_integracion
    OPTIONS (username :'fdw_mssql_user', password :'fdw_mssql_password');
```

`tds_fdw` resuelve el mapping con el usuario de la sesion, incluso cuando el
acceso ocurre a traves de una vista. Por eso los roles de las APIs tambien
necesitan un mapping; de lo contrario se obtiene:

```text
ERROR: user mapping not found for "usr_api_web"
```

Los roles de API solo reciben `USAGE` sobre el servidor foraneo. No tienen
`SELECT` directo sobre `integracion_ext`, asi que solo pueden consumir las
vistas autorizadas.

### 2.3 Tablas foraneas

```sql
CREATE FOREIGN TABLE integracion_ext.paciente_integracion (
    id_paciente        integer,
    id_aseguradora     integer,
    codigo_externo     varchar(40),
    estado_facturacion varchar(20),
    actualizado_en     timestamp
)
SERVER mssql_integracion
OPTIONS (
    schema_name 'integracion',
    table_name 'paciente_integracion',
    match_column_names 'true'
);
```

`match_column_names 'true'` hace que `tds_fdw` mapee por nombre de columna en
lugar de por posicion, lo que tolera cambios de orden en SQL Server.

Tablas expuestas:

- `integracion_ext.instituciones`
- `integracion_ext.convenios`
- `integracion_ext.paciente_integracion`
- `integracion_ext.facturas_externas`
- `integracion_ext.resumen_facturacion`

### 2.4 Prueba

```sql
SELECT count(*) FROM integracion_ext.paciente_integracion;
SELECT * FROM integracion_ext.facturas_externas LIMIT 5;
```

Tambien se puede validar desde el host:

```powershell
docker exec -it medical_pg psql -U postgres -d medical_oltp `
  -c "SELECT count(*) FROM integracion_ext.paciente_integracion;"
```

## 3. mongo_fdw: PostgreSQL hacia MongoDB

### 3.1 Usuario en MongoDB

El usuario se crea en la base `reportes_medicos`, no en `admin`:

```javascript
const target = db.getSiblingDB(targetDbName);

target.createUser({
  user: fdwUser,
  pwd: fdwPassword,
  roles: [{ role: 'readWrite', db: targetDbName }]
});
```

Por eso el servidor FDW declara:

```sql
CREATE SERVER mongo_reportes
    FOREIGN DATA WRAPPER mongo_fdw
    OPTIONS (
        address 'mongo',
        port '27017',
        authentication_database 'reportes_medicos'
    );
```

Si se usa `admin` por error, la autenticacion falla aunque las credenciales
sean correctas.

### 3.2 Tabla foranea

```sql
CREATE FOREIGN TABLE reportes_ext.resultados_estudios (
    _id          name,
    id_estudio   integer,
    id_paciente  integer,
    paciente     text,
    tipo         text,
    id_tipo      integer,
    medico       text,
    id_medico    integer,
    sucursal     text,
    id_sucursal  integer,
    fecha        timestamptz,
    estado       text,
    diagnostico  text,
    ingresos     numeric(12,2)
)
SERVER mongo_reportes
OPTIONS (database 'reportes_medicos', collection 'resultados_estudios');
```

Reglas importantes:

1. La primera columna debe llamarse `_id` y ser de tipo `name`.
2. Las columnas deben coincidir con los campos del documento.
3. Los documentos pueden tener campos adicionales; los no declarados se
   ignoran en la lectura.
4. En esta version de `mongo_fdw` los subdocumentos no se proyectan como
   columnas `jsonb`/`text`: si se declara `resultado`, la columna se lee vacia.
   Por eso el subdocumento `resultado` se consulta directamente en MongoDB con
   `mongosh`, y el FDW solo expone los campos planos.
5. El subdocumento `resultado` igual se conserva al actualizar otros campos,
   porque `mongo_fdw` usa `$set` y no reemplaza el documento completo.

### 3.3 Escrituras

`mongo_fdw` soporta `INSERT`, `UPDATE` y `DELETE`.

La sincronizacion se implementa en `operativo.fn_sincronizar_estudio`:

```sql
SELECT _id INTO v_mongo_id
FROM reportes_ext.resultados_estudios
WHERE id_estudio = p_id_estudio
LIMIT 1;

IF v_mongo_id IS NOT NULL THEN
    UPDATE reportes_ext.resultados_estudios
       SET estado = v_estudio.estado,
           diagnostico = v_estudio.diagnostico,
           ingresos = COALESCE(v_ingresos, 0)
     WHERE _id = v_mongo_id;
ELSE
    INSERT INTO reportes_ext.resultados_estudios (...) VALUES (...);
END IF;
```

`mongo_fdw` traduce el `UPDATE` a un `$set`. Esto significa que:

- Solo se modifican los campos enviados.
- Los campos anidados no enviados, como `resultado.hallazgo`, se conservan.
- No se reemplaza el documento completo.

Limitacion: los documentos nuevos creados por `INSERT` a traves del FDW solo
incluyen los campos planos declarados. El subdocumento `resultado` no se
escribe por esta via porque `mongo_fdw` no proyecta objetos anidados como
columnas. El resultado detallado de un estudio nuevo queda en
`<region>.estudios.resultado` (jsonb) y en el `payload` del outbox; los
documentos base ya cargados si incluyen `resultado`, y ese subdocumento se
conserva cuando se actualiza el resto de campos.

### 3.4 Prueba

```sql
SELECT count(*) FROM reportes_ext.resultados_estudios;
SELECT id_estudio, paciente, diagnostico, ingresos FROM reportes_ext.resultados_estudios LIMIT 3;
```

## 4. Comparacion de capacidades

| Capacidad | tds_fdw | mongo_fdw |
|-----------|---------|-----------|
| SELECT | Si | Si |
| INSERT | No | Si |
| UPDATE | No | Si |
| DELETE | No | Si |
| Pushdown de JOIN | No | Limitado |
| Transacciones remotas | No | No |
| Two-phase commit | No | No |

## 5. Seguridad de credenciales

- Las contrasenas se pasan a los scripts con variables de `psql`
  (`-v clave=valor`) y no se escriben en los archivos SQL.
- `.env` esta en `.gitignore`.
- Los mappings no son legibles por los roles de API; solo el propietario del
  servidor y superusuarios pueden ver las opciones.
- En un entorno productivo se recomienda un gestor de secretos y rotacion de
  contrasenas.

## 6. Diagnostico

### Ver servidores y mappings

```sql
SELECT srvname, srvoptions FROM pg_foreign_server;
SELECT umuser::regrole, srvname FROM pg_user_mappings;
```

### Ver extensiones instaladas

```sql
SELECT extname, extversion FROM pg_extension
WHERE extname IN ('tds_fdw', 'mongo_fdw');
```

### Errores frecuentes

| Error | Causa probable | Solucion |
|-------|----------------|----------|
| `user mapping not found` | Falta mapping para el usuario de la sesion | Crear mapping para el rol |
| `Redundant option: sqlserver_ansi_mode` | Opcion obsoleta en tds_fdw | Eliminarla del `CREATE SERVER` |
| `authentication failed` en MongoDB | `authentication_database` incorrecta | Usar `reportes_medicos` |
| `column "_id" does not exist` | Primera columna distinta de `_id name` | Reordenar la tabla foranea |
| Timeout al leer SQL Server | Contenedor aun iniciando | Esperar healthcheck y reintentar |
