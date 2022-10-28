
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @myNumber INT;

 -- Compression statement constructed here
DECLARE @CmdCompress NVARCHAR(4000);
DECLARE @CmdCompletion NVARCHAR(4000);
DECLARE @Msg NVARCHAR(256);
DECLARE @pLabel VARCHAR(128);

DECLARE @cpuWorkAdjusted_5Min DECIMAL(5, 1);

DECLARE @pID INT;
			-- Record ID from the PartitionInfo table
DECLARE @pDatabaseName VARCHAR(128);
DECLARE @pTableSchema VARCHAR(128);
DECLARE @pTableName VARCHAR(128);
DECLARE @pIndexName VARCHAR(128);
DECLARE @pIndexID INT;
			-- Index ID: 0-Heap, 1-Clustered Table/Index, 2+ - Non-clustered Indexes
DECLARE @pPartitionNo INT;
DECLARE @pPartitionBoundary DATETIME;

DECLARE @LoopStart DATETIME;
DECLARE @LoopFinish DATETIME;

DECLARE @CompressStart DATETIME;
DECLARE @CompressFinish DATETIME;

DECLARE @errorMessage VARCHAR(4000);

DECLARE @skip INT;
DECLARE @skip2 INT;
DECLARE @duration INT;

--
--	Build a blocked table delay list
--
DECLARE @delay TABLE
    (
      DatabaseName VARCHAR(128) ,
      TableSchema VARCHAR(128) ,
      TableName VARCHAR(128) ,
      TimeResume DATETIME
    );

--
--	Build the list of eligible partitions then use a cursor to loop through it -- ROLLBACK TRANSACTION;
--
DECLARE @pList TABLE
    (
      ID INT ,
      DatabaseName VARCHAR(128) ,
      TableSchema VARCHAR(128) ,
      TableName VARCHAR(128) ,
      IndexName VARCHAR(128) ,
      IndexID INT ,
      PartitionNo INT ,
      PartitionBoundary DATETIME ,
      DBRowNum INT
    );

INSERT  INTO @pList
        ( ID ,
          DatabaseName ,
          TableSchema ,
          TableName ,
          IndexName ,
          IndexID ,
          PartitionNo ,
          PartitionBoundary ,
          DBRowNum
        )
        SELECT  ID ,
                DatabaseName ,
                TableSchema ,
                TableName ,
                IndexName ,
                IndexID ,
                PartitionNo ,
                PartitionBoundary ,
                DBRowNum
        FROM    OPENQUERY(EDR1SQL01N901, '
WITH    Bckups
              AS ( SELECT   DISTINCT
                            r.session_id ,
                            r.command ,
                            DB_NAME(r.database_id) AS DatabaseName ,
                            CONVERT(NUMERIC(6, 2), r.percent_complete) AS [Percent Complete] ,
                            CONVERT(VARCHAR(1000), ( SELECT SUBSTRING(text, r.statement_start_offset / 2,
                                                                      CASE WHEN r.statement_end_offset = -1 THEN 1000
                                                                           ELSE ( r.statement_end_offset - r.statement_start_offset ) / 2
                                                                      END)
                                                     FROM   sys.dm_exec_sql_text(sql_handle)
                                                   )) AS SqlText
                   FROM     sys.dm_exec_requests r
                   WHERE    r.command IN ( ''BACKUP DATABASE'' )
                 ),
            PList
              AS ( SELECT   [ID] ,
                            [DatabaseName] ,
                            [TableSchema] ,
                            [TableName] ,
                            [IndexName] ,
                            [IndexID] ,
                            [PartitionNo] ,
                            [PartitionBoundary] ,
							--[CompressionStart],
							--[CompressionFinish],
                            ROW_NUMBER() OVER ( PARTITION BY [DatabaseName] ORDER BY [PartitionBoundary] DESC, [TableSchema], [TableName], [IndexID] ) AS DBRowNum
                   FROM     [DBA_Control].[dbo].[PartitionInfo] DPI
                   WHERE    ( Compression = ''NONE'' )
                            AND ( TotalPages >= 128 )
                            AND ( TableSchema = ''Performance'' )
                            --AND ( PartitionBoundary < ''2016-10-14'' )
                            AND ( ( CompressionStart IS NULL )
                                  OR ( ( CompressionStart IS NOT NULL )
                                       AND ( CompressionFinish IS NULL )
                                       AND ( DATEDIFF(HOUR, CompressionStart, GETDATE()) > 0 )
                                     )
                                )
                 )
        SELECT TOP ( 100 )
                *
        FROM    PList
        WHERE   ( DatabaseName NOT IN ( SELECT  DatabaseName
                                        FROM    Bckups ) )
        ORDER BY [DBRowNum];');

DECLARE pCurs CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY
FOR
    SELECT  [ID] ,
            [DatabaseName] ,
            [TableSchema] ,
            [TableName] ,
            [IndexName] ,
            [IndexID] ,
            [PartitionNo] ,
            [PartitionBoundary]
    FROM    @pList
    ORDER BY [DBRowNum] ,
            [DatabaseName] ,
            [TableSchema] ,
            [TableName] ,
            [IndexName] ,
            [IndexID];
OPEN pCurs;

--
--	Repeat Loop
--
SET @LoopStart = GETDATE()
SET @LoopFinish = DATEADD(MI, 57, GETDATE());

FETCH pCurs INTO @pID, @pDatabaseName, @pTableSchema, @pTableName, @pIndexName, @pIndexID, @pPartitionNo, @pPartitionBoundary;

WHILE ( ( GETDATE() < @LoopFinish )
        AND ( @@FETCH_STATUS = 0 )
      )
    BEGIN;

--
--	Build the logging label
--
        SELECT  @pLabel = FORMATMESSAGE('%s - [%s].[%s].[%s] IDX:(%d) P:%d - %s', CONVERT(VARCHAR(30), GETDATE(), 120), @pDatabaseName, @pTableSchema,
                                        @pTableName, @pIndexID, @pPartitionNo, CONVERT(VARCHAR(30), COALESCE(@pPartitionBoundary, '1900-01-01'), 120));
 
--
--	Check current CPU loading
--
        DECLARE @strCpuWork VARCHAR(10);
        SELECT  @strCpuWork = CAST(CpuWorkAdjusted_5Min AS VARCHAR(10))
        FROM    OPENQUERY(EDR1SQL01N901, 'SELECT CpuWorkAdjusted_5Min FROM DBA_Control.dbo.tvf_CpuLoadAverages(NULL, 1)');
        IF @cpuWorkAdjusted_5Min >= 95.0
            BEGIN
                RAISERROR('%s -- High CPU - %s', 0, 1, @pLabel, @strCpuWork) WITH NOWAIT;
                WAITFOR DELAY '00:30:00';
                CONTINUE;
            END;

--
--	Get List of active Database Backups 
--
        DECLARE @backups TABLE
            (
              DatabaseName VARCHAR(128)
            );

        INSERT  INTO @backups
                ( DatabaseName
                )
                SELECT  DISTINCT
                        DatabaseName
                FROM    OPENQUERY(EDR1SQL01N901, 'SELECT r.command ,
                        DB_NAME(r.database_id) AS DatabaseName ,
                        CONVERT(VARCHAR(1000), ( SELECT SUBSTRING(text, r.statement_start_offset / 2,
                                                                  CASE WHEN r.statement_end_offset = -1 THEN 1000
                                                                       ELSE ( r.statement_end_offset - r.statement_start_offset ) / 2
                                                                  END)
                                                 FROM   sys.dm_exec_sql_text(sql_handle)
                                               )) AS SqlText
               FROM     sys.dm_exec_requests r
               WHERE    r.command IN ( ''BACKUP DATABASE'' )');

		--	Skip this partition if the database is being backed up. 
		--	Exit the loop and terminate the job.  It will restart with a new set of potential partition targets
		--
        SELECT  @skip = COUNT(*)
        FROM    @backups
        WHERE   ( DatabaseName = @pDatabaseName );
        DELETE  FROM @backups;
        IF ( @skip > 0 )
            BEGIN
                RAISERROR('%s -- Skipped - Backup Active', 0, 1, @pLabel) WITH NOWAIT;
                BREAK;
            END;

		--	Skip this partition if the table is marked as busy
		--
        SELECT  @skip2 = COUNT(*)
        FROM    @delay
        WHERE   ( DatabaseName = @pDatabaseName )
                AND ( TableSchema = @pTableSchema )
                AND ( TableName = @pTableName )
                AND ( TimeResume > GETDATE() );
        IF ( @skip2 > 0 )
            BEGIN
                RAISERROR('%s -- Skipped - Table Busy', 0, 1, @pLabel) WITH NOWAIT;
            END;

        IF ( ( @skip + @skip2 ) = 0 )
            BEGIN
			-- 
			--	Build the compress statement
			--
                SET @CmdCompress = 'USE ' + QUOTENAME(@pDatabaseName, '[') + ';' + CHAR(13) + 'BEGIN TRANSACTION; ' + CHAR(13) + 'ALTER '
                    + CASE WHEN @pIndexID <= 1 THEN 'TABLE '
                           ELSE 'INDEX ' + QUOTENAME(@pIndexName, '[') + ' ON '
                      END + QUOTENAME(@pTableSchema, '[') + '.' + QUOTENAME(@pTableName, '[') + CHAR(13) + '		 REBUILD PARTITION = '
                    + CAST(@pPartitionNo AS VARCHAR(5))
                    + ' WITH ( ONLINE = ON (WAIT_AT_LOW_PRIORITY ( MAX_DURATION = 2 MINUTES, ABORT_AFTER_WAIT = SELF)), DATA_COMPRESSION = PAGE, MAXDOP = 2, SORT_IN_TEMPDB = ON ); '
                    + CHAR(13) + 'COMMIT TRANSACTION; ' + CHAR(13);
 
			--	Remotely submit the compress command
			--
                BEGIN TRY

                    SELECT  @CompressStart = PI.CompressionStart
                    FROM    [EDR1SQL01N901].[DBA_Control].[dbo].[PartitionInfo] PI
                    WHERE   ( ID = @pID )
                            AND ( ( CompressionStart IS NULL )
                                  OR ( ( CompressionStart IS NOT NULL )
                                       AND ( CompressionFinish IS NULL )
                                       AND ( ABS(DATEDIFF(HOUR, CompressionStart, GETDATE())) > 0 )
                                     )
                                );
                    IF ( @@ROWCOUNT > 0 )
                        BEGIN;
                            RAISERROR('%s -- Compressing', 0, 1, @pLabel) WITH NOWAIT;
                            BEGIN TRANSACTION;
                            SET @CompressStart = GETDATE();
                            UPDATE  PI
                            SET     [CompressionStart] = @CompressStart
                            FROM    [EDR1SQL01N901].[DBA_Control].[dbo].[PartitionInfo] PI
                            WHERE   ID = @pID;
                            COMMIT TRANSACTION;

                            EXEC (@CmdCompress) AT EDR1SQL01N901;

                            BEGIN TRANSACTION;
                            SET @CompressFinish = GETDATE();
                            UPDATE  PI
                            SET     [CompressionFinish] = @CompressFinish ,
                                    [Compression] = 'PAGE'
                            FROM    [EDR1SQL01N901].[DBA_Control].[dbo].[PartitionInfo] PI
                            WHERE   ID = @pID;
                            COMMIT TRANSACTION;

                            SET @duration = DATEDIFF(S, @CompressStart, @CompressFinish);
                            IF @duration > 20
                                WAITFOR DELAY '00:00:01';
                        END;
                    ELSE
                        BEGIN;
                            RAISERROR('%s -- Skipping (Active)', 0, 1, @pLabel) WITH NOWAIT;
                        END;
                END TRY
                BEGIN CATCH
					SET @errorMessage = ERROR_MESSAGE();
                    RAISERROR('%s -- Exception - %s', 0, 1, @pLabel, @errorMessage) WITH NOWAIT;
                    RAISERROR('%s -- Aborted - Table Delayed', 0, 1, @pLabel) WITH NOWAIT;
                    INSERT  INTO @delay
                            ( DatabaseName ,
                              TableSchema ,
                              TableName ,
                              TimeResume
                            )
                    VALUES  ( @pDatabaseName ,
                              @pTableSchema ,
                              @pTableName ,
                              DATEADD(MI, 10, GETDATE())
                            ); 
                END CATCH

            END;

        FETCH pCurs INTO @pID, @pDatabaseName, @pTableSchema, @pTableName, @pIndexName, @pIndexID, @pPartitionNo, @pPartitionBoundary;

    END;

--
--	Final Cleanup
--
CLOSE pCurs;
DEALLOCATE pCurs;
