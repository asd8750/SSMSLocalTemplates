
DECLARE	@MinimumRows	INT = 100000	-- Mimimum number of rows in a rowgroup to trigger a forced reorg


DECLARE @curDB CURSOR;
SET @curDB = CURSOR FORWARD_ONLY FOR 
	WITH CSI AS (
			SELECT	DISTINCT
					TOP (1000000)
					--OBJECT_SCHEMA_NAME(RG.[object_id]) AS SchemaName,
					--OBJECT_NAME(RG.[object_id]) AS TableName,
					--SI.[name] AS IndexName,
					--RG.partition_number,
					--RG.row_group_id,
					--RG.total_rows,
					--RG.deleted_rows,
					--RG.*
					CONCAT('ALTER INDEX ',
							QUOTENAME(SI.[name],'['),
							' ON ',
							QUOTENAME(OBJECT_SCHEMA_NAME(RG.[object_id]),'['),
							'.',
							QUOTENAME(OBJECT_NAME(RG.[object_id]),'['),
							' REORGANIZE PARTITION = ',
							CONVERT(VARCHAR(4),RG.partition_number),
							' WITH ( COMPRESS_ALL_ROW_GROUPS = ON)') AS ReorgCmd
				FROM sys.column_store_row_groups RG
					INNER JOIN sys.indexes SI
						ON (RG.[object_id] = SI.[object_id]) AND (RG.index_id = SI.index_id)
				WHERE (state_description = 'OPEN')
					AND (RG.total_rows >= @MinimumRows)
				ORDER BY ReorgCmd
			)
	SELECT	CSI.ReorgCmd
		FROM CSI;

OPEN @curDB;

DECLARE @ErrMsg  VARCHAR(2000);

DECLARE	@ReorgCmd	VARCHAR(2000);
FETCH NEXT FROM @curDB INTO @ReorgCmd;
WHILE (@@FETCH_STATUS = 0)
	BEGIN
		RAISERROR ('Reorg: %s', 0, 1, @ReorgCmd) WITH NOWAIT;
		BEGIN TRY
			EXEC (@ReorgCmd);
		END TRY
		BEGIN CATCH
			SELECT @ErrMsg = ERROR_MESSAGE();
			RAISERROR ('  Error: %s', 0, 1, @ErrMsg) WITH NOWAIT;
		END CATCH;
		FETCH NEXT FROM @curDB INTO @ReorgCmd;
	END;

CLOSE @curDB;
DEALLOCATE @curDB;

