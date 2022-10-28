SELECT
  	OBJECT_NAME(o.object_id) TableName,
	i.name AS Index_name
	, i.Type_Desc AS Type_Desc
	, ds.name AS DataSpaceName
	, ds.type_desc AS DataSpaceTypeDesc
	, st.is_incremental
FROM sys.objects AS o
JOIN sys.indexes AS i 
ON o.object_id = i.object_id
JOIN sys.data_spaces ds 
ON ds.data_space_id = i.data_space_id
JOIN sys.stats st
ON st.object_id = o.object_id AND st.name = i.name
LEFT OUTER JOIN sys.dm_db_index_usage_stats AS s 
ON i.object_id = s.object_id 
AND i.index_id = s.index_id AND s.database_id = DB_ID()
WHERE o.type = 'U'
AND i.type <= 2
AND o.object_id = OBJECT_ID('ProcessHistory.PdrAlarmEvent')

ORDER BY o.object_id, i.index_id


SELECT 
	OBJECT_SCHEMA_NAME(object_id) SchemaName,
	OBJECT_NAME(object_id) TableName
	, name 
	, is_incremental
	, stats_id
	, CONCAT('UPDATE STATISTICS ',
			 QUOTENAME(OBJECT_SCHEMA_NAME([object_id]),'['), '.', QUOTENAME(OBJECT_NAME([object_id]),'['),
			 '([', [name], ']) WITH SAMPLE 5 PERCENT , PERSIST_SAMPLE_PERCENT = ON, INCREMENTAL = ON; '
			 )
	, CONCAT('CREATE STATISTICS ',
			'[STS_', OBJECT_NAME([object_id]), '_', [name], '  ON ',
			 QUOTENAME(OBJECT_SCHEMA_NAME([object_id]),'['), '.', QUOTENAME(OBJECT_NAME([object_id]),'['),
			 ' WITH SAMPLE 5 PERCENT , PERSIST_SAMPLE_PERCENT = ON, INCREMENTAL = ON; '
			 )
FROM sys.stats
WHERE OBJECT_NAME(object_id) = 'PdrAlarmEvent'
ORDER BY object_id


SELECT 
	OBJECT_SCHEMA_NAME(a.object_id) SchName,
	OBJECT_NAME(a.object_id) TblName
	, a.stats_id
	, b.partition_number
	, b.last_updated
	, b.rows
	, b.rows_sampled
	, b.steps
FROM sys.stats a
CROSS APPLY sys.dm_db_incremental_stats_properties(a.object_id, a.stats_id) b
WHERE OBJECT_NAME(a.object_id) = 'PdrAlarmEvent'
ORDER BY a.object_id, a.stats_id, b.partition_number