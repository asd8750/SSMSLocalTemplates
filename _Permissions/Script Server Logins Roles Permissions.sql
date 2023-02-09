																						  -- Scripting Out the Logins, Server Role Assignments, and Server Permissions
-- ************************************************************************************************************************
-- Copyright © 2015 by JP Chen of DatAvail Corporation
-- This script is free for non-commercial purposes with no warranties. 

--	F. LaForest - Create a temp table to hold all output so only one select is needed at the sne

-- CRITICAL NOTE: You’ll need to change your results to display more characters in the query result.
-- Under Tools –> Options –> Query Results –> SQL Server –> Results to Text to increase the maximum number of characters 
-- returned to 8192 the maximum or to a number high enough to prevent the results being truncated.
-- ************************************************************************************************************************
SET NOCOUNT ON

IF OBJECT_ID('tempdb..#Cmds') IS NOT NULL
	DROP TABLE #Cmds;
CREATE TABLE #Cmds ( Seq INT NOT NULL IDENTITY(1,1), Cmd VARCHAR(2000));

-- Scripting Out the Logins To Be Created
INSERT INTO #CMDS (Cmd)
SELECT 'IF (SUSER_ID('+QUOTENAME(SP.name,'''')+') IS NULL) BEGIN CREATE LOGIN ' +QUOTENAME(SP.name)+
			   CASE 
					WHEN SP.type_desc = 'SQL_LOGIN' THEN ' WITH PASSWORD = ' +CONVERT(NVARCHAR(MAX),SL.password_hash,1)+ ' HASHED, CHECK_EXPIRATION = ' 
						+ CASE WHEN SL.is_expiration_checked = 1 THEN 'ON' ELSE 'OFF' END +', CHECK_POLICY = ' +CASE WHEN SL.is_policy_checked = 1 THEN 'ON,' ELSE 'OFF,' END
					ELSE ' FROM WINDOWS WITH'
				END 
	   +' DEFAULT_DATABASE=[' +SP.default_database_name+ ']' +
		CASE WHEN (SP.default_language_name IS NOT NULL) THEN ', DEFAULT_LANGUAGE=[' +SP.default_language_name+ '] ' ELSE '' END + 'END;' COLLATE SQL_Latin1_General_CP1_CI_AS AS [-- Logins To Be Created --]
FROM sys.server_principals AS SP LEFT JOIN sys.sql_logins AS SL
		ON SP.principal_id = SL.principal_id
WHERE SP.type IN ('S','G','U')
		AND SP.name NOT LIKE '##%##'
		AND SP.name NOT LIKE 'NT AUTHORITY%'
		AND SP.name NOT LIKE 'NT SERVICE%'
		AND SP.name <> ('sa')
ORDER BY SP.[name];

-- Scripting Out the Role Membership to Be Added
INSERT INTO #CMDS (Cmd)
SELECT 
'EXEC master..sp_addsrvrolemember @loginame = N''' + SL.name + ''', @rolename = N''' + SR.name + '''
' AS [-- Server Roles the Logins Need to be Added --]
FROM master.sys.server_role_members SRM
	JOIN master.sys.server_principals SR ON SR.principal_id = SRM.role_principal_id
	JOIN master.sys.server_principals SL ON SL.principal_id = SRM.member_principal_id
WHERE SL.type IN ('S','G','U')
		AND SL.name NOT LIKE '##%##'
		AND SL.name NOT LIKE 'NT AUTHORITY%'
		AND SL.name NOT LIKE 'NT SERVICE%'
		AND SL.name <> ('sa')
ORDER BY SL.[name];

-- Scripting out the Permissions to Be Granted
INSERT INTO #CMDS (Cmd)
SELECT 
	CASE WHEN SrvPerm.state_desc <> 'GRANT_WITH_GRANT_OPTION' 
		THEN SrvPerm.state_desc 
		ELSE 'GRANT' 
	END
    + ' ' + SrvPerm.permission_name + ' TO [' + SP.name + ']' + 
	CASE WHEN SrvPerm.state_desc <> 'GRANT_WITH_GRANT_OPTION' 
		THEN '' 
		ELSE ' WITH GRANT OPTION' 
	END collate database_default AS [-- Server Level Permissions to Be Granted --] 
FROM sys.server_permissions AS SrvPerm 
	JOIN sys.server_principals AS SP ON SrvPerm.grantee_principal_id = SP.principal_id 
WHERE   SP.type IN ( 'S', 'U', 'G' ) 
		AND SP.name NOT LIKE '##%##'
		AND SP.name NOT LIKE 'NT AUTHORITY%'
		AND SP.name NOT LIKE 'NT SERVICE%'
		AND SP.name <> ('sa')
		ORDER BY SP.[name];

SELECT	Cmd
	FROM #Cmds
	ORDER BY Seq;

DROP TABLE #Cmds;

SET NOCOUNT OFF