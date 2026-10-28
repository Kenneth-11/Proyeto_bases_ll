# Consultas de integracion

Todas las consultas se pueden ejecutar desde el host con:

```powershell
docker exec -it medical_pg psql -U postgres -d medical_oltp
```

o con una consulta directa:

```powershell
docker exec -it medical_pg psql -U postgres -d medical_oltp -c "SELECT ...;"
```

## 1. Vision local por region

```sql
SELECT region, count(*) AS pacientes
FROM operativo.v_pacientes_todos
GROUP BY region
ORDER BY region;
```

Resultado esperado:

```text
  region  | pacientes
----------+-----------
 alajuela |         5
 cartago  |         5
 san_jose |         5
```

Esta consulta demuestra la reconstruccion de la fragmentacion horizontal con
`UNION ALL`.

## 2. Paciente + facturacion externa (PostgreSQL + SQL Server)

```sql
SELECT id_paciente,
       region,
       nombre || ' ' || apellidos AS paciente,
       estado_facturacion,
       total_facturado,
       facturas_pendientes
FROM api_web.v_paciente_facturacion
ORDER BY id_paciente
LIMIT 10;
```

Resultado esperado (primeras filas):

```text
 id_paciente |  region  |       paciente        | estado_facturacion | total_facturado | facturas_pendientes
-------------+----------+-----------------------+--------------------+-----------------+---------------------
       10001 | san_jose | Ana Rodriguez Mora    | PENDIENTE          |        70000.00 |                   1
       10002 | san_jose | Jose Perez Vargas     | PAGADA             |        15000.00 |                   0
       10003 | san_jose | Maria Gonzalez Rojas  | PAGADA             |        35000.00 |                   0
       10004 | san_jose | Carlos Jimenez Solano | PENDIENTE          |        30000.00 |                   1
       10005 | san_jose | Laura Mora Chaves     | PAGADA             |        15000.00 |                   0
```

La vista une:

- `operativo.v_pacientes_todos` (PostgreSQL).
- `catalogo.sucursal` (PostgreSQL).
- `integracion_ext.paciente_integracion` (SQL Server).
- `integracion_ext.resumen_facturacion` (SQL Server).

El join con SQL Server se resuelve en PostgreSQL porque `tds_fdw` no hace
pushdown de JOIN.

## 3. Estudios + resumen analitico (PostgreSQL + MongoDB)

```sql
SELECT region,
       id_estudio,
       paciente,
       tipo,
       diagnostico_analitico,
       ingresos
FROM api_web.v_estudios_analitica
ORDER BY id_estudio
LIMIT 10;
```

Resultado esperado (primeras filas):

```text
  region  | id_estudio |       paciente        |          tipo           | diagnostico_analitico | ingresos
----------+------------+-----------------------+-------------------------+-----------------------+----------
 san_jose |      11001 | Ana Rodriguez Mora    | Ultrasonido Abdominal   | R10.4                 | 45000.00
 san_jose |      11002 | Jose Perez Vargas     | Hemograma Completo      | Z00.0                 | 25000.00
 san_jose |      11003 | Maria Gonzalez Rojas  | Radiografia de Torax    | Z01.6                 | 35000.00
 san_jose |      11004 | Carlos Jimenez Solano | Perfil Lipidico         | E78.5                 | 30000.00
 san_jose |      11005 | Laura Mora Chaves     | Glucosa en Ayunas       | Z00.0                 | 15000.00
```

La vista combina `operativo.v_estudios_todos` con
`reportes_ext.resultados_estudios` mediante `mongo_fdw`.

## 4. Facturacion por institucion (solo SQL Server via FDW)

```sql
SELECT codigo_institucion,
       institucion,
       tipo,
       facturas,
       monto_total,
       monto_pendiente
FROM api_web.v_facturacion_institucion
ORDER BY monto_total DESC;
```

Esta consulta agrega datos que solo existen en SQL Server. PostgreSQL recibe
las filas por `tds_fdw` y aplica el `GROUP BY` localmente.

## 5. Consulta directa a tablas foraneas

```sql
SELECT id_paciente, estado_facturacion, total_facturado
FROM integracion_ext.paciente_integracion i
JOIN integracion_ext.resumen_facturacion r USING (id_paciente)
WHERE i.estado_facturacion = 'PENDIENTE'
ORDER BY total_facturado DESC;
```

Esta consulta se ejecuta como `postgres`. Los roles de API no tienen acceso
directo a las tablas foraneas.

## 6. Agregaciones en MongoDB

### 6.1 Productividad por medico y tipo

```javascript
db.getSiblingDB('reportes_medicos').resultados_estudios.aggregate([
  {
    $group: {
      _id: { id_medico: '$id_medico', medico: '$medico', tipo: '$tipo' },
      estudios: { $sum: 1 },
      ingresos: { $sum: '$ingresos' },
      ticket_promedio: { $avg: '$ingresos' }
    }
  },
  { $sort: { ingresos: -1, '_id.medico': 1 } }
])
```

### 6.2 Indicadores mensuales por sucursal

```javascript
db.getSiblingDB('reportes_medicos').resultados_estudios.aggregate([
  {
    $group: {
      _id: {
        periodo: {
          $dateToString: {
            format: '%Y-%m',
            date: '$fecha',
            timezone: 'America/Costa_Rica'
          }
        },
        sucursal: '$sucursal',
        id_sucursal: '$id_sucursal'
      },
      total_estudios: { $sum: 1 },
      ingresos: { $sum: '$ingresos' },
      ticket_promedio: { $avg: '$ingresos' }
    }
  },
  { $sort: { '_id.periodo': 1, '_id.sucursal': 1 } }
])
```

### 6.3 Diagnostico mas frecuente

```javascript
db.getSiblingDB('reportes_medicos').resultados_estudios.aggregate([
  { $group: { _id: '$diagnostico', total: { $sum: 1 } } },
  { $sort: { total: -1, _id: 1 } }
])
```

Resultado esperado con el dataset base:

```text
{ _id: 'Z00.0', total: 6 }
{ _id: 'E78.5', total: 2 }
{ _id: 'R10.4', total: 2 }
{ _id: 'Z01.6', total: 2 }
{ _id: 'E04.1', total: 1 }
...
```

### 6.4 Resumen global

```javascript
db.getSiblingDB('reportes_medicos').resultados_estudios.aggregate([
  {
    $group: {
      _id: null,
      estudios: { $sum: 1 },
      ingresos: { $sum: '$ingresos' },
      ticket_promedio: { $avg: '$ingresos' }
    }
  },
  { $project: { _id: 0, estudios: 1, ingresos: 1, ticket_promedio: 1 } }
])
```

Con el dataset base:

```text
{ estudios: 15, ingresos: 455000, ticket_promedio: 30333.3333333333 }
```

### 6.5 Ejecutar todas las agregaciones

```powershell
docker exec -it medical_mongo mongosh --quiet `
  -u root -p "Mongo_Med_2026!" --authenticationDatabase admin `
  -e "MONGO_DB=reportes_medicos" `
  /scripts/03_aggregations.js
```

## 7. Consultas anidadas en MongoDB

### Documentos con hallazgo

```javascript
db.getSiblingDB('reportes_medicos').resultados_estudios.countDocuments({
  'resultado.hallazgo': { $exists: true }
})
```

Resultado esperado: `15`.

### Buscar por conclusion

```javascript
db.getSiblingDB('reportes_medicos').resultados_estudios.find(
  { 'resultado.conclusion': /Normal/i },
  { _id: 0, id_estudio: 1, paciente: 1, 'resultado.conclusion': 1 }
)
```

## 8. Consultas de seguridad

### Verificar que un rol de API no accede a tablas base

```powershell
$env:PGPASSWORD = "ApiWeb_2026!"
psql -h 127.0.0.1 -p 55432 -U usr_api_web -d medical_oltp `
  -c "SELECT count(*) FROM operativo.v_pacientes_todos;"
```

Debe fallar con `permission denied for schema operativo`.

### Verificar que el rol de API si accede a su vista

```powershell
psql -h 127.0.0.1 -p 55432 -U usr_api_web -d medical_oltp `
  -c "SELECT count(*) FROM api_web.v_paciente_facturacion;"
```

Debe devolver `15`.

## 9. Notas de rendimiento

- `tds_fdw` descarga las filas y PostgreSQL hace el join. Para tablas grandes
  conviene filtrar con `WHERE` sobre columnas indexadas en SQL Server y evitar
  `SELECT *`.
- `mongo_fdw` puede empujar filtros simples, pero no sustituye un indice
  adecuado en MongoDB. El campo `id_estudio` esta indexado implicitamente por
  la logica de busqueda; en produccion se agregaria un indice explicito.
- Las vistas `api_web` son convenientes para transparencia, pero cada consulta
  dispara acceso remoto. Para reportes pesados se recomienda materializar.
- Los `NOTICE` de `tds_fdw` se pueden silenciar con
  `SET client_min_messages = warning;` en la sesion.
