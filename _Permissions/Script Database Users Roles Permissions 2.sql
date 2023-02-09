/********************************************************************
 *                                                                  *
 * Author: John Eisbrener                                           *
 * Script Purpose: Script out Database Role Definition              *
 * Notes: Please report any bugs to http://www.dbaeyes.com/         *
 *                                                                  *
 * Update: 2014-03-03 - Adjusted output to accommodate Role         *
 *                      definitions that are longer than 8000 chars *
 * Update: 2013-09-03 - Added user output per Joe Spivey's comment  *
 *                    - Modified formatting for oddly named objects *
 *                    - Included support for Grants on DMVs         *
 * Update: 2019-03-07 - F.LaForest loop through all roles
 * Update: 2019-03-08 - F.LaForest loop thorugh all users to see all
 *					  - permissions
 * Update: 2019-06-13 - F.LaForest - Add database user script
 *		   2019-07-03 - F.LaForest - Add schema scripting
 *         2019-07-22 - F.LaForest - Added permissions to fixed db_roles
 *									 Removed scripting for users without logins
 *									 Role scripting and readability improvements
 *                                   Better filter on role/user list
 *******************************************************************/

--DECLARE @roleName VARCHAR(255)
--SET @roleName = 'DatabaseRoleName'
  
DECLARE @plantPrefixOld VARCHAR(16) = 'PGT1';
DECLARE @plantPrefixNew VARCHAR(16) = 'PGT1';

DECLARE @roleName VARCHAR(255);
DECLARE @newRoleName VARCHAR(255);
DECLARE @loginName VARCHAR(255);
DECLARE @oldLoginName VARCHAR(255);
DECLARE @pType    VARCHAR(255);
DECLARE @roleName2 VARCHAR(255);
DECLARE @roleDesc VARCHAR(MAX);
DECLARE @typeDesc VARCHAR(512);
DECLARE @typeOrder INT;
DECLARE @fixedRole INT;

DECLARE @crlf VARCHAR(2)

SET @crlf = CHAR(13) + CHAR(10);

SET @roleDesc = 'USE ' + QUOTENAME(DB_NAME(DB_ID()), '[') + @crlf + 'GO' + @crlf;
PRINT @roleDesc;

--
--	Output any schema creation statements
--
SELECT @roleDesc =  '------------------- Create Schemas: ' + @crlf +
					REPLACE(STUFF((SELECT ' IF NOT EXISTS (SELECT schema_id FROM sys.schemas WHERE [name] = ' + QUOTENAME(SCH.[name], '''') + ')' + '[crlf]' +
										'	EXEC(''CREATE SCHEMA ' + QUOTENAME(SCH.[name], '[') + ' AUTHORIZATION ' + QUOTENAME(DP.[name],'[') + ';'')' + '[crlf]'
									FROM sys.schemas SCH
										INNER JOIN sys.database_principals DP
											ON (SCH.principal_id = DP.principal_id)
									WHERE (SCH.[schema_id] < 16384)
										AND (SCH.[name] NOT IN ('dbo', 'sys', 'guest', 'INFORMATION_SCHEMA'))
									ORDER BY SCH.[name]
									FOR XML PATH('')), 1, 1, ''), '[crlf]', @crlf);

--
--	Loop and create database roles and permissions
--
DECLARE cur_Roles CURSOR FOR 
SELECT DISTINCT
	   dp.[name] AS RoleName,
	   REPLACE(dp.[name],@plantPrefixOld, @plantPrefixNew) AS newRoleName,
	   dp.[type] AS pType,
	   REPLACE(dp.[name],@plantPrefixOld, @plantPrefixNew) AS RoleName2,
	   SP.[name] AS OldLoginName,
	   REPLACE(ISNULL(SP.[name], ''),@plantPrefixOld, @plantPrefixNew) AS LoginName,
	   dp.is_fixed_role AS FixedRole,
	   dp.[type_desc] AS TypeDesc,
	   CASE dp.[type]
			WHEN 'R'  THEN 1
			WHEN 'S'  THEN 2
			WHEN 'U'  THEN 3
			WHEN 'G'  THEN 4
			ELSE 99
	   END AS TypeOrder
FROM sys.database_principals dp
    LEFT OUTER JOIN sys.database_permissions dperm
		ON (dp.principal_id = dperm.grantee_principal_id)
	LEFT OUTER JOIN sys.server_principals SP
		ON (DP.[sid] = SP.[sid])
	WHERE (dp.[name] NOT IN ('public', 'guest', 'dbo'))
	   AND  (
		   ((dp.[type] = 'R') AND (dp.is_fixed_role = 0)) OR
		   ((dp.[type] IN ('G', 'U', 'S')) AND (SP.[name] IS NOT NULL))
			)
	--	AND (dperm.permission_name NOT IN ('CONNECT'))
	ORDER BY TypeOrder, RoleName;

OPEN cur_Roles 
FETCH NEXT FROM cur_Roles INTO @roleName, @newRoleName, @pType, @RoleName2, @oldLoginName, @loginName, @fixedRole, @typeDesc, @typeOrder;   

WHILE (@@FETCH_STATUS = 0)
	BEGIN
--DECLARE @roleName VARCHAR(255)
--SET @roleName = 'MFG\zSvc_MesPGT2_SSIS'
		-- Script out the Role
	
		SET @roleDesc = @roleDesc + @crlf + '------------------- Role: ' + QUOTENAME(@newRoleName, '[') + '-- ' + @typeDesc + @crlf + @crlf;
		IF (@pType = 'R') AND (@fixedRole = 0)
			SET @roleDesc = @roleDesc + 'IF DATABASE_PRINCIPAL_ID('''+ @newRoleName +''') IS NULL ' + @crlf + '    CREATE ROLE [' + @newRoleName + ']' + @crlf + 'GO' + @crlf;
		ELSE IF (@pType IN ('G', 'U', 'S')) AND (@loginName <> '')
			SET @roleDesc = @roleDesc + 'IF DATABASE_PRINCIPAL_ID('''+ @newRoleName +''') IS NULL ' + @crlf + '    CREATE USER [' + @newRoleName + '] FROM LOGIN [' + @loginName + '];' + @crlf + 'GO' + @crlf
		ELSE
			SET @roleDesc = @roleDesc + '	------  No Login  ------' + @crlf + 'GO' + @crlf;;

		SELECT    @roleDesc = @roleDesc +
				CASE dp.state
					WHEN 'D' THEN 'DENY '
					WHEN 'G' THEN 'GRANT '
					WHEN 'R' THEN 'REVOKE '
					WHEN 'W' THEN 'GRANT '
				END + 
				dp.permission_name + ' ' +
				CASE dp.class
					WHEN 0 THEN ''
					WHEN 1 THEN --table or column subset on the table
						CASE WHEN dp.major_id < 0 THEN
							+ 'ON [sys].[' + OBJECT_NAME(dp.major_id) + '] '
						ELSE
							+ 'ON [' +
							(SELECT SCHEMA_NAME(schema_id) + '].[' + name FROM sys.objects WHERE object_id = dp.major_id)
								+ -- optionally concatenate column names
							CASE WHEN MAX(dp.minor_id) > 0 
								 THEN '] ([' + REPLACE(
												(SELECT name + '], [' 
												 FROM sys.columns 
												 WHERE object_id = dp.major_id 
													AND column_id IN (SELECT minor_id 
																	  FROM sys.database_permissions 
																	  WHERE major_id = dp.major_id
																		AND USER_NAME(grantee_principal_id) IN (@roleName)
																	 )
												 FOR XML PATH('')
												) --replace final square bracket pair
											+ '])', ', []', '')
								 ELSE ']'
							END + ' '
						END
					WHEN 3 THEN 'ON SCHEMA::[' + SCHEMA_NAME(dp.major_id) + '] '
					WHEN 4 THEN 'ON ' + (SELECT RIGHT(type_desc, 4) + '::[' + name FROM sys.database_principals WHERE principal_id = dp.major_id) + '] '
					WHEN 5 THEN 'ON ASSEMBLY::[' + (SELECT name FROM sys.assemblies WHERE assembly_id = dp.major_id) + '] '
					WHEN 6 THEN 'ON TYPE::[' + (SELECT name FROM sys.types WHERE user_type_id = dp.major_id) + '] '
					WHEN 10 THEN 'ON XML SCHEMA COLLECTION::[' + (SELECT SCHEMA_NAME(schema_id) + '.' + name FROM sys.xml_schema_collections WHERE xml_collection_id = dp.major_id) + '] '
					WHEN 15 THEN 'ON MESSAGE TYPE::[' + (SELECT name FROM sys.service_message_types WHERE message_type_id = dp.major_id) + '] '
					WHEN 16 THEN 'ON CONTRACT::[' + (SELECT name FROM sys.service_contracts WHERE service_contract_id = dp.major_id) + '] '
					WHEN 17 THEN 'ON SERVICE::[' + (SELECT name FROM sys.services WHERE service_id = dp.major_id) + '] '
					WHEN 18 THEN 'ON REMOTE SERVICE BINDING::[' + (SELECT name FROM sys.remote_service_bindings WHERE remote_service_binding_id = dp.major_id) + '] '
					WHEN 19 THEN 'ON ROUTE::[' + (SELECT name FROM sys.routes WHERE route_id = dp.major_id) + '] '
					WHEN 23 THEN 'ON FULLTEXT CATALOG::[' + (SELECT name FROM sys.fulltext_catalogs WHERE fulltext_catalog_id = dp.major_id) + '] '
					WHEN 24 THEN 'ON SYMMETRIC KEY::[' + (SELECT name FROM sys.symmetric_keys WHERE symmetric_key_id = dp.major_id) + '] '
					WHEN 25 THEN 'ON CERTIFICATE::[' + (SELECT name FROM sys.certificates WHERE certificate_id = dp.major_id) + '] '
					WHEN 26 THEN 'ON ASYMMETRIC KEY::[' + (SELECT name FROM sys.asymmetric_keys WHERE asymmetric_key_id = dp.major_id) + '] '
				 END COLLATE SQL_Latin1_General_CP1_CI_AS
				 + 'TO [' + @roleName2 + ']' + 
				 CASE dp.state WHEN 'W' THEN ' WITH GRANT OPTION' ELSE '' END + @crlf
		FROM    sys.database_permissions dp
		WHERE    USER_NAME(dp.grantee_principal_id) IN (@roleName)
			AND (dp.permission_name NOT IN ('CONNECT'))
		GROUP BY dp.state, dp.major_id, dp.permission_name, dp.class

		--SELECT @roleDesc = @roleDesc + 'GO' + @crlf 

		-- Display users within Role.  Code stubbed by Joe Spivey

		;WITH USR AS (
			SELECT	TOP (20000000)
					roles.[name] AS RoleName,
					REPLACE(roles.[name], @plantPrefixOld, @plantPrefixNew) AS NewRoleName,
					users.[name] AS UserName,
					REPLACE(users.[name], @plantPrefixOld, @plantPrefixNew) AS NewUserName
			FROM	sys.database_principals users
					INNER JOIN sys.database_role_members link 
						ON link.member_principal_id = users.principal_id
					INNER JOIN sys.database_principals roles 
						ON roles.principal_id = link.role_principal_id
			--WHERE	roles.[name] = @roleName
			WHERE	users.[name] = @oldLoginName
			ORDER BY roles.[name], users.[name] 
		)
			SELECT	@roleDesc = @roleDesc + 'IF IS_ROLEMEMBER(''' + USR.NewRoleName + ''', ''' + USR.NewUserName + ''') = 0' + @crlf +
											'    ALTER ROLE ' + QUOTENAME(USR.NewRoleName,'[') + ' ADD MEMBER ' + QUOTENAME(USR.NewUserName, '[') + @crlf
			FROM USR
			ORDER BY USR.RoleName, USR.UserName

		-- PRINT out in blocks of up to 8000 based on last \r\n
		DECLARE @printCur INT
		SET @printCur = 8000

		WHILE LEN(@roleDesc) > 8000
		BEGIN
			-- Reverse first 8000 characters and look for first lf cr (reversed crlf) as delimiter
			SET @printCur = 8000 - CHARINDEX(CHAR(10) + CHAR(13), REVERSE(SUBSTRING(@roleDesc, 0, 8000)))

			PRINT LEFT(@roleDesc, @printCur)
			SELECT @roleDesc = RIGHT(@roleDesc, LEN(@roleDesc) - @printCur)
		END

		PRINT @roleDesc + 'GO';
		SET @roleDesc = '';

		FETCH NEXT FROM cur_Roles INTO @roleName, @newRoleName, @pType, @RoleName2, @oldLoginName, @loginName, @fixedRole, @typeDesc, @typeOrder;  
	END;

CLOSE cur_Roles;
DEALLOCATE cur_Roles;
