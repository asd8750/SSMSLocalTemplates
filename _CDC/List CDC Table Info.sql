if OBJECT_ID('[cdc].[change_tables]') is not null
	WITH RC AS (
			SELECT object_id, SUM(row_count) as row_count
				FROM (  SELECT DISTINCT object_id, partition_number, row_count
						FROM [sys].[dm_db_partition_stats] ) dprc
				GROUP BY object_id
				)
		 ,TS AS (
			SELECT	ddps.object_id,
					SUM([ddps].[in_row_data_page_count]/128) AS  [in_row_data_page_count] ,
					SUM([ddps].[in_row_used_page_count]/128)  AS [in_row_used_page_alloc] ,
					SUM([ddps].[in_row_reserved_page_count])  AS [in_row_reserved_page_count] ,
					SUM([ddps].[lob_used_page_count]) AS  [lob_used_page_count] ,
					SUM([ddps].[lob_reserved_page_count])  AS [lob_reserved_page_count] ,
					SUM([ddps].[row_overflow_used_page_count])  AS [row_overflow_used_page_count] ,
					SUM([ddps].[row_overflow_reserved_page_count])  AS [row_overflow_reserved_page_count] ,
					SUM([ddps].[used_page_count]) AS  [used_page_count] ,
					SUM([ddps].[reserved_page_count])  AS [reserved_page_count] 
				FROM [sys].[dm_db_partition_stats] ddps
				GROUP BY ddps.object_id
				)
	SELECT TOP 1000 CT.[object_id]
		  ,CT.[source_object_id]
		  ,OBJECT_SCHEMA_NAME(CT.[object_id]) AS CDCTableSchema
		  ,OBJECT_NAME(CT.[object_id]) AS CDCTableName
		  ,CT.[capture_instance]
		  ,CT.[start_lsn]
		  ,CT.[supports_net_changes]
		  ,CT.[role_name]
		  ,CT.[index_name]
		  ,CT.[filegroup_name]
		  ,CT.[create_date]
		  ,RC.row_count
		  ,TS.used_page_count
		  ,convert(float,TS.used_page_count) / 128.0 as SizeMb
		  ,ServerProperty('ServerName') AS ServerName
		  ,DB_NAME() AS DBname
		  ,OBJECT_SCHEMA_NAME(CT.source_object_id) AS SrcTableSchema
		  ,OBJECT_NAME(CT.source_object_id) AS SrcTableName,
		  CONCAT('EXEC sys.sp_cdc_enable_table ',
				'@source_schema = N''' + OBJECT_SCHEMA_NAME(CT.source_object_id) + ''', ',
				'@source_name = N''' + OBJECT_NAME(CT.source_object_id) + ''', ',
				'@role_name = N''' + CT.[role_name] + ''', ',
				'@capture_instance = N''' + OBJECT_SCHEMA_NAME(CT.source_object_id) + '_' + OBJECT_NAME(CT.source_object_id) + ''', ',
				'@supports_net_changes = 1, ',
				'@index_name = N''' + CT.[index_name] + ''', ',
				'@filegroup_name = N''' + CT.[filegroup_name] + '''; '
				) AS CmdEnableTable,
		 CONCAT('EXEC sys.sp_cdc_disable_table ',
				'@source_schema = N''' + OBJECT_SCHEMA_NAME(CT.source_object_id) + ''', ',
				'@source_name = N''' + OBJECT_NAME(CT.source_object_id) + ''', ',
				'@capture_instance = N''' + OBJECT_SCHEMA_NAME(CT.source_object_id) + '_' + OBJECT_NAME(CT.source_object_id) + '''; '
				) AS CmdDIsableTable
	  FROM [cdc].[change_tables] CT
			INNER JOIN TS
				ON (CT.object_id = ts.object_id)
			INNER JOIN RC
				ON (CT.object_id = rc.object_id) 
	ORDER BY SrcTableSchema, SrcTableName
