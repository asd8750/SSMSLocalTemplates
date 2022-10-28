SELECT	OBJECT_SCHEMA_NAME(RG.[object_id]) AS SchemaName,
		OBJECT_NAME(RG.[object_id]) AS TableName,
		RG.index_id,
		RG.partition_number,
		--COUNT(CASE WHEN RG.deleted_rows IS NULL THEN NULL ELSE 1 END) AS DelGrps,
		--CAST((CAST(SUM(RG.deleted_rows) AS float)) / CAST(SUM(RG.total_rows) AS float) * 100.0 AS DECIMAL(10,2)) AS PctDel
		CAST((CAST(RG.deleted_rows AS float) / CAST(RG.total_rows AS float)) * 100.0 AS DECIMAL(10,2)) AS PctDel
		,RG.*
	FROM sys.column_store_row_groups RG
	WHERE (RG.deleted_rows IS NOT NULL) AND (RG.deleted_rows > 0)
	--GROUP BY RG.object_id, RG.index_id, RG.partition_number
	--HAVING CAST((CAST(SUM(RG.deleted_rows) AS float)) / CAST(SUM(RG.total_rows) AS float) * 100.0 AS DECIMAL(10,2)) > 1.0
	ORDER BY SchemaName,TableName, RG.partition_number, RG.row_group_id  --, row_group_id
	--ORDER BY SchemaName,TableName, [PctDel] DESC, partition_number--, row_group_id

	-- ALTER INDEX [NCCSI_erp_ACDOCA] ON  [erp].[ACDOCA] REBUILD PARTITION = 94 WITH (ONLINE = ON, SORT_IN_TEMPDB = ON)
	-- ALTER INDEX [NCCSI_erp_EQUI] ON  [erp].[EQUI] REBUILD PARTITION = 44 WITH (ONLINE = ON, SORT_IN_TEMPDB = ON)
	-- ALTER INDEX [NCCSI_erp_EDIDS] ON  [erp].[EDIDS] REBUILD PARTITION = ALL WITH (ONLINE = ON, SORT_IN_TEMPDB = ON)
