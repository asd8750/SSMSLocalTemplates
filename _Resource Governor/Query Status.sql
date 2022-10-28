USE master
GO
SELECT sess.session_id, sess.login_name, sess.group_id, grps.name
  FROM sys.dm_exec_sessions AS sess
  JOIN sys.dm_resource_governor_workload_groups AS grps
      ON sess.group_id = grps.group_id
  WHERE session_id > 60
  ORDER BY grps.name DESC, sess.login_name;

SELECT * FROM sys.resource_governor_workload_groups

SELECT * FROM sys.resource_governor_resource_pools

SELECT * FROM sys.resource_governor_configuration
