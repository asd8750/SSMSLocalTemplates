SELECT OBJECT_SCHEMA_NAME(sys.indexes.object_id) AS SchemaName, 
	   objects.name AS TableName, 
	   indexes.name AS Index_name, 
	   dm_db_index_usage_stats.user_seeks, 
	   dm_db_index_usage_stats.user_scans, 
	   dm_db_index_usage_stats.user_lookups,
	   dm_db_index_usage_stats.user_updates
	FROM sys.dm_db_index_usage_stats
		 INNER JOIN sys.objects
			 ON dm_db_index_usage_stats.object_id = objects.object_id
		 INNER JOIN sys.indexes
			 ON indexes.index_id = dm_db_index_usage_stats.index_id
				AND dm_db_index_usage_stats.object_id = indexes.object_id
	WHERE indexes.is_primary_key = 0 -- This condition excludes primary key constarint
		  AND indexes.is_unique = 0 -- This condition excludes unique key constarint
		  AND dm_db_index_usage_stats.user_lookups = 0
		  AND dm_db_index_usage_stats.user_seeks = 0
		  AND dm_db_index_usage_stats.user_scans = 0
	ORDER BY SchemaName, TableName, dm_db_index_usage_stats.user_updates DESC;