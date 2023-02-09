SELECT	OBJECT_SCHEMA_NAME(STAB.[object_id]) AS SchemaName,
		STAB.[name] AS TableName,
		SIDX.[name] AS IndexName,
		SIDX.[type] AS IndexType,
		SIDX.[index_id] AS IndexID,
		SPRNG.TopBoundary,
		SPRNG.PrevBoundary	,
		SSCH.[name] AS PtScheme,
		SFNC.[name] AS PtFunc

	FROM sys.tables STAB
		INNER JOIN sys.indexes SIDX
			ON (STAB.[object_id] = SIDX.[object_id])
		LEFT OUTER JOIN sys.partition_schemes SSCH  
			ON (SIDX.data_space_id = SSCH.data_space_id)
		LEFT OUTER JOIN sys.partition_functions SFNC  
			ON (SSCH.function_id = SFNC.function_id)
		LEFT OUTER JOIN sys.partition_parameters SPRM   
			ON (SSCH.function_id = SPRM.function_id)
		LEFT OUTER JOIN 
				(
					SELECT	function_id,  
							parameter_id,
							TopBoundary,
							PrevBoundary
						FROM (
							SELECT	function_id,  
									parameter_id,
									boundary_id,
									[value] AS TopBoundary,
									LEAD([value]) OVER (PARTITION BY function_id, parameter_id ORDER BY boundary_id DESC) AS PrevBoundary,
									ROW_NUMBER() OVER (PARTITION BY function_id, parameter_id ORDER BY boundary_id DESC) AS RowNum
									--MAX([value]) as TopBoundary
								FROM sys.partition_range_values
								WHERE ([value] IS NOT NULL)
								) BND2
							WHERE (BND2.RowNum = 1)
						--GROUP BY function_id, parameter_id
				) SPRNG  
			ON (SFNC.function_id = SPRNG.function_id) 
			AND (SPRM.parameter_id = SPRNG.parameter_id)

	WHERE (STAB.is_ms_shipped = 0)
		AND (SSCH.[name] IS NOT NULL)
		AND (SIDX.index_id IN (0,1))
		
	ORDER BY TopBoundary, SchemaName, TableName