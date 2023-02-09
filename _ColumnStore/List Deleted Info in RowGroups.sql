--  ALTER INDEX cci_FactInternetSales2 ON FactInternetSales2 REORGANIZE PARTITION = 0;  

SELECT	OBJECT_SCHEMA_NAME(RG.[object_id]) AS SchemaName,
		OBJECT_NAME(RG.[object_id]) AS TableName,
		IDX.[name] AS IndexName,
		RG.index_id,
		RG.partition_number,
		SUM(RG.deleted_rows) AS TotDel,
		COUNT(CASE WHEN RG.deleted_rows IS NULL THEN NULL ELSE 1 END) AS DelGrps,
		CAST((CAST(SUM(RG.deleted_rows) AS float)) / CAST(SUM(RG.total_rows) AS float) * 100.0 AS DECIMAL(10,2)) AS PctDel
		--CAST((CAST(RG.deleted_rows AS float) / CAST(RG.total_rows AS float)) * 100.0 AS DECIMAL(10,2)) AS PctDel
		--,RG.*2
		, CONCAT(' ALTER INDEX ',
				  QUOTENAME(IDX.[name], '['),
				  ' ON ',
				  QUOTENAME(OBJECT_SCHEMA_NAME(RG.[object_id]),'['), '.',
				  QUOTENAME(OBJECT_NAME(RG.[object_id]), '['),
				  ' REORGANIZE PARTITION = ', CONVERT(VARCHAR(10), RG.partition_number),
				  ' WITH ( COMPRESS_ALL_ROW_GROUPS = ON )'
				  ) AS ReorgCmd
	FROM sys.column_store_row_groups RG
		INNER JOIN sys.indexes IDX
			ON (RG.[object_id] = IDX.[object_id]) AND (RG.index_id = IDX.index_id)
	WHERE (RG.deleted_rows IS NOT NULL) AND (RG.deleted_rows > 0)
	GROUP BY IDX.[name], RG.object_id, RG.index_id , RG.partition_number
	HAVING CAST((CAST(SUM(RG.deleted_rows) AS float)) / CAST(SUM(RG.total_rows) AS float) * 100.0 AS DECIMAL(10,2)) > 1.0
	ORDER BY SchemaName,TableName, RG.partition_number --, RG.row_group_id  --, row_group_id
	--ORDER BY SchemaName,TableName, [PctDel] DESC, partition_number--, row_group_id

