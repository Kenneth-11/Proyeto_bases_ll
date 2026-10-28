\set ON_ERROR_STOP on

-- --------------------------------------------------------------------------
-- Roles internos del cluster (FDW) y roles externos (aplicaciones).
-- Las contrasenas llegan como variables de psql para no dejarlas en el repo.
-- --------------------------------------------------------------------------
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'fdw_mssql_user', :'fdw_mssql_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'fdw_mssql_user')
\gexec
ALTER ROLE :"fdw_mssql_user" WITH LOGIN PASSWORD :'fdw_mssql_password' NOSUPERUSER NOCREATEDB NOCREATEROLE;

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'fdw_mongo_user', :'fdw_mongo_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'fdw_mongo_user')
\gexec
ALTER ROLE :"fdw_mongo_user" WITH LOGIN PASSWORD :'fdw_mongo_password' NOSUPERUSER NOCREATEDB NOCREATEROLE;

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'api_web_user', :'api_web_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'api_web_user')
\gexec
ALTER ROLE :"api_web_user" WITH LOGIN PASSWORD :'api_web_password' NOSUPERUSER NOCREATEDB NOCREATEROLE;

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'api_mobile_user', :'api_mobile_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'api_mobile_user')
\gexec
ALTER ROLE :"api_mobile_user" WITH LOGIN PASSWORD :'api_mobile_password' NOSUPERUSER NOCREATEDB NOCREATEROLE;

GRANT CONNECT ON DATABASE :"db_name"
    TO :"fdw_mssql_user", :"fdw_mongo_user", :"api_web_user", :"api_mobile_user";

-- El esquema public no debe ser escribible por todos.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;

REVOKE ALL ON SCHEMA catalogo, operativo, auditoria FROM PUBLIC;

GRANT USAGE ON SCHEMA catalogo TO :"fdw_mssql_user", :"fdw_mongo_user";
GRANT USAGE ON SCHEMA operativo TO :"fdw_mssql_user", :"fdw_mongo_user";

-- Politicas de sesion diferenciadas para aplicaciones.
ALTER ROLE :"api_web_user" SET search_path = api_web, catalogo;
ALTER ROLE :"api_web_user" SET statement_timeout = '30s';
ALTER ROLE :"api_web_user" SET idle_in_transaction_session_timeout = '60s';

ALTER ROLE :"api_mobile_user" SET search_path = api_mobile;
ALTER ROLE :"api_mobile_user" SET statement_timeout = '15s';
ALTER ROLE :"api_mobile_user" SET idle_in_transaction_session_timeout = '30s';

ALTER ROLE :"fdw_mssql_user" SET search_path = integracion_ext;
ALTER ROLE :"fdw_mongo_user" SET search_path = reportes_ext;

DO $$
BEGIN
    RAISE NOTICE 'Roles configurados: %, %, %, %',
        'usr_fdw_pg_mssql', 'usr_fdw_pg_mongo', 'usr_api_web', 'usr_api_mobile';
END $$;
