# Arquitectura del sistema

## 1. Objetivo

Construir un sistema distribuido para la gestion de estudios medicos que
combine tres motores con responsabilidades distintas, sin perder de vista los
principios de fragmentacion, transparencia de acceso y seguridad.

El sistema cubre:

- Registro de pacientes, citas, ordenes, estudios y diagnosticos.
- Lectura de facturacion externa administrada por aseguradoras e instituciones.
- Analitica de estudios, ingresos, productividad medica y diagnosticos frecuentes.
- Exposicion controlada de datos a una API web y a una API movil.

## 2. Motores y responsabilidades

### PostgreSQL 16: OLTP y capa de integracion

- Fuente de verdad del expediente operativo local.
- Segmentacion horizontal: cada region tiene su propio esquema.
- Catalogo compartido de sucursales, tipos de estudio, medicos y aseguradoras.
- Capa de integracion: `tds_fdw` y `mongo_fdw`.
- Capa de exposicion: vistas `api_web` y `api_mobile`.
- Auditoria: outbox de eventos y bitacora de sincronizacion.

### SQL Server 2022: integracion externa

- Fuente de verdad de facturacion, convenios e instituciones.
- Segmentacion vertical: solo se modelan los atributos necesarios para la
  interoperabilidad; no replica datos clinicos.
- Expone procedimientos almacenados para registrar facturas y recalcular
  resumenes.
- PostgreSQL lo consume en modo lectura mediante `tds_fdw`.

### MongoDB 7.0: analitica

- Almacena documentos desnormalizados por estudio.
- Permite campos anidados como `resultado.hallazgo`, `resultado.medida` y
  `resultado.conclusion`.
- Soporta agregaciones por medico, tipo de estudio, sucursal, periodo y
  diagnostico.
- PostgreSQL lo consume y escribe mediante `mongo_fdw`.

## 3. Topologia de despliegue

```text
Host Windows
|
+-- Docker Desktop (WSL 2)
    |
    +-- medical_net (bridge)
        |
        +-- medical_pg      postgres:16 + tds_fdw + mongo_fdw   :55432 -> 5432
        +-- medical_mssql   SQL Server 2022 Developer            :51433 -> 1433
        +-- medical_mongo   MongoDB 7.0                          :52717 -> 27017
```

Los contenedores se resuelven por nombre dentro de `medical_net`:

- `mssql` para `tds_fdw`.
- `mongo` para `mongo_fdw`.
- `medical_pg` para los scripts de administracion.

## 4. Fragmentacion

### 4.1 Horizontal

La tabla de pacientes y todo el proceso operativo se reparten por region:

| Esquema | Sucursal | Rango de pacientes | Rango de estudios | Rango de citas | Rango de ordenes |
|---------|----------|--------------------|-------------------|----------------|------------------|
| `san_jose` | San Jose | 10001-19999 | 11001-11999 | 1001-1999 | 15001-15999 |
| `alajuela` | Alajuela | 20001-29999 | 21001-21999 | 2001-2999 | 25001-25999 |
| `cartago` | Cartago | 30001-39999 | 31001-31999 | 3001-3999 | 35001-35999 |

Cada esquema contiene: `pacientes`, `citas`, `ordenes`, `estudios` y
`diagnosticos`. Las vistas `operativo.v_pacientes_todos` y
`operativo.v_estudios_todos` reconstruyen la vision global con `UNION ALL`.

La unicidad global se garantiza con rangos de identificadores disjuntos y
restricciones `CHECK (id_sucursal = <region>)` en cada tabla de pacientes.

### 4.2 Vertical

SQL Server solo recibe las columnas necesarias para facturacion e
interoperabilidad:

- `instituciones`
- `convenios`
- `paciente_integracion`
- `facturas_externas`
- `resumen_facturacion`

No almacena resultados clinicos ni datos de contacto. MongoDB, por su parte,
solo recibe la proyeccion analitica del estudio.

## 5. Flujo de datos

### 5.1 Registro de un estudio

```text
Cliente
  |
  v
operativo.sp_registrar_estudio(region, paciente, tipo, medico, resultado, ...)
  |
  +--> INSERT en <region>.ordenes
  +--> INSERT en <region>.estudios
  +--> INSERT en <region>.diagnosticos (opcional)
  +--> INSERT en auditoria.outbox_eventos (PENDIENTE)
  |
  v
operativo.fn_sincronizar_estudio()
  |
  +--> UPDATE o INSERT en reportes_ext.resultados_estudios (mongo_fdw)
  +--> UPDATE auditoria.outbox_eventos (SINCRONIZADO)
  +--> INSERT auditoria.bitacora_sincronizacion
```

El procedimiento devuelve el `id_estudio` generado. Si la escritura remota
falla, el estudio local queda confirmado y el evento permanece `PENDIENTE` para
reintento.

### 5.2 Consulta distribuida

```text
api_web.v_paciente_facturacion
  = operativo.v_pacientes_todos (PostgreSQL)
  + catalogo.sucursal (PostgreSQL)
  + integracion_ext.paciente_integracion (tds_fdw -> SQL Server)
  + integracion_ext.resumen_facturacion (tds_fdw -> SQL Server)

api_web.v_estudios_analitica
  = operativo.v_estudios_todos (PostgreSQL)
  + reportes_ext.resultados_estudios (mongo_fdw -> MongoDB)
```

## 6. Componentes de integracion

### tds_fdw

- Solo lectura.
- Sin pushdown de JOIN; el join se resuelve en PostgreSQL.
- `match_column_names 'true'` para mapear por nombre de columna.
- `tds_version '7.4'` para SQL Server 2022.
- Mensajes del servidor expuestos como `NOTICE` (`msg_handler 'notice'`).

### mongo_fdw

- Lectura y escritura.
- Requiere que la primera columna de la tabla foranea sea `_id name`.
- El `authentication_database` es `reportes_medicos`, porque el usuario FDW se
  crea en esa base.
- Un `UPDATE` se traduce en `$set`, por lo que los campos anidados que no se
  actualizan se conservan.

## 7. Exposicion a aplicaciones

| Esquema | Rol | Objetos permitidos |
|---------|-----|-------------------|
| `api_web` | `usr_api_web` | `v_paciente_facturacion`, `v_estudios_analitica`, `v_facturacion_institucion` |
| `api_mobile` | `usr_api_mobile` | `v_paciente_resumen`, `v_ultimos_estudios` |

Los roles de API no tienen acceso directo a `operativo`, `catalogo`,
`integracion_ext` ni `reportes_ext`. Consumen exclusivamente las vistas y los
privilegios se otorgan con `GRANT SELECT` sobre cada esquema.

## 8. Disponibilidad y consistencia

- PostgreSQL, SQL Server y MongoDB tienen healthchecks y reinicio automatico.
- La sincronizacion hacia MongoDB es **at-least-once** y idempotente por
  `id_estudio`.
- No hay two-phase commit. La consistencia entre el OLTP y MongoDB es eventual
  y se controla con el outbox.
- La facturacion externa es consistente por definicion: PostgreSQL no la
  modifica, solo la lee.

## 9. Decisiones de diseno

1. **Un solo contenedor PostgreSQL con tres esquemas** en lugar de tres
   instancias: simplifica el entorno academico y conserva la semantica de
   fragmentacion horizontal.
2. **SQL Server como sistema externo de solo lectura** para PostgreSQL: refleja
   el caso real en el que la aseguradora es duena de la facturacion.
3. **MongoDB como proyeccion analitica**: evita joins costosos en consultas de
   agregacion y demuestra el uso de documentos con campos anidados.
4. **Outbox en PostgreSQL**: permite reintentar la sincronizacion sin perder
   eventos ni duplicar documentos.
5. **Roles separados por consumidor**: aplica el principio de minimo privilegio
   y permite politicas de sesion distintas (`statement_timeout`,
   `search_path`).
