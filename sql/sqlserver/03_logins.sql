:on error exit

USE [master];
GO

IF SUSER_ID(N'$(FdwUser)') IS NULL
BEGIN
    CREATE LOGIN [$(FdwUser)]
        WITH PASSWORD = N'$(FdwPassword)',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = OFF,
             DEFAULT_DATABASE = [$(DbName)];
END
ELSE
BEGIN
    ALTER LOGIN [$(FdwUser)] WITH PASSWORD = N'$(FdwPassword)';
END
GO

USE [$(DbName)];
GO

IF USER_ID(N'$(FdwUser)') IS NULL
BEGIN
    CREATE USER [$(FdwUser)] FOR LOGIN [$(FdwUser)];
END
GO

IF IS_ROLEMEMBER(N'db_datareader', N'$(FdwUser)') = 0
BEGIN
    ALTER ROLE db_datareader ADD MEMBER [$(FdwUser)];
END
GO

GRANT EXECUTE ON SCHEMA::integracion TO [$(FdwUser)];
GO

PRINT 'Login $(FdwUser) configurado con permisos minimos.';
GO
