DECLARE @TableSchema AS VARCHAR(256) = 'dbo';
DECLARE @TableName AS VARCHAR(256) = 'td_cucl_test1';

DECLARE @TableSchemaArchive AS VARCHAR(256) = 'PSwitch';
DECLARE @TableNameArchive AS VARCHAR(256) = 'dbo_td_cucl_test1';

DECLARE @newFileGroup AS VARCHAR(256) = NULL;

DECLARE @PartWidth AS INT = 6; -- Partition width in hours
DECLARE @PCntPast AS INT = 2 * 4 * @PartWidth; -- # of partition in past
DECLARE @PCntForward AS INT = 1 * 4 * @PartWidth; -- # of partitions in the future
DECLARE @timeNow AS DATETIME = GETDATE();

----------------------------------------------

DECLARE @PScheme AS VARCHAR(256);
DECLARE @PFunction AS VARCHAR(256);
DECLARE @PFileGroup AS VARCHAR(256);

DECLARE @cmd AS NVARCHAR(MAX);

DECLARE @BndEarly AS DATETIME;
DECLARE @BndLate AS DATETIME;

DECLARE @ExpectedFirstBnd AS DATETIME;
DECLARE @ExpectedLastBnd AS DATETIME;

DECLARE @partWorkNeeded INT = 0;
 -- Set non-zero if any partition manipulation required

SET @ExpectedFirstBnd = DATEADD(HOUR, -@PCntPast, @timeNow);
SET @ExpectedLastBnd = DATEADD(HOUR, @PCntForward, @timeNow);


--
--	Gather partition information for this table
--
WITH    DBS
          AS ( SELECT  DISTINCT TOP 1000000
                        SCHEMA_NAME(STAB.schema_id) AS TableSchema ,
                        STAB.Name AS TableName ,
                        CASE WHEN SIDX.index_id = 1 THEN ''
                             ELSE SIDX.name
                        END AS IndexName , -- 1 = Clustered index
                        SIDX.index_id AS [IDX#] ,
                        SSCH.name AS Scheme ,
                        SFNC.name AS [Function] ,
                        SPAR.partition_number AS [P#] ,
                        SPAR.data_compression_desc AS [Compression] ,
                        SPAR.[partition_id] ,
                        CASE WHEN SSCH.name IS NULL THEN '-'
                             WHEN SFNC.boundary_value_on_right = 1 THEN 'R <'
                             ELSE 'L <='
                        END AS PB ,
                        SFNC.boundary_value_on_right ,
                        SPRNG.value AS PartitionBoundary ,
                        SFNC.fanout ,
                        SFG.name AS [FileGroup] ,
                        SALL.type_desc AS [Content] ,
                        SPAR.rows ,
                        SALL.total_pages ,
                        SALL.data_pages ,
                        CONVERT(NUMERIC(15, 1), CONVERT(FLOAT, SALL.total_pages
                        * 8196.0) / 1024.0 / 1024.0) AS TotalSizeMB
               FROM     sys.tables STAB WITH ( NOLOCK )
                        LEFT OUTER JOIN sys.indexes SIDX WITH ( NOLOCK ) ON ( STAB.object_id = SIDX.object_id )
                        LEFT OUTER JOIN sys.partitions SPAR WITH ( NOLOCK ) ON ( SIDX.object_id = SPAR.object_id )
                                                              AND ( SIDX.index_id = SPAR.index_id )
                        LEFT OUTER JOIN sys.partition_schemes SSCH WITH ( NOLOCK ) ON ( SIDX.data_space_id = SSCH.data_space_id )
                        LEFT OUTER JOIN sys.partition_functions SFNC WITH ( NOLOCK ) ON ( SSCH.function_id = SFNC.function_id )
                        LEFT OUTER JOIN sys.partition_parameters SPRM WITH ( NOLOCK ) ON ( SSCH.function_id = SPRM.function_id )
                        LEFT OUTER JOIN sys.partition_range_values SPRNG WITH ( NOLOCK ) ON ( SFNC.function_id = SPRNG.function_id )
                                                              AND ( SPAR.partition_number = SPRNG.boundary_id )
                                                              AND ( SPRM.parameter_id = SPRNG.parameter_id )
                        LEFT OUTER JOIN sys.allocation_units SALL WITH ( NOLOCK ) ON ( SPAR.[partition_id] = SALL.container_id )
                        LEFT OUTER JOIN sys.filegroups SFG WITH ( NOLOCK ) ON ( SALL.data_space_id = SFG.data_space_id )
                        --LEFT OUTER JOIN sys.sysfiles SFL WITH ( NOLOCK ) ON ( SALL.data_space_id = SFL.groupid )
               WHERE    SPRNG.value IS NOT NULL
                        AND ( ( SCHEMA_NAME(STAB.schema_id) = @TableSchema )
                              AND ( STAB.Name = @TableName )
                            )
               ORDER BY [P#]
             ),
        PART
          AS ( SELECT   * ,
                        ROW_NUMBER() OVER ( PARTITION BY TableSchema,
                                            TableName, [IDX#] ORDER BY [P#] ) AS PBFirst ,
                        ROW_NUMBER() OVER ( PARTITION BY TableSchema,
                                            TableName, [IDX#] ORDER BY [P#] DESC ) AS PBLast
               FROM     DBS
             ),
        PBFirst
          AS ( SELECT   [Scheme] AS PScheme ,
                        [Function] AS PFunction ,
                        PartitionBoundary
               FROM     PART
               WHERE    PBFirst = 1
             ),
        PBLast
          AS ( SELECT   [Scheme] AS PScheme ,
                        [Function] AS PFunction ,
                        PartitionBoundary ,
                        [FileGroup]
               FROM     PART
               WHERE    PBLast = 1
             )
    SELECT  @PScheme = PBFirst.PScheme ,
            @PFunction = PBFirst.PFunction ,
            @BndEarly = CONVERT(DATETIME, PBFirst.PartitionBoundary) ,
            @BndLate = CONVERT(DATETIME, PBLast.PartitionBoundary) ,
            @PFileGroup = CASE WHEN @newFileGroup IS NULL THEN PBLast.[FileGroup] ELSE @newFileGroup END
    FROM    PBFirst
            CROSS JOIN PBLast;


---SET @BndLate = CONVERT(DATETIME, '2015-03-01');
--  DEBUG 
SELECT  @PScheme AS PScheme ,
        @PFunction AS PFunction ,
        @BndEarly AS BndEarly ,
        @BndLate AS BndLate ,
        @ExpectedFirstBnd AS ExpectedFirstBnd ,
        @ExpectedLastBnd AS ExpectedLastBnd;

--
--	Build the standard statements to be executed prior to partition manipulation
--
SET @cmd = 'BEGIN TRY' + CHAR(13);
SET @cmd = @cmd + '	BEGIN TRANSACTION;' + CHAR(13);

--
--	Build the statements to switch out the first parition if required
--
IF ( @ExpectedFirstBnd > @BndEarly )
    BEGIN
        SET @partWorkNeeded = @partWorkNeeded + 1;
        SET @cmd = @cmd + '	ALTER TABLE [' + @TableSchema + '].[' + @TableName
--            + '] SWITCH PARTITION 1 TO [PSwitch-' + @TableSchema + '].['
            + '] SWITCH PARTITION 1 TO [' + @TableSchemaArchive + '].['
            + @TableNameArchive + ']; ' + CHAR(13) 
			--
 --         + '	TRUNCATE TABLE [PSwitch-' + @TableSchema + '].[' + @TableName
            + '	TRUNCATE TABLE [' + @TableSchemaArchive + '].[' + @TableNameArchive
            + ']; ' + CHAR(13)
			--
            + '	ALTER PARTITION FUNCTION ' + @PFunction + '() MERGE RANGE ('''
            + CONVERT(VARCHAR(26), @BndEarly, 126) + '''); ' + CHAR(13);
    END;

--
--	Build the statements to create a new top end partition if required
--
IF ( @ExpectedLastBnd > @BndLate )
    BEGIN
        SET @partWorkNeeded = @partWorkNeeded + 1;
        WHILE ( @ExpectedLastBnd > @BndLate )
            BEGIN
                SET @BndLate = DATEADD(HOUR, @PartWidth, @BndLate);
            END;
	  --
        SET @cmd = @cmd + '	ALTER PARTITION SCHEME ' + @PScheme
            + ' NEXT USED [' + @PFileGroup + ']; ' + CHAR(13) 
			--
            + '	ALTER PARTITION FUNCTION ' + @PFunction + '() SPLIT RANGE ('''
            + CONVERT(VARCHAR(26), @BndLate, 126) + '''); ' + CHAR(13);
    END;

--
--	Build the standard statements to be execued after any partition manipulation
--
SET @cmd = @cmd + '	COMMIT TRANSACTION;' + CHAR(13);
SET @cmd = @cmd + 'END TRY' + CHAR(13);
SET @cmd = @cmd + 'BEGIN CATCH' + CHAR(13);
SET @cmd = @cmd + '	WHILE (@@TRANCOUNT > 0)' + CHAR(13);
SET @cmd = @cmd + '	  BEGIN' + CHAR(13);
SET @cmd = @cmd + '		ROLLBACK TRANSACTION;' + CHAR(13);
SET @cmd = @cmd + '	  END;' + CHAR(13);
SET @cmd = @cmd + 'END CATCH' + CHAR(13);

--
--	Execute the statements if work is required
--
PRINT @cmd;
IF ( @partWorkNeeded > 0 )
    BEGIN
        PRINT '--Partition work required!';
		-- EXECUTE sp_executesql @cmd
    END;


--  DEBUG 
SELECT  @PScheme AS PScheme ,
        @PFunction AS PFunction ,
        @BndEarly AS BndEarly ,
        @BndLate AS BndLate ,
        @ExpectedFirstBnd AS ExpectedFirstBnd ,
        @ExpectedLastBnd AS ExpectedLastBnd;


