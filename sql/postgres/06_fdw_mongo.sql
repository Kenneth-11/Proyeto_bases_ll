\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS mongo_fdw;
CREATE SCHEMA IF NOT EXISTS reportes_ext;

DROP SERVER IF EXISTS mongo_reportes CASCADE;

CREATE SERVER mongo_reportes
    FOREIGN DATA WRAPPER mongo_fdw
    OPTIONS (
        address 'mongo',
        port '27017',
        authentication_database 'reportes_medicos'
    );

CREATE USER MAPPING FOR postgres
    SERVER mongo_reportes
    OPTIONS (username :'fdw_mongo_user', password :'fdw_mongo_password');

CREATE USER MAPPING FOR :"fdw_mongo_user"
    SERVER mongo_reportes
    OPTIONS (username :'fdw_mongo_user', password :'fdw_mongo_password');

CREATE USER MAPPING FOR :"api_web_user"
    SERVER mongo_reportes
    OPTIONS (username :'fdw_mongo_user', password :'fdw_mongo_password');

CREATE USER MAPPING FOR :"api_mobile_user"
    SERVER mongo_reportes
    OPTIONS (username :'fdw_mongo_user', password :'fdw_mongo_password');

GRANT USAGE ON FOREIGN SERVER mongo_reportes TO :"fdw_mongo_user", :"api_web_user", :"api_mobile_user";

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

CREATE FOREIGN TABLE reportes_ext.indicadores_mensuales (
    _id            name,
    periodo        text,
    id_sucursal    integer,
    sucursal       text,
    total_estudios integer,
    ingresos       numeric(12,2),
    ticket_promedio numeric(12,2)
)
SERVER mongo_reportes
OPTIONS (database 'reportes_medicos', collection 'indicadores_mensuales');

CREATE FOREIGN TABLE reportes_ext.productividad_medicos (
    _id            name,
    id_medico      integer,
    medico         text,
    tipo           text,
    sucursal       text,
    estudios       integer,
    ingresos       numeric(12,2),
    ticket_promedio numeric(12,2)
)
SERVER mongo_reportes
OPTIONS (database 'reportes_medicos', collection 'productividad_medicos');

CREATE FOREIGN TABLE reportes_ext.medicos (
    _id          name,
    id_medico    integer,
    nombre       text,
    especialidad text,
    id_sucursal  integer
)
SERVER mongo_reportes
OPTIONS (database 'reportes_medicos', collection 'medicos');

GRANT USAGE ON SCHEMA reportes_ext TO :"fdw_mongo_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA reportes_ext TO :"fdw_mongo_user";

DO $$
DECLARE
    v_estudios integer;
    v_medicos  integer;
BEGIN
    SELECT count(*) INTO v_estudios FROM reportes_ext.resultados_estudios;
    SELECT count(*) INTO v_medicos  FROM reportes_ext.medicos;
    RAISE NOTICE 'FDW MongoDB OK: % estudios, % medicos en la capa analitica', v_estudios, v_medicos;
END $$;
