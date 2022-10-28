--SELECT ONE.OneValue,
--       DME.[name] AS [EndpointName],
--       DME.endpoint_id,
--       TE.[port],
--       DME.encryption_algorithm_desc,
--       DME.connection_auth_desc,
--       DME.state_desc,
--       DME.principal_id,
--       SPR.[name] AS EndpointPrincipalName,
--       DME.certificate_id AS EndpointPrincipalID,
--       CERT.principal_id AS CertPrincipalId,
--       CERT.[name] AS CertName,
--       DPRC.[name] AS CertOwner,
--       CERT.cert_serial_number
--   FROM ( SELECT 1 AS OneValue ) ONE
--       LEFT OUTER JOIN sys.database_mirroring_endpoints DME
--         ON ( 1 = 1 )
--       INNER JOIN sys.tcp_endpoints TE
--          ON ( DME.endpoint_id = TE.endpoint_id )
--       LEFT OUTER JOIN(sys.certificates CERT
--       INNER JOIN master.sys.database_principals DPRC
--          ON ( CERT.principal_id = DPRC.principal_id ))
--         ON ( DME.certificate_id = CERT.certificate_id )
--       LEFT OUTER JOIN sys.server_principals SPR
--         ON ( DME.principal_id = SPR.principal_id );



WITH MP AS
   (
       SELECT ISNULL (DME.[name], 'NONE') AS [MPortName],
              DME.endpoint_id AS MEndpointID,
              TE.[port] AS [MPortNo],
              DME.[state_desc] AS [MPortState],
              REPLACE (DME.connection_auth_desc, ' ', '') AS [MPortConnAuth], -- 7 = Negotiate, Certificate or 10 = Certificate, Negotiate
              DME.[role_desc] AS [MPortRole],                                 -- 3=ALL
              DME.is_encryption_enabled AS [MPortEncState],                   -- 1 = enabled
              REPLACE (DME.encryption_algorithm_desc, ' ', '') AS [MPortEnc],
              DME.certificate_id,
              --CT.[name] AS CertName,
              SPR.[name] AS EndpointPrincipalName,
              DME.certificate_id AS EndpointPrincipalID,
              CERT.principal_id AS CertPrincipalId,
              CERT.[name] AS CertName,
              DPRC.[name] AS CertOwner,
			  CERT.cert_serial_number
          FROM sys.database_mirroring_endpoints DME
              INNER JOIN sys.tcp_endpoints TE
                 ON ( DME.endpoint_id = TE.endpoint_id )
                    AND ( DME.protocol_desc = 'TCP' )
              LEFT OUTER JOIN sys.certificates CT
                ON ( DME.certificate_id = CT.certificate_id )
              LEFT OUTER JOIN(sys.certificates CERT
              INNER JOIN master.sys.database_principals DPRC
                 ON ( CERT.principal_id = DPRC.principal_id ))
                ON ( DME.certificate_id = CERT.certificate_id )
              LEFT OUTER JOIN sys.server_principals SPR
                ON ( DME.principal_id = SPR.principal_id )
          WHERE
           ( DME.type_desc = 'DATABASE_MIRRORING' )
   )
   SELECT SERVERPROPERTY ('MachineName') AS Name,
          SERVERPROPERTY ('productversion') AS SqlVersion,
          ISNULL (MP.MEndpointID, 0) AS MEndpointID,
          ISNULL (MP.MPortName, 'HADR_EndPoint') AS MPortName,
          ISNULL (MP.MPortNo, 5022) AS MPortNo,
          ISNULL (MP.MPortState, 'STARTED') AS MPortState,
          ISNULL (MP.MPortConnAuth, 'CERTIFICATE,NEGOTIATE') AS MPortConnAuth,
          ISNULL (MP.MPortRole, 'ALL') AS MPortRole,
          ISNULL (MP.MPortEncState, 1) AS MPortEncState,
          ISNULL (MP.MPortEnc, 'AES') AS MPortEnc,
          ISNULL (MP.certificate_id, 0) AS MPortCertNo,
          MP.EndpointPrincipalName,
          MP.EndpointPrincipalID,
          MP.CertPrincipalId,
          MP.CertName,
          MP.CertOwner,
		  MP.cert_serial_number
      FROM ( SELECT 1 AS ONE ) J1
          LEFT OUTER JOIN MP
            ON ( 1 = 1 );