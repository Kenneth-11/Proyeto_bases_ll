:on error exit

USE [$(DbName)];
GO

-- --------------------------------------------------------------------------
-- Datos de referencia
-- --------------------------------------------------------------------------
MERGE integracion.instituciones AS t
USING (VALUES
    ('INS',     'Instituto Nacional de Seguros',       'ASEGURADORA'),
    ('CCSS',    'Caja Costarricense de Seguro Social', 'ASEGURADORA'),
    ('MAPFRE',  'Mapfre Seguros Costa Rica',           'ASEGURADORA'),
    ('HOSP-MX', 'Hospital Mexico',                     'HOSPITAL'),
    ('MIN-SAL', 'Ministerio de Salud',                 'MINISTERIO')
) AS s(codigo_institucion, nombre, tipo)
ON t.codigo_institucion = s.codigo_institucion
WHEN MATCHED THEN
    UPDATE SET nombre = s.nombre, tipo = s.tipo
WHEN NOT MATCHED THEN
    INSERT (codigo_institucion, nombre, tipo)
    VALUES (s.codigo_institucion, s.nombre, s.tipo);
GO

MERGE integracion.convenios AS t
USING (VALUES
    (1, 'Convenio INS General',   80.00, CAST('2026-01-01' AS DATE), NULL),
    (2, 'Convenio CCSS Universal', 100.00, CAST('2026-01-01' AS DATE), NULL),
    (3, 'Convenio MAPFRE Plus',    70.00, CAST('2026-01-01' AS DATE), NULL)
) AS s(id_aseguradora, nombre, porcentaje_cobertura, vigencia_inicio, vigencia_fin)
ON t.id_aseguradora = s.id_aseguradora AND t.nombre = s.nombre
WHEN MATCHED THEN
    UPDATE SET porcentaje_cobertura = s.porcentaje_cobertura,
               vigencia_inicio = s.vigencia_inicio,
               vigencia_fin = s.vigencia_fin
WHEN NOT MATCHED THEN
    INSERT (id_aseguradora, nombre, porcentaje_cobertura, vigencia_inicio, vigencia_fin)
    VALUES (s.id_aseguradora, s.nombre, s.porcentaje_cobertura, s.vigencia_inicio, s.vigencia_fin);
GO

-- --------------------------------------------------------------------------
-- Integracion de pacientes: solo columnas de interoperabilidad.
-- --------------------------------------------------------------------------
MERGE integracion.paciente_integracion AS t
USING (VALUES
    (10001, 1, 'EXT-10001', 'PENDIENTE'),
    (10002, 2, 'EXT-10002', 'PAGADA'),
    (10003, 1, 'EXT-10003', 'PAGADA'),
    (10004, 3, 'EXT-10004', 'PENDIENTE'),
    (10005, 2, 'EXT-10005', 'PAGADA'),
    (20001, 3, 'EXT-20001', 'PENDIENTE'),
    (20002, 2, 'EXT-20002', 'RECHAZADA'),
    (20003, 3, 'EXT-20003', 'PENDIENTE'),
    (20004, 1, 'EXT-20004', 'PAGADA'),
    (20005, 2, 'EXT-20005', 'PENDIENTE'),
    (30001, 1, 'EXT-30001', 'PAGADA'),
    (30002, 3, 'EXT-30002', 'PENDIENTE'),
    (30003, 2, 'EXT-30003', 'PAGADA'),
    (30004, 1, 'EXT-30004', 'PENDIENTE'),
    (30005, 3, 'EXT-30005', 'PENDIENTE')
) AS s(id_paciente, id_aseguradora, codigo_externo, estado_facturacion)
ON t.id_paciente = s.id_paciente
WHEN MATCHED THEN
    UPDATE SET id_aseguradora = s.id_aseguradora,
               codigo_externo = s.codigo_externo,
               estado_facturacion = s.estado_facturacion,
               actualizado_en = SYSDATETIME()
WHEN NOT MATCHED THEN
    INSERT (id_paciente, id_aseguradora, codigo_externo, estado_facturacion)
    VALUES (s.id_paciente, s.id_aseguradora, s.codigo_externo, s.estado_facturacion);
GO

-- --------------------------------------------------------------------------
-- Facturas externas
-- --------------------------------------------------------------------------
MERGE integracion.facturas_externas AS t
USING (VALUES
    ('F-2026-10001-01', 10001, 'INS',    45000.00, CAST('2026-09-15' AS DATE), 'PAGADA'),
    ('F-2026-10001-02', 10001, 'INS',    25000.00, CAST('2026-10-01' AS DATE), 'PENDIENTE'),
    ('F-2026-10002-01', 10002, 'CCSS',   15000.00, CAST('2026-09-20' AS DATE), 'PAGADA'),
    ('F-2026-10003-01', 10003, 'INS',    35000.00, CAST('2026-09-22' AS DATE), 'PAGADA'),
    ('F-2026-10004-01', 10004, 'MAPFRE', 30000.00, CAST('2026-10-02' AS DATE), 'PENDIENTE'),
    ('F-2026-10005-01', 10005, 'CCSS',   15000.00, CAST('2026-10-03' AS DATE), 'PAGADA'),
    ('F-2026-20001-01', 20001, 'MAPFRE', 50000.00, CAST('2026-09-28' AS DATE), 'PENDIENTE'),
    ('F-2026-20002-01', 20002, 'CCSS',   30000.00, CAST('2026-09-30' AS DATE), 'RECHAZADA'),
    ('F-2026-20003-01', 20003, 'MAPFRE', 35000.00, CAST('2026-10-04' AS DATE), 'PENDIENTE'),
    ('F-2026-20004-01', 20004, 'INS',    30000.00, CAST('2026-10-05' AS DATE), 'PAGADA'),
    ('F-2026-20005-01', 20005, 'CCSS',   15000.00, CAST('2026-10-06' AS DATE), 'PENDIENTE'),
    ('F-2026-30001-01', 30001, 'INS',    25000.00, CAST('2026-09-25' AS DATE), 'PAGADA'),
    ('F-2026-30002-01', 30002, 'MAPFRE', 45000.00, CAST('2026-10-01' AS DATE), 'PENDIENTE'),
    ('F-2026-30003-01', 30003, 'CCSS',   15000.00, CAST('2026-10-02' AS DATE), 'PAGADA'),
    ('F-2026-30004-01', 30004, 'INS',    35000.00, CAST('2026-10-03' AS DATE), 'PENDIENTE'),
    ('F-2026-30005-01', 30005, 'MAPFRE', 30000.00, CAST('2026-10-04' AS DATE), 'PENDIENTE')
) AS s(numero_factura, id_paciente, codigo_institucion, monto, fecha, estado)
ON t.numero_factura = s.numero_factura
WHEN MATCHED THEN
    UPDATE SET id_paciente = s.id_paciente,
               codigo_institucion = s.codigo_institucion,
               monto = s.monto,
               fecha = s.fecha,
               estado = s.estado
WHEN NOT MATCHED THEN
    INSERT (numero_factura, id_paciente, codigo_institucion, monto, fecha, estado)
    VALUES (s.numero_factura, s.id_paciente, s.codigo_institucion, s.monto, s.fecha, s.estado);
GO

EXEC integracion.usp_RecalcularResumenTodos;
GO

PRINT 'Datos de integracion cargados.';
GO
