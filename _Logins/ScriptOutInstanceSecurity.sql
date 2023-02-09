																						  -- Scripting Out the Logins, Server Role Assignments, and Server Permissions
-- ************************************************************************************************************************
-- Copyright © 2015 by JP Chen of DatAvail Corporation
-- This script is free for non-commercial purposes with no warranties. 

-- CRITICAL NOTE: You’ll need to change your results to display more characters in the query result.
-- Under Tools –> Options –> Query Results –> SQL Server –> Results to Text to increase the maximum number of characters 
-- returned to 8192 the maximum or to a number high enough to prevent the results being truncated.
-- ************************************************************************************************************************
--
--	Updated: 2019-06-26 F.LaForest - Remove DEFAULT LANGUAGE when none specified
--			 2020-06-10 F.LaForest - Correct GRANT permission to Endpoint
--			 2020-09-04 F.LaForest - Add "SID=" to the SQL Login statement
--			 2021-04-19 F.LaForest - Correct ENdpoint grant formet
--			 2021-05-17 F.LaForest - Set login default database in a separate ALTER LOGIN command
-- 

DECLARE @oldPlant VARCHAR(24) = 'PGT1';
DECLARE @newPlant VARCHAR(24) = 'PGT1';

DECLARE @crlf  CHAR(2) = CHAR(13)+CHAR(10);

IF OBJECT_ID('tempdb..#cmdlist') IS NOT NULL
	DROP TABLE #cmdlist;

CREATE TABLE #cmdlist (
		ID INT IDENTITY(1,1) NOT NULL,
		LoginName VARCHAR(128) NOT NULL,
		CMD VARCHAR(2000) NOT NULL
			);
			
SET NOCOUNT ON
-- Scripting Out the Logins To Be Created
INSERT INTO #cmdlist (LoginName, CMD)
SELECT  SP.name AS LoginName,
		'IF (SUSER_ID('+QUOTENAME(SP.name,'''')+') IS NULL) BEGIN '
		+ 'CREATE LOGIN ' +QUOTENAME(SP.name)
			 +  CASE 
					WHEN SP.type_desc = 'SQL_LOGIN' THEN ' WITH PASSWORD = ' +CONVERT(NVARCHAR(MAX),SL.password_hash,1)+ @crlf +' HASHED, ' + 
					        ' SID = ' + CONVERT(NVARCHAR(MAX),SL.[sid],1) + @crlf 
						+ ', CHECK_EXPIRATION = ' 
						+ IIF(SL.is_expiration_checked = 1, 'ON', 'OFF') 
						+ ', CHECK_POLICY = ' + IIF(SL.is_policy_checked = 1, 'ON', 'OFF')
						+ IIF(NOT SP.default_language_name IS NULL, ', DEFAULT_LANGUAGE=[' +SP.default_language_name+ ']','')
					ELSE ' FROM WINDOWS ' +  IIF(NOT SP.default_language_name IS NULL, 'WITH DEFAULT_LANGUAGE=[' +SP.default_language_name+ ']','')
				END 
	 --  +' DEFAULT_DATABASE=[' +SP.default_database_name+ ']' 
	 --  + CASE WHEN (NOT SP.default_language_name IS NULL) THEN ', DEFAULT_LANGUAGE=[' +SP.default_language_name+ ']' ELSE '' END 
	   + IIF(SP.default_database_name <> 'master', @crlf + 'ALTER LOGIN '+QUOTENAME(SP.name,'[')+' WITH DEFAULT_DATABASE = '+QUOTENAME(SP.default_database_name,'['), '') +' END;' COLLATE SQL_Latin1_General_CP1_CI_AS AS [-- Logins To Be Created --]
FROM sys.server_principals AS SP 
		LEFT JOIN sys.sql_logins AS SL
			ON SP.principal_id = SL.principal_id
WHERE SP.type IN ('S','G','U')
		AND SP.name NOT LIKE '##%##'
		AND SP.name NOT LIKE 'NT AUTHORITY%'
		AND SP.name NOT LIKE 'NT SERVICE%'
		AND SP.name NOT LIKE 'AG_In_%'
		AND SP.name <> ('sa')
ORDER BY SP.[type_desc], SP.[name];

--
-- Create Server ROles
--
INSERT INTO #cmdlist (LoginName, CMD)

SELECT	'__' + SP.[name] AS LoginName,
		'IF NOT EXISTS (SELECT [name] from master.sys.server_principals WHERE [name] = ' +
				QUOTENAME(SP.[name], '''') + ' and [type] = ''R'')' + CHAR(13) + CHAR(10) +
				'	CREATE SERVER ROLE ' + QUOTENAME(SP.[name], '[') +' AUTHORIZATION [sa];' + CHAR(13) + CHAR(10) AS Command
	FROM sys.server_principals AS SP 
	WHERE (SP.[type] IN ('R'))
		--AND (SP.[is_fixed_role] <> 1)
		AND (SP.[principal_id] > 10 )
		AND (SP.[name] NOT IN ('public'))
	ORDER BY SP.[name];

-- Scripting Out the Role Membership to Be Added
INSERT INTO #cmdlist (LoginName, CMD)
SELECT SL.name AS LoginName,
'EXEC master..sp_addsrvrolemember @loginame = N''' + SL.name + ''', @rolename = N''' + SR.name + '''
' AS [-- Server Roles the Logins Need to be Added --]
FROM master.sys.server_principals SR
	INNER JOIN master.sys.server_role_members SRM ON SR.principal_id = SRM.role_principal_id
	INNER JOIN master.sys.server_principals SL ON SL.principal_id = SRM.member_principal_id
WHERE (SL.type IN ('S','G','U'))
		AND (SL.name NOT LIKE '##%##' AND
		 SL.name NOT LIKE 'NT AUTHORITY%'
		AND SL.name NOT LIKE 'AG_In_%'
		AND SL.name NOT LIKE 'NT SERVICE%'
		AND SL.name <> 'sa')
		AND (SR.[type] IN ('R'))
ORDER BY SL.[name];

-- Scripting out the Permissions to Be Granted
INSERT INTO #cmdlist (LoginName, CMD)
SELECT SP.name AS LoginName,
       CASE
           WHEN SrvPerm.state_desc <> 'GRANT_WITH_GRANT_OPTION' THEN
               SrvPerm.state_desc
           ELSE
               'GRANT'
       END + ' ' + 
	   SrvPerm.permission_name + 
	   CASE WHEN SrvPerm.class_desc = 'ENDPOINT'
				THEN 
					' ON ENDPOINT::[' + ISNULL(EP.[name],'') + '] '
				ELSE ' ' END +
	   ' TO [' + SP.name + '] ' +
	   CASE
			WHEN SrvPerm.state_desc <> 'GRANT_WITH_GRANT_OPTION ' THEN
				''
			ELSE
				' WITH GRANT OPTION '
	   END COLLATE DATABASE_DEFAULT AS [-- Server Level Permissions to Be Granted --]
       --,SrvPerm.class,
       --SrvPerm.class_desc,
       --SrvPerm.major_id,
       --SrvPerm.minor_id
   FROM sys.server_permissions AS SrvPerm
       INNER JOIN sys.server_principals AS SP
         ON (SrvPerm.grantee_principal_id = SP.principal_id)
	   LEFT OUTER JOIN sys.endpoints EP
			ON (SrvPerm.class = 105) AND (SrvPerm.major_id = EP.endpoint_id)
   WHERE
    SP.type IN ( 'S', 'G', 'U' )
    AND SP.name NOT LIKE '##%##'
    AND SP.name NOT LIKE 'NT AUTHORITY%'
    AND SP.name NOT LIKE 'NT SERVICE%'
    AND SP.name NOT LIKE 'm_*$'
    AND SP.name NOT LIKE 'g_*$'
    AND SP.name NOT LIKE 'AG_In_%'
    AND SP.name <> ( 'sa' )
   ORDER BY
    LoginName,
    SrvPerm.permission_name

--
--  Adjust command for new plant name
--
UPDATE #cmdlist
	SET CMD = REPLACE(CMD, @oldPlant, @newPlant)
	WHERE (CHARINDEX(@oldPlant, CMD) > 0)

SELECT LoginName, CMD	
	FROM #cmdlist
	ORDER BY LoginName, ID;

DROP TABLE #cmdlist;

SET NOCOUNT OFF


---  SELECT * FROM sys.server_principals AS SP 