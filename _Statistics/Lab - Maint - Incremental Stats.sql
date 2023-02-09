DECLARE @STS TABLE
([object_id]                [INT] NOT NULL, 
 [stats_id]                 [INT] NOT NULL, 
 [name]                     [NVARCHAR](128) NULL, 
 [ColName]                  [SYSNAME] NULL, 
 [has_filter]               [BIT] NULL, 
 [filter_definition]        [NVARCHAR](MAX) NULL, 
 [is_incremental]           [BIT] NULL, 
 [is_temporary]             [BIT] NULL, 
 [user_created]             [BIT] NULL, 
 [last_updated]             [DATETIME2](7) NULL, 
 [rows]                     [BIGINT] NULL, 
 [rows_sampled]             [BIGINT] NULL, 
 [steps]                    [INT] NULL, 
 [modification_counter]     [BIGINT] NULL, 
 [persisted_sample_percent] [FLOAT] NOT NULL
);


INSERT INTO @STS
([object_id], 
 [stats_id], 
 [name], 
 [ColName], 
 [has_filter], 
 [filter_definition], 
 [is_incremental], 
 [is_temporary], 
 [user_created], 
 [last_updated], 
 [rows], 
 [rows_sampled], 
 [steps], 
 [modification_counter], 
 [persisted_sample_percent]
)
SELECT DISTINCT 
	   ST.[object_id], 
	   ST.stats_id, 
	   ST.[name], 
	(
		SELECT TOP (1) COL.[name] AS ColName
			FROM sys.stats_columns stc
				 INNER JOIN sys.columns COL
					 ON (COL.[object_id] = stc.[object_id])
						AND (COL.column_id = stc.column_id)
			WHERE (ST.[object_id] = stc.[object_id])
				  AND (ST.stats_id = stc.stats_id)
			ORDER BY stc.stats_column_id
	) AS ColName, 
	   ST.has_filter, 
	   ST.filter_definition, 
	   ST.is_incremental, 
	   ST.is_temporary, 
	   ST.user_created, 
	   SP.last_updated, 
	   SP.[rows], 
	   SP.rows_sampled, 
	   SP.[steps], 
	   SP.modification_counter, 
	   ISNULL(SP.persisted_sample_percent, 0) AS persisted_sample_percent
	  -- ,PTSCH.*
	FROM sys.stats ST
		 INNER JOIN sys.indexes IDX
			 ON (ST.[object_id] = IDX.[object_id]) 
		 INNER JOIN sys.partition_schemes PTSCH
			 ON (IDX.data_space_id = PTSCH.data_space_id) 
		 INNER JOIN sys.objects OBJ
			 ON (ST.[object_id] = OBJ.[object_id]) 
		 CROSS APPLY sys.dm_db_stats_properties(ST.[object_id], ST.stats_id) SP
	WHERE (PTSCH.[type] = 'PS')
		  AND (OBJ.is_ms_shipped = 0)
		  AND (( (IDX.[name] = ST.[name])
				 AND (IDX.[type] NOT IN(5, 6)))
	OR ( (IDX.[name] <> ST.[name])
		 AND (IDX.[type] IN(0, 1, 5))))
--AND (OBJECT_SCHEMA_NAME(OBJ.[object_id]) NOT IN('DBA-Stg', 'DBA-Post'));


SELECT OBJECT_SCHEMA_NAME(STS.[object_id]) AS SchemaName, 
	   OBJECT_NAME(STS.[object_id]) AS TableName, 
	   STS.[name] AS StatsName, 
	   STS.stats_id, 
	   STS.persisted_sample_percent,
	   ((STS.rows_sampled * 100) / STS.[rows]) AS samplepct, 
	   STS.is_temporary, 
	   STS.user_created,
	   CONCAT('RAISERROR(''[', OBJECT_SCHEMA_NAME(STS.[object_id]), '].[', OBJECT_NAME(STS.[object_id]), '] - STAT: ', STS.[name], ''', 0, 1) WITH NOWAIT;') + CHAR(13) + CHAR(10) +
	   CASE
		   WHEN (is_temporary <> 0)
				AND (user_created = 0)
		   THEN CONCAT('CREATE STATISTICS [STS_', OBJECT_NAME(STS.[object_id]), '_', STS.ColName, '] ON ', '[', OBJECT_SCHEMA_NAME(STS.[object_id]), '].[', OBJECT_NAME(STS.[object_id]), ']([', STS.ColName, ']) ', 'WITH INCREMENTAL=ON, SAMPLE 5 PERCENT, PERSIST_SAMPLE_PERCENT = ON', CHAR(13), CHAR(10))
		   ELSE CONCAT('UPDATE STATISTICS [', OBJECT_SCHEMA_NAME(STS.[object_id]), '].[', OBJECT_NAME(STS.[object_id]), ']([', STS.[name], ']) ', 'WITH INCREMENTAL=ON, SAMPLE 5 PERCENT, PERSIST_SAMPLE_PERCENT = ON', CHAR(13), CHAR(10))
	   END +
	   'WAITFOR DELAY ''00:00:15'';' +  CHAR(13) + CHAR(10) +
	   'GO' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) 
	   AS StsSetupCmd
	FROM @STS STS
	WHERE (STS.is_incremental = 0)
		  OR (STS.persisted_sample_percent < 5)
	ORDER BY SchemaName, 
			 TableName, 
			 STS.stats_id;
	





SELECT OBJECT_SCHEMA_NAME(STS.[object_id]) AS SchemaName, 
	   OBJECT_NAME(STS.[object_id]) AS TableName, 
	   STS.[name] AS StatsName, 
	   STS.stats_id, 
	   STS.is_incremental, 
	   ISP.partition_number, 
	   ((ISP.rows_sampled * 100) / ISP.[rows]) AS samplepct, 
	   ISP.[rows], 
	   ISP.[rows_sampled], 
	   ISP.[steps], 
	   ISP.[modification_counter], 
	   ISP.last_updated, 
	   CONCAT('UPDATE STATISTICS [', OBJECT_SCHEMA_NAME(STS.[object_id]), '].[', OBJECT_NAME(STS.[object_id]), ']([', STS.[name], ']) ', 'WITH RESAMPLE ON PARTITIONS(', CONVERT(VARCHAR(5), ISP.partition_number), ')') AS UpdateCmd
--,STS.*, 
--ISP.*
	FROM @STS STS
		 INNER JOIN sys.objects OBJ
			 ON (STS.[object_id] = OBJ.[object_id]) 
		 CROSS APPLY sys.dm_db_incremental_stats_properties(STS.[object_id], STS.stats_id) ISP
	WHERE (Obj.[type] = 'U')
		  AND (STS.is_incremental = 1)
		  AND (((ISP.modification_counter IS NOT NULL)
				AND (ISP.modification_counter > 1000) )
			   OR (((ISP.rows_sampled * 100) / ISP.[rows]) < 2) )
		  AND (OBJECT_SCHEMA_NAME(STS.[object_id]) <> 'DBA-Post')
	ORDER BY SchemaName, 
			 TableName, 
			 STS.stats_id, 
			 ISP.partition_number;

--UPDATE STATISTICS [DBA-STG].[PdrBarCodeEvent]([NCUI_PdrBarcodeEvent_PdrBarcodeEventId-TimeStmpUtc]) WITH INCREMENTAL=ON, SAMPLE 5 PERCENT, PERSIST_SAMPLE_PERCENT = ON


--SELECT *
--	FROM sys.stats STS
--		 CROSS APPLY sys.dm_db_incremental_stats_properties(STS.[object_id], STS.stats_id) ISP
--	WHERE (is_temporary <> 0)
--		  AND (user_created = 0);
