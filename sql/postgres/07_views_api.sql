\set ON_ERROR_STOP on

CREATE SCHEMA IF NOT EXISTS api_web;
CREATE SCHEMA IF NOT EXISTS api_mobile;

-- --------------------------------------------------------------------------
-- Vista web: combina pacientes locales (3 regiones) con facturacion remota
-- en SQL Server a traves de tds_fdw.
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW api_web.v_paciente_facturacion AS
SELECT  p.id_paciente,
        p.region,
        p.cedula,
        p.nombre,
        p.apellidos,
        s.nombre AS sucursal,
        i.codigo_externo,
        COALESCE(i.estado_facturacion, 'SIN_REGISTRO') AS estado_facturacion,
        COALESCE(r.total_facturado, 0)::numeric(12,2) AS total_facturado,
        COALESCE(r.facturas_pendientes, 0) AS facturas_pendientes,
        r.ultima_fecha
FROM operativo.v_pacientes_todos p
JOIN catalogo.sucursal s
  ON s.id_sucursal = p.id_sucursal
LEFT JOIN integracion_ext.paciente_integracion i
  ON i.id_paciente = p.id_paciente
LEFT JOIN integracion_ext.resumen_facturacion r
  ON r.id_paciente = p.id_paciente;

-- --------------------------------------------------------------------------
-- Vista web: estudios locales enriquecidos con el resumen analitico de
-- MongoDB (mongo_fdw).
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW api_web.v_estudios_analitica AS
SELECT  e.region,
        e.id_estudio,
        e.paciente,
        e.tipo,
        e.medico,
        e.sucursal,
        e.fecha,
        e.estado,
        e.resultado,
        m.diagnostico AS diagnostico_analitico,
        COALESCE(m.ingresos, 0)::numeric(12,2) AS ingresos
FROM operativo.v_estudios_todos e
LEFT JOIN reportes_ext.resultados_estudios m
  ON m.id_estudio = e.id_estudio;

-- --------------------------------------------------------------------------
-- Vista web: facturacion externa por institucion (segmentacion vertical).
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW api_web.v_facturacion_institucion AS
SELECT  i.codigo_institucion,
        i.nombre AS institucion,
        i.tipo,
        COUNT(f.id_factura) AS facturas,
        COALESCE(SUM(f.monto), 0)::numeric(12,2) AS monto_total,
        COALESCE(SUM(CASE WHEN f.estado = 'PENDIENTE' THEN f.monto ELSE 0 END), 0)::numeric(12,2) AS monto_pendiente
FROM integracion_ext.instituciones i
LEFT JOIN integracion_ext.facturas_externas f
  ON f.codigo_institucion = i.codigo_institucion
GROUP BY i.codigo_institucion, i.nombre, i.tipo;

-- --------------------------------------------------------------------------
-- Vista movil: columnas minimas y sin datos sensibles.
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW api_mobile.v_paciente_resumen AS
SELECT  id_paciente,
        nombre || ' ' || apellidos AS nombre_completo,
        region,
        estado_facturacion,
        total_facturado
FROM api_web.v_paciente_facturacion;

CREATE OR REPLACE VIEW api_mobile.v_ultimos_estudios AS
SELECT  id_estudio,
        fecha,
        tipo,
        sucursal,
        estado
FROM operativo.v_estudios_todos
ORDER BY fecha DESC;

-- --------------------------------------------------------------------------
-- Privilegios: cada aplicacion solo ve su esquema.
-- --------------------------------------------------------------------------
GRANT USAGE ON SCHEMA api_web TO :"api_web_user";
GRANT SELECT ON ALL TABLES IN SCHEMA api_web TO :"api_web_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA api_web GRANT SELECT ON TABLES TO :"api_web_user";

GRANT USAGE ON SCHEMA api_mobile TO :"api_mobile_user";
GRANT SELECT ON ALL TABLES IN SCHEMA api_mobile TO :"api_mobile_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA api_mobile GRANT SELECT ON TABLES TO :"api_mobile_user";

DO $$
BEGIN
    RAISE NOTICE 'Vistas API creadas y privilegios otorgados.';
END $$;
