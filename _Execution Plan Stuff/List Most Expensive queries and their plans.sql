DECLARE @dbname sysname
SET @dbname = 'ODS'
SELECT
        OBJECT_NAME(st.objectid, CONVERT(INT, epa.value)) ObjectName
    ,   objtype
    ,   STR(execution_count, 10) ExecCount
    ,   STR(total_worker_time / 1000.0, 12, 1) TotalCpuInMs
    ,   STR(total_worker_time / 1000.0 / execution_count, 12, 1) AvgCpuInMs
    ,   STR(total_elapsed_time / 1000.0 / 1000.0, 12, 1) TotalExecTimeInSec
    ,   STR(max_elapsed_time / 1000.0, 12, 1) MaxExecTimeInMs
    ,   STR(total_elapsed_time / 1000.0 / execution_count, 12, 1) AvgExecTimeInMs
    ,   STR(total_logical_reads, 12) TotalLogicalReads
    ,   STR(total_logical_reads / execution_count, 10, 1) AvgLogicalReads
    ,   creation_time PlanCompilationTime
    ,   GETDATE() CheckTime
    ,   SUBSTRING(st.text, ( qs.statement_start_offset / 2 ) + 1,
                  ( ( CASE qs.statement_end_offset
                        WHEN -1 THEN DATALENGTH(st.text)
                        ELSE qs.statement_end_offset
                      END - qs.statement_start_offset ) / 2 ) + 1) AS statement_text
    ,   qs.plan_handle
    ,   query_plan

    FROM
        sys.dm_exec_query_stats qs
        JOIN sys.dm_exec_cached_plans p
        ON p.plan_handle = qs.plan_handle
        OUTER APPLY sys.dm_exec_plan_attributes(qs.plan_handle) AS epa
        CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
        CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS pl
    WHERE
        cacheobjtype = 'Compiled Plan'
        AND attribute = 'dbid'
        AND value IN ( DB_ID(@dbname) )
    ORDER BY
        total_elapsed_time DESC
