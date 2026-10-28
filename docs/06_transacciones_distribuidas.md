# Transacciones y consistencia distribuida

## 1. Problema

El sistema escribe en dos motores con garantias transaccionales distintas:

- PostgreSQL confirma la transaccion local del estudio.
- MongoDB recibe el documento analitico mediante `mongo_fdw`.

No existe un coordinador de two-phase commit (2PC) entre PostgreSQL y MongoDB.
Tampoco lo hay entre PostgreSQL y SQL Server, y `tds_fdw` es de solo lectura,
por lo que las escrituras a facturacion no forman parte de la transaccion
local.

La solucion aplicada es el **patron outbox** con sincronizacion idempotente.

## 2. Transaccion local

`operativo.sp_registrar_estudio` ejecuta dentro de una sola transaccion de
PostgreSQL:

1. `INSERT` en `<region>.ordenes`.
2. `INSERT` en `<region>.estudios`.
3. `INSERT` en `<region>.diagnosticos` si hay diagnostico.
4. `INSERT` en `auditoria.outbox_eventos` con estado `PENDIENTE`.

Si cualquiera de estos pasos falla, PostgreSQL revierte todo el bloque. No queda
un estudio sin evento de outbox ni un evento sin estudio.

Despues del `COMMIT` implicito de la funcion, se intenta la sincronizacion
remota. El resultado remoto no puede revertir la transaccion local ya
confirmada; por eso se registra en el outbox y en la bitacora.

## 3. Outbox

### 3.1 Estructura

```text
auditoria.outbox_eventos
  id_evento | tipo_evento | id_estudio | region | payload | estado | intentos | ultimo_error
```

Estados:

| Estado | Significado |
|--------|-------------|
| `PENDIENTE` | El evento aun no se ha sincronizado o fallo y requiere reintento |
| `SINCRONIZADO` | El documento remoto fue insertado o actualizado |
| `ERROR` | Estado reservado para fallos definitivos o intervencion manual |

### 3.2 Flujo

```text
BEGIN
  INSERT orden
  INSERT estudio
  INSERT diagnostico
  INSERT outbox (PENDIENTE)
COMMIT
  |
  v
fn_sincronizar_estudio()
  |
  +-- exito --> outbox = SINCRONIZADO
  +-- fallo --> outbox = PENDIENTE, intentos + 1, ultimo_error = SQLERRM
```

### 3.3 Reintento

```sql
SELECT operativo.sp_reintentar_outbox();
```

Recorre todos los eventos no sincronizados y llama a
`fn_sincronizar_estudio` para cada uno. Devuelve la cantidad de eventos
sincronizados correctamente.

## 4. Idempotencia

La sincronizacion busca primero el documento por `id_estudio`:

```sql
SELECT _id INTO v_mongo_id
FROM reportes_ext.resultados_estudios
WHERE id_estudio = p_id_estudio
LIMIT 1;
```

- Si existe, hace `UPDATE` por `_id`.
- Si no existe, hace `INSERT`.

Esto permite reintentar sin duplicar documentos. La operacion es
**at-least-once**: el evento puede intentarse mas de una vez, pero el resultado
es el mismo.

### 4.1 Conservacion de campos anidados

`mongo_fdw` traduce el `UPDATE` a `$set`. Si el documento ya tiene
`resultado.hallazgo`, `resultado.medida` y `resultado.conclusion`, y la
sincronizacion solo actualiza `estado`, `diagnostico` e `ingresos`, los campos
anidados se conservan.

Los documentos nuevos insertados por FDW no reciben el subdocumento
`resultado`, porque el FDW no proyecta objetos anidados como columnas. El
resultado clinico de un estudio nuevo queda en `<region>.estudios.resultado` y
en el `payload` del outbox. Los 15 documentos analiticos base si incluyen
`resultado`; la demostracion actualiza uno de ellos para comprobar que el
subdocumento se conserva.

## 5. Garantias y ventanas de inconsistencia

| Escenario | Garantia |
|-----------|----------|
| Fallo antes del `COMMIT` local | No queda nada en PostgreSQL |
| Fallo despues del `COMMIT` y antes de MongoDB | Estudio local confirmado, outbox `PENDIENTE` |
| Fallo despues de escribir en MongoDB y antes de marcar outbox | Evento queda `PENDIENTE`; el reintento es idempotente |
| Fallo al marcar outbox pero documento ya escrito | Reintento hace `UPDATE` del mismo documento |
| MongoDB no disponible | El estudio local no se pierde; el evento se reintenta |

La ventana de inconsistencia es el tiempo entre el `COMMIT` local y la
sincronizacion remota. Para analitica es aceptable; para facturacion no aplica
porque SQL Server es la fuente de verdad y PostgreSQL solo lee.

## 6. Prueba de fallo controlado

### 6.1 Detener MongoDB

```powershell
docker stop medical_mongo
```

### 6.2 Registrar un estudio

```sql
SELECT operativo.sp_registrar_estudio(
    'san_jose',
    10001,
    3,
    501,
    jsonb_build_object('hallazgo', 'Prueba de fallo', 'medida', '5 mm'),
    'R10.4',
    'Prueba de outbox'
);
```

El estudio queda en PostgreSQL y el outbox en `PENDIENTE`:

```sql
SELECT id_evento, id_estudio, estado, intentos, ultimo_error
FROM auditoria.outbox_eventos
ORDER BY id_evento DESC
LIMIT 1;
```

### 6.3 Reiniciar MongoDB y reintentar

```powershell
docker start medical_mongo
```

Esperar el healthcheck y ejecutar:

```sql
SELECT operativo.sp_reintentar_outbox();

SELECT id_evento, id_estudio, estado, intentos, ultimo_error
FROM auditoria.outbox_eventos
ORDER BY id_evento DESC
LIMIT 1;
```

El evento debe pasar a `SINCRONIZADO` y el documento debe existir una sola vez
en MongoDB.

### 6.4 Limpieza

Si se ejecuto la prueba manual, eliminar el estudio de prueba y sus eventos
para no alterar los conteos de `verify.ps1`. La demostracion automatica ya
incluye su propia limpieza.

## 7. Por que no 2PC

| Alternativa | Ventaja | Problema en este contexto |
|-------------|---------|---------------------------|
| 2PC | Atomicidad fuerte | MongoDB y PostgreSQL no comparten coordinador; latencia y bloqueos; `mongo_fdw` no lo soporta |
| Transaccion distribuida XA | Estandar | Requiere soporte del driver y del motor; no disponible en `mongo_fdw` |
| Saga | Tolerante a fallos | Requiere acciones compensatorias; mas complejo para un estudio clinico |
| Outbox | Simple, resiliente, idempotente | Consistencia eventual y necesidad de monitoreo |

El outbox es adecuado porque:

- La escritura critica es local.
- La proyeccion analitica tolera segundos o minutos de retraso.
- Los reintentos son seguros por `id_estudio`.
- Se puede auditar cada intento.

## 8. Monitoreo

Consultas utiles:

```sql
-- Eventos pendientes
SELECT count(*) FROM auditoria.outbox_eventos WHERE estado = 'PENDIENTE';

-- Eventos con mas intentos
SELECT id_estudio, region, intentos, ultimo_error
FROM auditoria.outbox_eventos
ORDER BY intentos DESC
LIMIT 10;

-- Ultimas sincronizaciones
SELECT id_estudio, operacion, resultado, detalle, ejecutado_en
FROM auditoria.bitacora_sincronizacion
ORDER BY id_bitacora DESC
LIMIT 10;
```

En produccion se agregaria una alerta cuando `PENDIENTE` supere un umbral o
cuando `intentos` crezca sin exito.

## 9. Facturacion externa

La facturacion no usa outbox porque PostgreSQL no escribe en SQL Server.
El flujo es:

1. El sistema externo registra la factura con
   `integracion.usp_RegistrarFactura`.
2. El procedimiento actualiza `facturas_externas` y recalcula
   `resumen_facturacion` con `MERGE`.
3. PostgreSQL lee el resultado por `tds_fdw`.

La consistencia es inmediata dentro de SQL Server. La vista de PostgreSQL puede
ver el dato con el retraso propio de la consulta remota, no de una
sincronizacion programada.
