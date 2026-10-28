\set ON_ERROR_STOP on

-- --------------------------------------------------------------------------
-- Catalogos globales
-- --------------------------------------------------------------------------
INSERT INTO catalogo.sucursal (id_sucursal, nombre, region, direccion) VALUES
    (1, 'San Jose', 'San Jose', 'Avenida Central, San Jose'),
    (2, 'Alajuela', 'Alajuela', 'Calle 2, Alajuela Centro'),
    (3, 'Cartago',  'Cartago',  'Avenida 4, Cartago Centro')
ON CONFLICT (id_sucursal) DO UPDATE
SET nombre = EXCLUDED.nombre, region = EXCLUDED.region, direccion = EXCLUDED.direccion;

INSERT INTO catalogo.tipo_estudio (id_tipo, codigo, nombre, precio_base, modalidad) VALUES
    (1, 'LAB-HEM', 'Hemograma Completo',        25000.00, 'Laboratorio'),
    (2, 'LAB-GLU', 'Glucosa en Ayunas',         15000.00, 'Laboratorio'),
    (3, 'ULT-ABD', 'Ultrasonido Abdominal',     45000.00, 'Ultrasonido'),
    (4, 'RAD-TOR', 'Radiografia de Torax',      35000.00, 'Radiografia'),
    (5, 'LAB-PER', 'Perfil Lipidico',           30000.00, 'Laboratorio'),
    (6, 'ULT-TIR', 'Ultrasonido de Tiroides',   50000.00, 'Ultrasonido')
ON CONFLICT (id_tipo) DO UPDATE
SET codigo = EXCLUDED.codigo, nombre = EXCLUDED.nombre,
    precio_base = EXCLUDED.precio_base, modalidad = EXCLUDED.modalidad;

INSERT INTO catalogo.medico (id_medico, cedula, nombre, especialidad, id_sucursal) VALUES
    (501, 'MED-501', 'Dra. Laura Jimenez',    'Radiologia',          1),
    (502, 'MED-502', 'Dr. Carlos Vargas',     'Laboratorio Clinico', 1),
    (503, 'MED-503', 'Dra. Maria Solis',      'Ultrasonido',         2),
    (504, 'MED-504', 'Dr. Andres Ramirez',    'Radiologia',          3),
    (505, 'MED-505', 'Dra. Sofia Castro',     'Medicina General',    2),
    (506, 'MED-506', 'Dr. Felipe Araya',      'Radiologia',          2),
    (507, 'MED-507', 'Dra. Natalia Vega',     'Laboratorio Clinico', 3),
    (508, 'MED-508', 'Dra. Priscilla Rojas',  'Laboratorio Clinico', 2),
    (509, 'MED-509', 'Dr. Esteban Munoz',     'Ultrasonido',         3)
ON CONFLICT (id_medico) DO UPDATE
SET cedula = EXCLUDED.cedula, nombre = EXCLUDED.nombre,
    especialidad = EXCLUDED.especialidad, id_sucursal = EXCLUDED.id_sucursal;

INSERT INTO catalogo.aseguradora (id_aseguradora, nombre, codigo_externo) VALUES
    (1, 'Instituto Nacional de Seguros',       'INS'),
    (2, 'Caja Costarricense de Seguro Social', 'CCSS'),
    (3, 'Mapfre Seguros Costa Rica',           'MAPFRE')
ON CONFLICT (id_aseguradora) DO UPDATE
SET nombre = EXCLUDED.nombre, codigo_externo = EXCLUDED.codigo_externo;

-- --------------------------------------------------------------------------
-- San Jose (IDs 10xxx)
-- --------------------------------------------------------------------------
INSERT INTO san_jose.pacientes
    (id_paciente, cedula, nombre, apellidos, fecha_nacimiento, sexo, telefono, email, direccion, id_sucursal)
VALUES
    (10001, '1-1234-5678', 'Ana',     'Rodriguez Mora',   '1985-03-12', 'F', '8888-1111', 'ana.rodriguez@example.com',   'Barrio Escalante', 1),
    (10002, '2-0456-0789', 'Jose',    'Perez Vargas',     '1978-07-23', 'M', '8888-2222', 'jose.perez@example.com',      'Sabana Sur',       1),
    (10003, '3-1122-3344', 'Maria',   'Gonzalez Rojas',   '1990-11-05', 'F', '8888-3333', 'maria.gonzalez@example.com',  'Curridabat',       1),
    (10004, '4-5566-7788', 'Carlos',  'Jimenez Solano',   '1965-01-30', 'M', '8888-4444', 'carlos.jimenez@example.com',  'Moravia',          1),
    (10005, '5-9988-7766', 'Laura',   'Mora Chaves',      '2001-09-15', 'F', '8888-5555', 'laura.mora@example.com',      'Desamparados',     1)
ON CONFLICT (id_paciente) DO UPDATE
SET cedula = EXCLUDED.cedula, nombre = EXCLUDED.nombre, apellidos = EXCLUDED.apellidos,
    fecha_nacimiento = EXCLUDED.fecha_nacimiento, sexo = EXCLUDED.sexo,
    telefono = EXCLUDED.telefono, email = EXCLUDED.email,
    direccion = EXCLUDED.direccion, id_sucursal = EXCLUDED.id_sucursal;

INSERT INTO san_jose.citas (id_cita, id_paciente, id_medico, fecha_hora, estado, motivo) VALUES
    (1001, 10001, 501, '2026-10-05 13:00:00-06', 'ATENDIDA', 'Dolor abdominal'),
    (1002, 10002, 502, '2026-10-06 08:00:00-06', 'ATENDIDA', 'Chequeo general'),
    (1003, 10003, 501, '2026-10-07 10:00:00-06', 'ATENDIDA', 'Control radiologico'),
    (1004, 10004, 502, '2026-10-08 07:30:00-06', 'ATENDIDA', 'Perfil lipidico'),
    (1005, 10005, 502, '2026-10-09 09:00:00-06', 'ATENDIDA', 'Glucosa')
ON CONFLICT (id_cita) DO UPDATE
SET id_paciente = EXCLUDED.id_paciente, id_medico = EXCLUDED.id_medico,
    fecha_hora = EXCLUDED.fecha_hora, estado = EXCLUDED.estado, motivo = EXCLUDED.motivo;

INSERT INTO san_jose.ordenes (id_orden, id_cita, id_paciente, fecha, estado) VALUES
    (15001, 1001, 10001, '2026-10-05 13:15:00-06', 'PROCESADA'),
    (15002, 1002, 10002, '2026-10-06 08:15:00-06', 'PROCESADA'),
    (15003, 1003, 10003, '2026-10-07 10:15:00-06', 'PROCESADA'),
    (15004, 1004, 10004, '2026-10-08 07:45:00-06', 'PROCESADA'),
    (15005, 1005, 10005, '2026-10-09 09:15:00-06', 'PROCESADA')
ON CONFLICT (id_orden) DO UPDATE
SET id_cita = EXCLUDED.id_cita, id_paciente = EXCLUDED.id_paciente,
    fecha = EXCLUDED.fecha, estado = EXCLUDED.estado;

INSERT INTO san_jose.estudios
    (id_estudio, id_orden, id_paciente, id_tipo, id_medico, fecha, estado, resultado, observaciones)
VALUES
    (11001, 15001, 10001, 3, 501, '2026-10-05 14:30:00-06', 'COMPLETADO',
     '{"hallazgo": "Sin alteraciones", "medida": "12 mm", "conclusion": "Normal"}'::jsonb, 'Control anual'),
    (11002, 15002, 10002, 1, 502, '2026-10-06 09:00:00-06', 'COMPLETADO',
     '{"hemoglobina": "14.2 g/dL", "leucocitos": "7.1 x10^3/uL", "conclusion": "Normal"}'::jsonb, 'Sin sintomas'),
    (11003, 15003, 10003, 4, 501, '2026-10-07 11:15:00-06', 'COMPLETADO',
     '{"hallazgo": "Campos pulmonares limpios", "conclusion": "Normal"}'::jsonb, 'Chequeo preoperatorio'),
    (11004, 15004, 10004, 5, 502, '2026-10-08 08:30:00-06', 'COMPLETADO',
     '{"colesterol_total": "190 mg/dL", "trigliceridos": "140 mg/dL", "conclusion": "Limite"}'::jsonb, 'Control en 6 meses'),
    (11005, 15005, 10005, 2, 502, '2026-10-09 10:00:00-06', 'COMPLETADO',
     '{"glucosa": "92 mg/dL", "conclusion": "Normal"}'::jsonb, 'Ayuno de 8 horas')
ON CONFLICT (id_estudio) DO UPDATE
SET id_orden = EXCLUDED.id_orden, id_paciente = EXCLUDED.id_paciente,
    id_tipo = EXCLUDED.id_tipo, id_medico = EXCLUDED.id_medico,
    fecha = EXCLUDED.fecha, estado = EXCLUDED.estado,
    resultado = EXCLUDED.resultado, observaciones = EXCLUDED.observaciones;

-- --------------------------------------------------------------------------
-- Alajuela (IDs 20xxx)
-- --------------------------------------------------------------------------
INSERT INTO alajuela.pacientes
    (id_paciente, cedula, nombre, apellidos, fecha_nacimiento, sexo, telefono, email, direccion, id_sucursal)
VALUES
    (20001, '6-1111-2222',  'Diego',     'Hernandez Vega',  '1982-04-18', 'M', '7777-1111', 'diego.hernandez@example.com',  'Grecia',       2),
    (20002, '7-2222-3333',  'Sofia',     'Ramirez Quesada', '1995-06-27', 'F', '7777-2222', 'sofia.ramirez@example.com',    'San Ramon',    2),
    (20003, '8-3333-4444',  'Andres',    'Castro Mora',     '1970-12-09', 'M', '7777-3333', 'andres.castro@example.com',    'Naranjo',      2),
    (20004, '9-4444-5555',  'Valentina', 'Rojas Ulate',     '1998-02-14', 'F', '7777-4444', 'valentina.rojas@example.com',  'Atenas',       2),
    (20005, '10-5555-6666', 'Marco',     'Solis Brenes',    '1988-08-21', 'M', '7777-5555', 'marco.solis@example.com',      'Palmares',     2)
ON CONFLICT (id_paciente) DO UPDATE
SET cedula = EXCLUDED.cedula, nombre = EXCLUDED.nombre, apellidos = EXCLUDED.apellidos,
    fecha_nacimiento = EXCLUDED.fecha_nacimiento, sexo = EXCLUDED.sexo,
    telefono = EXCLUDED.telefono, email = EXCLUDED.email,
    direccion = EXCLUDED.direccion, id_sucursal = EXCLUDED.id_sucursal;

INSERT INTO alajuela.citas (id_cita, id_paciente, id_medico, fecha_hora, estado, motivo) VALUES
    (2001, 20001, 503, '2026-10-05 15:00:00-06', 'ATENDIDA', 'Nodulo tiroideo'),
    (2002, 20002, 505, '2026-10-06 11:00:00-06', 'ATENDIDA', 'Glucosa'),
    (2003, 20003, 506, '2026-10-07 14:00:00-06', 'ATENDIDA', 'Tos persistente'),
    (2004, 20004, 508, '2026-10-08 10:00:00-06', 'ATENDIDA', 'Chequeo general'),
    (2005, 20005, 505, '2026-10-09 12:00:00-06', 'ATENDIDA', 'Perfil lipidico')
ON CONFLICT (id_cita) DO UPDATE
SET id_paciente = EXCLUDED.id_paciente, id_medico = EXCLUDED.id_medico,
    fecha_hora = EXCLUDED.fecha_hora, estado = EXCLUDED.estado, motivo = EXCLUDED.motivo;

INSERT INTO alajuela.ordenes (id_orden, id_cita, id_paciente, fecha, estado) VALUES
    (25001, 2001, 20001, '2026-10-05 15:15:00-06', 'PROCESADA'),
    (25002, 2002, 20002, '2026-10-06 11:15:00-06', 'PROCESADA'),
    (25003, 2003, 20003, '2026-10-07 14:15:00-06', 'PROCESADA'),
    (25004, 2004, 20004, '2026-10-08 10:15:00-06', 'PROCESADA'),
    (25005, 2005, 20005, '2026-10-09 12:15:00-06', 'PROCESADA')
ON CONFLICT (id_orden) DO UPDATE
SET id_cita = EXCLUDED.id_cita, id_paciente = EXCLUDED.id_paciente,
    fecha = EXCLUDED.fecha, estado = EXCLUDED.estado;

INSERT INTO alajuela.estudios
    (id_estudio, id_orden, id_paciente, id_tipo, id_medico, fecha, estado, resultado, observaciones)
VALUES
    (21001, 25001, 20001, 6, 503, '2026-10-05 16:00:00-06', 'COMPLETADO',
     '{"hallazgo": "Nodulo benigno", "medida": "8 mm", "conclusion": "Control anual"}'::jsonb, 'Seguimiento'),
    (21002, 25002, 20002, 2, 505, '2026-10-06 12:00:00-06', 'COMPLETADO',
     '{"glucosa": "88 mg/dL", "conclusion": "Normal"}'::jsonb, 'Ayuno de 8 horas'),
    (21003, 25003, 20003, 4, 506, '2026-10-07 15:00:00-06', 'COMPLETADO',
     '{"hallazgo": "Infiltrado basal derecho", "conclusion": "Neumonia en resolucion"}'::jsonb, 'Control en 2 semanas'),
    (21004, 25004, 20004, 1, 508, '2026-10-08 11:00:00-06', 'COMPLETADO',
     '{"hemoglobina": "13.5 g/dL", "conclusion": "Normal"}'::jsonb, 'Sin sintomas'),
    (21005, 25005, 20005, 5, 505, '2026-10-09 13:00:00-06', 'COMPLETADO',
     '{"trigliceridos": "210 mg/dL", "conclusion": "Dieta y control"}'::jsonb, 'Control en 3 meses')
ON CONFLICT (id_estudio) DO UPDATE
SET id_orden = EXCLUDED.id_orden, id_paciente = EXCLUDED.id_paciente,
    id_tipo = EXCLUDED.id_tipo, id_medico = EXCLUDED.id_medico,
    fecha = EXCLUDED.fecha, estado = EXCLUDED.estado,
    resultado = EXCLUDED.resultado, observaciones = EXCLUDED.observaciones;

-- --------------------------------------------------------------------------
-- Cartago (IDs 30xxx)
-- --------------------------------------------------------------------------
INSERT INTO cartago.pacientes
    (id_paciente, cedula, nombre, apellidos, fecha_nacimiento, sexo, telefono, email, direccion, id_sucursal)
VALUES
    (30001, '11-6666-7777', 'Elena',   'Vargas Picado',  '1975-05-03', 'F', '6666-1111', 'elena.vargas@example.com',   'Paraiso',      3),
    (30002, '12-7777-8888', 'Pablo',   'Jimenez Arias',  '1983-10-17', 'M', '6666-2222', 'pablo.jimenez@example.com',  'Turrialba',    3),
    (30003, '13-8888-9999', 'Daniela', 'Mora Salas',     '1992-03-08', 'F', '6666-3333', 'daniela.mora@example.com',   'Tres Rios',    3),
    (30004, '14-9999-0000', 'Roberto', 'Chaves Quesada', '1968-11-26', 'M', '6666-4444', 'roberto.chaves@example.com', 'Tejar',        3),
    (30005, '15-0000-1111', 'Camila',  'Ulate Rojas',    '2000-07-30', 'F', '6666-5555', 'camila.ulate@example.com',   'Orosi',        3)
ON CONFLICT (id_paciente) DO UPDATE
SET cedula = EXCLUDED.cedula, nombre = EXCLUDED.nombre, apellidos = EXCLUDED.apellidos,
    fecha_nacimiento = EXCLUDED.fecha_nacimiento, sexo = EXCLUDED.sexo,
    telefono = EXCLUDED.telefono, email = EXCLUDED.email,
    direccion = EXCLUDED.direccion, id_sucursal = EXCLUDED.id_sucursal;

INSERT INTO cartago.citas (id_cita, id_paciente, id_medico, fecha_hora, estado, motivo) VALUES
    (3001, 30001, 507, '2026-10-05 09:00:00-06', 'ATENDIDA', 'Chequeo general'),
    (3002, 30002, 509, '2026-10-06 15:00:00-06', 'ATENDIDA', 'Dolor abdominal'),
    (3003, 30003, 507, '2026-10-07 09:30:00-06', 'ATENDIDA', 'Glucosa'),
    (3004, 30004, 507, '2026-10-08 08:00:00-06', 'ATENDIDA', 'Perfil lipidico'),
    (3005, 30005, 504, '2026-10-09 12:00:00-06', 'ATENDIDA', 'Chequeo radiologico')
ON CONFLICT (id_cita) DO UPDATE
SET id_paciente = EXCLUDED.id_paciente, id_medico = EXCLUDED.id_medico,
    fecha_hora = EXCLUDED.fecha_hora, estado = EXCLUDED.estado, motivo = EXCLUDED.motivo;

INSERT INTO cartago.ordenes (id_orden, id_cita, id_paciente, fecha, estado) VALUES
    (35001, 3001, 30001, '2026-10-05 09:15:00-06', 'PROCESADA'),
    (35002, 3002, 30002, '2026-10-06 15:15:00-06', 'PROCESADA'),
    (35003, 3003, 30003, '2026-10-07 09:45:00-06', 'PROCESADA'),
    (35004, 3004, 30004, '2026-10-08 08:15:00-06', 'PROCESADA'),
    (35005, 3005, 30005, '2026-10-09 12:15:00-06', 'PROCESADA')
ON CONFLICT (id_orden) DO UPDATE
SET id_cita = EXCLUDED.id_cita, id_paciente = EXCLUDED.id_paciente,
    fecha = EXCLUDED.fecha, estado = EXCLUDED.estado;

INSERT INTO cartago.estudios
    (id_estudio, id_orden, id_paciente, id_tipo, id_medico, fecha, estado, resultado, observaciones)
VALUES
    (31001, 35001, 30001, 1, 507, '2026-10-05 10:00:00-06', 'COMPLETADO',
     '{"hemoglobina": "12.9 g/dL", "conclusion": "Normal"}'::jsonb, 'Sin sintomas'),
    (31002, 35002, 30002, 3, 509, '2026-10-06 16:00:00-06', 'COMPLETADO',
     '{"hallazgo": "Higado graso leve", "medida": "Grado I", "conclusion": "Control"}'::jsonb, 'Control en 6 meses'),
    (31003, 35003, 30003, 2, 507, '2026-10-07 10:00:00-06', 'COMPLETADO',
     '{"glucosa": "95 mg/dL", "conclusion": "Normal"}'::jsonb, 'Ayuno de 8 horas'),
    (31004, 35004, 30004, 5, 507, '2026-10-08 09:00:00-06', 'COMPLETADO',
     '{"colesterol_total": "225 mg/dL", "conclusion": "Tratamiento"}'::jsonb, 'Inicio de tratamiento'),
    (31005, 35005, 30005, 4, 504, '2026-10-09 13:00:00-06', 'COMPLETADO',
     '{"hallazgo": "Sin hallazgos", "conclusion": "Normal"}'::jsonb, 'Chequeo preoperatorio')
ON CONFLICT (id_estudio) DO UPDATE
SET id_orden = EXCLUDED.id_orden, id_paciente = EXCLUDED.id_paciente,
    id_tipo = EXCLUDED.id_tipo, id_medico = EXCLUDED.id_medico,
    fecha = EXCLUDED.fecha, estado = EXCLUDED.estado,
    resultado = EXCLUDED.resultado, observaciones = EXCLUDED.observaciones;

-- --------------------------------------------------------------------------
-- Diagnosticos
-- --------------------------------------------------------------------------
INSERT INTO san_jose.diagnosticos (id_estudio, codigo_cie10, descripcion) VALUES
    (11001, 'R10.4', 'Dolor abdominal no especificado'),
    (11002, 'Z00.0', 'Examen medico general'),
    (11003, 'Z01.6', 'Examen radiologico'),
    (11004, 'E78.5', 'Hiperlipidemia no especificada'),
    (11005, 'Z00.0', 'Examen medico general')
ON CONFLICT (id_estudio, codigo_cie10) DO NOTHING;

INSERT INTO alajuela.diagnosticos (id_estudio, codigo_cie10, descripcion) VALUES
    (21001, 'E04.1', 'Nodulo tiroideo benigno'),
    (21002, 'Z00.0', 'Examen medico general'),
    (21003, 'J18.9', 'Neumonia no especificada'),
    (21004, 'Z00.0', 'Examen medico general'),
    (21005, 'E78.5', 'Hiperlipidemia no especificada')
ON CONFLICT (id_estudio, codigo_cie10) DO NOTHING;

INSERT INTO cartago.diagnosticos (id_estudio, codigo_cie10, descripcion) VALUES
    (31001, 'Z00.0', 'Examen medico general'),
    (31002, 'K76.0', 'Higado graso no clasificado'),
    (31003, 'Z00.0', 'Examen medico general'),
    (31004, 'E78.0', 'Hipercolesterolemia pura'),
    (31005, 'Z01.6', 'Examen radiologico')
ON CONFLICT (id_estudio, codigo_cie10) DO NOTHING;

-- --------------------------------------------------------------------------
-- Ajustar secuencias de identidad despues de las inserciones explicitas.
-- --------------------------------------------------------------------------
SELECT setval(pg_get_serial_sequence('san_jose.pacientes', 'id_paciente'), (SELECT COALESCE(max(id_paciente), 10005) FROM san_jose.pacientes));
SELECT setval(pg_get_serial_sequence('san_jose.citas', 'id_cita'), (SELECT COALESCE(max(id_cita), 1005) FROM san_jose.citas));
SELECT setval(pg_get_serial_sequence('san_jose.ordenes', 'id_orden'), (SELECT COALESCE(max(id_orden), 15005) FROM san_jose.ordenes));
SELECT setval(pg_get_serial_sequence('san_jose.estudios', 'id_estudio'), (SELECT COALESCE(max(id_estudio), 11005) FROM san_jose.estudios));
SELECT setval(pg_get_serial_sequence('san_jose.diagnosticos', 'id_diagnostico'), (SELECT COALESCE(max(id_diagnostico), 1) FROM san_jose.diagnosticos));

SELECT setval(pg_get_serial_sequence('alajuela.pacientes', 'id_paciente'), (SELECT COALESCE(max(id_paciente), 20005) FROM alajuela.pacientes));
SELECT setval(pg_get_serial_sequence('alajuela.citas', 'id_cita'), (SELECT COALESCE(max(id_cita), 2005) FROM alajuela.citas));
SELECT setval(pg_get_serial_sequence('alajuela.ordenes', 'id_orden'), (SELECT COALESCE(max(id_orden), 25005) FROM alajuela.ordenes));
SELECT setval(pg_get_serial_sequence('alajuela.estudios', 'id_estudio'), (SELECT COALESCE(max(id_estudio), 21005) FROM alajuela.estudios));
SELECT setval(pg_get_serial_sequence('alajuela.diagnosticos', 'id_diagnostico'), (SELECT COALESCE(max(id_diagnostico), 1) FROM alajuela.diagnosticos));

SELECT setval(pg_get_serial_sequence('cartago.pacientes', 'id_paciente'), (SELECT COALESCE(max(id_paciente), 30005) FROM cartago.pacientes));
SELECT setval(pg_get_serial_sequence('cartago.citas', 'id_cita'), (SELECT COALESCE(max(id_cita), 3005) FROM cartago.citas));
SELECT setval(pg_get_serial_sequence('cartago.ordenes', 'id_orden'), (SELECT COALESCE(max(id_orden), 35005) FROM cartago.ordenes));
SELECT setval(pg_get_serial_sequence('cartago.estudios', 'id_estudio'), (SELECT COALESCE(max(id_estudio), 31005) FROM cartago.estudios));
SELECT setval(pg_get_serial_sequence('cartago.diagnosticos', 'id_diagnostico'), (SELECT COALESCE(max(id_diagnostico), 1) FROM cartago.diagnosticos));
