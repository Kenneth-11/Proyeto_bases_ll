:on error exit

USE [$(DbName)];
GO

IF SCHEMA_ID(N'integracion') IS NULL
    EXEC(N'CREATE SCHEMA integracion AUTHORIZATION dbo;');
GO

-- --------------------------------------------------------------------------
-- Segmentacion vertical: solo columnas necesarias para interoperabilidad.
-- --------------------------------------------------------------------------
IF OBJECT_ID(N'integracion.instituciones', N'U') IS NULL
BEGIN
    CREATE TABLE integracion.instituciones (
        codigo_institucion VARCHAR(20)  NOT NULL CONSTRAINT PK_instituciones PRIMARY KEY,
        nombre             VARCHAR(120) NOT NULL,
        tipo               VARCHAR(30)  NOT NULL,
        CONSTRAINT CK_instituciones_tipo CHECK (tipo IN ('ASEGURADORA', 'HOSPITAL', 'MINISTERIO'))
    );
END
GO

IF OBJECT_ID(N'integracion.convenios', N'U') IS NULL
BEGIN
    CREATE TABLE integracion.convenios (
        id_convenio            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_convenios PRIMARY KEY,
        id_aseguradora         INT           NOT NULL,
        nombre                 VARCHAR(120)  NOT NULL,
        porcentaje_cobertura   DECIMAL(5,2)  NOT NULL,
        vigencia_inicio        DATE          NOT NULL,
        vigencia_fin           DATE          NULL,
        CONSTRAINT CK_convenios_cobertura CHECK (porcentaje_cobertura BETWEEN 0 AND 100),
        CONSTRAINT UQ_convenios_aseguradora_nombre UNIQUE (id_aseguradora, nombre)
    );
END
GO

IF OBJECT_ID(N'integracion.paciente_integracion', N'U') IS NULL
BEGIN
    CREATE TABLE integracion.paciente_integracion (
        id_paciente         INT          NOT NULL CONSTRAINT PK_paciente_integracion PRIMARY KEY,
        id_aseguradora      INT          NOT NULL,
        codigo_externo      VARCHAR(40)  NOT NULL,
        estado_facturacion  VARCHAR(20)  NOT NULL,
        actualizado_en      DATETIME2(0) NOT NULL CONSTRAINT DF_paciente_integracion_act DEFAULT SYSDATETIME(),
        CONSTRAINT CK_paciente_integracion_estado
            CHECK (estado_facturacion IN ('PENDIENTE', 'PAGADA', 'RECHAZADA', 'EXONERADA'))
    );
END
GO

IF OBJECT_ID(N'integracion.facturas_externas', N'U') IS NULL
BEGIN
    CREATE TABLE integracion.facturas_externas (
        id_factura          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_facturas_externas PRIMARY KEY,
        numero_factura      VARCHAR(40)  NOT NULL CONSTRAINT UQ_facturas_numero UNIQUE,
        id_paciente         INT           NOT NULL,
        codigo_institucion  VARCHAR(20)   NOT NULL,
        monto               DECIMAL(12,2) NOT NULL,
        fecha               DATE          NOT NULL,
        estado              VARCHAR(20)   NOT NULL,
        CONSTRAINT FK_facturas_institucion FOREIGN KEY (codigo_institucion)
            REFERENCES integracion.instituciones (codigo_institucion),
        CONSTRAINT CK_facturas_monto CHECK (monto >= 0),
        CONSTRAINT CK_facturas_estado CHECK (estado IN ('PENDIENTE', 'PAGADA', 'RECHAZADA', 'EXONERADA'))
    );
END
GO

IF OBJECT_ID(N'integracion.resumen_facturacion', N'U') IS NULL
BEGIN
    CREATE TABLE integracion.resumen_facturacion (
        id_paciente          INT           NOT NULL CONSTRAINT PK_resumen_facturacion PRIMARY KEY,
        total_facturado      DECIMAL(12,2) NOT NULL CONSTRAINT DF_resumen_total DEFAULT (0),
        facturas_pendientes  INT           NOT NULL CONSTRAINT DF_resumen_pendientes DEFAULT (0),
        ultima_fecha         DATE          NULL,
        calculado_en         DATETIME2(0)  NOT NULL CONSTRAINT DF_resumen_calculado DEFAULT SYSDATETIME()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_facturas_paciente' AND object_id = OBJECT_ID('integracion.facturas_externas'))
    CREATE INDEX IX_facturas_paciente ON integracion.facturas_externas (id_paciente);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_paciente_integracion_estado' AND object_id = OBJECT_ID('integracion.paciente_integracion'))
    CREATE INDEX IX_paciente_integracion_estado ON integracion.paciente_integracion (estado_facturacion);
GO

PRINT 'Esquema de integracion creado.';
GO
