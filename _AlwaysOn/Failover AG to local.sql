SELECT AG.[name] AS AGName,
       HRS.role_desc,
       HRS.synchronization_health_desc,
       'ALTER AVAILABILITY GROUP ' + QUOTENAME(AG.[name], '[') + ' FAILOVER;' AS Cmd
  FROM sys.availability_groups AG
 INNER JOIN sys.dm_hadr_availability_replica_states HRS
    ON (AG.group_id = HRS.group_id)
 WHERE (HRS.is_local = 1)
   AND (HRS.[role]   = 2)
   AND (AG.resource_id IS NOT NULL);