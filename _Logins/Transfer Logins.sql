-- Usage
-- Populate @list variable below with account(s),comma delimited list to script. 
-- Save output to recreate:Login,Default DB,Server Roles,DB Access,DB Roles,DB Object Permissions.
-- NOTE:
-- Stored procedures are created in Master, but are deleted
-- to limit by database see section /*Get a table with dbs where login has access*/ and change the where clause
-- to script all logins, see section /*To Script all sql and windows logins...
/*****************************Start Create needed procedures***************************/
USE master
GO
IF OBJECT_ID('usp_hexadecimal') IS NOT NULL
    DROP PROCEDURE usp_hexadecimal
GO
CREATE PROCEDURE usp_hexadecimal
    @binvalue VARBINARY(256) ,
    @hexvalue VARCHAR(514) OUTPUT
AS
    DECLARE @charvalue VARCHAR(514)
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
    SELECT  @hexvalue = @charvalue
GO

IF OBJECT_ID('Transfer_login_2005_2008') IS NOT NULL
    DROP PROCEDURE Transfer_login_2005_2008
GO
CREATE PROCEDURE Transfer_login_2005_2008
    @login_name sysname = NULL
AS
    DECLARE @name sysname
    DECLARE @type VARCHAR(1)
    DECLARE @hasaccess INT
    DECLARE @denylogin INT
    DECLARE @is_disabled INT
    DECLARE @PWD_varbinary VARBINARY(256)
    DECLARE @PWD_string VARCHAR(514)
    DECLARE @SID_varbinary VARBINARY(85)
    DECLARE @SID_string VARCHAR(514)
    DECLARE @tmpstr VARCHAR(1024)
    DECLARE @is_policy_checked VARCHAR(3)
    DECLARE @is_expiration_checked VARCHAR(3)
    DECLARE @defaultdb sysname

    IF ( @login_name IS NULL )
        DECLARE login_curs CURSOR
        FOR
            SELECT  p.sid ,
                    p.name ,
                    p.type ,
                    p.is_disabled ,
                    p.default_database_name ,
                    l.hasaccess ,
                    l.denylogin
            FROM    sys.server_principals p
                    LEFT JOIN sys.syslogins l ON ( l.name = p.name )
            WHERE   p.type IN ( 'S', 'G', 'U' )
                    AND p.name <> 'sa'
    ELSE
        DECLARE login_curs CURSOR
        FOR
            SELECT  p.sid ,
                    p.name ,
                    p.type ,
                    p.is_disabled ,
                    p.default_database_name ,
                    l.hasaccess ,
                    l.denylogin
            FROM    sys.server_principals p
                    LEFT JOIN sys.syslogins l ON ( l.name = p.name )
            WHERE   p.type IN ( 'S', 'G', 'U' )
                    AND p.name = @login_name
    OPEN login_curs
    FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @type, @is_disabled, @defaultdb, @hasaccess, @denylogin
    IF ( @@fetch_status = -1 )
        BEGIN
            PRINT '--No login(s) found.'
            CLOSE login_curs
            DEALLOCATE login_curs
            RETURN -1
        END
    SET @tmpstr = '/* Transfer_login_2005_2008 script '
--PRINT @tmpstr
    SET @tmpstr = '** Generated ' + CONVERT (VARCHAR, GETDATE()) + ' on ' + @@SERVERNAME + ' */'
--PRINT @tmpstr
--PRINT ''
    WHILE ( @@fetch_status <> -1 )
        BEGIN
            IF ( @@fetch_status <> -2 )
                BEGIN
                    PRINT ''
                    SET @tmpstr = '-- Login: ' + @name
                    PRINT @tmpstr
                    IF ( @type IN ( 'G', 'U' ) )
                        BEGIN -- NT authenticated account/group
                            SET @tmpstr = 'CREATE LOGIN ' + QUOTENAME(@name) + ' FROM WINDOWS WITH DEFAULT_DATABASE = [' + @defaultdb + ']'
                        END
                    ELSE
                        BEGIN -- SQL Server authentication
-- obtain password and sid
                            SET @PWD_varbinary = CAST(LOGINPROPERTY(@name, 'PasswordHash') AS varbinary(256))
                            EXEC usp_hexadecimal @PWD_varbinary, @PWD_string OUT
                            EXEC usp_hexadecimal @SID_varbinary, @SID_string OUT

-- obtain password policy state
                            SELECT  @is_policy_checked = CASE is_policy_checked
                                                           WHEN 1 THEN 'ON'
                                                           WHEN 0 THEN 'OFF'
                                                           ELSE NULL
                                                         END
                            FROM    sys.sql_logins
                            WHERE   name = @name
                            SELECT  @is_expiration_checked = CASE is_expiration_checked
                                                               WHEN 1 THEN 'ON'
                                                               WHEN 0 THEN 'OFF'
                                                               ELSE NULL
                                                             END
                            FROM    sys.sql_logins
                            WHERE   name = @name

                            SET @tmpstr = 'CREATE LOGIN ' + QUOTENAME(@name) + ' WITH PASSWORD = ' + @PWD_string + ' HASHED, SID = ' + @SID_string
                                + ', DEFAULT_DATABASE = [' + @defaultdb + ']'
                            IF ( @is_policy_checked IS NOT NULL )
                                BEGIN
                                    SET @tmpstr = @tmpstr + ', CHECK_POLICY = ' + @is_policy_checked
                                END
                            IF ( @is_expiration_checked IS NOT NULL )
                                BEGIN
                                    SET @tmpstr = @tmpstr + ', CHECK_EXPIRATION = ' + @is_expiration_checked
                                END
                        END
                    IF ( @denylogin = 1 )
                        BEGIN -- login is denied access
                            SET @tmpstr = @tmpstr + '; DENY CONNECT SQL TO ' + QUOTENAME(@name)
                        END
                    ELSE
                        IF ( @hasaccess = 0 )
                            BEGIN -- login exists but does not have access
                                SET @tmpstr = @tmpstr + '; REVOKE CONNECT SQL TO ' + QUOTENAME(@name)
                            END
                    IF ( @is_disabled = 1 )
                        BEGIN -- login is disabled
                            SET @tmpstr = @tmpstr + '; ALTER LOGIN ' + QUOTENAME(@name) + ' DISABLE'
                        END
                    PRINT @tmpstr
                END
            FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @type, @is_disabled, @defaultdb, @hasaccess, @denylogin
        END
    CLOSE login_curs
    DEALLOCATE login_curs
    RETURN 0
GO
/*****************************End Create needed procedures***************************/
SET NOCOUNT ON
DECLARE @List VARCHAR(8000) ,
    @DatabaseUserName sysname ,
    @DB_principal_id SMALLINT ,
    @ServerUserName sysname ,
    @RoleName sysname ,
    @DB_Name sysname ,
    @cmd VARCHAR(MAX) ,
    @default_schema_name sysname ,
    @DB_Nam sysname ,
    @state_desc sysname ,
    @permission_name sysname ,
    @schema_name sysname ,
    @object_name sysname ,
    @user_name sysname 
/******************************************USER LIST HERE******************************/
/*E.G. 'User1, user3,domain\user1,domain\user2'*/
SET @List = 'ip'
/*To Script all sql and windows logins uncomment below, note this may re-create undesired accounts and 
should be modified in the where clause when needed*/
--select @list = isnull(@list,'') + [name] + ',' from master.sys.server_principals where type in ('S','U','G','R','C','K')
IF RIGHT(@List, 1) <> ','
    BEGIN
        SET @List = @List + ',' 
    END
CREATE TABLE ##DB_USERs
    (
      Name sysname ,
      DatabaseUserID SMALLINT NULL ,
      ServerUserName sysname NULL ,
      default_schema_name sysname NULL
    )
CREATE TABLE ##DB_Roles ( Name sysname )

CREATE TABLE ##syspermissions
    (
      [DB_Name] [sysname] NULL ,
      [state_desc] [sysname] NULL ,
      [permission_name] [sysname] NULL ,
      [schema_name] [sysname] NULL ,
      [object_name] [sysname] NULL ,
      [user_name] [sysname] NULL ,
      [principal_id] [INT] NULL
    )

CREATE TABLE ##SRV_Roles
    (
      SERVERROLE VARCHAR(100) ,
      MEMBERNAME VARCHAR(100) ,
      MEMBERSID VARBINARY(85)
    )
/*Loop thru file_list*/
WHILE @List <> ''
    BEGIN
        SET @DatabaseUserName = LEFT(@List, CHARINDEX(',', @List) - 1) 
        PRINT '--BEGIN ' + @DatabaseUserName + ' ************************************'
        PRINT '--********Begin Script the Login ********************************************************'
/*Script login with password*/
        EXECUTE Transfer_login_2005_2008 @DatabaseUserName
        PRINT 'GO'


/*GET SERVER ROLES INTO TEMPORARY TABLE*/
        SET @CMD = '[MASTER].[DBO].[SP_HELPSRVROLEMEMBER]'
        INSERT  INTO ##SRV_Roles
                EXEC ( @CMD
                    )

        SET @CMD = ''
        SELECT  @CMD = @CMD + 'EXEC sp_addsrvrolemember @loginame = ' + CHAR(39) + MemberName + CHAR(39) + ', @rolename = ' + CHAR(39) + ServerRole + CHAR(39)
                + CHAR(10) + 'GO' + CHAR(10)
        FROM    ##SRV_Roles
        WHERE   MemberName = @DatabaseUserName
        PRINT '--Assign Server Roles'
        PRINT @CMD
        DELETE  ##SRV_Roles
        PRINT '--********End Script the Login *********************************************************'
        PRINT ''

/*Get a table with dbs where login has access*/
        SET @DB_Name = ''
        WHILE @DB_Name IS NOT NULL
            BEGIN
                SELECT  @DB_Name = MIN(name)
                FROM    master.sys.databases
                WHERE   /*limit by database if needed*/
                        name > @DB_Name
--and name in ('Accounting','CAMDW_DST','Employee','FFS_Staging','HRTraining')
                IF @DB_Name IS NULL
                    BREAK
                SET @cmd = 'insert ##DB_USERs
SELECT ' + CHAR(39) + @DB_Name + CHAR(39) + ',' + 'u.[principal_id],
l.[name],
u.default_schema_name
FROM ' + '[' + @DB_Name + '].[sys].[database_principals] u
INNER JOIN [master].[sys].[server_principals] l
ON u.[sid] = l.[sid]
WHERE 
u.[name] = ' + CHAR(39) + @DatabaseUserName + CHAR(39)
                EXEC (@cmd)
            END

/*Add users/roles/object permissions to databases*/
        SET @DB_Name = ''
        WHILE @DB_Name IS NOT NULL
            BEGIN
                SELECT  @DB_Name = MIN(name)
                FROM    ##DB_USERs
                WHERE   name > @DB_Name 
                IF @DB_Name IS NULL
                    BREAK
                PRINT '/************Begin Database ' + @DB_Name + ' ****************/'
                SELECT  @ServerUserName = ServerUserName ,
                        @DB_principal_id = DatabaseUserID ,
                        @default_schema_name = default_schema_name
                FROM    ##DB_USERs
                WHERE   name = @DB_Name
                SET @cmd = 'USE [' + @DB_Name + '];' + CHAR(10) + 'CREATE USER [' + @DatabaseUserName + ']' + CHAR(10) + CHAR(9) + 'FOR LOGIN ['
                    + @ServerUserName + ']' + CHAR(10) + CHAR(9) + 'With DEFAULT_SCHEMA = [' + @default_schema_name + ']' + CHAR(10) + 'GO' 
                PRINT '--Add user to databases'
                PRINT @cmd

/*Populate roles for this user*/
                SELECT  @cmd = 'Insert ##DB_Roles
Select name
FROM ' + '[' + @DB_Name + '].[sys].[database_principals]
WHERE
[principal_id] IN (SELECT [role_principal_id] FROM [' + @DB_Name + '].[sys].[database_role_members] WHERE [member_principal_id] = '
                        + CAST(@DB_principal_id AS VARCHAR(25)) + ')'
--Print @cmd
                EXEC (@cmd)

/*Add user to roles*/
                SET @cmd = ''
                SELECT  @cmd = ISNULL(@cmd, '') + 'EXEC [sp_addrolemember]' + CHAR(10) + CHAR(9) + '@rolename = ''' + Name + ''',' + CHAR(10) + CHAR(9)
                        + '@membername = ''' + @DatabaseUserName + '''' + CHAR(10) + 'GO' + CHAR(10)
                FROM    ##DB_Roles
                IF LEN(@cmd) > 0
                    PRINT '--Add user to role(s)'
                PRINT @cmd

                DELETE  ##DB_Roles

/*Object Permissions*/
                SET @cmd = '
Insert ##syspermissions
select ' + CHAR(39) + @DB_Name + CHAR(39) + ',a.[state_desc],a.[permission_name], d.[name],b.[name],c.[name],c.[principal_id] 
from ' + '[' + @DB_Name + '].sys.database_permissions A
JOIN ' + '[' + @DB_Name + '].[sys].[objects] b 
ON A.major_id = B.object_id
JOIN ' + '[' + @DB_Name + '].[sys].[database_principals] c
ON grantee_principal_id = c.principal_id
JOIN ' + '[' + @DB_Name + '].sys.schemas d
ON b.schema_id = d.schema_id'
                EXEC (@cmd)
                IF EXISTS ( SELECT  1
                            FROM    ##syspermissions
                            WHERE   principal_id = @DB_principal_id )
                    PRINT '--Assign specific object permissions'

                DECLARE crs_Permissions CURSOR LOCAL FORWARD_ONLY READ_ONLY
                FOR
                    SELECT  [DB_Name] ,
                            [state_desc] ,
                            [permission_name] ,
                            [schema_name] ,
                            [object_name] ,
                            [user_name]
                    FROM    ##syspermissions
                    WHERE   principal_id = @DB_principal_id
                OPEN crs_Permissions
                FETCH NEXT FROM crs_Permissions INTO @DB_Name, @state_desc, @permission_name, @schema_name, @object_name, @user_name 
                WHILE @@FETCH_STATUS = 0
                    BEGIN
                        SET @cmd = @state_desc + ' ' + @permission_name + ' ON [' + @schema_name + '].[' + @object_name + '] TO [' + @user_name + ']'
                        PRINT @cmd
                        FETCH NEXT FROM crs_Permissions INTO @DB_Name, @state_desc, @permission_name, @schema_name, @object_name, @user_name 
                    END
                CLOSE crs_Permissions
                DEALLOCATE crs_Permissions

                DELETE  ##syspermissions


                PRINT '/************End Database ' + @DB_Name + ' ****************/'
                PRINT ''
/*next db*/
            END
        PRINT '--END ' + @DatabaseUserName + ' ************************************'
        PRINT ''
/*Parse the list down*/
        SET @List = RIGHT(@List, DATALENGTH(@List) - CHARINDEX(',', @List)) 
/*Clear data for the last user*/
        DELETE  ##DB_USERs 
    END
/*Clean up*/
DROP TABLE ##DB_USERs
DROP TABLE ##DB_Roles
DROP TABLE ##syspermissions
DROP TABLE ##SRV_Roles
USE master
DROP PROCEDURE Transfer_login_2005_2008
DROP PROCEDURE usp_hexadecimal

