--DATABASE ROLE PERMISSIONS
SELECT
       @@SERVERNAME ServerName,
       DB_NAME() DatabaseName,
       dppri.principal_id,
       dppri.sid,
       USER_NAME(dpperm.grantee_principal_id) AS [DatabaseRoleName],
       dppri.type_desc AS principal_type_desc,
       dpperm.class_desc,
       CASE 
              WHEN dpperm.class = 1 THEN OBJECT_NAME(dpperm.major_id) 
              WHEN dpperm.class = 3 THEN SCHEMA_NAME(dpperm.major_id)
       END AS [object_name],
       dpperm.permission_name,
       dpperm.state_desc AS permission_state_desc
FROM    sys.database_permissions dpperm
       INNER JOIN sys.database_principals dppri
              ON dpperm.grantee_principal_id = dppri.principal_id
WHERE dppri.type_desc = 'DATABASE_ROLE'
ORDER BY DatabaseRoleName


--DATABASE USER PERMISSIONS
SELECT
       @@SERVERNAME ServerName,
       DB_NAME() DatabaseName,
       dppri.principal_id,
       dppri.sid,
       USER_NAME(dpperm.grantee_principal_id) AS [DatabaseUserName],
       dppri.type_desc AS principal_type_desc,
       dpperm.class_desc,
       CASE 
              WHEN dpperm.class = 1 THEN OBJECT_NAME(dpperm.major_id) 
              WHEN dpperm.class = 3 THEN SCHEMA_NAME(dpperm.major_id)
       END AS [object_name],
       dpperm.permission_name,
       dpperm.state_desc AS permission_state_desc
FROM    sys.database_permissions dpperm
       INNER JOIN sys.database_principals dppri
              ON dpperm.grantee_principal_id = dppri.principal_id
WHERE dppri.type_desc <> 'DATABASE_ROLE'
ORDER BY DatabaseUserName

--DATABASE USERS IN ROLES
SELECT 
       @@SERVERNAME ServerName,
       DB_NAME() DatabaseName,
       dbpri.name AS DatabaseRoleName,   
       ISNULL (dbpri2.name, 'No members') AS DatabaseUserName,
       dbpri2.principal_id DatabaseUserName_principal_id,
       dbpri2.sid DatabaseUserName_sid
FROM sys.database_principals dbpri 
       LEFT OUTER JOIN sys.database_role_members drm ON drm.role_principal_id = dbpri.principal_id
       LEFT OUTER JOIN sys.database_principals dbpri2 ON drm.member_principal_id = dbpri2.principal_id
WHERE dbpri.type_desc = 'DATABASE_ROLE'
--WHERE ISNULL (dbpri2.name, 'No members') = @UserName
ORDER BY DatabaseRoleName


--SERVER ROLE PERMISSIONS
SELECT
       @@SERVERNAME ServerName,
       dppri.principal_id,
       dppri.sid,
       dppri.name AS [ServerRoleName],
       dppri.type_desc AS principal_type_desc,
       dpperm.class_desc,
       OBJECT_NAME(dpperm.major_id) AS [object_name],
       dpperm.permission_name,
       dpperm.state_desc AS permission_state_desc
FROM    sys.server_permissions dpperm
       RIGHT OUTER JOIN sys.server_principals dppri
              ON dpperm.grantee_principal_id = dppri.principal_id
WHERE dppri.type_desc = 'SERVER_ROLE'
ORDER BY [ServerRoleName]

--SERVER LOGINS PERMISSIONS
SELECT
       @@SERVERNAME ServerName,
       dppri.principal_id,
       dppri.sid,
       dppri.name AS [LoginName],
       dppri.type_desc AS principal_type_desc,
       dpperm.class_desc,
       OBJECT_NAME(dpperm.major_id) AS [object_name],
       dpperm.permission_name,
       dpperm.state_desc AS permission_state_desc
FROM    sys.server_permissions dpperm
       RIGHT OUTER JOIN sys.server_principals dppri
              ON dpperm.grantee_principal_id = dppri.principal_id
WHERE dppri.type_desc <> 'SERVER_ROLE'
ORDER BY [LoginName]

--SERVER LOGINS IN ROLES
SELECT 
       @@SERVERNAME ServerName,
       dbpri.name AS ServerRoleName,   
       ISNULL (dbpri2.name, 'No members') AS MemberLoginName,
       dbpri2.principal_id MemberLoginName_principal_id,
       dbpri2.sid MemberLoginName_sid
FROM sys.server_principals dbpri
       LEFT OUTER JOIN sys.server_role_members drm ON drm.role_principal_id = dbpri.principal_id
       LEFT OUTER JOIN sys.server_principals dbpri2 ON drm.member_principal_id = dbpri2.principal_id
       WHERE dbpri.type_desc = 'SERVER_ROLE'
ORDER BY ServerRoleName


