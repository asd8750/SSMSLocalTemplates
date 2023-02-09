SELECT *
FROM sys.dm_exec_requests
WHERE command LIKE '%HADR%'
      OR command LIKE '%DB%'
      OR command LIKE '%BRKR%'
ORDER BY command, database_id