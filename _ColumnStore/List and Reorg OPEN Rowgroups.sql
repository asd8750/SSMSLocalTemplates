SELECT	DISTINCT
		OBJECT_SCHEMA_NAME(RG.[object_id]) AS SchemaName,
		OBJECT_NAME(RG.[object_id]) AS TableName,
		SI.[name] AS IndexName,
		RG.partition_number,
		--RG.*
		CONCAT('ALTER INDEX ',
				QUOTENAME(SI.[name],'['),
				' ON ',
				QUOTENAME(OBJECT_SCHEMA_NAME(RG.[object_id]),'['),
				'.',
				QUOTENAME(OBJECT_NAME(RG.[object_id]),'['),
				' REORGANIZE PARTITION = ',
				CONVERT(VARCHAR(4),RG.partition_number),
				' WITH ( COMPRESS_ALL_ROW_GROUPS = ON)')
	FROM sys.column_store_row_groups RG
		INNER JOIN sys.indexes SI
			ON (RG.[object_id] = SI.[object_id]) AND (RG.index_id = SI.index_id)
	WHERE (state_description = 'OPEN')

	ORDER BY SchemaName, TableName,partition_number	;

SELECT	DISTINCT
		OBJECT_SCHEMA_NAME(RG.[object_id]) AS SchemaName,
		OBJECT_NAME(RG.[object_id]) AS TableName,
		SI.[name] AS IndexName,
		RG.partition_number,
		--RG.*
		CONCAT('ALTER INDEX ',
				QUOTENAME(SI.[name],'['),
				' ON ',
				QUOTENAME(OBJECT_SCHEMA_NAME(RG.[object_id]),'['),
				'.',
				QUOTENAME(OBJECT_NAME(RG.[object_id]),'['),
				' REBUILD PARTITION = ',
				CONVERT(VARCHAR(4),RG.partition_number)	 )
	FROM sys.column_store_row_groups RG
		INNER JOIN sys.indexes SI
			ON (RG.[object_id] = SI.[object_id]) AND (RG.index_id = SI.index_id)
	WHERE (RG.deleted_rows > 0)

	ORDER BY SchemaName, TableName,partition_number	;



	

SELECT     OBJECT_NAME(rg.object_id)   AS TableName,
           i.name                      AS IndexName,
           i.type_desc                 AS IndexType,
           rg.partition_number,
           rg.state_description,
           COUNT(*)                    AS NumberOfRowgroups,
           SUM(rg.total_rows)          AS TotalRows,
           SUM(rg.size_in_bytes)       AS TotalSizeInBytes,
           SUM(rg.deleted_rows)        AS TotalDeletedRows
		,CONCAT('ALTER INDEX ',
				QUOTENAME(i.name,'['),
				' ON ',
				QUOTENAME(OBJECT_SCHEMA_NAME(rg.object_id), '['),
				'.',
				QUOTENAME(OBJECT_NAME(rg.object_id), '['),
				' REORGANIZE PARTITION = ',
				CONVERT(VARCHAR(5), rg.partition_number) ,
				' WITH ( COMPRESS_ALL_ROW_GROUPS = ON)')
FROM       sys.column_store_row_groups AS rg
INNER JOIN sys.indexes                 AS i
      ON   i.object_id                  = rg.object_id
      AND  i.index_id                   = rg.index_id
--WHERE      (i.[type] = 5)
GROUP BY   rg.object_id, i.name, i.type_desc,
           rg.partition_number, rg.state_description
HAVING	(rg.state_description = 'OPEN')
ORDER BY   TableName, IndexName, rg.partition_number;
