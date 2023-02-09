IF (OBJECT_ID('tempdb..#PT') IS NOT NULL)
	DROP TABLE #PT;

SELECT	DISTINCT
		OBJECT_SCHEMA_NAME(RG.[object_id]) AS SchemaName,
		OBJECT_NAME(RG.[object_id]) AS TableName,
		SIDX.[name] AS IndexName,
		SFNC.[name] AS PtFunc,
		--SIDXC.column_id AS ColOrd,
		--(SELECT [name] FROM sys.types STY WHERE (STY.system_type_id = COL.system_type_id) ) AS PtColData,
		RG.partition_number,

		 CONCAT('ALTER INDEX ',
				QUOTENAME(SIDX.[name],'['),
				' ON ',
				QUOTENAME(OBJECT_SCHEMA_NAME(RG.[object_id]),'['),
				'.',
				QUOTENAME(OBJECT_NAME(RG.[object_id]),'['),
				' REORGANIZE PARTITION = ',
				CONVERT(VARCHAR(4),RG.partition_number),
				' WITH ( COMPRESS_ALL_ROW_GROUPS = ON)',
				CHAR(13) + CHAR(10),
				'GO',
				CHAR(13) + CHAR(10), 
				'',CHAR(13) + CHAR(10)) AS RebuildStmt
	INTO  #PT
	FROM sys.column_store_row_groups RG
		INNER JOIN sys.indexes SIDX
			ON (RG.[object_id] = SIDX.[object_id]) AND (RG.index_id = SIDX.index_id)
		LEFT OUTER JOIN 
			(sys.index_columns SIDXC 
				INNER JOIN sys.columns COL
					ON (COL.object_id = SIDXC.object_id) AND (COL.column_id = SIDXC.column_id)
				INNER JOIN sys.types STY 
					ON (STY.system_type_id = COL.system_type_id))
				ON (SIDXC.object_id = SIDX.object_id) AND (SIDXC.index_id = SIDX.index_id) AND (SIDXC.partition_ordinal <> 0)
		LEFT OUTER JOIN sys.partitions SPAR  
			ON (SIDX.object_id = SPAR.object_id) AND (SIDX.index_id = SPAR.index_id)
		LEFT OUTER JOIN sys.partition_schemes SSCH  
			ON (SIDX.data_space_id = SSCH.data_space_id)
		LEFT OUTER JOIN sys.partition_functions SFNC  
			ON (SSCH.function_id = SFNC.function_id)
	WHERE (state_description = 'OPEN')
		AND (STY.[name] LIKE '%DATE%')
		AND (RG.[total_rows] > 0)
	ORDER BY 1;

	--SELECT * FROM  #PT;
	DECLARE @PtSelect VARCHAR(MAX);

	WITH PTL AS (
	SELECT DISTINCT PtFunc
		FROM #PT
		)
	SELECT @PtSelect = STUFF((SELECT 'UNION ALL SELECT ' + QUOTENAME(PtFunc, '''') + ' AS PtFunc, ' + 
						'$PARTITION.' + QUOTENAME(PtFunc, '[') + '(GETDATE()) AS CurPtNum ' 
			FROM PTL
			FOR XML PATH('')), 1,10, '');

    --PRINT @PtSelect;

	DECLARE @CurPtList TABLE ( PtFunc VARCHAR(256), CurPtNum INT);
	INSERT INTO @CurPtList (PtFunc, CurPtNum)
	EXEC (@PtSelect);

	SELECT * FROM @CurPtList;

	SELECT	PT.RebuildStmt
		FROM #PT PT
			INNER JOIN @CurPtList CPT
				ON (PT.PtFunc = CPT.PtFunc)
		WHERE (PT.partition_number <> CPT.CurPtNum)
		ORDER BY 1;

	DROP TABLE #PT;


