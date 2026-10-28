\set ON_ERROR_STOP on

-- Exportacion inicial de los estudios locales hacia la capa analitica.
SELECT operativo.sp_exportar_todos_estudios() AS estudios_sincronizados;

-- Reintento de eventos pendientes (si existieran de ejecuciones previas).
SELECT operativo.sp_reintentar_outbox() AS eventos_reintentados;

DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count FROM reportes_ext.resultados_estudios;
    RAISE NOTICE 'Documentos en MongoDB visibles desde PostgreSQL: %', v_count;
END $$;
