  
IF (SERVERPROPERTY('IsHadrEnabled') IS NOT NULL)
	SELECT	TOP (1000000)
            CASE LEFT(@@SERVERNAME,3) 
                        WHEN 'PBG' THEN 
                            IIF((RIGHT(@@SERVERNAME,4) LIKE 'T7%'), 'PBG3',   
										'PGT' + LEFT(RIGHT(@@SERVERNAME,3),1))
						WHEN 'KLM' THEN 'KMT' + LEFT(RIGHT(@@SERVERNAME,3),1)
						WHEN 'DMT' THEN 'DMT' + LEFT(RIGHT(@@SERVERNAME,3),1)
						WHEN 'PKM' THEN 'PMT' + LEFT(RIGHT(@@SERVERNAME,3),1)
						ELSE '----' END  AS PlantCode,
            CONVERT(VARCHAR(128), @@SERVERNAME) AS SourceInst,
            AG.[name] AS AGName,
            AG.[group_id] AS AGID,
			ISNULL((SELECT TOP (1) UPPER(cluster_name) FROM sys.dm_hadr_cluster), '') AS ClusterName,
            AR.replica_server_name AS AGReplServer,
            AR.failover_mode_desc AS AGFailMode,
            AR.availability_mode_desc AS AGAvlMode,
            AR.seeding_mode_desc AS AGSeeding,
			AG.failure_condition_level AS AGFailCondLevel,
			AG.health_check_timeout AS AGHealthTimeout,
			AG.automated_backup_preference_desc AS AGBackupPref,
			AR.backup_priority,
			AG.dtc_support AS AGDtcEnabled,
			AG.db_failover AS AGHealthFailover,
			AGL.dns_name AS AGListenerName,
			--AGL.ip_configuration_string_from_cluster AS ListenerConfig,
			AGLIP.ip_address AS AGLIPAddr,
			AGLIP.ip_subnet_mask AS AGLIPSubnet,
			AGLIP.state_desc AS AGLState,
            ISNULL(HARS.role_desc, 'UNKNOWN') AS AGReplRole,
            SUBSTRING(LEFT(AR.[endpoint_url], CHARINDEX(':', AR.[endpoint_url], 6) - 1), 7, 128) AS EndPointServer,
            IIF(DAG.[name] IS NULL, 0, 1) AS InDAG,
            ISNULL(HDRS.database_id, 0) AS DatabaseID,
            HDRCS.[database_name] AS DatabaseName,
            MIN(CAST(HDRCS.is_failover_ready AS TINYINT)) OVER (PARTITION BY AG.[name]) AS AGFailoverReady,
            HDRCS.is_failover_ready AS DBFailoverReady,
            ISNULL(HDRS.is_local, 0) AS DBIsLocal,
            HDRS.synchronization_health_desc AS DBSyncHealth,
            HDRS.synchronization_state_desc AS DBSyncState,
   --         ISNULL(HDRS.log_send_queue_size, 0) AS DBLogSendQueueSize,
   --         ISNULL(HDRS.log_send_rate, 0) AS DBLogSendRate,
   --         ISNULL(HDRS.redo_queue_size, 0) AS DBRedoQueueSize,
   --         ISNULL(HDRS.redo_rate, 0) AS DBRedoRate,
   --         ISNULL(HDRS.low_water_mark_for_ghosts, 0) AS DBLowWaterMark,
   --         HDRS.last_hardened_lsn AS DBLastHardenedLsn,
			--HDRS.last_sent_time,
			--HDRS.last_received_time,
   --         HDRS.last_received_lsn AS DBLastReceivedLsn,
            DAG.[name] AS DAGName,
            DAG.group_id AS DAGID,
            SUBSTRING(LEFT(DARRmt.[endpoint_url], CHARINDEX(':', DARRmt.[endpoint_url], 6) - 1), 7, 128) AS DAGRmtSvr,
            DARRmt.replica_server_name AS DAGRmtAG,
            --CASE WHEN DARPS.role_desc IS NULL THEN 'PRIMARY' ELSE DARPS.role_desc END AS DAGReplRole,
            IIF(DAG.[name] IS NULL, NULL, ISNULL(DARPS.role_desc, 'PRIMARY')) AS DAGReplRole,
            DARRmt.availability_mode_desc AS DAGAvlMode,
            DARRmt.failover_mode_desc AS DAGFailMode,
            DARRmt.seeding_mode_desc AS DAGSeeding,
            DAGState.synchronization_health_desc AS DAGSyncHealth,
            SYSUTCDATETIME() AS DateCollectedUtc
            --,DARRmt.*
        FROM sys.availability_groups AG
            INNER JOIN sys.availability_replicas AR
                ON (AG.[group_id] = AR.[group_id])
            LEFT OUTER JOIN sys.dm_hadr_availability_replica_states HARS
                ON ( AG.group_id = HARS.group_id )
                    AND ( AR.replica_id = HARS.replica_id )
			LEFT OUTER JOIN sys.availability_group_listeners AGL
				ON (AG.group_id = AGL.group_id)
			LEFT OUTER JOIN sys.availability_group_listener_ip_addresses AGLIP
				ON (AGL.listener_id = AGLIP.listener_id)
            LEFT OUTER JOIN (
                    sys.availability_groups DAG
                INNER JOIN sys.availability_replicas DAR
                    ON (DAG.[group_id] = DAR.[group_id])
                INNER JOIN sys.availability_replicas DARRmt
                    ON (DAG.[group_id] = DARRmt.[group_id]) AND (DAR.[replica_id] <> DARRmt.[replica_id])
                LEFT OUTER JOIN sys.dm_hadr_availability_group_states DAGState
                    ON (DAG.group_id = DAGState.group_id)
                INNER JOIN sys.dm_hadr_availability_replica_states DARPS
                    ON (DAR.replica_id = DARPS.replica_id)
                    )
                ON (AG.[name] = DAR.replica_server_name)
            LEFT OUTER JOIN (
                sys.dm_hadr_database_replica_states HDRS
                INNER JOIN sys.dm_hadr_database_replica_cluster_states HDRCS
                    ON (HDRS.group_database_id = HDRCS.group_database_id)
                        AND (HDRCS.replica_id = HDRS.replica_id)
                    )
                ON (HDRS.group_id = AR.group_id) AND (HDRS.replica_id = AR.replica_id)

        WHERE (AG.is_distributed = 0)
			--AND (AR.replica_server_name = @@SERVERNAME)
        ORDER BY AG.[name], DatabaseName, AR.replica_server_name;


SELECT * FROM sys.availability_group_listener_ip_addresses
