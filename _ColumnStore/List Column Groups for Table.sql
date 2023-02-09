SELECT	OBJECT_SCHEMA_NAME(RG.[object_id]) AS SchemaName,
		OBJECT_NAME(RG.[object_id]) AS TableName,
		RG.*,
		CAST((CAST(RG.deleted_rows AS float) / CAST(RG.total_rows AS float)) * 100.0 AS DECIMAL(10,2)) AS PctDel
	FROM sys.column_store_row_groups RG
	ORDER BY SchemaName,TableName, partition_number, row_group_id
