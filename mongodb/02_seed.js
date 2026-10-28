const targetDbName = process.env.MONGO_DB || 'reportes_medicos';
const target = db.getSiblingDB(targetDbName);

const medicos = [
  { id_medico: 501, nombre: 'Dra. Laura Jimenez',   especialidad: 'Radiologia',        id_sucursal: 1 },
  { id_medico: 502, nombre: 'Dr. Carlos Vargas',    especialidad: 'Laboratorio Clinico', id_sucursal: 1 },
  { id_medico: 503, nombre: 'Dra. Maria Solis',     especialidad: 'Ultrasonido',       id_sucursal: 2 },
  { id_medico: 504, nombre: 'Dr. Andres Ramirez',   especialidad: 'Radiologia',        id_sucursal: 3 },
  { id_medico: 505, nombre: 'Dra. Sofia Castro',    especialidad: 'Medicina General',  id_sucursal: 2 },
  { id_medico: 506, nombre: 'Dr. Felipe Araya',     especialidad: 'Radiologia',        id_sucursal: 2 },
  { id_medico: 507, nombre: 'Dra. Natalia Vega',    especialidad: 'Laboratorio Clinico', id_sucursal: 3 },
  { id_medico: 508, nombre: 'Dra. Priscilla Rojas', especialidad: 'Laboratorio Clinico', id_sucursal: 2 },
  { id_medico: 509, nombre: 'Dr. Esteban Munoz',    especialidad: 'Ultrasonido',       id_sucursal: 3 }
];

medicos.forEach((m) => {
  target.medicos.replaceOne({ id_medico: m.id_medico }, m, { upsert: true });
});

const resultados = [
  {
    id_estudio: 11001, id_paciente: 10001, paciente: 'Ana Rodriguez Mora',
    tipo: 'Ultrasonido Abdominal', id_tipo: 3, medico: 'Dra. Laura Jimenez', id_medico: 501,
    sucursal: 'San Jose', id_sucursal: 1, fecha: new Date('2026-10-05T20:30:00Z'),
    estado: 'COMPLETADO', diagnostico: 'R10.4', ingresos: 45000,
    resultado: { hallazgo: 'Sin alteraciones', medida: '12 mm', conclusion: 'Normal' }
  },
  {
    id_estudio: 11002, id_paciente: 10002, paciente: 'Jose Perez Vargas',
    tipo: 'Hemograma Completo', id_tipo: 1, medico: 'Dr. Carlos Vargas', id_medico: 502,
    sucursal: 'San Jose', id_sucursal: 1, fecha: new Date('2026-10-06T15:00:00Z'),
    estado: 'COMPLETADO', diagnostico: 'Z00.0', ingresos: 25000,
    resultado: { hallazgo: 'Valores dentro de rango', medida: 'Hb 14.2 g/dL', conclusion: 'Normal' }
  },
  {
    id_estudio: 11003, id_paciente: 10003, paciente: 'Maria Gonzalez Rojas',
    tipo: 'Radiografia de Torax', id_tipo: 4, medico: 'Dra. Laura Jimenez', id_medico: 501,
    sucursal: 'San Jose', id_sucursal: 1, fecha: new Date('2026-10-07T17:15:00Z'),
    estado: 'COMPLETADO', diagnostico: 'Z01.6', ingresos: 35000,
    resultado: { hallazgo: 'Campos pulmonares limpios', medida: 'PA y lateral', conclusion: 'Normal' }
  },
  {
    id_estudio: 11004, id_paciente: 10004, paciente: 'Carlos Jimenez Solano',
    tipo: 'Perfil Lipidico', id_tipo: 5, medico: 'Dr. Carlos Vargas', id_medico: 502,
    sucursal: 'San Jose', id_sucursal: 1, fecha: new Date('2026-10-08T14:30:00Z'),
    estado: 'COMPLETADO', diagnostico: 'E78.5', ingresos: 30000,
    resultado: { hallazgo: 'Colesterol limite', medida: '190 mg/dL', conclusion: 'Control en 6 meses' }
  },
  {
    id_estudio: 11005, id_paciente: 10005, paciente: 'Laura Mora Chaves',
    tipo: 'Glucosa en Ayunas', id_tipo: 2, medico: 'Dr. Carlos Vargas', id_medico: 502,
    sucursal: 'San Jose', id_sucursal: 1, fecha: new Date('2026-10-09T16:00:00Z'),
    estado: 'COMPLETADO', diagnostico: 'Z00.0', ingresos: 15000,
    resultado: { hallazgo: 'Glucemia normal', medida: '92 mg/dL', conclusion: 'Normal' }
  },
  {
    id_estudio: 21001, id_paciente: 20001, paciente: 'Diego Hernandez Vega',
    tipo: 'Ultrasonido de Tiroides', id_tipo: 6, medico: 'Dra. Maria Solis', id_medico: 503,
    sucursal: 'Alajuela', id_sucursal: 2, fecha: new Date('2026-10-05T22:00:00Z'),
    estado: 'COMPLETADO', diagnostico: 'E04.1', ingresos: 50000,
    resultado: { hallazgo: 'Nodulo benigno', medida: '8 mm', conclusion: 'Control anual' }
  },
  {
    id_estudio: 21002, id_paciente: 20002, paciente: 'Sofia Ramirez Quesada',
    tipo: 'Glucosa en Ayunas', id_tipo: 2, medico: 'Dra. Sofia Castro', id_medico: 505,
    sucursal: 'Alajuela', id_sucursal: 2, fecha: new Date('2026-10-06T18:00:00Z'),
    estado: 'COMPLETADO', diagnostico: 'Z00.0', ingresos: 15000,
    resultado: { hallazgo: 'Glucemia normal', medida: '88 mg/dL', conclusion: 'Normal' }
  },
  {
    id_estudio: 21003, id_paciente: 20003, paciente: 'Andres Castro Mora',
    tipo: 'Radiografia de Torax', id_tipo: 4, medico: 'Dr. Felipe Araya', id_medico: 506,
    sucursal: 'Alajuela', id_sucursal: 2, fecha: new Date('2026-10-07T20:45:00Z'),
    estado: 'COMPLETADO', diagnostico: 'J18.9', ingresos: 35000,
    resultado: { hallazgo: 'Infiltrado basal derecho', medida: 'PA', conclusion: 'Neumonia en resolucion' }
  },
  {
    id_estudio: 21004, id_paciente: 20004, paciente: 'Valentina Rojas Ulate',
    tipo: 'Hemograma Completo', id_tipo: 1, medico: 'Dra. Priscilla Rojas', id_medico: 508,
    sucursal: 'Alajuela', id_sucursal: 2, fecha: new Date('2026-10-08T17:20:00Z'),
    estado: 'COMPLETADO', diagnostico: 'Z00.0', ingresos: 25000,
    resultado: { hallazgo: 'Valores dentro de rango', medida: 'Hb 13.5 g/dL', conclusion: 'Normal' }
  },
  {
    id_estudio: 21005, id_paciente: 20005, paciente: 'Marco Solis Brenes',
    tipo: 'Perfil Lipidico', id_tipo: 5, medico: 'Dra. Sofia Castro', id_medico: 505,
    sucursal: 'Alajuela', id_sucursal: 2, fecha: new Date('2026-10-09T19:00:00Z'),
    estado: 'COMPLETADO', diagnostico: 'E78.5', ingresos: 30000,
    resultado: { hallazgo: 'Trigliceridos elevados', medida: '210 mg/dL', conclusion: 'Dieta y control' }
  },
  {
    id_estudio: 31001, id_paciente: 30001, paciente: 'Elena Vargas Picado',
    tipo: 'Hemograma Completo', id_tipo: 1, medico: 'Dra. Natalia Vega', id_medico: 507,
    sucursal: 'Cartago', id_sucursal: 3, fecha: new Date('2026-10-05T16:30:00Z'),
    estado: 'COMPLETADO', diagnostico: 'Z00.0', ingresos: 25000,
    resultado: { hallazgo: 'Valores dentro de rango', medida: 'Hb 12.9 g/dL', conclusion: 'Normal' }
  },
  {
    id_estudio: 31002, id_paciente: 30002, paciente: 'Pablo Jimenez Arias',
    tipo: 'Ultrasonido Abdominal', id_tipo: 3, medico: 'Dr. Esteban Munoz', id_medico: 509,
    sucursal: 'Cartago', id_sucursal: 3, fecha: new Date('2026-10-06T21:00:00Z'),
    estado: 'COMPLETADO', diagnostico: 'K76.0', ingresos: 45000,
    resultado: { hallazgo: 'Higado graso leve', medida: 'Grado I', conclusion: 'Control' }
  },
  {
    id_estudio: 31003, id_paciente: 30003, paciente: 'Daniela Mora Salas',
    tipo: 'Glucosa en Ayunas', id_tipo: 2, medico: 'Dra. Natalia Vega', id_medico: 507,
    sucursal: 'Cartago', id_sucursal: 3, fecha: new Date('2026-10-07T15:40:00Z'),
    estado: 'COMPLETADO', diagnostico: 'Z00.0', ingresos: 15000,
    resultado: { hallazgo: 'Glucemia normal', medida: '95 mg/dL', conclusion: 'Normal' }
  },
  {
    id_estudio: 31004, id_paciente: 30004, paciente: 'Roberto Chaves Quesada',
    tipo: 'Perfil Lipidico', id_tipo: 5, medico: 'Dra. Natalia Vega', id_medico: 507,
    sucursal: 'Cartago', id_sucursal: 3, fecha: new Date('2026-10-08T14:10:00Z'),
    estado: 'COMPLETADO', diagnostico: 'E78.0', ingresos: 30000,
    resultado: { hallazgo: 'Colesterol elevado', medida: '225 mg/dL', conclusion: 'Tratamiento' }
  },
  {
    id_estudio: 31005, id_paciente: 30005, paciente: 'Camila Ulate Rojas',
    tipo: 'Radiografia de Torax', id_tipo: 4, medico: 'Dr. Andres Ramirez', id_medico: 504,
    sucursal: 'Cartago', id_sucursal: 3, fecha: new Date('2026-10-09T18:25:00Z'),
    estado: 'COMPLETADO', diagnostico: 'Z01.6', ingresos: 35000,
    resultado: { hallazgo: 'Sin hallazgos', medida: 'PA', conclusion: 'Normal' }
  }
];

resultados.forEach((doc) => {
  target.resultados_estudios.replaceOne({ id_estudio: doc.id_estudio }, doc, { upsert: true });
});

const indicadores = [
  { periodo: '2026-10', id_sucursal: 1, sucursal: 'San Jose', total_estudios: 5, ingresos: 150000, ticket_promedio: 30000 },
  { periodo: '2026-10', id_sucursal: 2, sucursal: 'Alajuela', total_estudios: 5, ingresos: 155000, ticket_promedio: 31000 },
  { periodo: '2026-10', id_sucursal: 3, sucursal: 'Cartago', total_estudios: 5, ingresos: 150000, ticket_promedio: 30000 }
];

indicadores.forEach((doc) => {
  target.indicadores_mensuales.replaceOne(
    { periodo: doc.periodo, id_sucursal: doc.id_sucursal },
    doc,
    { upsert: true }
  );
});

target.resultados_estudios.createIndex({ id_estudio: 1 }, { unique: true });
target.resultados_estudios.createIndex({ sucursal: 1, fecha: -1 });
target.resultados_estudios.createIndex({ id_medico: 1, tipo: 1 });
target.medicos.createIndex({ id_medico: 1 }, { unique: true });
target.indicadores_mensuales.createIndex({ periodo: 1, id_sucursal: 1 }, { unique: true });

print(`Cargados ${resultados.length} resultados, ${medicos.length} medicos y ${indicadores.length} indicadores.`);
