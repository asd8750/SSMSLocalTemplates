


WITH PTB AS (	  
	  SELECT TOP ( 2000000000 )
             COALESCE (SPRV1.function_id, SPRV2.function_id) AS function_id,
             COALESCE (SPRV2.boundary_id, SPRV1.boundary_id + 1) AS boundary_id,
             CAST(ISNULL (SPRV1.[value], CONVERT (DATE, '1900-01-01')) AS DATE) AS Bndry1,
             CAST(ISNULL (SPRV2.[value], CONVERT (DATE, '2200-01-01')) AS DATE) AS Bndry2
         FROM sys.partition_range_values SPRV1
             FULL OUTER JOIN sys.partition_range_values SPRV2
               ON ( SPRV1.function_id = SPRV2.function_id )
                  AND ( SPRV1.boundary_id = ( SPRV2.boundary_id - 1 ))
             INNER JOIN sys.partition_parameters SPP
                ON ( SPP.function_id = COALESCE (SPRV1.function_id, SPRV2.function_id))
             INNER JOIN
                 (
                     SELECT *
                        FROM sys.types
                        WHERE
                         ( [name] IN ( 'date', 'datetime', 'datetime2', 'datetimeoffset', 'smalldatetime' ))
                 ) FType
                ON ( SPP.user_type_id = FType.user_type_id )
		)
	SELECT	OBJECT_SCHEMA_NAME(TAB.[object_id]) AS SrcSchemaName,
			TAB.[name] AS SrcTableName,
			OBJECT_SCHEMA_NAME(TAB2.[object_id]) AS DstSchemaName,
			TAB2.[name] AS DstTableName,
			--PTSCH.[name] AS PtScheme,
			PT.partition_number,
			PTB.Bndry1,
			PTB.Bndry2,
			PT.[rows] AS RowCnt,
			CONCAT(
				'ALTER TABLE ',
				QUOTENAME(OBJECT_SCHEMA_NAME(TAB.[object_id])), '.', QUOTENAME(TAB.[name]),
				' SWITCH PARTITION ', CONVERT(VARCHAR(10), PT.partition_number),
				' TO ', QUOTENAME(OBJECT_SCHEMA_NAME(TAB2.[object_id])), '.', QUOTENAME(TAB2.[name]),
				' PARTITION ', CONVERT(VARCHAR(10), PT.partition_number),
				' WITH (WAIT_AT_LOW_PRIORITY, MAX_DURATION=1 minute, ABORT_AFTER_WAIT=SELF)'
				) AS SqlSwitch

		FROM sys.tables TAB
			INNER JOIN sys.indexes IDX
				ON (TAB.[object_id] = IDX.[object_id])
			INNER JOIN sys.partitions PT
				ON (TAB.[object_id] = PT.[object_id]) AND (IDX.[index_id] = PT.[index_id])
			INNER JOIN sys.partition_schemes PTSCH  
				ON (IDX.data_space_id = PTSCH.data_space_id)
			INNER JOIN PTB	
				ON (PTSCH.function_id = PTB.function_id) AND (PT.partition_number = PTB.boundary_id)
			INNER JOIN sys.tables TAB2
				ON (TAB.[name] = TAB2.[name]) AND (TAB.[object_id] <> TAB2.[object_id])
		WHERE (OBJECT_SCHEMA_NAME(TAB.[object_id]) NOT IN ('DBA-Stg', 'DBA-Post'))
			AND (OBJECT_SCHEMA_NAME(TAB2.[object_id]) IN ('DBA-Stg'))
			AND (TAB.[name] IN ('PdrEquipmentState', 'PdrPartProducedEvent'))
			AND (IDX.[type] IN (1,5))
			AND (PT.[rows] > 0)
			AND (PTB.Bndry2 <= '2020-01-01')

		ORDER BY SrcSchemaName, SrcTableName, PT.index_id, PT.partition_number