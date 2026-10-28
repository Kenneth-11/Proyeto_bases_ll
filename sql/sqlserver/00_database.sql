:on error exit

IF DB_ID(N'$(DbName)') IS NULL
BEGIN
    CREATE DATABASE [$(DbName)];
END
GO

ALTER DATABASE [$(DbName)] SET RECOVERY SIMPLE;
GO

PRINT 'Base de datos $(DbName) lista.';
GO
