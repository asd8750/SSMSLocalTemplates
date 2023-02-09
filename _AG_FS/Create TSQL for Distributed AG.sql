
	DECLARE @CRLF AS CHAR(2) = CHAR(13)+CHAR(10);

	WITH DAG AS (
			SELECT	ReplicaNameMfg = 'AG_S6_PGT3_MesSqlSpc)',
					EndpointUrlMfg = 'TCP://10.1.14.18:5022',
					ReplicaNameFs = 'AG_PGT3_MesSqlSpc_ODS',
					EndpointUrlFs = 'TCP://10.1.9.169:5022'
			)

		SELECT	CONCAT('CREATE AVAILABILITY GROUP [',
						'D',REPLACE(DAG.ReplicaNameMfg,')',''),'_ODS]', @CRLF,
                    ' WITH (DISTRIBUTED) AVAILABILITY GROUP ON N''', DAG.ReplicaNameMfg, '''', @CRLF, 
                    '	WITH (LISTENER_URL = N''', DAG.EndpointUrlMfg, ''',', @CRLF,
                    '		FAILOVER_MODE = MANUAL, AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT, SEEDING_MODE = AUTOMATIC),', @CRLF, 
                    '		N''', DAG.ReplicaNameFs, '''', @CRLF, 
                    '	WITH (LISTENER_URL = N''', DAG.EndpointUrlFs, ''', FAILOVER_MODE = MANUAL, AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT, SEEDING_MODE = AUTOMATIC);',
					@CRLF, @CRLF
					) AS Sql_Pri,

				CONCAT('ALTER AVAILABILITY GROUP [',
						'D',REPLACE(DAG.ReplicaNameMfg,')',''),'_ODS]', @CRLF,
                    ' JOIN AVAILABILITY GROUP ON N''', DAG.ReplicaNameMfg, '''', @CRLF, 
                    '	WITH (LISTENER_URL = N''', DAG.EndpointUrlMfg, ''',', @CRLF,
                    '		FAILOVER_MODE = MANUAL, AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT, SEEDING_MODE = AUTOMATIC),', @CRLF, 
                    '		N''', DAG.ReplicaNameFs, '''', @CRLF, 
                    '	WITH (LISTENER_URL = N''', DAG.EndpointUrlFs, ''', FAILOVER_MODE = MANUAL, AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT, SEEDING_MODE = AUTOMATIC);',
					@CRLF, @CRLF
					) AS Sql_Sec
			FROM DAG


