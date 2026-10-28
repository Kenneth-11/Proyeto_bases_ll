\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS tds_fdw;
CREATE EXTENSION IF NOT EXISTS mongo_fdw;

DO $$
BEGIN
    RAISE NOTICE 'Extensiones instaladas: %', (
        SELECT string_agg(extname, ', ' ORDER BY extname)
        FROM pg_extension
        WHERE extname IN ('tds_fdw', 'mongo_fdw')
    );
END $$;
