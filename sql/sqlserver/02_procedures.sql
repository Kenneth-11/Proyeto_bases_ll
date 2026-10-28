:on error exit

USE [$(DbName)];
GO

CREATE OR ALTER PROCEDURE integracion.usp_RecalcularResumenPaciente
    @id_paciente INT
AS
BEGIN
    SET NOCOUNT ON;

    MERGE integracion.resumen_facturacion AS t
    USING (
        SELECT  pi.id_paciente,
                COALESCE(SUM(fe.monto), 0) AS total_facturado,
                COALESCE(SUM(CASE WHEN fe.estado = 'PENDIENTE' THEN 1 ELSE 0 END), 0) AS facturas_pendientes,
                MAX(fe.fecha) AS ultima_fecha
        FROM integracion.paciente_integracion pi
        LEFT JOIN integracion.facturas_externas fe
               ON fe.id_paciente = pi.id_paciente
        WHERE pi.id_paciente = @id_paciente
        GROUP BY pi.id_paciente
    ) AS s
    ON t.id_paciente = s.id_paciente
    WHEN MATCHED THEN
        UPDATE SET total_facturado     = s.total_facturado,
                   facturas_pendientes = s.facturas_pendientes,
                   ultima_fecha        = s.ultima_fecha,
                   calculado_en        = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (id_paciente, total_facturado, facturas_pendientes, ultima_fecha, calculado_en)
        VALUES (s.id_paciente, s.total_facturado, s.facturas_pendientes, s.ultima_fecha, SYSDATETIME());
END
GO

CREATE OR ALTER PROCEDURE integracion.usp_RecalcularResumenTodos
AS
BEGIN
    SET NOCOUNT ON;

    MERGE integracion.resumen_facturacion AS t
    USING (
        SELECT  pi.id_paciente,
                COALESCE(SUM(fe.monto), 0) AS total_facturado,
                COALESCE(SUM(CASE WHEN fe.estado = 'PENDIENTE' THEN 1 ELSE 0 END), 0) AS facturas_pendientes,
                MAX(fe.fecha) AS ultima_fecha
        FROM integracion.paciente_integracion pi
        LEFT JOIN integracion.facturas_externas fe
               ON fe.id_paciente = pi.id_paciente
        GROUP BY pi.id_paciente
    ) AS s
    ON t.id_paciente = s.id_paciente
    WHEN MATCHED THEN
        UPDATE SET total_facturado     = s.total_facturado,
                   facturas_pendientes = s.facturas_pendientes,
                   ultima_fecha        = s.ultima_fecha,
                   calculado_en        = SYSDATETIME()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (id_paciente, total_facturado, facturas_pendientes, ultima_fecha, calculado_en)
        VALUES (s.id_paciente, s.total_facturado, s.facturas_pendientes, s.ultima_fecha, SYSDATETIME())
    WHEN NOT MATCHED BY SOURCE THEN
        DELETE;
END
GO

CREATE OR ALTER PROCEDURE integracion.usp_RegistrarFactura
    @numero_factura     VARCHAR(40),
    @id_paciente        INT,
    @codigo_institucion VARCHAR(20),
    @monto              DECIMAL(12,2),
    @fecha              DATE,
    @estado             VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM integracion.paciente_integracion WHERE id_paciente = @id_paciente)
    BEGIN
        THROW 50001, 'El paciente no existe en integracion.', 1;
    END

    IF NOT EXISTS (SELECT 1 FROM integracion.instituciones WHERE codigo_institucion = @codigo_institucion)
    BEGIN
        THROW 50002, 'La institucion no existe.', 1;
    END

    IF EXISTS (SELECT 1 FROM integracion.facturas_externas WHERE numero_factura = @numero_factura)
    BEGIN
        THROW 50003, 'El numero de factura ya existe.', 1;
    END

    INSERT INTO integracion.facturas_externas
        (numero_factura, id_paciente, codigo_institucion, monto, fecha, estado)
    VALUES
        (@numero_factura, @id_paciente, @codigo_institucion, @monto, @fecha, @estado);

    EXEC integracion.usp_RecalcularResumenPaciente @id_paciente = @id_paciente;
END
GO

CREATE OR ALTER PROCEDURE integracion.usp_ActualizarEstadoFacturacion
    @id_paciente INT,
    @estado      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    IF @estado NOT IN ('PENDIENTE', 'PAGADA', 'RECHAZADA', 'EXONERADA')
    BEGIN
        THROW 50004, 'Estado de facturacion invalido.', 1;
    END

    UPDATE integracion.paciente_integracion
       SET estado_facturacion = @estado,
           actualizado_en     = SYSDATETIME()
     WHERE id_paciente = @id_paciente;

    IF @@ROWCOUNT = 0
    BEGIN
        THROW 50005, 'El paciente no existe en integracion.', 1;
    END
END
GO

CREATE OR ALTER PROCEDURE integracion.usp_ResumenPorInstitucion
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  i.nombre AS institucion,
            COUNT(DISTINCT fe.id_paciente) AS pacientes,
            COUNT(fe.id_factura)           AS facturas,
            SUM(fe.monto)                  AS monto_total,
            SUM(CASE WHEN fe.estado = 'PENDIENTE' THEN fe.monto ELSE 0 END) AS monto_pendiente
    FROM integracion.instituciones i
    LEFT JOIN integracion.facturas_externas fe
           ON fe.codigo_institucion = i.codigo_institucion
    GROUP BY i.nombre
    ORDER BY monto_total DESC;
END
GO

CREATE OR ALTER PROCEDURE integracion.usp_ResumenFacturacionPaciente
    @id_paciente INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  pi.id_paciente,
            pi.id_aseguradora,
            pi.codigo_externo,
            pi.estado_facturacion,
            r.total_facturado,
            r.facturas_pendientes,
            r.ultima_fecha,
            r.calculado_en
    FROM integracion.paciente_integracion pi
    LEFT JOIN integracion.resumen_facturacion r
           ON r.id_paciente = pi.id_paciente
    WHERE pi.id_paciente = @id_paciente;
END
GO

PRINT 'Procedimientos almacenados creados.';
GO
