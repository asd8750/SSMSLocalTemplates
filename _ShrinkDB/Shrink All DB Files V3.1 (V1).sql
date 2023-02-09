DECLARE @SegName VARCHAR(128);
DECLARE @SegGrowthFlg INT;
DECLARE @SegAllocatedMB DECIMAL(12, 2);
DECLARE @SegSizeMB DECIMAL(12, 2);
DECLARE @SegPercentUsed DECIMAL(12, 2);

DECLARE @CurTime VARCHAR(30);

DECLARE @ChunkSize DECIMAL(12, 0);
DECLARE @MinFreeSpace DECIMAL(12, 0);
DECLARE @MinFreeSpaceLocked DECIMAL(12, 0);
DECLARE @MinFreeSpaceNoLock DECIMAL(12, 0);
DECLARE @CurFreeSpace DECIMAL(12, 0);
DECLARE @NextSize DECIMAL(12, 0);

DECLARE @DBCCCmd NVARCHAR(4000);


DECLARE @QueueSizeRecovered INT = 1000000;
DECLARE @QueueSizeMaxSize INT = 5000000;
DECLARE @QueueState INT = 0; -- 0-OK, 1-TooLarge (Pause until size goes to lower threshold)


DECLARE FNames CURSOR STATIC READ_ONLY FORWARD_ONLY FOR
SELECT RTRIM(name) AS SqlFile,
	   CASE WHEN [growth] <> 0 THEN 1 ELSE 0 END AS FlgGrowth
FROM sysfiles
WHERE groupid >= 1;

OPEN FNames;
FETCH NEXT FROM FNames
INTO @SegName,  @SegGrowthFlg;
WHILE @@FETCH_STATUS = 0
BEGIN

	-- ===================================================
    SET @ChunkSize = 2000; -- # MB to shrink on each pass
    SET @MinFreeSpaceLocked =  40000; -- Stop the loop when reduce the free space to this level in MB for a growth locked file
    SET @MinFreeSpaceNoLock =  100000; -- Stop the loop when reduce the free space to this level in MB for normal file
	-- =======================================================

	IF (@SegGrowthFlg = 1)
		SET @MinFreeSpace = @MinFreeSpaceNoLock
	ELSE
		SET @MinFreeSpace = @MinFreeSpaceLocked

    SET @CurFreeSpace = @MinFreeSpace + 1;

    WHILE (@CurFreeSpace > @MinFreeSpace)
    BEGIN;

        --	Determine if a backup is in progress for this database.
        --
        DECLARE @BackupDB VARCHAR(256);
        SET @BackupDB = '';
        WITH CMDS
        AS (SELECT r.session_id,
                   r.command,
                   DB_NAME(r.database_id) AS DatabaseName,
                   CONVERT(NUMERIC(6, 2), r.percent_complete) AS [Percent Complete],
                   CONVERT(VARCHAR(20), DATEADD(ms, r.estimated_completion_time, GETDATE()), 20) AS [ETA Completion Time],
                   CONVERT(NUMERIC(10, 2), r.total_elapsed_time / 1000.0 / 60.0) AS [Elapsed Min],
                   CONVERT(NUMERIC(10, 2), r.estimated_completion_time / 1000.0 / 60.0) AS [ETA Min],
                   CONVERT(NUMERIC(10, 2), r.estimated_completion_time / 1000.0 / 60.0 / 60.0) AS [ETA Hours],
                   CONVERT(
                              VARCHAR(1000),
                   (
                       SELECT SUBSTRING(
                                           text,
                                           r.statement_start_offset / 2,
                                           CASE
                                               WHEN r.statement_end_offset = -1 THEN
                                                   1000
                                               ELSE
                                           (r.statement_end_offset - r.statement_start_offset) / 2
                                           END
                                       )
                       FROM sys.dm_exec_sql_text(sql_handle)
                   )
                          ) AS SqlText
            FROM sys.dm_exec_requests r
            WHERE command IN ( 'BACKUP DATABASE' ))
        SELECT TOP 1
               @BackupDB = COALESCE(C.DatabaseName, 'SHRINK DATABASE')
        FROM CMDS C;

        IF (@@RowCount > 0)
        BEGIN
            IF (DB_NAME() = @BackupDB)
                SET @BackupDB = 'PAUSE SHRINK';
            ELSE
                SET @BackupDB = 'SHRINK DATABASE';
        END;
        ELSE
            SET @BackupDB = 'SHRINK DATABASE';


        -- Determine if a replica log queue size is getting too large
        --
        DECLARE @RmtReplicaServer VARCHAR(128);
        DECLARE @LogSendQueueSize INT;
        DECLARE @RedoQueueSize INT;

        SET @LogSendQueueSize = 0;

        --IF SERVERPROPERTY('IsHadrEnabled') IS NOT NULL
        --BEGIN;
        --    SELECT @RmtReplicaServer = ar.replica_server_name,
        --           @LogSendQueueSize = ISNULL(SUM(drs.log_send_queue_size), 0),
        --           @RedoQueueSize = ISNULL(SUM(drs.redo_queue_size), 0)
        --    FROM sys.availability_groups ag
        --        INNER JOIN sys.dm_hadr_database_replica_states drs
        --            ON (ag.group_id = drs.group_id)
        --        INNER JOIN sys.databases dbs
        --            ON (drs.database_id = dbs.database_id)
        --        INNER JOIN sys.dm_hadr_availability_replica_states ars
        --            ON (drs.replica_id = ars.replica_id)
        --        INNER JOIN sys.availability_replicas ar
        --            ON (ar.replica_id = ars.replica_id)
        --    WHERE (ag.[name] = 'GlobalFEDAG')
        --          AND (ars.role_desc = 'SECONDARY')
        --          AND (ar.replica_server_name = 'PBG1SQL81N904')
        --    GROUP BY ar.replica_server_name;
        --    SELECT @RmtReplicaServer,
        --           @LogSendQueueSize,
        --           @RedoQueueSize;

        --    IF (@QueueState = 0)
        --       AND (@LogSendQueueSize > @QueueSizeMaxSize)
        --    BEGIN
        --        SET @QueueState = 1;
        --    END;
        --    ELSE IF (@QueueState = 1)
        --            AND (@LogSendQueueSize < @QueueSizeRecovered)
        --    BEGIN
        --        SET @QueueState = 0;
        --    END;
        --END;



        --	Now perform one shrink cycle
        --
        IF (@BackupDB = 'SHRINK DATABASE')
           AND (@QueueState = 0)
        BEGIN;
            WITH DBI
            AS (SELECT RTRIM(name) AS [SegmentName],
                       groupid AS [GroupId],
                       filename AS [FileName],
                       CAST(size / 128.0 AS DECIMAL(12, 2)) AS [MBAllocated],
                       CAST(FILEPROPERTY(name, 'SpaceUsed') / 128.0 AS DECIMAL(12, 2)) AS [MBUsed],
                       CAST((CAST(FILEPROPERTY(name, 'SpaceUsed') AS DECIMAL(12, 2)) / CAST(CASE
                                                                                                WHEN [size] > 0 THEN
                                                                                                    [size]
                                                                                                ELSE
                                                                                                    1.0
                                                                                            END AS DECIMAL(12, 2))
                            ) * 100.0 AS DECIMAL(12, 2)) AS [PercentUsed]
                FROM sysfiles)
            SELECT @SegAllocatedMB = MBAllocated,
                   @SegSizeMB = MBUsed,
                   @SegPercentUsed = PercentUsed
            FROM DBI
            WHERE (SegmentName = @SegName);

            SET @CurFreeSpace = @SegAllocatedMB - @SegSizeMB;

            IF (@CurFreeSpace > @MinFreeSpace)
            BEGIN
                SET @NextSize = @SegAllocatedMB - @ChunkSize;
                SET @DBCCCmd
                    = 'DBCC SHRINKFILE (N' + QUOTENAME(@SegName, '''') + ' , ' + CONVERT(VARCHAR(12), @NextSize) + ')' +
							' -- Free space: ' + CONVERT(VARCHAR(12), @CurFreeSpace) + ' (MB)';

                SET @CurTime = CONVERT(VARCHAR(30), GETDATE(), 120);
                RAISERROR('%s: %s', 0, 1, @CurTime, @DBCCCmd) WITH NOWAIT;
                EXECUTE (@DBCCCmd);
            END;
        END;
        ELSE
        BEGIN
            SET @CurTime = CONVERT(VARCHAR(30), GETDATE(), 120);
            RAISERROR('%s: Pause - Backup runnning', 0, 1, @CurTime) WITH NOWAIT;
            WAITFOR DELAY '00:05';
        END;
    END;

    FETCH NEXT FROM FNames
    INTO @SegName;
END;

CLOSE FNames;
DEALLOCATE FNames;