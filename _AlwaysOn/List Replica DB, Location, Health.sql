SELECT  g.name AS ag_name ,
        r.replica_server_name AS replica_name ,
        DB_NAME(drs.database_id) AS [db_name] ,
        drs.database_state_desc AS db_state ,
        drs.is_primary_replica ,
        drs.synchronization_health_desc AS sync_health ,
        drs.synchronization_state_desc AS sync_state
FROM    sys.dm_hadr_database_replica_states AS drs
        JOIN sys.availability_groups AS g ON g.group_id = drs.group_id
        JOIN sys.availability_replicas AS r ON r.replica_id = drs.replica_id
ORDER BY r.replica_server_name;
