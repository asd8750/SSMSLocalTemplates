SELECT DB_NAME(IUS.database_id) AS DBName,
		OBJECT_SCHEMA_NAME(IUS.[object_id], IUS.database_id) AS SchemaName,
		OBJECT_NAME(IUS.[object_id],IUS.database_id) AS TableName,
		IDX.[name] AS IndexName,
		IUS.*
	FROM sys.dm_db_index_usage_stats IUS
		INNER JOIN sys.indexes IDX ON (IUS.[object_id] = IDX.[object_id]) AND (IUS.index_id = IDX.index_id)
	WHERE (IUS.database_id = DB_ID('ODS'))
	--	AND (IUS.[object_id] = OBJECT_ID('dbo.PanelHistoryView'))
	ORDER BY DBName, SchemaName, TableName, IUS.index_id;