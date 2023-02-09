--SELECT * 
--	FROM sys.dm_exec_query_stats
--	ORDER BY sql_handle, plan_generation_num;


SELECT TOP 10
    qs.total_worker_time/qs.execution_count AS Avg_CPU_Time
        ,qs.execution_count
        ,qs.total_elapsed_time/qs.execution_count as AVG_Run_Time
		,qp.query_plan
        ,(SELECT
              SUBSTRING(text,qs.statement_start_offset/2,(CASE
                                                           WHEN qs.statement_end_offset = -1 THEN LEN(CONVERT(nvarchar(max), text)) * 2 
                                                           ELSE qs.statement_end_offset 
                                                       END -qs.statement_start_offset)/2
                       ) FROM sys.dm_exec_sql_text(sql_handle)
         ) AS query_text 

FROM sys.dm_exec_query_stats qs
	CROSS APPLY sys.dm_exec_query_plan ( qs.plan_handle ) qp
WHERE qs.execution_count >= 5

--pick your criteria

ORDER BY Avg_CPU_Time DESC
--ORDER BY AVG_Run_Time DESC
--ORDER BY execution_count DESC