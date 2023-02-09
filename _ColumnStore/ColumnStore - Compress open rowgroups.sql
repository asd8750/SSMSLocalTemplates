SELECT	DISTINCT
		OBJECT_SCHEMA_NAME(RG.[object_id]) AS SchemaName,
		OBJECT_NAME(RG.[object_id]) AS TableName,
		SI.[name] AS IndexName,
		RG.partition_number,
		RG.row_group_id,
		RG.total_rows,
		RG.deleted_rows,
		--RG.*
		CONCAT('ALTER INDEX ',
				QUOTENAME(SI.[name],'['),
				' ON ',
				QUOTENAME(OBJECT_SCHEMA_NAME(RG.[object_id]),'['),
				'.',
				QUOTENAME(OBJECT_NAME(RG.[object_id]),'['),
				' REORGANIZE PARTITION = ',
				CONVERT(VARCHAR(4),RG.partition_number),
				' WITH ( COMPRESS_ALL_ROW_GROUPS = ON)') AS ReorgCmd
	FROM sys.column_store_row_groups RG
		INNER JOIN sys.indexes SI
			ON (RG.[object_id] = SI.[object_id]) AND (RG.index_id = SI.index_id)
	WHERE (state_description = 'OPEN')
		AND (RG.total_rows >= 10)

	ORDER BY SchemaName, TableName,partition_number, row_group_id
