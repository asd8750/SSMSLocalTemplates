
SELECT	SERVERPROPERTY('ServerName') AS SrcInstance,
		AG.name AS DAGName,
		AG.group_id AS DAGID,
		ARP.replica_id AS DAGReplID,
		ARP.replica_server_name AS DAG_AGName,
		COALESCE(AGLoc.group_id,AGRmt.group_id) AS DAG_AGID,
		IIF(AGLoc.group_id IS NULL, 0, 1) AS IsLocal,
		ARP.endpoint_url AS EndPointURL,
		SUBSTRING(SUBSTRING(ARP.endpoint_url,1,LEN(ARP.endpoint_url)-5),7,100) AS DAG_AGIP,
		RIGHT(ARP.endpoint_url,4) AS DAG_AGPort,
		AGLLN.dns_name AS LocLnName,
		AGLLN.port AS LocLnPort,
		--AGLLN.ip_configuration_string_from_cluster AS LocLnIP,
		ARP.availability_mode_desc AS DAGMode,
		ARP.failover_mode_desc AS DAGFailover,
		ARP.primary_role_allow_connections_desc AS DAGConnPrimary,
		ARP.secondary_role_allow_connections_desc AS DAGConnSecondary,
		ARP.seeding_mode_desc AS SeedingMode,
		CASE WHEN ARPS.role_desc IS NULL THEN 'PRIMARY' ELSE ARPS.role_desc END AS DAGRole,
		ARPS.synchronization_health_desc AS AGRepSyncHealth,
		ARPS.operational_state_desc AS DAGOperState,
		ARPS.connected_state_desc AS DAGConnected
		--,AG.*, ARP.*, ARPS.*
	FROM sys.availability_groups AG
		INNER JOIN sys.availability_replicas ARP
			ON (AG.group_id = ARP.group_id)
		LEFT OUTER JOIN sys.dm_hadr_availability_replica_states ARPS
			ON (ARP.replica_id = ARPS.replica_id)
		LEFT OUTER JOIN sys.availability_groups AGLoc
			ON (ARP.replica_server_name = AGLoc.[name])
		LEFT OUTER JOIN sys.dm_hadr_availability_group_states AGRmt
			ON (ARP.replica_server_name = AGRmt.primary_replica)
		LEFT OUTER JOIN sys.availability_group_listeners AGLLN
			ON (AGLoc.group_id = AGLLN.group_id)
	WHERE (AG.is_distributed = 1)
