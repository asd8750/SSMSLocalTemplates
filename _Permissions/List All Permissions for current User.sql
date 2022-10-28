WITH objects AS (
	SELECT objects.name AS object_name,
		   schemas.name AS schema_name,
		   object_id, objects.type_desc AS object_type
	FROM   sys.objects
			 JOIN sys.schemas
				ON objects.schema_id = schemas.SCHEMA_ID
	WHERE objects.parent_object_id = 0 
         --no constraints that have the parent_object_id reference or triggers
		)
	SELECT 'OBJECT'  AS permission_set,
			object_type,
		   schema_name, 
		   object_name ,
		   permissions.permission_name 
	FROM objects
	        CROSS APPLY fn_my_permissions(schema_name + '.' +  OBJECT_NAME, 
                                                                  'Object') AS permissions   
	WHERE  permissions.subentity_name = '' --I am ignoring column level permissions. 
	  --hide this object from view
	  AND  NOT (objects.schema_name = 'Utility' 
                    AND objects.object_name = 'EffectiveSecurity')
	
	UNION ALL
	SELECT 'ASSEMBLY',
		   'ASSEMBLY' AS object_type,
			'' AS schema_name,
			assemblies.name AS object_name,
			permissions.permission_name
	FROM sys.assemblies
		CROSS APPLY fn_my_permissions(QUOTENAME(assemblies.name), 
                                                               'ASSEMBLY') AS permissions  
	UNION ALL
	
	SELECT 'APPLICATION ROLE',
		   'APPLICATION ROLE' AS object_type,
			'' AS schema_name,
			database_principals.name AS object_name,
			permissions.permission_name
	FROM sys.database_principals
		CROSS APPLY fn_my_permissions(QUOTENAME(database_principals.name), 
                                                      'APPLICATION ROLE') AS permissions 	
	
	UNION ALL
	SELECT 'ASYMMETRIC KEY',
		   'ASYMMETRIC KEY' AS object_type,
			'' AS schema_name,
			asymmetric_keys.name AS object_name,
			permissions.permission_name
	FROM sys.asymmetric_keys
		CROSS APPLY fn_my_permissions(QUOTENAME(asymmetric_keys.name), 
                                                        'ASYMMETRIC KEY') AS permissions  
	UNION ALL
	SELECT 'AVAILABILITY GROUP',
		   'AVAILABILITY GROUP' AS object_type,
			'' AS schema_name,
			availability_groups.name AS object_name,
			permissions.permission_name
	FROM sys.availability_groups
		CROSS APPLY fn_my_permissions(QUOTENAME(availability_groups.name), 
                                                    'AVAILABILITY GROUP') AS permissions  
	UNION ALL
	SELECT 'CERTIFICATE',
		   'CERTIFICATE' AS object_type,
			'' AS schema_name,
			certificates.name AS object_name,
			permissions.permission_name
	FROM sys.certificates
		CROSS APPLY fn_my_permissions(QUOTENAME(certificates.name), 
                                                           'CERTIFICATE') AS permissions  
	
	UNION ALL
	SELECT 'CONTRACT',
		   'CONTRACT' AS object_type,
			'' AS schema_name,
			service_contracts.name AS object_name,
			permissions.permission_name
	FROM sys.service_contracts
		CROSS APPLY fn_my_permissions(QUOTENAME(service_contracts.name), 
                                                           'CONTRACT') AS permissions  
	UNION ALL
	SELECT 'DATABASE' AS permission_set,
			'' AS object_type,
			'' AS schema_name,
			'' AS object_name,
			permissions.permission_name
	FROM    fn_my_permissions(NULL, 'DATABASE') AS permissions 
	UNION ALL
	SELECT 'DATABASE SCOPED CREDENTIAL',
		   'DATABASE SCOPED CREDENTIAL' AS object_type,
			'' AS schema_name,
			database_scoped_credentials.name AS object_name,
			permissions.permission_name
	FROM sys.database_scoped_credentials
		CROSS APPLY fn_my_permissions(QUOTENAME(database_scoped_credentials.name), 
					    'DATABASE SCOPED CREDENTIAL') AS permissions
	UNION ALL
	SELECT 'ENDPOINT',
		   'ENDPOINT' AS object_type,
			'' AS schema_name,
			endpoints.name AS object_name,
			permissions.permission_name
	FROM sys.endpoints
		CROSS APPLY fn_my_permissions(QUOTENAME(endpoints.name), 
                                                              'ENDPOINT') AS permissions  
	UNION ALL
	SELECT 'FULLTEXT CATALOG',
		   'FULLTEXT CATALOG' AS object_type,
			'' AS schema_name,
			fulltext_catalogs.name AS object_name,
			permissions.permission_name
	FROM sys.fulltext_catalogs
		CROSS APPLY fn_my_permissions(QUOTENAME(fulltext_catalogs.name), 
                                                       'FULLTEXT CATALOG') AS permissions  
	UNION ALL
	SELECT 'FULLTEXT STOPLIST',
		   'FULLTEXT STOPLIST' AS object_type,
			'' AS schema_name,
			fulltext_stoplists.name AS object_name,
			permissions.permission_name
	FROM sys.fulltext_stoplists
		CROSS APPLY fn_my_permissions(QUOTENAME(fulltext_stoplists.name), 
                                                      'FULLTEXT STOPLIST') AS permissions  
	
	UNION ALL
	SELECT 'LOGIN',
		   'LOGIN' AS object_type,
			'' AS schema_name,
			server_principals.name AS object_name,
			permissions.permission_name
	FROM sys.server_principals
		CROSS APPLY fn_my_permissions(QUOTENAME(server_principals.name), 
                                                                  'LOGIN') AS permissions 
	WHERE type_desc <> 'SERVER_ROLE'
	UNION ALL
	SELECT 'MESSAGE TYPE',
		   'MESSAGE TYPE' AS object_type,
			'' AS schema_name,
			service_message_types.name AS object_name,
			permissions.permission_name
	FROM sys.service_message_types
		CROSS APPLY fn_my_permissions(QUOTENAME(service_message_types.name), 
                                                           'MESSAGE TYPE') AS permissions 
	
	UNION ALL
 
	SELECT 'REMOTE SERVICE BINDING',
	       'REMOTE SERVICE BINDING' AS object_type,
	       '' AS schema_name,
               remote_service_bindings.name AS object_name,
	       permissions.permission_name
	FROM sys.remote_service_bindings
		CROSS APPLY fn_my_permissions(QUOTENAME(remote_service_bindings.name), 
                                                 'REMOTE SERVICE BINDING') AS permissions 
	UNION ALL
	SELECT 'ROLE',
		   'ROLE' AS object_type,
			'' AS schema_name,
			database_principals.name AS object_name,
			permissions.permission_name
	FROM sys.database_principals
		CROSS APPLY fn_my_permissions(QUOTENAME(database_principals.name), 
                                                                  'ROLE') AS permissions 	
	WHERE name NOT LIKE ('db~_%') ESCAPE '~'
	  AND name <> 'public'
 
	UNION ALL
 
	SELECT 'ROUTE',
		   'ROUTE' AS object_type,
			'' AS schema_name,
			routes.name AS object_name,
			permissions.permission_name
	FROM sys.routes
		CROSS APPLY fn_my_permissions(QUOTENAME(routes.name), 
                                                                 'ROUTE') AS permissions  
	
	UNION ALL
	SELECT 'SCHEMA',
			'SCHEMA' AS object_type,
			schemas.name AS schema_name,
			'' AS object_name,
			permissions.permission_name
	FROM    sys.schemas
	           CROSS APPLY fn_my_permissions(QUOTENAME(schemas.name), 
                                                              'SCHEMA') AS permissions 
        --don't include the schemas that should not be used
        WHERE	schemas.name NOT IN ('INFORMATION_SCHEMA','sys','guest')
	  AND   schemas.name NOT LIKE ('db~_%') ESCAPE '~'
 
	UNION ALL
 
	SELECT 'SERVER' AS permission_set,
			'' AS object_type,
			'' AS schema_name,
			'' AS object_name,
			permissions.permission_name
	FROM    fn_my_permissions(NULL, 'SERVER') AS permissions 
	
	UNION ALL
 
	SELECT 'SERVER ROLE',
		   'SERVER ROLE' AS object_type,
			'' AS schema_name,
			server_principals.name AS object_name,
			permissions.permission_name
	FROM sys.server_principals
		CROSS APPLY fn_my_permissions(QUOTENAME(server_principals.name), 
                                                          'SERVER ROLE') AS permissions 
	WHERE type_desc = 'SERVER_ROLE'
 
	UNION ALL
 
	SELECT 'SERVICE',
		   'SERVICE' AS object_type,
			'' AS schema_name,
			--the column is case sensitive. This could return > 1 row 
                        --that your query sees as one if you grouped
			--on it, but this is a very low probability
			services.name COLLATE DATABASE_DEFAULT AS object_name,
			permissions.permission_name
	FROM sys.services
		CROSS APPLY fn_my_permissions(QUOTENAME(services.name), 
                                                              'SERVICE') AS permissions  
	UNION ALL
	SELECT 'SYMMETRIC KEY',
		   'SYMMETRIC KEY' AS object_type,
			'' AS schema_name,
			symmetric_keys.name AS object_name,
			permissions.permission_name
	FROM sys.symmetric_keys
		CROSS APPLY fn_my_permissions(QUOTENAME(symmetric_keys.name), 
                                                        'SYMMETRIC KEY') AS permissions  
		
	UNION ALL
 
	SELECT 'TYPE',
	       'TYPE' AS object_type,
	       '' AS schema_name,
	       types.name AS object_name,
	       permissions.permission_name
	FROM sys.types
		CROSS APPLY fn_my_permissions(QUOTENAME(types.name), 
                                                                 'TYPE') AS permissions 
	WHERE is_user_defined = 1
 
	UNION ALL
 
	SELECT 'USER',
	       'USER' AS object_type,
	       '' AS schema_name,
	       database_principals.name AS object_name,
	       permissions.permission_name
	FROM sys.database_principals
		CROSS APPLY fn_my_permissions(QUOTENAME(database_principals.name), 
                                                                'USER') AS permissions 	
	WHERE	name NOT IN ('INFORMATION_SCHEMA','sys','guest')
 
	UNION ALL
 
	SELECT 'XML SCHEMA COLLECTION',
	       'XML SCHEMA COLLECTION' AS object_type,
	       '' AS schema_name,
	       xml_schema_collections.name AS object_name,
	       permissions.permission_name
	FROM sys.xml_schema_collections
		CROSS APPLY fn_my_permissions(QUOTENAME(xml_schema_collections.name), 
                                                 'XML SCHEMA COLLECTION') AS permissions 
