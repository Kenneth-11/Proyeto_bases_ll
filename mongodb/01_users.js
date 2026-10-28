const targetDbName = process.env.MONGO_DB || 'reportes_medicos';
const fdwUser = process.env.FDW_MONGO_USER || 'usr_fdw_pg_mongo';
const fdwPassword = process.env.FDW_MONGO_PASSWORD;

if (!fdwPassword) {
  throw new Error('FDW_MONGO_PASSWORD no esta definido en el entorno.');
}

const target = db.getSiblingDB(targetDbName);

try {
  target.dropUser(fdwUser);
} catch (e) {
  // El usuario aun no existe: es la primera ejecucion.
}

target.createUser({
  user: fdwUser,
  pwd: fdwPassword,
  roles: [
    { role: 'readWrite', db: targetDbName }
  ]
});

print(`Usuario ${fdwUser} creado con readWrite sobre ${targetDbName}.`);
