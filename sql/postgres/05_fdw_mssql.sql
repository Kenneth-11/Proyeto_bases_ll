\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS tds_fdw;
CREATE SCHEMA IF NOT EXISTS integracion_ext;

DROP SERVER IF EXISTS mssql_integracion CASCADE;

CREATE SERVER mssql_integracion
    FOREIGN DATA WRAPPER tds_fdw
    OPTIONS (
        servername 'mssql',
        port '1433',
        database :'mssql_db',
        tds_version '7.4',
        msg_handler 'notice'
    );

CREATE USER MAPPING FOR postgres
    SERVER mssql_integracion
    OPTIONS (username :'fdw_mssql_user', password :'fdw_mssql_password');

CREATE USER MAPPING FOR :"fdw_mssql_user"
    SERVER mssql_integracion
    OPTIONS (username :'fdw_mssql_user', password :'fdw_mssql_password');

CREATE USER MAPPING FOR :"api_web_user"
    SERVER mssql_integracion
    OPTIONS (username :'fdw_mssql_user', password :'fdw_mssql_password');

CREATE USER MAPPING FOR :"api_mobile_user"
    SERVER mssql_integracion
    OPTIONS (username :'fdw_mssql_user', password :'fdw_mssql_password');

GRANT USAGE ON FOREIGN SERVER mssql_integracion TO :"fdw_mssql_user", :"api_web_user", :"api_mobile_user";

CREATE FOREIGN TABLE integracion_ext.instituciones (
    codigo_institucion varchar(20),
    nombre             varchar(120),
    tipo               varchar(30)
)
SERVER mssql_integracion
OPTIONS (schema_name 'integracion', table_name 'instituciones', match_column_names 'true');

CREATE FOREIGN TABLE integracion_ext.convenios (
    id_convenio          integer,
    id_aseguradora       integer,
    nombre               varchar(120),
    porcentaje_cobertura numeric(5,2),
    vigencia_inicio      date,
    vigencia_fin         date
)
SERVER mssql_integracion
OPTIONS (schema_name 'integracion', table_name 'convenios', match_column_names 'true');

CREATE FOREIGN TABLE integracion_ext.paciente_integracion (
    id_paciente        integer,
    id_aseguradora     integer,
    codigo_externo     varchar(40),
    estado_facturacion varchar(20),
    actualizado_en     timestamp
)
SERVER mssql_integracion
OPTIONS (schema_name 'integracion', table_name 'paciente_integracion', match_column_names 'true');

CREATE FOREIGN TABLE integracion_ext.facturas_externas (
    id_factura         integer,
    numero_factura     varchar(40),
    id_paciente        integer,
    codigo_institucion varchar(20),
    monto              numeric(12,2),
    fecha              date,
    estado             varchar(20)
)
SERVER mssql_integracion
OPTIONS (schema_name 'integracion', table_name 'facturas_externas', match_column_names 'true');

CREATE FOREIGN TABLE integracion_ext.resumen_facturacion (
    id_paciente         integer,
    total_facturado     numeric(12,2),
    facturas_pendientes integer,
    ultima_fecha        date,
    calculado_en        timestamp
)
SERVER mssql_integracion
OPTIONS (schema_name 'integracion', table_name 'resumen_facturacion', match_column_names 'true');

GRANT USAGE ON SCHEMA integracion_ext TO :"fdw_mssql_user";
GRANT SELECT ON ALL TABLES IN SCHEMA integracion_ext TO :"fdw_mssql_user";

DO $$
DECLARE
    v_pacientes integer;
    v_facturas  integer;
BEGIN
    SELECT count(*) INTO v_pacientes FROM integracion_ext.paciente_integracion;
    SELECT count(*) INTO v_facturas  FROM integracion_ext.facturas_externas;
    RAISE NOTICE 'FDW SQL Server OK: % pacientes, % facturas remotas', v_pacientes, v_facturas;
END $$;
