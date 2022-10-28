																															--SELECT SUSER_SNAME(), SUSER_NAME()

SELECT session_id AS 'Session ID',
       [host_name] AS 'Host Name',
       [program_name] AS 'Program Name',
       nt_user_name AS 'User Name',
       SDES.login_name,
       SDRGWG.[name] AS 'Group Assigned',
       DRGRP.[name] AS 'Pool Assigned'	,
	   SDES.status
FROM sys.dm_exec_sessions SDES
    LEFT OUTER JOIN(sys.dm_resource_governor_workload_groups SDRGWG
    INNER JOIN sys.dm_resource_governor_resource_pools DRGRP
        ON SDRGWG.pool_id = DRGRP.pool_id)
        ON SDES.group_id = SDRGWG.group_id
WHERE (SDES.login_name <> 'sa')	AND (SDES.status <> 'sleeping')
ORDER BY [Group Assigned] DESC,
         [User Name];

SELECT *
	FROM	sys.dm_resource_governor_workload_groups;

SELECT *
	FROM sys.dm_resource_governor_resource_pools 
