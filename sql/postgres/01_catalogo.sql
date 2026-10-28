\set ON_ERROR_STOP on

CREATE SCHEMA IF NOT EXISTS catalogo;
CREATE SCHEMA IF NOT EXISTS operativo;
CREATE SCHEMA IF NOT EXISTS auditoria;

CREATE TABLE IF NOT EXISTS catalogo.sucursal (
    id_sucursal integer PRIMARY KEY,
    nombre      varchar(80)  NOT NULL,
    region      varchar(80)  NOT NULL UNIQUE,
    direccion   text
);

CREATE TABLE IF NOT EXISTS catalogo.tipo_estudio (
    id_tipo      integer PRIMARY KEY,
    codigo       varchar(20)  NOT NULL UNIQUE,
    nombre       varchar(120) NOT NULL,
    precio_base  numeric(12,2) NOT NULL CHECK (precio_base >= 0),
    modalidad    varchar(40)  NOT NULL
);

CREATE TABLE IF NOT EXISTS catalogo.medico (
    id_medico    integer PRIMARY KEY,
    cedula       varchar(20)  NOT NULL UNIQUE,
    nombre       varchar(120) NOT NULL,
    especialidad varchar(80)  NOT NULL,
    id_sucursal  integer      NOT NULL REFERENCES catalogo.sucursal (id_sucursal)
);

CREATE TABLE IF NOT EXISTS catalogo.aseguradora (
    id_aseguradora integer PRIMARY KEY,
    nombre         varchar(120) NOT NULL,
    codigo_externo varchar(40)  NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS auditoria.outbox_eventos (
    id_evento       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_evento     varchar(40)  NOT NULL,
    id_estudio      integer      NOT NULL,
    region          varchar(40)  NOT NULL,
    payload         jsonb        NOT NULL,
    estado          varchar(20)  NOT NULL DEFAULT 'PENDIENTE',
    intentos        integer      NOT NULL DEFAULT 0,
    creado_en       timestamptz  NOT NULL DEFAULT now(),
    sincronizado_en timestamptz,
    ultimo_error    text,
    CONSTRAINT ck_outbox_estado CHECK (estado IN ('PENDIENTE', 'SINCRONIZADO', 'ERROR'))
);

CREATE INDEX IF NOT EXISTS ix_outbox_pendientes
    ON auditoria.outbox_eventos (estado, creado_en);

CREATE TABLE IF NOT EXISTS auditoria.bitacora_sincronizacion (
    id_bitacora  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_estudio   integer,
    region       varchar(40),
    operacion    varchar(40) NOT NULL,
    resultado    varchar(20) NOT NULL,
    detalle      text,
    ejecutado_en timestamptz NOT NULL DEFAULT now()
);
