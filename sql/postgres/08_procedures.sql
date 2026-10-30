\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION operativo.fn_schema_region(p_region text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE p_region
        WHEN 'san_jose' THEN 'san_jose'
        WHEN 'alajuela' THEN 'alajuela'
        WHEN 'cartago'  THEN 'cartago'
    END;
$$;

-- --------------------------------------------------------------------------
-- Sincroniza un estudio local hacia MongoDB. Devuelve false si la escritura
-- remota falla, dejando el evento en el outbox para reintento.
-- SECURITY DEFINER: usr_fdw_pg_mongo puede ejecutarla sin tener acceso
-- directo a los esquemas regionales.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION operativo.fn_sincronizar_estudio(
    p_id_estudio integer,
    p_region     text DEFAULT NULL
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_estudio  record;
    v_ingresos numeric(12,2);
    v_mongo_id name;
BEGIN
    SELECT * INTO v_estudio
    FROM operativo.v_estudios_todos
    WHERE id_estudio = p_id_estudio
      AND (p_region IS NULL OR region = p_region)
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Estudio % no encontrado en la region %', p_id_estudio, COALESCE(p_region, 'todas');
    END IF;

    SELECT precio_base INTO v_ingresos
    FROM catalogo.tipo_estudio
    WHERE id_tipo = v_estudio.id_tipo;

    SELECT _id INTO v_mongo_id
    FROM reportes_ext.resultados_estudios
    WHERE id_estudio = p_id_estudio
    LIMIT 1;

    IF v_mongo_id IS NOT NULL THEN
        -- mongo_fdw genera $set, por lo que los campos anidados (resultado)
        -- del documento existente se conservan.
        UPDATE reportes_ext.resultados_estudios
           SET id_paciente    = v_estudio.id_paciente,
               paciente       = v_estudio.paciente,
               tipo           = v_estudio.tipo,
               id_tipo        = v_estudio.id_tipo,
               medico         = v_estudio.medico,
               id_medico      = v_estudio.id_medico,
               sucursal       = v_estudio.sucursal,
               id_sucursal    = v_estudio.id_sucursal,
               fecha          = v_estudio.fecha,
               estado         = v_estudio.estado,
               diagnostico    = v_estudio.diagnostico,
               ingresos       = COALESCE(v_ingresos, 0),
               resultado_json = v_estudio.resultado::text
         WHERE _id = v_mongo_id;
    ELSE
        INSERT INTO reportes_ext.resultados_estudios (
            id_estudio, id_paciente, paciente, tipo, id_tipo, medico, id_medico,
            sucursal, id_sucursal, fecha, estado, diagnostico, ingresos,
            resultado_json
        ) VALUES (
            v_estudio.id_estudio, v_estudio.id_paciente, v_estudio.paciente,
            v_estudio.tipo, v_estudio.id_tipo, v_estudio.medico, v_estudio.id_medico,
            v_estudio.sucursal, v_estudio.id_sucursal, v_estudio.fecha,
            v_estudio.estado, v_estudio.diagnostico, COALESCE(v_ingresos, 0),
            v_estudio.resultado::text
        );
    END IF;

    UPDATE auditoria.outbox_eventos
       SET estado = 'SINCRONIZADO',
           sincronizado_en = now(),
           intentos = intentos + 1,
           ultimo_error = NULL
     WHERE id_estudio = p_id_estudio
       AND region = v_estudio.region
       AND estado <> 'SINCRONIZADO';

    INSERT INTO auditoria.bitacora_sincronizacion
        (id_estudio, region, operacion, resultado, detalle)
    VALUES
        (p_id_estudio, v_estudio.region, 'SYNC_MONGO', 'OK', 'Documento insertado o reemplazado');

    RETURN true;
EXCEPTION
    WHEN OTHERS THEN
        UPDATE auditoria.outbox_eventos
           SET estado = 'PENDIENTE',
               intentos = intentos + 1,
               ultimo_error = SQLERRM
         WHERE id_estudio = p_id_estudio
           AND (p_region IS NULL OR region = p_region)
           AND estado <> 'SINCRONIZADO';

        INSERT INTO auditoria.bitacora_sincronizacion
            (id_estudio, region, operacion, resultado, detalle)
        VALUES
            (p_id_estudio, COALESCE(p_region, 'desconocida'), 'SYNC_MONGO', 'ERROR', SQLERRM);

        RETURN false;
END;
$$;

-- --------------------------------------------------------------------------
-- Parte local (transaccional) del registro de un estudio: orden, estudio,
-- diagnostico y evento de outbox. Todo o nada dentro de PostgreSQL.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION operativo.fn_registrar_estudio_local(
    p_region      text,
    p_id_paciente integer,
    p_id_tipo     integer,
    p_id_medico   integer,
    p_resultado   jsonb,
    p_diagnostico varchar(10) DEFAULT NULL,
    p_descripcion text DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_schema     text := operativo.fn_schema_region(p_region);
    v_id_orden   integer;
    v_id_estudio integer;
BEGIN
    IF v_schema IS NULL THEN
        RAISE EXCEPTION 'Region invalida: %', p_region;
    END IF;

    EXECUTE format(
        'INSERT INTO %I.ordenes (id_cita, id_paciente, fecha, estado)
         VALUES (NULL, $1, now(), $2)
         RETURNING id_orden', v_schema)
        INTO v_id_orden
        USING p_id_paciente, 'PROCESADA';

    EXECUTE format(
        'INSERT INTO %I.estudios
            (id_orden, id_paciente, id_tipo, id_medico, fecha, estado, resultado)
         VALUES ($1, $2, $3, $4, now(), $5, $6)
         RETURNING id_estudio', v_schema)
        INTO v_id_estudio
        USING v_id_orden, p_id_paciente, p_id_tipo, p_id_medico, 'COMPLETADO', p_resultado;

    IF p_diagnostico IS NOT NULL THEN
        EXECUTE format(
            'INSERT INTO %I.diagnosticos (id_estudio, codigo_cie10, descripcion)
             VALUES ($1, $2, $3)
             ON CONFLICT (id_estudio, codigo_cie10) DO NOTHING', v_schema)
            USING v_id_estudio, p_diagnostico, COALESCE(p_descripcion, 'Sin descripcion');
    END IF;

    INSERT INTO auditoria.outbox_eventos
        (tipo_evento, id_estudio, region, payload, estado)
    VALUES (
        'ESTUDIO_CREADO',
        v_id_estudio,
        p_region,
        jsonb_build_object(
            'id_estudio', v_id_estudio,
            'id_paciente', p_id_paciente,
            'id_tipo', p_id_tipo,
            'id_medico', p_id_medico,
            'resultado', p_resultado,
            'diagnostico', p_diagnostico
        ),
        'PENDIENTE'
    );

    RETURN v_id_estudio;
END;
$$;

-- --------------------------------------------------------------------------
-- Registro transaccional local + sincronizacion analitica (patron outbox).
-- Es un PROCEDURE para poder hacer COMMIT: la sincronizacion con MongoDB se
-- ejecuta solo despues de que la transaccion local quedo confirmada.
-- Uso (fuera de un BEGIN explicito):
--   CALL operativo.sp_registrar_estudio('san_jose', 10001, 3, 501,
--        '{"hallazgo": "..."}'::jsonb, 'R10.4', 'Descripcion', NULL);
-- --------------------------------------------------------------------------
DROP FUNCTION IF EXISTS operativo.sp_registrar_estudio(text, integer, integer, integer, jsonb, varchar, text);

CREATE OR REPLACE PROCEDURE operativo.sp_registrar_estudio(
    p_region      text,
    p_id_paciente integer,
    p_id_tipo     integer,
    p_id_medico   integer,
    p_resultado   jsonb,
    p_diagnostico varchar(10) DEFAULT NULL,
    p_descripcion text DEFAULT NULL,
    INOUT p_id_estudio integer DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sync_ok boolean;
BEGIN
    p_id_estudio := operativo.fn_registrar_estudio_local(
        p_region, p_id_paciente, p_id_tipo, p_id_medico,
        p_resultado, p_diagnostico, p_descripcion);

    -- 1) Confirmar la transaccion local (estudio + outbox PENDIENTE).
    COMMIT;

    -- 2) Solo entonces escribir en MongoDB. Si falla, el estudio no se
    --    pierde y el evento queda PENDIENTE para sp_reintentar_outbox().
    v_sync_ok := operativo.fn_sincronizar_estudio(p_id_estudio, p_region);

    IF NOT v_sync_ok THEN
        RAISE NOTICE 'Estudio % creado. La sincronizacion con MongoDB quedo pendiente en el outbox.', p_id_estudio;
    END IF;
END;
$$;

-- --------------------------------------------------------------------------
-- Reintenta todos los eventos pendientes del outbox.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION operativo.sp_reintentar_outbox()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    e       record;
    v_ok    integer := 0;
BEGIN
    FOR e IN
        SELECT id_estudio, region
        FROM auditoria.outbox_eventos
        WHERE estado <> 'SINCRONIZADO'
        ORDER BY id_evento
    LOOP
        IF operativo.fn_sincronizar_estudio(e.id_estudio, e.region) THEN
            v_ok := v_ok + 1;
        END IF;
    END LOOP;

    RETURN v_ok;
END;
$$;

-- --------------------------------------------------------------------------
-- Exportacion inicial/completa de estudios locales hacia MongoDB.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION operativo.sp_exportar_todos_estudios()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    e    record;
    v_ok integer := 0;
BEGIN
    FOR e IN
        SELECT id_estudio, region
        FROM operativo.v_estudios_todos
        ORDER BY region, id_estudio
    LOOP
        IF operativo.fn_sincronizar_estudio(e.id_estudio, e.region) THEN
            v_ok := v_ok + 1;
        END IF;
    END LOOP;

    RETURN v_ok;
END;
$$;

-- --------------------------------------------------------------------------
-- Exportacion de reportes agregados: PostgreSQL calcula los indicadores
-- mensuales por sucursal (sobre las 3 regiones) y los reemplaza en la
-- coleccion indicadores_mensuales de MongoDB via mongo_fdw.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION operativo.sp_exportar_indicadores()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_count integer;
BEGIN
    DELETE FROM reportes_ext.indicadores_mensuales;

    INSERT INTO reportes_ext.indicadores_mensuales
        (periodo, id_sucursal, sucursal, total_estudios, ingresos, ticket_promedio)
    SELECT  to_char(e.fecha AT TIME ZONE 'America/Costa_Rica', 'YYYY-MM'),
            e.id_sucursal,
            e.sucursal,
            count(*)::integer,
            sum(t.precio_base)::numeric(12,2),
            round(avg(t.precio_base), 2)::numeric(12,2)
    FROM operativo.v_estudios_todos e
    JOIN catalogo.tipo_estudio t ON t.id_tipo = e.id_tipo
    GROUP BY 1, 2, 3;

    GET DIAGNOSTICS v_count = ROW_COUNT;

    INSERT INTO auditoria.bitacora_sincronizacion
        (id_estudio, region, operacion, resultado, detalle)
    VALUES
        (NULL, 'todas', 'EXPORT_INDICADORES', 'OK', format('%s indicadores exportados', v_count));

    RETURN v_count;
END;
$$;

-- --------------------------------------------------------------------------
-- Privilegios. Las funciones son ejecutables por PUBLIC por defecto; se
-- restringen y se otorgan solo al perfil interno de MongoDB.
-- sp_registrar_estudio no es SECURITY DEFINER (PostgreSQL no permite COMMIT
-- dentro de un procedimiento SECURITY DEFINER), por eso lo ejecuta el rol
-- administrador / operativo y no un perfil de integracion.
-- --------------------------------------------------------------------------
REVOKE ALL ON FUNCTION operativo.fn_sincronizar_estudio(integer, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION operativo.fn_registrar_estudio_local(text, integer, integer, integer, jsonb, varchar, text) FROM PUBLIC;
REVOKE ALL ON PROCEDURE operativo.sp_registrar_estudio(text, integer, integer, integer, jsonb, varchar, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION operativo.sp_reintentar_outbox() FROM PUBLIC;
REVOKE ALL ON FUNCTION operativo.sp_exportar_todos_estudios() FROM PUBLIC;
REVOKE ALL ON FUNCTION operativo.sp_exportar_indicadores() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION operativo.fn_schema_region(text) TO :"fdw_mongo_user";
GRANT EXECUTE ON FUNCTION operativo.fn_sincronizar_estudio(integer, text) TO :"fdw_mongo_user";
GRANT EXECUTE ON FUNCTION operativo.sp_reintentar_outbox() TO :"fdw_mongo_user";
GRANT EXECUTE ON FUNCTION operativo.sp_exportar_todos_estudios() TO :"fdw_mongo_user";
GRANT EXECUTE ON FUNCTION operativo.sp_exportar_indicadores() TO :"fdw_mongo_user";

DO $$
BEGIN
    RAISE NOTICE 'Procedimientos de integracion creados.';
END $$;
