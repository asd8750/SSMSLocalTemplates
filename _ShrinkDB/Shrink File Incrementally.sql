USE [MesSystem]		-- Set to database that needs shrinking

DECLARE @SegName		VARCHAR(128);
DECLARE @SegAllocatedMB	DECIMAL(12,2);
DECLARE @SegSizeMB		DECIMAL(12,2);
DECLARE @SegPercentUsed	DECIMAL(12,2);

DECLARE @ChunkSize		DECIMAL(12,0);
DECLARE @MinFreeSpace	DECIMAL(12,0);
DECLARE @CurFreeSpace	DECIMAL(12,0);
DECLARE @NextSize		DECIMAL(12,0);

DECLARE @DBCCCmd		NVARCHAR(4000);

SET @SegName = 'MesSystem';		-- Database logical filename that needs shrinking
SET @ChunkSize = 2000;			-- # MB to shrink on each pass
SET @MinFreeSpace = 60000;		-- Stop the loop when reduce the free space to this level in MB

SET @CurFreeSpace = @MinFreeSpace + 1;

WHILE (@CurFreeSpace > @MinFreeSpace)
	BEGIN;

		WITH DBI AS (
				SELECT  RTRIM(name) AS [SegmentName] ,
						groupid AS [GroupId] ,
						filename AS [FileName] ,
						CAST(size / 128.0 AS DECIMAL(12, 2)) AS [MBAllocated] ,
						CAST(FILEPROPERTY(name, 'SpaceUsed') / 128.0 AS DECIMAL(12, 2)) AS [MBUsed] ,
						CAST((CAST(FILEPROPERTY(name, 'SpaceUsed') AS DECIMAL(12, 2)) /
								CAST(CASE WHEN [size]> 0 THEN [size] ELSE 1.0 END  AS DECIMAL(12, 2))) * 100.0 AS DECIMAL(12,2))  AS [PercentUsed]
				FROM    sysfiles
				-- ORDER BY [SegmentName] 
			)
		SELECT	@SegAllocatedMB = MBAllocated,
				@SegSizeMB = MBUsed,
				@SegPercentUsed = PercentUsed
			FROM DBI
			WHERE (SegmentName = @SegName);

		SET @CurFreeSpace = @SegAllocatedMB - @SegSizeMB
	
		IF (@CurFreeSpace > @MinFreeSpace)
			BEGIN
				SET @NextSize = @SegAllocatedMB - @ChunkSize;
				SET @DBCCCmd = 'DBCC SHRINKFILE (N' + QUOTENAME(@SegName, '''') + ' , ' + CONVERT(VARCHAR(12), @NextSize) + ')';
				--PRINT @DBCCCmd;
				RAISERROR (@DBCCCmd, 0, 1) WITH NOWAIT;
				EXECUTE (@DBCCCmd);
			END;

	END;
	-- 
	-- DBCC SHRINKFILE (N'MesSystem' , 1952000)