
----------------------
-- script stats
-- not compatible with sql 2005
-- does not include STATS_STREAM
-- marcello miorelli
-- 30-sep-2016
-----------------------

WITH STCOLS AS (
		SELECT	sts.[object_id],
				sts.stats_id,
				STUFF((
					SELECT ',' + QUOTENAME(c.[name])
						FROM sys.stats_columns sc
							 INNER JOIN sys.columns c
								 ON c.[object_id] = sc.[object_id]
									AND c.column_id = sc.column_id
						WHERE sc.[object_id] = sts.[object_id]
							  AND sc.stats_id = sts.stats_id
						ORDER BY sc.stats_column_id FOR XML PATH('')
				), 1, 1, '') AS ColListQ,
				STUFF((
					SELECT '_' + c.[name]
						FROM sys.stats_columns sc
							 INNER JOIN sys.columns c
								 ON c.[object_id] = sc.[object_id]
									AND c.column_id = sc.column_id
						WHERE sc.[object_id] = sts.[object_id]
							  AND sc.stats_id = sts.stats_id
						ORDER BY sc.stats_column_id FOR XML PATH('')
				), 1, 1, '') AS ColList
			FROM sys.stats sts
	)
SELECT DISTINCT 
	   OBJECT_SCHEMA_NAME(obj.[object_id]) AS [Schema], 
	   obj.[name] AS TableName, 
	   s.name AS StatName, 
	   s.stats_id, 
	   STATS_DATE(s.[object_id], s.stats_id) AS LastUpdated, 
	   s.auto_created, 
	   s.user_created, 
	   s.no_recompute, 
	   s.is_incremental, 
	   s.is_temporary, 
	   s.filter_definition, -- not compatible with sql 2005
	   s.[object_id], 
	   IIF(LEN(ISNULL(s.filter_definition,'')) > 0, ' WHERE ' + s.filter_definition, ''),
	   THE_SCRIPT = 'CREATE STATISTICS [' + 
					IIF(S.[name] LIKE '_WA_Sys%', 'STS_'+obj.[name]+'_'+STCOLS.ColList, s.[name]) + '] ON ' + QUOTENAME(SCHEMA_NAME(obj.schema_id)) + '.' + QUOTENAME(obj.[name]) + '(' + STCOLS.ColListQ
	   + ')' + 
	   IIF(LEN(ISNULL(s.filter_definition,'')) > 0, ' WHERE ' + s.filter_definition, '') + 
		ISNULL(STUFF( 
		--ISNULL(',STATS_STREAM = ' + @StatsStream, '') +
		CASE
			WHEN s.no_recompute = 1
			THEN ', NORECOMPUTE'
			ELSE ''
		END + CASE
				  WHEN s.is_incremental = 1
				  THEN ', INCREMENTAL=ON'
				  ELSE ''
			  END, 1, 1, ' WITH '), '')
	FROM sys.stats s
		 INNER JOIN sys.partitions par
			 ON par.[object_id] = s.[object_id]
		 INNER JOIN sys.objects obj
			 ON par.[object_id] = obj.[object_id]
	     INNER JOIN STCOLS	
			 ON (s.[object_id] = STCOLS.[object_id]) AND (s.[stats_id] = STCOLS.[stats_id])
	WHERE 1 = 1
		  AND OBJECTPROPERTY(s.OBJECT_ID, 'IsUserTable') = 1
		  AND (s.auto_created = 1
			   OR s.user_created = 1)

	ORDER BY [SCHEMA],TableName, s.stats_id