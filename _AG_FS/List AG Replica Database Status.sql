SELECT	SERVERPROPERTY('ServerName') AS SrcInstance,
		AG.[name] AS AGName,
		--HARS.group_id AS AGID,
		--HARS.replica_id AS AGRepID,
		--HDRS.group_database_id AS AGDBID,
		--HDRS.database_id AS DatabaseID,
		HDRCS.[database_name],
		HDRS.is_local AS IsLocal,
		HDRS.is_primary_replica AS IsPrimary,
		HDRCS.is_failover_ready AS IsFailoverReady,
		AR.replica_server_name AS ReplServer,
		HARS.role_desc AS ReplRole,
		HDRS.synchronization_health_desc AS DBSyncHealth,
		HDRS.synchronization_state_desc AS DBSyncState,
		AR.availability_mode_desc AS AvailabilityMode,
		AR.[failover_mode_desc] AS [FailoverMode],
		AR.[seeding_mode_desc] AS SeedingMode,
		HDRS.log_send_queue_size AS LogSendQueueSize,
		HDRS.log_send_rate AS LogSendRate,
		HDRS.redo_queue_size AS RedoQueueSize,
		HDRS.redo_rate AS RedoRate,
		HDRS.low_water_mark_for_ghosts AS LowWaterMark,
		HDRS.last_hardened_lsn AS LastHardenedLsn,
		HDRS.last_received_lsn AS LastReceivedLsn
		--, AR.*
	FROM sys.dm_hadr_availability_replica_states HARS
		INNER JOIN sys.dm_hadr_database_replica_states HDRS
			ON (HARS.group_id = HDRS.group_id) AND (HARS.replica_id = HDRS.replica_id)
		INNER JOIN sys.dm_hadr_database_replica_cluster_states HDRCS
			ON (HDRS.group_database_id = HDRCS.group_database_id) AND (HDRS.replica_id = HDRCS.replica_id)
		INNER JOIN sys.availability_groups AG
			ON (HARS.group_id = AG.group_id)
		INNER JOIN sys.availability_replicas AR
			ON (AR.group_id = HARS. group_id) AND (AR.replica_id = HARS.replica_id)
	--WHERE (SERVERPROPERTY('ServerName') = AR.replica_server_name)
	ORDER BY IsLocal DESC, ReplServer, AGName, [database_name]

