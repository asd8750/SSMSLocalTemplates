IF OBJECT_ID('tempdb..#TBL') IS NOT NULL
	DROP TABLE  #TBL;

IF (1=1)
	BEGIN
		SELECT	OBJECT_SCHEMA_NAME(TAB.[object_id]) AS SchemaName,
				TAB.[name] AS TableName,
				CONCAT(QUOTENAME(OBJECT_SCHEMA_NAME(TAB.[object_id]), '['), '.',
						QUOTENAME(TAB.[name], '[')
					) AS FullTableName,
				pf.[name] AS PtFunc,
				ROW_NUMBER() OVER (ORDER BY TAB.[name]) AS RN
				,PTI.*
			INTO #TBL
			FROM sys.tables TAB
				INNER JOIN sys.indexes IDX
					ON (TAB.[object_id] = IDX.[object_id])
				INNER JOIN sys.partition_schemes ps
					  ON IDX.data_space_id = ps.data_space_id
				INNER JOIN sys.partition_functions pf
					   ON ps.function_id = pf.function_id
				LEFT OUTER JOIN (
					SELECT  IDXC.[object_id],
							IDXC.index_id,
							COL.[name] AS PtColName
						FROM sys.index_columns IDXC
							INNER JOIN sys.columns COL
								ON (IDXC.[object_id] = COL.[object_id])
									AND (IDXC.column_id = COL.column_id)
							INNER JOIN sys.types TYP
								ON (COL.system_type_id = TYP.system_type_id)
						WHERE (IDXC.partition_ordinal > 0)
							) PTI
					ON (TAB.[object_id] = PTI.[object_id])
						AND (IDX.[index_id] = PTI.[index_id])
			WHERE --(IDX.[type] = 1) AND 
				(IDX.data_space_id > 6000)
				AND (pf.[name] = 'LogEntry_pf')
				--AND (TAB.[name] = 'LogEntryPrinting')
			ORDER BY FullTableName
	END;

SET NOCOUNT ON;
DECLARE @DeletedThisPass INT = 1
DECLARE @DeletedTotals INT = 0

DECLARE @tidx INT = 1;
DECLARE @FullTableName VARCHAR(128);
DECLARE @PtColName  VARCHAR(128);

DECLARE @cmd VARCHAR(4000);

WHILE (1=1)
	BEGIN
		SELECT	@FullTableName = FullTableName,
				@PtColName     = PtColName
			FROM #TBL
			WHERE (RN = @tidx);
		IF @@ROWCOUNT < 1
			BREAK;

		RAISERROR ('Table: %s  (%s) ...', 0, 1, @FullTableName, @PtColName) WITH NOWAIT;
		SET @cmd = CONCAT('TRUNCATE TABLE [MESLogging].',
							@FullTableName,
							' WITH (PARTITIONs ( 1 TO 27))');
		--PRINT @cmd;
		--EXECUTE (@cmd);

		SET @DeletedTotals = 0
		SET @DeletedThisPass = 1
		WHILE (@DeletedThisPass > 0)
			BEGIN
				SET @cmd = CONCAT('DELETE TOP (100000) ', @FullTableName, 'WHERE ([', @PtColName ,'] < DATEADD(DAY, -3, CAST(GETDATE() AS DATE)))
						AND ($PARTITION.LogEntry_pf([', @PtColName ,']) = 2)')
				--PRINT @cmd;
				EXECUTE (@cmd);
				SET @DeletedThisPass = @@ROWCOUNT
				SET @DeletedTotals = @DeletedTotals + @DeletedThisPass;
				RAISERROR ('... Deleted - %d', 0, 1, @DeletedTotals) WITH NOWAIT;
				IF (@DeletedThisPass > 0)
					WAITFOR DELAY '00:00:02'
			END
		SET @tidx = @tidx + 1;
	END
