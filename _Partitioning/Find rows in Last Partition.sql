--  Find rows in the last partition
--
--	History:
--		2021-06-14 - F. LaForest - Initial version

SELECT	PTF.function_id,
		PTF.[name] AS PfFunc,
		PTF.[boundary_value_on_right] AS RL,
		PTF.fanout,
		PTS.data_space_id AS [PartSchemaID],
		PTS.[name] AS PtScheme,
		IDX.[object_id],
		IDX.index_id,
		OBJECT_SCHEMA_NAME(IDX.[object_id]) AS SchemaName,
		IDX.[name] AS IndexName,
		IDX.[type] AS IndexType,
		PT.[rows]
		

	FROM sys.partition_functions PTF
		INNER JOIN sys.partition_schemes PTS
			ON (PTF.function_id = PTS.function_id)
		INNER JOIN sys.indexes IDX
			ON (IDX.data_space_id = PTS.data_space_id)
		INNER JOIN sys.partitions PT
			ON (IDX.[object_id] = PT.[object_id]) AND (IDX.index_id = PT.index_id)
	WHERE (ptf.fanout = PT.[partition_number]) 
		AND (PT.[rows] > 0)
