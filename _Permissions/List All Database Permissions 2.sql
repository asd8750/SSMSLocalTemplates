SELECT DB_NAME() AS database_name,
       class,
       class_desc,
       major_id,
       minor_id,
       grantee_principal_id,
       grantor_principal_id,
       databasepermissions.type,
       permission_name,
       state,
       state_desc,
       granteedatabaseprincipal.name AS grantee_name,
       granteedatabaseprincipal.type_desc AS grantee_type_desc,
       granteeserverprincipal.name AS grantee_principal_name,
       granteeserverprincipal.type_desc AS grantee_principal_type_desc,
       grantor.name AS grantor_name,
       granted_on_name,
       permissionstatement + N' TO ' + QUOTENAME(granteedatabaseprincipal.name) + CASE
                                                                                      WHEN state = N'W' THEN
                                                                                          N' WITH GRANT OPTION'
                                                                                      ELSE
                                                                                          N''
                                                                                  END AS permissionstatement
FROM
(
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(CONVERT(NVARCHAR(MAX), DB_NAME())) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS AS permissionstatement
    FROM sys.database_permissions SP
    WHERE (SP.class = 0)
    UNION ALL
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(sys.schemas.name) + N'.' + QUOTENAME(sys.objects.name) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS + N' ON '
           + QUOTENAME(sys.schemas.name) + N'.' + QUOTENAME(sys.objects.name)
           + COALESCE(N' (' + QUOTENAME(sys.columns.name) + N')', N'') AS permissionstatement
    FROM sys.database_permissions SP
        INNER JOIN sys.objects
            ON sys.objects.object_id = SP.major_id
        INNER JOIN sys.schemas
            ON sys.schemas.schema_id = sys.objects.schema_id
        LEFT OUTER JOIN sys.columns
            ON sys.columns.object_id = SP.major_id
               AND sys.columns.column_id = SP.minor_id
    WHERE (SP.major_id >= 0)
          AND (SP.class = 1)
    UNION ALL
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(sys.schemas.name) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS + N' ON SCHEMA::'
           + QUOTENAME(sys.schemas.name) AS permissionstatement
    FROM sys.database_permissions SP
        INNER JOIN sys.schemas
            ON sys.schemas.schema_id = SP.major_id
    WHERE (SP.major_id >= 0)
          AND (SP.class = 3)
    UNION ALL
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(targetPrincipal.name) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS + N' ON '
           + targetPrincipal.type_desc + N'::' + QUOTENAME(targetPrincipal.name) AS permissionstatement
    FROM sys.database_permissions SP
        INNER JOIN sys.database_principals AS targetPrincipal
            ON targetPrincipal.principal_id = SP.major_id
    WHERE (SP.major_id >= 0)
          AND (SP.class = 4)
    UNION ALL
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(sys.assemblies.name) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS
           + N' ON ASSEMBLY::' + QUOTENAME(sys.assemblies.name) AS permissionstatement
    FROM sys.database_permissions SP
        INNER JOIN sys.assemblies
            ON sys.assemblies.assembly_id = SP.major_id
    WHERE (SP.major_id >= 0)
          AND (SP.class = 5)
    UNION ALL
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(sys.types.name) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS + N' ON TYPE::'
           + QUOTENAME(sys.types.name) AS permissionstatement
    FROM sys.database_permissions SP
        INNER JOIN sys.types
            ON sys.types.user_type_id = SP.major_id
    WHERE (SP.major_id >= 0)
          AND (SP.class = 6)
    UNION ALL
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(sys.types.name) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS + N' ON TYPE::'
           + QUOTENAME(sys.types.name) AS permissionstatement
    FROM sys.database_permissions SP
        INNER JOIN sys.types
            ON sys.types.user_type_id = SP.major_id
    WHERE (SP.major_id >= 0)
          AND (SP.class = 6)
    UNION ALL
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(sys.xml_schema_collections.name COLLATE SQL_Latin1_General_CP1_CI_AS) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS
           + N' ON XML SCHEMA COLLECTION::' + QUOTENAME(sys.xml_schema_collections.name) AS permissionstatement
    FROM sys.database_permissions SP
        INNER JOIN sys.xml_schema_collections
            ON sys.xml_schema_collections.xml_collection_id = SP.major_id
    WHERE (SP.major_id >= 0)
          AND (SP.class = 10)
    UNION ALL
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(sys.service_message_types.name COLLATE SQL_Latin1_General_CP1_CI_AS) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS
           + N' ON MESSAGE TYPE::' + QUOTENAME(sys.service_message_types.name COLLATE SQL_Latin1_General_CP1_CI_AS) AS permissionstatement
    FROM sys.database_permissions SP
        INNER JOIN sys.service_message_types
            ON sys.service_message_types.message_type_id = SP.major_id
    WHERE (SP.major_id >= 0)
          AND (SP.class = 15)
    UNION ALL
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(sys.service_contracts.name COLLATE SQL_Latin1_General_CP1_CI_AS) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS
           + N' ON CONTRACT::' + QUOTENAME(sys.service_contracts.name COLLATE SQL_Latin1_General_CP1_CI_AS) AS permissionstatement
    FROM sys.database_permissions SP
        INNER JOIN sys.service_contracts
            ON sys.service_contracts.service_contract_id = SP.major_id
    WHERE (SP.major_id >= 0)
          AND (SP.class = 16)
    UNION ALL
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(sys.services.name COLLATE SQL_Latin1_General_CP1_CI_AS) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS
           + N' ON SERVICE::' + QUOTENAME(sys.services.name COLLATE SQL_Latin1_General_CP1_CI_AS) AS permissionstatement
    FROM sys.database_permissions SP
        INNER JOIN sys.services
            ON sys.services.service_id = SP.major_id
    WHERE (SP.major_id >= 0)
          AND (SP.class = 17)
    UNION ALL
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(sys.remote_service_bindings.name COLLATE SQL_Latin1_General_CP1_CI_AS) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS
           + N' ON REMOTE SERVICE BINDING::'
           + QUOTENAME(sys.remote_service_bindings.name COLLATE SQL_Latin1_General_CP1_CI_AS) AS permissionstatement
    FROM sys.database_permissions SP
        INNER JOIN sys.remote_service_bindings
            ON sys.remote_service_bindings.remote_service_binding_id = SP.major_id
    WHERE (SP.major_id >= 0)
          AND (SP.class = 18)
    UNION ALL
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(sys.routes.name COLLATE SQL_Latin1_General_CP1_CI_AS) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS + N' ON ROUTE::'
           + QUOTENAME(sys.routes.name COLLATE SQL_Latin1_General_CP1_CI_AS) AS permissionstatement
    FROM sys.database_permissions SP
        INNER JOIN sys.routes
            ON sys.routes.route_id = SP.major_id
    WHERE (SP.major_id >= 0)
          AND (SP.class = 19)
    UNION ALL
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(sys.symmetric_keys.name) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS
           + N' ON ASYMMETRIC KEY::' + QUOTENAME(sys.symmetric_keys.name) AS permissionstatement
    FROM sys.database_permissions SP
        INNER JOIN sys.symmetric_keys
            ON sys.symmetric_keys.symmetric_key_id = SP.major_id
    WHERE (SP.major_id >= 0)
          AND (SP.class = 24)
    UNION ALL
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(sys.certificates.name) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS
           + N' ON CERTIFICATE::' + QUOTENAME(sys.certificates.name) AS permissionstatement
    FROM sys.database_permissions SP
        INNER JOIN sys.certificates
            ON sys.certificates.certificate_id = SP.major_id
    WHERE (SP.major_id >= 0)
          AND (SP.class = 25)
    UNION ALL
    SELECT SP.class,
           SP.class_desc,
           SP.major_id,
           SP.minor_id,
           SP.grantee_principal_id,
           SP.grantor_principal_id,
           SP.type,
           SP.permission_name,
           SP.state,
           SP.state_desc,
           QUOTENAME(sys.asymmetric_keys.name) AS granted_on_name,
           CASE
               WHEN SP.state = N'W' THEN
                   N'GRANT'
               ELSE
                   SP.state_desc
           END + N' ' + SP.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS
           + N' ON ASYMMETRIC KEY::' + QUOTENAME(sys.asymmetric_keys.name) AS permissionstatement
    FROM sys.database_permissions SP
        INNER JOIN sys.asymmetric_keys
            ON sys.asymmetric_keys.asymmetric_key_id = SP.major_id
    WHERE (SP.major_id >= 0)
          AND (SP.class = 26)
) AS databasepermissions
    INNER JOIN sys.database_principals AS granteedatabaseprincipal
        ON granteedatabaseprincipal.principal_id = grantee_principal_id
    LEFT OUTER JOIN sys.server_principals AS granteeserverprincipal
        ON granteeserverprincipal.sid = granteedatabaseprincipal.sid
    INNER JOIN sys.database_principals AS grantor
        ON grantor.principal_id = grantor_principal_id
ORDER BY grantee_name,
         granted_on_name;

SELECT roles.name AS role_name,
       roles.principal_id,
       roles.type AS role_type,
       roles.type_desc AS role_type_desc,
       roles.is_fixed_role AS role_is_fixed_role,
       memberdatabaseprincipal.name AS member_name,
       memberdatabaseprincipal.principal_id AS member_principal_id,
       memberdatabaseprincipal.type AS member_type,
       memberdatabaseprincipal.type_desc AS member_type_desc,
       memberdatabaseprincipal.is_fixed_role AS member_is_fixed_role,
       memberserverprincipal.name AS member_principal_name,
       memberserverprincipal.type_desc member_principal_type_desc,
       N'ALTER ROLE ' + QUOTENAME(roles.name) + N' ADD MEMBER ' + QUOTENAME(memberdatabaseprincipal.name) AS AddRoleMembersStatement
FROM sys.database_principals AS roles
    INNER JOIN sys.database_role_members
        ON sys.database_role_members.role_principal_id = roles.principal_id
    INNER JOIN sys.database_principals AS memberdatabaseprincipal
        ON memberdatabaseprincipal.principal_id = sys.database_role_members.member_principal_id
    LEFT OUTER JOIN sys.server_principals AS memberserverprincipal
        ON memberserverprincipal.sid = memberdatabaseprincipal.sid
ORDER BY role_name,
         member_name;