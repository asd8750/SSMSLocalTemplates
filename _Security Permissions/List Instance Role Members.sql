SELECT p.name AS [Login name],
       r.type_desc AS [Role Type] ,
       r.is_disabled ,
       r.create_date ,
       r.modify_date ,
       r.default_database_name
FROM   sys.server_principals r
       INNER JOIN sys.server_role_members m ON r.principal_id = m.role_principal_id
       INNER JOIN sys.server_principals p ON p.principal_id = m.member_principal_id
WHERE  r.type = 'R'
       AND r.name = N'sysadmin'
	   AND ((p.name NOT LIKE 'NT SERVICE\%') AND (p.name NOT LIKE 'NT AUTHORITY\%'));
