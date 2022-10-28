WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT
	DB_NAME(E.dbid) AS [DBName],
	object_name(E.objectid, dbid) AS [ObjectName],
	P.cacheobjtype AS [CacheObjType],
	P.objtype AS [ObjType],
	E.query_plan.query('count(//RelOp[@LogicalOp = ''Index Scan'' or @LogicalOp = ''Clustered Index Scan'']/*/Object[@Index=''[IX_FactETAPanel_SubID_ExperimentID]''])') AS [ScanCount],
	E.query_plan.query('count(//RelOp[@LogicalOp = ''Index Seek'' or @LogicalOp = ''Clustered Index Seek'']/*/Object[@Index=''[IX_FactETAPanel_SubID_ExperimentID]''])') AS [SeekCount],
	E.query_plan.query('count(//Update/Object[@Index=''[IX_FactETAPanel_SubID_ExperimentID]''])') AS [UpdateCount],
	P.refcounts AS [RefCounts],
	P.usecounts AS [UseCounts],
	E.query_plan AS [QueryPlan]
FROM sys.dm_exec_cached_plans P
CROSS APPLY sys.dm_exec_query_plan(P.plan_handle) E
WHERE
	E.dbid = DB_ID('DWPROD01') AND
	E.query_plan.exist('//*[@Index=''[IX_FactETAPanel_SubID_ExperimentID]'']') = 1