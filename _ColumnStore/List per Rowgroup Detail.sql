SELECT --object_name(phst.object_id) as TableName, 
	OBJECT_SCHEMA_NAME(phst.[object_id]) AS SchemaName,
	OBJECT_NAME(phst.[object_id]) AS TableName,
	ind.[name] AS IndexName,
    phst.index_id,
    phst.partition_number,
	phst.row_group_id,
    phst.generation,
    phst.[state],
    phst.state_desc,
    phst.total_rows,
    phst.deleted_rows,
    phst.size_in_bytes,
    phst.trim_reason,
    phst.trim_reason_desc,
    phst.transition_to_compressed_state,
    phst.transition_to_compressed_state_desc,
    phst.has_vertipaq_optimization,
	CONCAT('ALTER INDEX ',QUOTENAME(ind.[name],'['), ' ON ',
			QUOTENAME(OBJECT_SCHEMA_NAME(phst.[object_id]),'['),'.',
			QUOTENAME(OBJECT_NAME(phst.[object_id]),'['),
			' REBUILD PARTITION=',
			CONVERT(VARCHAR(5),phst.partition_number),
			' WITH (ONLINE=ON)') AS RebuildCmd
   FROM sys.dm_db_column_store_row_group_physical_stats phst
       INNER JOIN sys.indexes ind
          ON phst.object_id = ind.object_id
             AND phst.index_id = ind.index_id
	--WHERE (phst.total_rows < 1048576)
   ORDER BY
    SchemaName,
	TableName,
	--phst.deleted_rows DESC,
    --phst.object_id,
    phst.partition_number,
    phst.row_group_id;

	-- ALTER INDEX [CCSI_erp_EQUI] ON [erp].[EQUI] REBUILD PARTITION=45 WITH (ONLINE=ON)

