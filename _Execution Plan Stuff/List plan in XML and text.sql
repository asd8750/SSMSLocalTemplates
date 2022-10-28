SELECT cp.UseCounts,
       cp.RefCounts,
       cp.Cacheobjtype,
       cp.Objtype,
	   LEN(txt.[TEXT]) AS strlen,
       txt.[TEXT] AS SQL,
       planxml = CONVERT(XML, tqp.query_plan)
FROM sys.dm_exec_cached_plans cp
     CROSS APPLY sys.dm_exec_sql_text(plan_handle) txt
     CROSS APPLY sys.dm_exec_text_query_plan(plan_handle, 0, -1) tqp
WHERE (cp.usecounts > 1) 