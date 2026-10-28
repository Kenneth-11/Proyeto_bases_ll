const targetDbName = process.env.MONGO_DB || 'reportes_medicos';
const target = db.getSiblingDB(targetDbName);

print('=== 1. Productividad por medico y tipo de estudio ===');
target.resultados_estudios.aggregate([
  {
    $group: {
      _id: { id_medico: '$id_medico', medico: '$medico', tipo: '$tipo' },
      estudios: { $sum: 1 },
      ingresos: { $sum: '$ingresos' },
      ticket_promedio: { $avg: '$ingresos' }
    }
  },
  { $sort: { ingresos: -1, '_id.medico': 1 } }
]).forEach(printjson);

print('=== 2. Indicadores mensuales por sucursal ===');
target.resultados_estudios.aggregate([
  {
    $group: {
      _id: {
        periodo: { $dateToString: { format: '%Y-%m', date: '$fecha', timezone: 'America/Costa_Rica' } },
        sucursal: '$sucursal',
        id_sucursal: '$id_sucursal'
      },
      total_estudios: { $sum: 1 },
      ingresos: { $sum: '$ingresos' },
      ticket_promedio: { $avg: '$ingresos' }
    }
  },
  { $sort: { '_id.periodo': 1, '_id.sucursal': 1 } }
]).forEach(printjson);

print('=== 3. Detalle de estudios con $lookup a medicos ===');
target.resultados_estudios.aggregate([
  {
    $lookup: {
      from: 'medicos',
      localField: 'id_medico',
      foreignField: 'id_medico',
      as: 'info_medico'
    }
  },
  { $unwind: '$info_medico' },
  {
    $project: {
      _id: 0,
      id_estudio: 1,
      paciente: 1,
      tipo: 1,
      medico: 1,
      especialidad: '$info_medico.especialidad',
      sucursal: 1,
      fecha: 1,
      ingresos: 1
    }
  },
  { $sort: { fecha: 1 } }
]).forEach(printjson);

print('=== 4. Diagnosticos mas frecuentes ===');
target.resultados_estudios.aggregate([
  { $group: { _id: '$diagnostico', total: { $sum: 1 } } },
  { $sort: { total: -1, _id: 1 } }
]).forEach(printjson);

print('=== 5. Resumen global ===');
target.resultados_estudios.aggregate([
  {
    $group: {
      _id: null,
      estudios: { $sum: 1 },
      ingresos: { $sum: '$ingresos' },
      ticket_promedio: { $avg: '$ingresos' }
    }
  },
  { $project: { _id: 0, estudios: 1, ingresos: 1, ticket_promedio: 1 } }
]).forEach(printjson);

const productividad = target.resultados_estudios.aggregate([
  {
    $group: {
      _id: { id_medico: '$id_medico', medico: '$medico', tipo: '$tipo', sucursal: '$sucursal' },
      estudios: { $sum: 1 },
      ingresos: { $sum: '$ingresos' },
      ticket_promedio: { $avg: '$ingresos' }
    }
  },
  {
    $project: {
      _id: 0,
      id_medico: '$_id.id_medico',
      medico: '$_id.medico',
      tipo: '$_id.tipo',
      sucursal: '$_id.sucursal',
      estudios: 1,
      ingresos: 1,
      ticket_promedio: 1
    }
  },
  { $sort: { ingresos: -1 } }
]).toArray();

target.productividad_medicos.deleteMany({});
if (productividad.length > 0) {
  target.productividad_medicos.insertMany(productividad);
}
print(`Coleccion productividad_medicos actualizada con ${productividad.length} documentos.`);
