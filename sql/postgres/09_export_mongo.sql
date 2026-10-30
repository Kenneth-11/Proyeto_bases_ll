\set ON_ERROR_STOP on

-- Exportacion inicial de los estudios locales hacia la capa analitica.
SELECT operativo.sp_exportar_todos_estudios() AS estudios_sincronizados;

-- Reintento de eventos pendientes (si existieran de ejecuciones previas).
SELECT operativo.sp_reintentar_outbox() AS eventos_reintentados;

-- Exportacion de reportes agregados (indicadores mensuales por sucursal).
SELECT operativo.sp_exportar_indicadores() AS indicadores_exportados;

DO $$
DECLARE
    v_count       integer;
    v_indicadores integer;
BEGIN
    SELECT count(*) INTO v_count FROM reportes_ext.resultados_estudios;
    SELECT count(*) INTO v_indicadores FROM reportes_ext.indicadores_mensuales;
    RAISE NOTICE 'Documentos en MongoDB visibles desde PostgreSQL: % estudios, % indicadores',
        v_count, v_indicadores;
END $$;
