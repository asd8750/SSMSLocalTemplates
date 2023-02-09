SET NOCOUNT ON;

DECLARE @srcInstanceName VARCHAR(100) = 'EDR1SQL01S821\SRM';
--DECLARE @dstInstanceName VARCHAR(100) = 'PBG2SQL01T104.fs.local';
DECLARE @dstInstanceName VARCHAR(100) = 'EDR1SQL01S820\SRM';

DECLARE @srcLinkedSvrName VARCHAR(100) = '_TEMP_LNK_SRC_';
DECLARE @dstLinkedSvrName VARCHAR(100) = '_TEMP_LNK_DST_';

--DECLARE @EmailAdd nvarchar(200)
--DECLARE @DBMailProfile varchar(20)
--DECLARE @EmailSubject varchar(500)
--DECLARE @TableHead varchar(max)
--DECLARE @TableTail varchar(max)
--DECLARE @Body nvarchar(max)
--DECLARE @svrNameTbl TABLE (row_id int IDENTITY(1,1) NOT NULL PRIMARY KEY, servername sysname)

--Change target recipient here
--SET @EmailAdd = 'siewshing.ang@firstsolar.com'
--SET @EmailAdd = 'fs111257@firstsolar.com'

--Retrive mail profile on the server
--SET @DBMailProfile = (SELECT TOP 1 name FROM msdb.dbo.sysmail_profile (NOLOCK))

--Set email subject
--SET @EmailSubject = 'Discrepancy settings on server '+ @localInstanceName+'!' 

--Prepare temporary tables needed for LOGINS
--
IF OBJECT_ID('tempdb..#srcLogins') IS NOT NULL
BEGIN
    DROP TABLE #srcLogins;
END;

IF OBJECT_ID('tempdb..#dstLogins') IS NOT NULL
BEGIN
    DROP TABLE #dstLogins;
END;

CREATE TABLE #srcLogins (
    LoginName sysname,
    LoginType VARCHAR(10),
    DefaultDB VARCHAR(256),
    Sid VARBINARY(1000),
    PasswordHash VARBINARY(1000));

CREATE TABLE #dstLogins (
    LoginName sysname,
    LoginType VARCHAR(10),
    DefaultDB VARCHAR(256),
    Sid VARBINARY(1000),
    PasswordHash VARBINARY(1000));

DECLARE @sqlFetchLogins VARCHAR(2000)
    = '
			SELECT sp.[name] AS LoginName,
				  -- sp.[type],
				   CASE
						WHEN sp.[type] = ''S'' THEN ''SQL''
						WHEN sp.[type] = ''U'' THEN ''ADUser''
						WHEN sp.[type] = ''G'' THEN ''ADGrp''
						ELSE sp.[type] END AS LoginType,
				   SP.default_database_name as DefaultDB,
				   sp.[sid] AS [Sid],
				   sl.password_hash AS PasswordHash
			  FROM <<LnkSrvr>>.master.sys.server_principals sp
			  LEFT OUTER JOIN <<LnkSrvr>>.master.sys.sql_logins sl
				ON (sp.[sid] = sl.[sid])
			 WHERE sp.[type] IN ( ''U'', ''G'', ''S'' )
			   AND (   sp.[name] NOT LIKE ''NT [AS]%\%''
				 AND   sp.[name] NOT LIKE ''##MS%''
				 AND   sp.[name] NOT LIKE ''AG_In_%''
				 AND   sp.[name] NOT LIKE ''BUILTIN%'');
';


--Prepare temporary tables needed for Server ROLES
--
IF OBJECT_ID('tempdb..#srcRoles') IS NOT NULL
BEGIN
    DROP TABLE #srcRoles;
END;

IF OBJECT_ID('tempdb..#dstRoles') IS NOT NULL
BEGIN
    DROP TABLE #dstRoles;
END;

CREATE TABLE #srcRoles (
    RoleName sysname,
    RoleSid VARBINARY(1000),
    RoleOwner sysname,
    MemberName sysname NULL,
    MemberSid VARBINARY(1000) NULL,
    FixedRole INT NULL,
    GrantAction VARCHAR(25) NULL,
    PermissionName VARCHAR(256) NULL,
    Grantor VARCHAR(256) NULL);

CREATE TABLE #dstRoles (
    RoleName sysname,
    RoleSid VARBINARY(1000),
    RoleOwner sysname NULL,
    MemberName sysname NULL,
    MemberSid VARBINARY(1000) NULL,
    FixedRole INT NULL,
    GrantAction VARCHAR(25) NULL,
    PermissionName VARCHAR(256) NULL,
    Grantor VARCHAR(256) NULL);

DECLARE @sqlFetchRoles VARCHAR(2000)
    = '
			SELECT DISTINCT r.name AS [RoleName],
					r.principal_id AS [RoleSid],
					ro.name AS [RoleOwner],
					rm.member_principal_id AS [MemberSid],
					l.name AS [MemberName],
					r.is_fixed_role AS [FixedRole],
					spr.state_desc AS [GrantAction],
					spr.[permission_name] AS [PermissionName],
					sprl.[name] AS [Grantor]
				FROM master.sys.server_principals r
					LEFT OUTER JOIN (
						master.sys.server_role_members rm
							INNER JOIN  master.sys.server_principals l
								ON (rm.member_principal_id = l.principal_id)
								)
						ON (r.principal_id = rm.role_principal_id)
					INNER JOIN master.sys.server_principals ro
						ON (r.owning_principal_id = ro.principal_id)
					LEFT OUTER JOIN sys.server_permissions AS spr
						ON (rm.role_principal_id  = spr.grantee_principal_id)
							AND (spr.[permission_name] IN ( ''VIEW SERVER STATE'', ''VIEW ANY DEFINITION'' ))
					LEFT OUTER JOIN master.sys.server_principals AS sprl
						ON (spr.grantor_principal_id = sprl.principal_id)
					WHERE (r.[type] IN ( ''R'' ));
 ';


--Prepare temporary tables needed for Created Commands
--
IF OBJECT_ID('tempdb..#syncCmds') IS NOT NULL
BEGIN
    DROP TABLE #syncCmds;
END;

CREATE TABLE #syncCmds (
    COrder INT,
    ClCmd VARCHAR(2000));

--
-- create a temp linked servers to the source and destination servers
--
IF EXISTS (   SELECT 1
                FROM master.sys.servers s
               WHERE (s.name = @srcLinkedSvrName))
BEGIN
    EXEC master.dbo.sp_dropserver @server = @srcLinkedSvrName;
END;
EXEC master.dbo.sp_addlinkedserver @server = @srcLinkedSvrName,
                                   @srvproduct = N'',
                                   @provider = N'SQLNCLI11',
                                   @datasrc = @srcInstanceName,
                                   @catalog = N'master';
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = @srcLinkedSvrName,
                                     @locallogin = NULL,
                                     @useself = N'True',
                                     @rmtpassword = NULL;
EXEC master.dbo.sp_serveroption @server = @srcLinkedSvrName,
                                @optname = N'data access',
                                @optvalue = N'true';
EXEC master.dbo.sp_serveroption @server = @srcLinkedSvrName,
                                @optname = N'rpc',
                                @optvalue = N'true';


IF EXISTS (   SELECT 1
                FROM master.sys.servers s
               WHERE (s.name = @dstLinkedSvrName))
BEGIN
    EXEC master.dbo.sp_dropserver @server = @dstLinkedSvrName;
END;
EXEC master.dbo.sp_addlinkedserver @server = @dstLinkedSvrName,
                                   @srvproduct = N'',
                                   @provider = N'SQLNCLI11',
                                   @datasrc = @dstInstanceName,
                                   @catalog = N'master';
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = @dstLinkedSvrName,
                                     @locallogin = NULL,
                                     @useself = N'True',
                                     @rmtpassword = NULL;
EXEC master.dbo.sp_serveroption @server = @dstLinkedSvrName,
                                @optname = N'data access',
                                @optvalue = N'true';
EXEC master.dbo.sp_serveroption @server = @dstLinkedSvrName,
                                @optname = N'rpc',
                                @optvalue = N'true';

--
--	Fetch the list of logins from each instance
--
DECLARE @rmtSql VARCHAR(2000);

SET @rmtSql = REPLACE(@sqlFetchLogins, '<<LnkSrvr>>', @srcLinkedSvrName);
INSERT INTO #srcLogins (LoginName,
                        LoginType,
                        DefaultDB,
                        [Sid],
                        PasswordHash)
EXECUTE (@rmtSql);

SET @rmtSql = REPLACE(@sqlFetchLogins, '<<LnkSrvr>>', @dstLinkedSvrName);
INSERT INTO #dstLogins (LoginName,
                        LoginType,
                        DefaultDB,
                        [Sid],
                        PasswordHash)
EXECUTE (@rmtSql);

--	
--	Compare the logins between both instances and create any the destination instances does not have
--
WITH MAD
  AS (SELECT 'CREATE LOGIN [' + SL.LoginName + '] FROM WINDOWS WITH DEFAULT_DATABASE=[' + SL.DefaultDB
             + '], DEFAULT_LANGUAGE=[us_english]' AS CLCmd
        FROM #srcLogins SL
        LEFT OUTER JOIN #dstLogins DL
          ON (SL.[Sid] = DL.[Sid])
       WHERE (DL.[Sid] IS NULL)
         AND (SL.LoginType IN ( 'ADUser', 'ADGrp' ))),
     MSQL
  AS (SELECT 'CREATE LOGIN [' + SL.LoginName + '] 
        WITH PASSWORD=0x' + CONVERT(VARCHAR(200), SL.PasswordHash, 2) + ' HASHED,
        SID = 0x' + CONVERT(VARCHAR(200), SL.[Sid], 2) + ',  
        DEFAULT_DATABASE=[' + SL.DefaultDB
             + '], DEFAULT_LANGUAGE=[us_english], 
        CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF' AS CLCmd
        FROM #srcLogins SL
        LEFT OUTER JOIN #dstLogins DL
          ON (SL.[Sid] = DL.[Sid])
       WHERE (DL.[Sid] IS NULL)
         AND (SL.LoginType IN ( 'SQL' )))
INSERT INTO #syncCmds (COrder,
                       ClCmd)
SELECT 1 AS COrder,
       MAD.CLCmd
  FROM MAD
UNION ALL
SELECT 1 AS COrder,
       MSQL.CLCmd
  FROM MSQL;


--
--	Fetch role data from each instance
--
SET @rmtSql
    = 'SELECT RoleName, RoleSid, RoleOwner, MemberName, MemberSid, FixedRole, GrantAction, PermissionName, Grantor FROM OPENQUERY('
      + QUOTENAME(@srcLinkedSvrName, '[') + ', ''' + REPLACE(@sqlFetchRoles, '''', '''''') + ''')';
--SELECT @rmtSql;
INSERT INTO #srcRoles (RoleName,
                       RoleSid,
                       RoleOwner,
                       MemberName,
                       MemberSid,
                       FixedRole,
                       GrantAction,
                       PermissionName,
                       Grantor)
EXECUTE (@rmtSql);

--SELECT @rmtSql;
SET @rmtSql
    = 'SELECT RoleName, RoleSid, RoleOwner, MemberName, MemberSid, FixedRole, GrantAction, PermissionName, Grantor FROM OPENQUERY('
      + QUOTENAME(@dstLinkedSvrName, '[') + ', ''' + REPLACE(@sqlFetchRoles, '''', '''''') + ''')';
INSERT INTO #dstRoles (RoleName,
                       RoleSid,
                       RoleOwner,
                       MemberName,
                       MemberSid,
                       FixedRole,
                       GrantAction,
                       PermissionName,
                       Grantor)
EXECUTE (@rmtSql);

--SELECT *
--  FROM #srcRoles
-- ORDER BY RoleName,
--          MemberName;
--SELECT *
--  FROM #dstRoles
-- ORDER BY RoleName,
--          MemberName;

--
--	Detect missing roles
--
WITH CSR
  AS (SELECT DISTINCT SR.RoleName,
             SR.RoleOwner,
             SR.MemberName,
             CASE
                  WHEN DR.RoleName IS NULL THEN 1
                  ELSE 0 END AS NeedRole
        FROM #srcRoles SR
        LEFT OUTER JOIN #dstRoles DR
          ON (SR.RoleName = DR.RoleName)
       WHERE (DR.RoleName IS NULL)
          OR (   (SR.MemberName IS NOT NULL)
           AND   (DR.MemberName IS NULL)))
INSERT INTO #syncCmds (COrder,
                       ClCmd)
SELECT DISTINCT 2 AS COrder,
       'CREATE SERVER ROLE ' + QUOTENAME(CSR.RoleName, '[') + ' AUTHORIZATION ' + QUOTENAME(CSR.RoleOwner, '[') + ';' AS ClCmd
  FROM CSR
 WHERE (NeedRole = 1)
UNION ALL
SELECT DISTINCT 3 AS COrder,
       'ALTER SERVER ROLE ' + QUOTENAME(CSR.RoleName, '[') + ' ADD MEMBER ' + QUOTENAME(CSR.MemberName, '[') + '' AS CLCmd
  FROM CSR
 WHERE (MemberName IS NOT NULL)
 ORDER BY COrder;


INSERT INTO #syncCmds (COrder,
                       ClCmd)
SELECT DISTINCT 5 AS COrder,
       'GRANT ' + SR.PermissionName + ' TO ' + QUOTENAME(SR.MemberName, '[') AS ClCmd
  FROM #srcRoles SR
  LEFT OUTER JOIN #dstRoles DR
    ON (SR.RoleName       = DR.RoleName)
   AND (SR.MemberName     = DR.MemberName)
   AND (SR.GrantAction    = DR.GrantAction)
   AND (SR.PermissionName = DR.PermissionName)
   AND (DR.GrantAction IS NOT NULL)
 WHERE (   (SR.MemberName IS NOT NULL)
     AND   (DR.MemberName IS NULL))
   AND (SR.GrantAction IS NOT NULL)
   AND (DR.PermissionName IS NULL);

--
--	Output the resulting update commands
--
SELECT COrder,
       ClCmd
  FROM #syncCmds
 ORDER BY COrder;


--	Remove temp objects
--
IF EXISTS (   SELECT 1
                FROM master.sys.servers s
               WHERE (s.name = @srcLinkedSvrName))
BEGIN
    EXEC master.dbo.sp_dropserver @server = @srcLinkedSvrName;
END;
IF EXISTS (   SELECT 1
                FROM master.sys.servers s
               WHERE (s.name = @dstLinkedSvrName))
BEGIN
    EXEC master.dbo.sp_dropserver @server = @dstLinkedSvrName;
END;

DROP TABLE #srcLogins;
DROP TABLE #dstLogins;

DROP TABLE #srcRoles;
DROP TABLE #dstRoles;
