
SELECT cntr_value 
  FROM sys.dm_os_performance_counters 
  WHERE counter_name = 'Cache Pages' 
    AND instance_name = 'SQL Plans'; 

SELECT  objtype,
		COUNT(*) AS ItemCount,
		SUM(CONVERT(BIGINT,refcounts)) as refcounts,
		sum(CONVERT(BIGINT, usecounts)) as usecounts,
		sum(convert(BIGINT, size_in_bytes)) as size_in_bytes
	FROM sys.dm_exec_cached_plans
	GROUP BY objtype
	ORDER BY objtype