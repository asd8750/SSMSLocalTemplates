--USE [MESLogging]
--GO
--/****** Object:  StoredProcedure [DBA].[usp_PartitionTruncateOld]    Script Date: 9/29/2017 9:12:33 AM ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

----
----	[DBA].[usp_PartitionTruncateOld]
----
----	Purpose: Remove unneeded old partitions from the scheme and function
----	Execution: Run daily.  Can be run more frequently, but no action will be taken if 
----		no eligible paritions are found to remove.
----	Revision history:
----	2017-09-01	F. LaForest -- Initial version
----
--ALTER   PROCEDURE [DBA].[usp_PartitionTruncateOld]
--    @pSchName NVARCHAR(50), -- Partition Scheme name
--    @retentionDays SMALLINT,  -- Number of days prior to the current date to retain partitioned data.
--    @currentDate DATETIME = NULL,		-- Date used as the current date used to determine the earliest still valid boundary
--	  @debug INT = 0	-- Set to non-zero when debugging, more debug output and does not commit changes
--AS
--BEGIN;
--    SET XACT_ABORT ON;
--    SET DEADLOCK_PRIORITY LOW;

SET NOCOUNT ON;

DECLARE @pSchName NVARCHAR(50) = 'LogEntry_ps';
DECLARE @retentionDays SMALLINT = 24;
DECLARE @currentDate DATETIME = NULL;
DECLARE @debug INT = 1;

DECLARE @EarliestSavedBoundary DATETIME; -- First date boundary deined in the partitioning function
DECLARE @Scratch VARCHAR(2000);
DECLARE @str NVARCHAR(2000);
DECLARE @TableName NVARCHAR(128);
DECLARE @SchemaName NVARCHAR(50);

--
--	Create the Date boundaries for this execution
--
IF @currentDate IS NULL
BEGIN
    SET @currentDate = GETDATE();
END;
SET @currentDate = CAST(CAST(@currentDate AS DATE) AS DATETIME);

SET @EarliestSavedBoundary = DATEADD(DAY, -@retentionDays, @currentDate);

PRINT '           Current Date: ' + CONVERT(VARCHAR(24), @currentDate, 126);
PRINT 'Earliest Retention Date: ' + CONVERT(VARCHAR(24), @EarliestSavedBoundary, 126);


--
--	Create a temp table to hold current partition scheme metadata
--
DECLARE @tbl_plist TABLE (
    [TableSchema] [NVARCHAR](128) NULL,
    [TableName] [sysname] NOT NULL,
    [PSName] [sysname] NULL,
    [PFName] [sysname] NULL,
    [object_id] INT,
    [IsRR] [BIT] NULL,
    [PSDataSpaceID] [INT] NULL,
    [index_id] [INT] NULL,
    [partition_number] [INT] NULL,
    [boundary_id] [INT] NULL,
    [boundary_value] [SQL_VARIANT] NULL,
    [rows] [BIGINT] NULL,
    [Expired] BIT
        DEFAULT 0,
    [SeqExpired] INT
        DEFAULT 0);

INSERT INTO @tbl_plist
SELECT --DISTINCT
       SCHEMA_NAME(STAB.schema_id) AS TableSchema,
       STAB.[name] AS TableName,
       SSCH.[name] AS PSName,
       SFNC.[name] AS PFName,
       STAB.[object_id],
       SFNC.boundary_value_on_right AS [IsRR],
       SSCH.data_space_id AS PSDataSpaceID,
       SIDX.index_id,
       SPAR.partition_number,
       CASE
            WHEN SFNC.boundary_value_on_right = 1 THEN COALESCE(SPRNG.boundary_id, 0)
            ELSE COALESCE(SPRNG.boundary_id, SFNC.fanout)END AS boundary_id,
       SPRNG.[value] AS boundary_value,
       SPAR.[rows],
       CASE
            WHEN (CAST(SPRNG.[value] AS DATETIME) < @EarliestSavedBoundary) THEN 1
            ELSE 0 END AS Expired,
       CASE
            WHEN (CAST(SPRNG.[value] AS DATETIME) < @EarliestSavedBoundary) THEN
                ROW_NUMBER() OVER (PARTITION BY STAB.[object_id],
                                                CASE
                                                     WHEN (CAST(SPRNG.[value] AS DATETIME) < @EarliestSavedBoundary) THEN
                                                         1
                                                     ELSE 0 END
                                   ORDER BY SPAR.partition_number DESC)
            ELSE 0 END AS SeqExpired
  FROM sys.tables STAB
  LEFT OUTER JOIN sys.indexes SIDX
    ON (STAB.object_id        = SIDX.object_id)
  LEFT OUTER JOIN sys.partitions SPAR
    ON (SIDX.object_id        = SPAR.object_id)
   AND (SIDX.index_id         = SPAR.index_id)
  LEFT OUTER JOIN sys.partition_schemes SSCH
    ON (SIDX.data_space_id    = SSCH.data_space_id)
  LEFT OUTER JOIN sys.partition_functions SFNC
    ON (SSCH.function_id      = SFNC.function_id)
  LEFT OUTER JOIN sys.partition_parameters SPRM
    ON (SSCH.function_id      = SPRM.function_id)
  LEFT OUTER JOIN sys.partition_range_values SPRNG
    ON (SFNC.function_id      = SPRNG.function_id)
   AND (SPAR.partition_number = SPRNG.boundary_id)
   AND (SPRM.parameter_id     = SPRNG.parameter_id)
 WHERE (   (SSCH.[name] IS NOT NULL)
     AND   (SSCH.[name] = @pSchName))
   AND (SIDX.index_id IN ( 0, 1 ));

IF (@debug <> 0)
BEGIN;
    SELECT *
      FROM @tbl_plist
     ORDER BY TableSchema,
              TableName,
              partition_number;
END;


--
--	Create a temp table to hold commands to execute
--
DECLARE @tbl_Commands TABLE (
    Seq INT NOT NULL,
    SqlCmd VARCHAR(2000));


--
--	Create TRUNCATE TABLE commands
--
WITH Cmds
  AS (SELECT TableSchema,
             TableName,
             PList,
             CONCAT(
                 'TRUNCATE TABLE ',
                 QUOTENAME(TableSchema, '['),
                 '.',
                 QUOTENAME(TableName, '['),
                 ' WITH (PARTITIONS (',
                 PList,
                 '));') AS TTCmd
        FROM (   SELECT DISTINCT TP1.TableSchema,
                        TP1.TableName,
                        (STUFF((   SELECT ',' + CONVERT(VARCHAR(5), TP2.partition_number)
                                     FROM @tbl_plist TP2
                                    WHERE (TP1.[object_id] = TP2.[object_id])
                                      AND (TP2.rows        > 0)
                                      AND (TP2.Expired     = 1)
                                    ORDER BY TP2.partition_number
                                   FOR XML PATH('')),
                               1,
                               1,
                               '')) AS PList
                   FROM @tbl_plist TP1
                  WHERE (   (TP1.rows > 0)
                      AND   (TP1.Expired = 1))) TP3
       WHERE (TP3.PList IS NOT NULL))
INSERT INTO @tbl_Commands (Seq,
                           SqlCmd)
SELECT 1,
       TTCmd
  FROM Cmds;

--
-- Select the partition info for expired partitions
--
WITH Cmds
  AS (SELECT DISTINCT TOP 10000000 partition_number,
             boundary_value,
             Expired,
             PFName,
             CONCAT(
                 'ALTER PARTITION FUNCTION ',
                 QUOTENAME(PFName, '['),
                 '() MERGE RANGE (''',
                 CONVERT(VARCHAR(50), boundary_value, 126),
                 '''); -- P# ',
                 CONVERT(VARCHAR(5), partition_number)) AS RmPartCmd
        FROM @tbl_plist
       WHERE (Expired    = 1)
         AND (boundary_value IS NOT NULL)
         AND (SeqExpired > 1)
       ORDER BY partition_number)
INSERT INTO @tbl_Commands (Seq,
                           SqlCmd)
SELECT 2,
       RmPartCmd
  FROM Cmds
 ORDER BY 1;

--
--	Create the UPDATE STATISTICS commands
--
WITH Cmds
  AS (SELECT DISTINCT CONCAT('UPDATE STATISTICS [', TableSchema, '].[', TableName, '] with resample;') AS USCmd
        FROM @tbl_plist
       WHERE (rows    > 0)
         AND (Expired = 1))
INSERT INTO @tbl_Commands (Seq,
                           SqlCmd)
SELECT 3,
       USCmd
  FROM Cmds
 ORDER BY 1;

IF (@debug <> 0)
BEGIN;
    SELECT SqlCmd
      FROM @tbl_Commands;
END;
