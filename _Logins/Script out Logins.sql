USE [master]
GO

/****** Object:  UserDefinedFunction [dbo].[fn_hexadecimal]    ****/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[fn_hexadecimal]
    (
      -- Add the parameters for the function here
      @binvalue VARBINARY(256)
    )
RETURNS VARCHAR(256)
AS
    BEGIN

        DECLARE @charvalue VARCHAR(256)
        DECLARE @i INT
        DECLARE @length INT
        DECLARE @hexstring CHAR(16)
        SELECT  @charvalue = '0x'
        SELECT  @i = 1
        SELECT  @length = DATALENGTH(@binvalue)
        SELECT  @hexstring = '0123456789ABCDEF' 
        WHILE ( @i <= @length )
            BEGIN
                DECLARE @tempint INT
                DECLARE @firstint INT
                DECLARE @secondint INT
                SELECT  @tempint = CONVERT(INT, SUBSTRING(@binvalue, @i, 1))
                SELECT  @firstint = FLOOR(@tempint / 16)
                SELECT  @secondint = @tempint - ( @firstint * 16 )
                SELECT  @charvalue = @charvalue + SUBSTRING(@hexstring, @firstint + 1, 1) + SUBSTRING(@hexstring, @secondint + 1, 1)
                SELECT  @i = @i + 1
            END
        RETURN @charvalue

    END
GO


SET NOCOUNT ON
GO
--use MASTER
GO
PRINT '-----------------------------------------------------------------------------'
PRINT '-- Script created on ' + CAST(GETDATE() AS VARCHAR(100))
PRINT '-----------------------------------------------------------------------------'
PRINT ''
PRINT '-----------------------------------------------------------------------------'
PRINT '-- Create the windows logins'
PRINT '-----------------------------------------------------------------------------'
SELECT  'IF NOT EXISTS (SELECT * FROM master.sys.server_principals WHERE [name] = ''' + [name] + ''')
    CREATE LOGIN [' + [name] + '] FROM WINDOWS WITH DEFAULT_DATABASE=[' + default_database_name + '], DEFAULT_LANGUAGE=[us_english]
GO

'
FROM    master.sys.server_principals
WHERE   type_desc IN ( 'WINDOWS_GROUP', 'WINDOWS_LOGIN' )
        AND [name] NOT LIKE 'BUILTIN%'
        AND [NAME] NOT LIKE 'NT AUTHORITY%'
        AND [name] NOT LIKE '%\SQLServer%'
ORDER BY [name]
GO

PRINT '-----------------------------------------------------------------------------'
PRINT '-- Create the SQL Logins'
PRINT '-----------------------------------------------------------------------------'
SELECT  'IF NOT EXISTS (SELECT * FROM master.sys.sql_logins WHERE [name] = ''' + [name] + ''')
    CREATE LOGIN [' + [name] + '] 
        WITH PASSWORD=' + [master].[dbo].[fn_hexadecimal](password_hash) + ' HASHED,
        SID = ' + [master].[dbo].[fn_hexadecimal]([sid]) + ',  
        DEFAULT_DATABASE=[' + default_database_name + '], DEFAULT_LANGUAGE=[us_english], 
        CHECK_EXPIRATION=' + CASE WHEN is_expiration_checked = 1 THEN 'ON'
                                  ELSE 'OFF'
                             END + ', CHECK_POLICY=OFF
GO
IF EXISTS (SELECT * FROM master.sys.sql_logins WHERE [name] = ''' + [name] + ''')
    ALTER LOGIN [' + [name] + ']
        WITH CHECK_EXPIRATION=' + CASE WHEN is_expiration_checked = 1 THEN 'ON'
                                       ELSE 'OFF'
                                  END + ', CHECK_POLICY=' + CASE WHEN is_policy_checked = 1 THEN 'ON'
                                                                 ELSE 'OFF'
                                                            END + '
GO


'
--[name], [sid] , password_hash 
FROM    master.sys.sql_logins
WHERE   type_desc = 'SQL_LOGIN'
        AND [name] NOT IN ( 'sa', 'guest' )
ORDER BY [name]

PRINT '-----------------------------------------------------------------------------'
PRINT '-- Disable any logins'
PRINT '-----------------------------------------------------------------------------'
SELECT  'ALTER LOGIN [' + [name] + '] DISABLE
GO
'
FROM    master.sys.server_principals
WHERE   is_disabled = 1

PRINT '-----------------------------------------------------------------------------'
PRINT '-- Assign groups'
PRINT '-----------------------------------------------------------------------------'
SELECT  'EXEC master..sp_addsrvrolemember @loginame = N''' + l.name + ''', @rolename = N''' + r.name + '''
GO

'
FROM    master.sys.server_role_members rm
        JOIN master.sys.server_principals r ON r.principal_id = rm.role_principal_id
        JOIN master.sys.server_principals l ON l.principal_id = rm.member_principal_id
WHERE   l.[name] NOT IN ( 'sa' )
        AND l.[name] NOT LIKE 'BUILTIN%'
        AND l.[NAME] NOT LIKE 'NT AUTHORITY%'
        AND l.[name] NOT LIKE '%\SQLServer%'
