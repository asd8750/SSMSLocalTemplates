USE [master]
GO

/****** Object:  StoredProcedure [dbo].[usp_Restore_Database]    Script Date: 6/22/2016 2:32:45 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Fred LaForest
-- Create date: Feb 20, 2014
-- Description:	Query the src database backup history to create a restoration script.
--
-- Revision History:
-- 2014-02-26	v1.0	LaForest - Initial release
-- 2014-06-18	v1.02	LaForest - Output device type in backupset listing
-- 2014-09-03	v1.03	LaForest - Add XML output, Add options to cut down output
-- 2014-09-04	v1.04	LaForest - Remove extra output, Add LISTCMDS option
-- 2014-11-25	v1.05	LaForest - Move the version number to a separate line
-- 2015-05-21	v1.06	LaForest - Seperate VERBOSE and DEBUG output
-- 2015-07-02	v1.08	LaForest - Add pathTable and input XML parsing of path substitution XML
-- 2015-07-02	v1.09   LaForest - Change any incremental terminology to the correct, differential. Improve status messages
-- 2015-07-06	v1.10	LaForest - Tweak the progress message format
-- 2015-11-10	v1.11	LaForest - NORECOVERY on all restores, insert final recovery restore if @recover = 1
--								 - Add @maxTransferSize parameter (Default 4194304)
--								 - Add @stats to indicate progress percentage (Default 10)
--								 - Add @bufferCount parameter to allow setting custom size (Default 2000)
--								 - Add @useUNC parameter to access server local drives (Default 0)
-- 2015-11-11	v1.12	LaForest - Setting @maxTransferSize and/or @bufferCount to 0 will cause that option caluse to be removed
-- 2015-11-13	v1.13	LaForest - Make @bufferCount = 0 default
--								 - LOG restores now sets STATS to min of 20.  Other bug fixes
-- 2015-11-13	v1.14	LaForest - If @initialDiffSeq < 0 then the DIFF chosen is that count back from most recent DIFF
-- 2015-11-13	v1.15	LaForest - Remove SeqNo from LISTCMDS select but ORDER BY SeqNo instead.
-- 2016-01-20	v1.16	LaForest - Correct wrong UNIQUE index key in @tvBackupSet
--								 - Added error message if specified databaseName not found in backup records
--								 - Add backup start date to log file restore status display
-- 2016-02-10	v1.17	LaForest - Only use backupfile rows with state_desc = ONLINE (exclude DROPPED files)
-- 2016-05-31	v1,18	LaForest - Correct @stats if suppied as NULL
-- 2016-06-06	v1.19	LaForest - Correct buffering options. Default: No Buffercount and MaxTransferSize is set to 2MB
-- 2016-06-22	v1.20	LaForest - Correct command sequencing on LISTCMDS
--								 - If @earliestDate is NULL, default to the most recent full backup
-- 2017-03-08	v1.21	LaForest - Correct @backupMediaFamily and @backupMediaSet queries to add DISTINCT keyword
-- 2017-06-09   v1.22   LaForest - Ensure all log restores follow the full/incremental restores
-- 2017-06-09	v1.23	LaForest - Make LISTCMDS the default @options value
--
ALTER PROCEDURE [dbo].[usp_Restore_Database]
    @srcLinkedServer VARCHAR(128) = '' ,		-- Backup source linked server name
    --@dstLinkedServer VARCHAR(128) = '' ,		-- Backup destination linked server name
    @databaseName VARCHAR(128) ,				-- Database to be restored
    @dstDatabaseName VARCHAR(128) = NULL ,		-- Restored database name on the destination server
    @initialBackupSetID INT = 0 ,				-- Specific [backup_set_id] of initial full database backup 
    @initialDiffSeq INT = 9999999 ,				-- Which differential after the full backup, 0-no differential, 1-first differential, ... 9999999 - latest differential
    @replace BIT = 0 ,							-- 0-NOREPLACE / 1-REPLACE
    @recover BIT = 0 ,							-- 0-NoRecover / 1-Recover
    @earliestDate DATETIME = NULL ,				-- Earliest date to query for a starting full database backup
	--
    @maxTransferSize INT = 2097152 ,			-- The MAXTRANSFERSIZE option for RESTORE
    @bufferCount INT = 0 ,						-- The BUFFERCOUNT option
    @stats INT = 10 ,							-- The STATS options to indicate how often progress is indicated
	--
    @useUNC BIT = 0 ,							-- Use UNC path to access server local drives (Default 0)
    @alternateBackupFile VARCHAR(256) = '' ,	-- Alternate database full backup source file
    @srcBackupPath VARCHAR(256) = NULL ,		-- Alternate directory (UNC) holding full database backup files
    @srcBackupDiffPath VARCHAR(256) = NULL ,	-- Alternate directory (UNC) holding differential database backup files
    @srcBackupLogPath VARCHAR(256) = NULL ,		-- Alternate directory (UNC) holding database transaction logs
    @dstDefaultDataPath VARCHAR(256) = NULL ,	-- Alternate destination directory to restore database data files
    @dstDefaultLogPath VARCHAR(256) = NULL ,	-- Alternate destination directory to restore database log files
    @dstPathsXml XML = NULL ,					-- Optional mapping XML for alternate placement of database files 
	--
    @xmlCmds XML = NULL OUTPUT ,
    @options VARCHAR(128) = 'LISTCMDS'  		-- String holding comma separated list of options:
												-- LISTFULL - Show FULL/DIFFERENTIAL backups information
												-- LISTALL  - Show All backup sets including log backups
												-- LISTCMDS - List the RESTORE commands returned in @xmlCmds
												-- VERBOSE  - Show internal dynamic commands and oher progress information
												-- DEBUG    - Show internal table contents for debugging purposes
												-- NOFULL	- Do not generate FULL RESTORE commands
												-- NOINC	- Do not generate DIFFERENTIAL RESTORE commands
												-- NOLOG	- Do not generate LOG RESTORE COMMANDS
AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @spVersion VARCHAR(10);
        SET @spVersion = 'v1.23'

        DECLARE @ErrorMessage NVARCHAR(4000);	-- Standard error condition variables
        DECLARE @ErrorSeverity INT;
        DECLARE @ErrorState INT;
        DECLARE @ErrorLine INT;

        DECLARE @prtMsg NVARCHAR(3086);

        DECLARE @xmlCommands XML;

        DECLARE @rmtParams NVARCHAR(MAX);	-- Query return parameter declarations string
        DECLARE @rmtQuery NVARCHAR(MAX);	-- Build string for remote commands

        DECLARE @lnkServer VARCHAR(256);	-- linked server name

        DECLARE @trnCount INT;
        DECLARE @rowCount INT;

        DECLARE @physicalServerName VARCHAR(128);

--
--	Set initial variables
--
        SET @prtMsg = 'usp_Restore_Database ' + @spVersion;
        PRINT @prtMsg;		-- Update this line to reflect current version

        SET @options = UPPER(@options);

        SET @trnCount = @@TRANCOUNT;

        SET @physicalServerName = CONVERT(VARCHAR(128), SERVERPROPERTY('ComputerNamePhysicalNetBIOS'));

--
--	Parse any supplied XML @dstPathsXml
--
        DECLARE @pathTable TABLE
            (
              dbName NVARCHAR(128) ,
              fileType NVARCHAR(60) ,
              logicalName NVARCHAR(128) ,
              srcPath NVARCHAR(260) ,
              [fileName] NVARCHAR(260) ,
              dstPath NVARCHAR(260)
            );

        INSERT  INTO @pathTable
                ( dbName ,
                  fileType ,
                  logicalName ,
                  srcPath ,
                  dstPath ,
                  [fileName]
                )
                SELECT  r.value('@dbName', 'nvarchar(128)') AS dbName ,
                        r.value('@fileType', 'nvarchar(60)') AS fileType ,
                        r.value('@logicalName', 'nvarchar(128)') AS logicalName ,
                        r.value('@srcPath', 'nvarchar(260)') AS srcPath ,
                        CASE WHEN r.value('@dstPath', 'nvarchar(260)') IS NULL THEN NULL
                             WHEN LEN(r.value('@dstPath', 'nvarchar(260)')) = 0 THEN NULL
                             ELSE r.value('@dstPath', 'nvarchar(260)')
                        END AS dstPath ,
                        r.value('@fileName', 'nvarchar(260)') AS [fileName]
                FROM    @dstPathsXml.nodes('/srcInstance/database') AS X ( r );

        UPDATE  @pathTable
        SET     srcPath = CASE WHEN RIGHT(srcPath, 1) = '\' THEN LEFT(srcPath, LEN(srcPath) - 1)
                               ELSE srcPath
                          END ,
                dstPath = CASE WHEN dstPath IS NULL THEN NULL
                               WHEN LEN(dstPath) = 0 THEN NULL
                               WHEN RIGHT(dstPath, 1) = '\' THEN LEFT(dstPath, LEN(dstPath) - 1)
                               ELSE dstPath
                          END;

        IF CHARINDEX(N'LISTFULL', @options) > 0
            BEGIN
                SELECT  *
                FROM    @pathTable
                ORDER BY dbName ,
                        fileType ,
                        srcPath;
            END;

--
--	Declare the temp working tables
--
        DECLARE @tvBackupSet TABLE				-- BackupSet - One row per database backup
            (
              [backup_set_id] INT NOT NULL ,
              [media_set_id] INT NOT NULL ,
              [_root_backup_set_id] INT DEFAULT ( 0 ) ,
              [_backup_step] INT DEFAULT ( 0 ) ,
              [_diff_seq] INT DEFAULT ( 0 ) ,
              [_type_seq] INT DEFAULT ( 0 ) ,
              [_max_seq] INT DEFAULT ( 0 ) ,
              [backup_start_date] DATETIME ,
              [backup_finish_date] DATETIME ,
              [database_name] NVARCHAR(128) ,
              [type] CHAR(1) ,
              [backup_size] NUMERIC(20, 0) ,
              [database_backup_lsn] NUMERIC(25, 0) ,
              [checkpoint_lsn] NUMERIC(25, 0) ,
              [first_family_number] TINYINT NOT NULL ,
              [last_family_number] TINYINT NOT NULL ,
              [catalog_family_number] TINYINT NOT NULL ,
              [first_media_number] SMALLINT NOT NULL ,
              [last_media_number] SMALLINT NOT NULL ,
              [catalog_media_number] SMALLINT NOT NULL ,
              [position] INT NOT NULL ,
              UNIQUE NONCLUSTERED ( [backup_set_id] )
            );

        DECLARE @backupMediaFamily TABLE		-- BackupMediaFamily - One row per output file
            (
              [media_set_id] [INT] NOT NULL ,
              [family_sequence_number] [TINYINT] NOT NULL ,
              [media_family_id] [UNIQUEIDENTIFIER] NULL ,
              [media_count] [INT] NULL ,
              [logical_device_name] [NVARCHAR](128) NULL ,
              [physical_device_name] [NVARCHAR](260) NULL ,
              [device_type] [TINYINT] NULL ,
              [physical_block_size] [INT] NULL ,
              [mirror] [TINYINT] NOT NULL ,
              UNIQUE NONCLUSTERED ( [media_set_id], [family_sequence_number], [mirror] )
            );

        DECLARE @backupMediaSet TABLE			-- BackupMediaSet - One row per backup operation
            (
              [media_set_id] [INT] NOT NULL ,
              [media_uuid] [UNIQUEIDENTIFIER] NULL ,
              [media_family_count] [TINYINT] NULL ,
              [name] [NVARCHAR](128) NULL ,
              [description] [NVARCHAR](255) NULL ,
              [software_name] [NVARCHAR](128) NULL ,
              [software_vendor_id] [INT] NULL ,
              [MTF_major_version] [TINYINT] NULL ,
              [mirror_count] [TINYINT] NULL ,
              [is_password_protected] [BIT] NULL ,
              [is_compressed] [BIT] NULL ,
              UNIQUE NONCLUSTERED ( [media_set_id] )
            );

        DECLARE @backupFile TABLE		-- BackupFile - One row per output file
            (
              [backup_set_id] [INT] NOT NULL ,
              [first_family_number] [TINYINT] NULL ,
              [first_media_number] [SMALLINT] NULL ,
              [filegroup_name] [NVARCHAR](128) NULL ,
              [page_size] [INT] NULL ,
              [file_number] [NUMERIC](10, 0) NOT NULL ,
              [backed_up_page_count] [NUMERIC](10, 0) NULL ,
              [file_type] [CHAR](1) NULL ,
              [source_file_block_size] [NUMERIC](10, 0) NULL ,
              [file_size] [NUMERIC](20, 0) NULL ,
              [logical_name] [NVARCHAR](128) NULL ,
              [physical_drive] [NVARCHAR](260) NULL ,
              [physical_name] [NVARCHAR](260) NULL ,
              [state] [TINYINT] NULL ,
              [state_desc] [NVARCHAR](64) NULL ,
              [create_lsn] [NUMERIC](25, 0) NULL ,
              [drop_lsn] [NUMERIC](25, 0) NULL ,
              [file_guid] [UNIQUEIDENTIFIER] NULL ,
              [read_only_lsn] [NUMERIC](25, 0) NULL ,
              [read_write_lsn] [NUMERIC](25, 0) NULL ,
              [differential_base_lsn] [NUMERIC](25, 0) NULL ,
              [differential_base_guid] [UNIQUEIDENTIFIER] NULL ,
              [backup_size] [NUMERIC](20, 0) NULL ,
              [filegroup_guid] [UNIQUEIDENTIFIER] NULL ,
              [is_readonly] [BIT] NULL ,
              [is_present] [BIT] NULL ,
              UNIQUE NONCLUSTERED ( [backup_set_id], [file_number] )
            );

        DECLARE @backupFilegroup TABLE		-- BackupFile - One row per database per filegroup
            (
              [backup_set_id] [INT] NOT NULL ,
              [name] [NVARCHAR](128) NOT NULL ,
              [filegroup_id] [INT] NOT NULL ,
              [filegroup_guid] [UNIQUEIDENTIFIER] NULL ,
              [type] [CHAR](2) NOT NULL ,
              [type_desc] [NVARCHAR](60) NOT NULL ,
              [is_default] [BIT] NOT NULL ,
              [is_readonly] [BIT] NOT NULL ,
              [log_filegroup_guid] [UNIQUEIDENTIFIER] NULL ,
              UNIQUE NONCLUSTERED ( [backup_set_id], [filegroup_id] )
            );

--
--	Validate input parameters
--
        --IF @earliestDate IS NULL
        --    SET @earliestDate = DATEADD(dd, -22, GETDATE());
		
        IF @dstDefaultDataPath IS NOT NULL
            SET @dstDefaultDataPath = CASE WHEN RIGHT(@dstDefaultDataPath, 1) = '\' THEN LEFT(@dstDefaultDataPath, LEN(@dstDefaultDataPath) - 1)
                                           ELSE @dstDefaultDataPath
                                      END;
		
        IF @dstDefaultLogPath IS NOT NULL
            SET @dstDefaultLogPath = CASE WHEN RIGHT(@dstDefaultLogPath, 1) = '\' THEN LEFT(@dstDefaultLogPath, LEN(@dstDefaultLogPath) - 1)
                                          ELSE @dstDefaultLogPath
                                     END;

        SET @bufferCount = COALESCE(@bufferCount, 0);					-- Eliminate NULL value
        SET @maxTransferSize = COALESCE(@maxTransferSize, 2097152);	
        SET @stats = COALESCE(@stats, 10);					

--
--	Begin processing
--
        BEGIN TRY

	--
	-- 	Fetch information on the most recent database backups - BackupSet
	--			
            SET @rmtQuery = '
			            SELECT		BKSET.[backup_set_id] ,
									BKSET.[media_set_id] ,
									CASE WHEN BKSET.[type] IN ( ''D'' ) THEN BKSET.[backup_set_id]
										 ELSE 0
									END AS [_root_backup_set_id] ,
									ROW_NUMBER() OVER (PARTITION BY BKSET.[type], BKSET.[database_backup_lsn] ORDER BY BKSET.[backup_start_date]) AS [_diff_seq] ,
									ROW_NUMBER() OVER (PARTITION BY BKSET.[type] ORDER BY BKSET.[backup_start_date]) AS [_type_seq] ,
									COUNT(*) OVER (PARTITION BY BKSET.[type], BKSET.[database_backup_lsn] ) AS [_max_seq] ,
									BKSET.[backup_start_date] ,
									BKSET.[backup_finish_date] ,
									BKSET.[database_name] ,
									BKSET.[type] ,
									BKSET.[backup_size] ,
									BKSET.[database_backup_lsn] ,
									BKSET.[checkpoint_lsn] ,
									BKSET.[first_family_number] ,
									BKSET.[last_family_number] ,
									BKSET.[catalog_family_number] ,
									BKSET.[first_media_number] ,
									BKSET.[last_media_number] ,
									BKSET.[catalog_media_number] ,
									BKSET.[position]
							FROM    msdb.dbo.backupset BKSET WITH (NOWAIT)
		                    WHERE   BKSET.database_name = ''<<databaseName>>''
								AND BKSET.is_copy_only = 0
								AND ((<<initialBackupSetID>>=0 AND BKSET.backup_start_date >= CONVERT(datetime, ''<<earliestDate>>'', 121)) 
										OR (<<initialBackupSetID>>>0 AND BKSET.backup_set_id >= <<initialBackupSetID>>)); 
							';
            SET @rmtQuery = REPLACE(@rmtQuery, '<<databaseName>>', @databaseName);
            SET @rmtQuery = REPLACE(@rmtQuery, '<<earliestDate>>', CONVERT(VARCHAR, CASE WHEN @earliestDate IS NOT NULL THEN @earliestDate
                                                                                         ELSE DATEADD(DAY, -22, CAST(GETDATE() AS DATE))
                                                                                    END, 121));
            SET @rmtQuery = REPLACE(@rmtQuery, '<<initialBackupSetID>>', CONVERT(VARCHAR, @initialBackupSetID));
			--PRINT @rmtQuery;

            SET @rmtQuery = 'EXEC (''' + REPLACE(@rmtQuery, '''', '''''') + ' '')'
            IF @srcLinkedServer <> ''
                BEGIN
                    SET @rmtQuery = @rmtQuery + ' AT [' + @srcLinkedServer + ']';
                END;

            IF CHARINDEX(N'VERBOSE', @options) > 0
                RAISERROR (@rmtQuery, 0, 1) WITH NOWAIT;
 
            INSERT  INTO @tvBackupSet
                    ( [backup_set_id] ,
                      [media_set_id] ,
                      [_root_backup_set_id] ,
                      [_diff_seq] ,
                      [_type_seq] ,
                      [_max_seq] ,
                      [backup_start_date] ,
                      [backup_finish_date] ,
                      [database_name] ,
                      [type] ,
                      [backup_size] ,
                      [database_backup_lsn] ,
                      [checkpoint_lsn] ,
                      [first_family_number] ,
                      [last_family_number] ,
                      [catalog_family_number] ,
                      [first_media_number] ,
                      [last_media_number] ,
                      [catalog_media_number] ,
                      [position] 
					)
                    EXEC ( @rmtQuery
                        );
            SET @rowCount = @@ROWCOUNT;		-- Save # of rows returned
            IF CHARINDEX(N'VERBOSE', @options) > 0
                RAISERROR ('---- (%d) BackupSet rows retrieved...', 0, 1, @rowCount) WITH NOWAIT;
            IF @rowCount = 0
                RAISERROR ('No backups found for database [%s] ', 15, 1, @databaseName) WITH NOWAIT;

		--
		--	Link differential and log backups to the initial full backup
		--
            UPDATE  SBK
            SET     [_root_backup_set_id] = RSBK.[backup_set_id]
            FROM    @tvBackupSet SBK
                    INNER JOIN @tvBackupSet RSBK ON ( SBK.[database_backup_lsn] = RSBK.[checkpoint_lsn] )
            WHERE   ( SBK._root_backup_set_id <> SBK.backup_set_id )
                    AND ( RSBK._root_backup_set_id <> 0 );

		--
		--	Sequence log, differential backups
		--
            WITH    BKStep
                      AS ( SELECT   backup_set_id ,
                                    ROW_NUMBER() OVER ( /* PARTITION BY [_root_backup_set_id] */  ORDER BY [backup_start_date] ) AS _backup_step
                           FROM     @tvBackupSet
                           WHERE    [_root_backup_set_id] <> 0
                         )
                UPDATE  SBK
                SET     [_backup_step] = CASE WHEN SBK.[type] = 'L' THEN BKStep.[_backup_step] + 10 ELSE BKStep.[_backup_step] END
                FROM    @tvBackupSet SBK
                        INNER JOIN BKStep ON ( SBK.backup_set_id = BKStep.[backup_set_id] );

            SELECT  *
            FROM    @tvBackupSet SBK
            ORDER BY backup_start_date;

		--
		--	Determine the initial full backup start point
		--
            DECLARE @rootFullBackup INT;
            DECLARE @earliestFullBackup INT;
            DECLARE @mostRecentFullBackup INT;

            WITH    FBK
                      AS ( SELECT   MAX(_type_seq) AS max_type_seq
                           FROM     @tvBackupSet
                           WHERE    ( [type] = 'D' )
                                    AND ( ( ( @earliestDate IS NULL )
                                            AND ( backup_start_date >= DATEADD(DAY, -22, CAST(GETDATE() AS DATE)) )
                                          )
                                          OR ( ( @earliestDate IS NOT NULL )
                                               AND ( backup_start_date >= CAST(@earliestDate AS DATE) )
                                             )
                                        )
                         )
                SELECT  @earliestFullBackup = SUM(CASE WHEN TBK.[_type_seq] = 1 THEN TBK.backup_set_id
                                                       ELSE 0
                                                  END) ,
                        @mostRecentFullBackup = SUM(CASE WHEN TBK.[_type_seq] = [max_type_seq] THEN TBK.backup_set_id
                                                         ELSE 0
                                                    END)
                FROM    @tvBackupSet TBK
                        CROSS JOIN FBK
                WHERE   TBK.[type] = 'D';
;
            SELECT  @earliestFullBackup AS Earliest ,
                    @mostRecentFullBackup AS MostRecent;

            SET @rootFullBackup = CASE WHEN @earliestDate IS NULL THEN @mostRecentFullBackup
                                       ELSE @earliestFullBackup
                                  END;

            SET @earliestDate = CASE WHEN @earliestDate IS NOT NULL THEN @earliestDate
                                     ELSE DATEADD(DAY, -22, CAST(GETDATE() AS DATE))
                                END;

		--
		-- Remove orphan differentials and logs
		--
            DELETE  FROM @tvBackupSet
            WHERE   [_root_backup_set_id] = 0;

	--
	--	Fetch information on the most recent database backups - BackupMediaFamily
	--			
            SET @rmtQuery = '
						WITH MSET AS (
								SELECT  DISTINCT
										[backup_set_id] ,
										[media_set_id] 
									FROM    msdb.dbo.backupset BKSET WITH (NOWAIT)
									WHERE   BKSET.database_name = ''<<databaseName>>''
										AND BKSET.is_copy_only = 0
										AND ((<<initialBackupSetID>>=0 AND BKSET.backup_start_date >= CONVERT(datetime, ''<<earliestDate>>'', 121)) 
											OR (<<initialBackupSetID>>>0 AND BKSET.backup_set_id >= <<initialBackupSetID>>)) 
									)
			            SELECT    DISTINCT
								  BKMF.[media_set_id] ,
								  BKMF.[family_sequence_number] ,
								  BKMF.[media_family_id]  ,
								  BKMF.[media_count]  ,
								  BKMF.[logical_device_name]  ,
								  BKMF.[physical_device_name] ,
								  BKMF.[device_type]  ,
								  BKMF.[physical_block_size]  ,
								  BKMF.[mirror] 
							FROM    msdb.dbo.backupmediafamily BKMF WITH (NOWAIT)
								INNER JOIN MSET
									ON (BKMF.[media_set_id] = MSET.[media_set_id]);
							';
            SET @rmtQuery = REPLACE(@rmtQuery, '<<databaseName>>', @databaseName);
            SET @rmtQuery = REPLACE(@rmtQuery, '<<earliestDate>>', CONVERT(VARCHAR, @earliestDate, 121));
            SET @rmtQuery = REPLACE(@rmtQuery, '<<initialBackupSetID>>', CONVERT(VARCHAR, @initialBackupSetID));
 
            SET @rmtQuery = 'EXEC (''' + REPLACE(@rmtQuery, '''', '''''') + ' '')'
            IF @srcLinkedServer <> ''
                BEGIN
                    SET @rmtQuery = @rmtQuery + ' AT [' + @srcLinkedServer + ']';
                END;

            IF CHARINDEX(N'VERBOSE', @options) > 0
                RAISERROR (@rmtQuery, 0, 1) WITH NOWAIT;
  
            INSERT  INTO @backupMediaFamily
                    ( [media_set_id] ,
                      [family_sequence_number] ,
                      [media_family_id] ,
                      [media_count] ,
                      [logical_device_name] ,
                      [physical_device_name] ,
                      [device_type] ,
                      [physical_block_size] ,
                      [mirror] 
					)
                    EXEC ( @rmtQuery
                        );
            IF CHARINDEX(N'VERBOSE', @options) > 0
                RAISERROR ('---- BackupMediaFamily rows retrieved...', 0, 1) WITH NOWAIT;

	--
	--	Fetch information on the most recent database backups - BackupMediaSet
	--			
            SET @rmtQuery = '
						WITH MSET AS (
								SELECT  DISTINCT
										[backup_set_id] ,
										[media_set_id] 
									FROM    msdb.dbo.backupset BKSET WITH (NOWAIT)
									WHERE   BKSET.database_name = ''<<databaseName>>''
										AND BKSET.is_copy_only = 0
										AND ((<<initialBackupSetID>>=0 AND BKSET.backup_start_date >= CONVERT(datetime, ''<<earliestDate>>'', 121)) 
											OR (<<initialBackupSetID>>>0 AND BKSET.backup_set_id >= <<initialBackupSetID>>)) 
									)
			            SELECT    DISTINCT
								  BKMS.[media_set_id] ,
								  BKMS.[media_uuid] ,
								  BKMS.[media_family_count] ,
								  BKMS.[name] ,
								  BKMS.[description] ,
								  BKMS.[software_name]  ,
								  BKMS.[software_vendor_id]  ,
								  BKMS.[MTF_major_version]  ,
								  BKMS.[mirror_count] ,
								  BKMS.[is_password_protected] 
								  --,BKMS.[is_compressed] 
							FROM    msdb.dbo.backupmediaset BKMS WITH (NOWAIT)
								INNER JOIN MSET
									ON (BKMS.[media_set_id] = MSET.[media_set_id]);
							';
            SET @rmtQuery = REPLACE(@rmtQuery, '<<databaseName>>', @databaseName);
            SET @rmtQuery = REPLACE(@rmtQuery, '<<earliestDate>>', CONVERT(VARCHAR, @earliestDate, 121));
            SET @rmtQuery = REPLACE(@rmtQuery, '<<initialBackupSetID>>', CONVERT(VARCHAR, @initialBackupSetID));
 
            SET @rmtQuery = 'EXEC (''' + REPLACE(@rmtQuery, '''', '''''') + ' '')'
            IF @srcLinkedServer <> ''
                BEGIN
                    SET @rmtQuery = @rmtQuery + ' AT [' + @srcLinkedServer + ']';
                END;

            IF CHARINDEX(N'VERBOSE', @options) > 0
                RAISERROR (@rmtQuery, 0, 1) WITH NOWAIT;
  
            INSERT  INTO @backupMediaSet
                    ( [media_set_id] ,
                      [media_uuid] ,
                      [media_family_count] ,
                      [name] ,
                      [description] ,
                      [software_name] ,
                      [software_vendor_id] ,
                      [MTF_major_version] ,
                      [mirror_count] ,
                      [is_password_protected] 
                     -- ,[is_compressed] 
					)
                    EXEC ( @rmtQuery
                        );
            IF CHARINDEX(N'VERBOSE', @options) > 0
                RAISERROR ('---- BackupMediaSet rows retrieved...', 0, 1) WITH NOWAIT;


	--
	--	Fetch information on the most recent database backups - BackupFile - One per database file
	--			
            SET @rmtQuery = '
						WITH MSET AS (
								SELECT  DISTINCT
										[backup_set_id] ,
										[media_set_id] 
									FROM    msdb.dbo.backupset BKSET WITH (NOWAIT)
									WHERE   BKSET.database_name = ''<<databaseName>>''
										AND BKSET.is_copy_only = 0
										AND BKSET.[type] <> ''L''
										AND ((<<initialBackupSetID>>=0 AND BKSET.backup_start_date >= CONVERT(datetime, ''<<earliestDate>>'', 121)) 
											OR (<<initialBackupSetID>>>0 AND BKSET.backup_set_id >= <<initialBackupSetID>>)) 
									)
			            SELECT	  BKF.[backup_set_id] ,
								  BKF.[first_family_number] ,
								  BKF.[first_media_number]  ,
								  BKF.[filegroup_name]  ,
								  BKF.[page_size] ,
								  BKF.[file_number]  ,
								  BKF.[backed_up_page_count]  ,
								  BKF.[file_type]  ,
								  BKF.[source_file_block_size],
								  BKF.[file_size] ,
								  BKF.[logical_name]  ,
								  BKF.[physical_drive]  ,
								  BKF.[physical_name]  ,
								  BKF.[state] ,
								  BKF.[state_desc]  ,
								  BKF.[create_lsn] ,
								  BKF.[drop_lsn] ,
								  BKF.[file_guid]  ,
								  BKF.[read_only_lsn]  ,
								  BKF.[read_write_lsn] ,
								  BKF.[differential_base_lsn]  ,
								  BKF.[differential_base_guid] ,
								  BKF.[backup_size] ,
								  BKF.[filegroup_guid] ,
								  BKF.[is_readonly] ,
								  BKF.[is_present]
							FROM    msdb.dbo.backupfile BKF WITH (NOWAIT)
								INNER JOIN MSET
									ON (BKF.[backup_set_id] = MSET.[backup_set_id])
							WHERE (BKF.[state_desc] = ''ONLINE'');
							';
            SET @rmtQuery = REPLACE(@rmtQuery, '<<databaseName>>', @databaseName);
            SET @rmtQuery = REPLACE(@rmtQuery, '<<earliestDate>>', CONVERT(VARCHAR, @earliestDate, 121));
            SET @rmtQuery = REPLACE(@rmtQuery, '<<initialBackupSetID>>', CONVERT(VARCHAR, @initialBackupSetID));
 
            SET @rmtQuery = 'EXEC (''' + REPLACE(@rmtQuery, '''', '''''') + ' '')'
            IF @srcLinkedServer <> ''
                BEGIN
                    SET @rmtQuery = @rmtQuery + ' AT [' + @srcLinkedServer + ']';
                END;

            IF CHARINDEX(N'VERBOSE', @options) > 0
                RAISERROR (@rmtQuery, 0, 1) WITH NOWAIT;
  
            INSERT  INTO @backupFile
                    ( [backup_set_id] ,
                      [first_family_number] ,
                      [first_media_number] ,
                      [filegroup_name] ,
                      [page_size] ,
                      [file_number] ,
                      [backed_up_page_count] ,
                      [file_type] ,
                      [source_file_block_size] ,
                      [file_size] ,
                      [logical_name] ,
                      [physical_drive] ,
                      [physical_name] ,
                      [state] ,
                      [state_desc] ,
                      [create_lsn] ,
                      [drop_lsn] ,
                      [file_guid] ,
                      [read_only_lsn] ,
                      [read_write_lsn] ,
                      [differential_base_lsn] ,
                      [differential_base_guid] ,
                      [backup_size] ,
                      [filegroup_guid] ,
                      [is_readonly] ,
                      [is_present]
					)
                    EXEC ( @rmtQuery
                        );
            IF CHARINDEX(N'VERBOSE', @options) > 0
                RAISERROR ('---- BackupFile rows retrieved...', 0, 1) WITH NOWAIT;


	--
	--	Fetch information on the most recent database backups - BackupFileGroup - One per database filegroup
	--			
            SET @rmtQuery = '
						WITH MSET AS (
								SELECT  DISTINCT
										[backup_set_id] ,
										[media_set_id] 
									FROM    msdb.dbo.backupset BKSET WITH (NOWAIT)
									WHERE   BKSET.database_name = ''<<databaseName>>''
										AND BKSET.is_copy_only = 0
										AND BKSET.[type] <> ''L''
										AND ((<<initialBackupSetID>>=0 AND BKSET.backup_start_date >= CONVERT(datetime, ''<<earliestDate>>'', 121)) 
											OR (<<initialBackupSetID>>>0 AND BKSET.backup_set_id >= <<initialBackupSetID>>)) 

									)
			            SELECT	BKFG.[backup_set_id]  ,
							    BKFG.[name]  ,
							    BKFG.[filegroup_id]  ,
							    BKFG.[filegroup_guid],
							    BKFG.[type] ,
							    BKFG.[type_desc]  ,
							    BKFG.[is_default] ,
							    BKFG.[is_readonly] ,
							    BKFG.[log_filegroup_guid] 
							FROM    msdb.dbo.backupfilegroup BKFG WITH (NOWAIT)
								INNER JOIN MSET
									ON (BKFG.[backup_set_id] = MSET.[backup_set_id]);
							';
            SET @rmtQuery = REPLACE(@rmtQuery, '<<databaseName>>', @databaseName);
            SET @rmtQuery = REPLACE(@rmtQuery, '<<earliestDate>>', CONVERT(VARCHAR, @earliestDate, 121));
            SET @rmtQuery = REPLACE(@rmtQuery, '<<initialBackupSetID>>', CONVERT(VARCHAR, @initialBackupSetID));
 
            SET @rmtQuery = 'EXEC (''' + REPLACE(@rmtQuery, '''', '''''') + ' '')'
            IF @srcLinkedServer <> ''
                BEGIN
                    SET @rmtQuery = @rmtQuery + ' AT [' + @srcLinkedServer + ']';
                END;

            IF CHARINDEX(N'VERBOSE', @options) > 0
                RAISERROR (@rmtQuery, 0, 1) WITH NOWAIT;
  
            INSERT  INTO @backupFilegroup
                    ( [backup_set_id] ,
                      [name] ,
                      [filegroup_id] ,
                      [filegroup_guid] ,
                      [type] ,
                      [type_desc] ,
                      [is_default] ,
                      [is_readonly] ,
                      [log_filegroup_guid] 
					)
                    EXEC ( @rmtQuery
                        );
            IF CHARINDEX(N'VERBOSE', @options) > 0
                RAISERROR ('---- BackupFileGroup rows retrieved...', 0, 1) WITH NOWAIT;

		--
		--	Find first FULL backup ID and checkpoint_LSN
		--
            DECLARE @first_backup_set_id INT;
            DECLARE @first_full_backup_checkpoint DECIMAL(25, 0);

            SET @first_backup_set_id = 0;

            --SELECT  @first_full_backup_checkpoint = [checkpoint_lsn] ,
            --        @first_backup_set_id = [backup_set_id]
            --FROM    ( SELECT    [checkpoint_lsn] ,
            --                    [backup_set_id] ,
            --                    ROW_NUMBER() OVER ( ORDER BY [backup_start_date] ) AS rownum
            --          FROM      @tvBackupSet
            --          WHERE     [type] = 'D'
            --        ) BK
            --WHERE   BK.rownum = 1;
            SELECT  @first_full_backup_checkpoint = [checkpoint_lsn] ,
                    @first_backup_set_id = [backup_set_id]
            FROM    @tvBackupSet
            WHERE   backup_set_id = @rootFullBackup;

            IF @@ROWCOUNT = 0
                OR COALESCE(@first_backup_set_id, 0) = 0
                RAISERROR ('Cannot find a FULL database backup in the period specified', 11, 1);

			--SELECT @rootFullBackup, @first_full_backup_checkpoint , @first_backup_set_id ;

		--
		--	Find the selected differential or last one if none selected
		--
            DECLARE @backup_b4_logs INT;
            WITH    INCList
                      AS ( SELECT   [backup_set_id] ,
                                    [_diff_seq] ,
                                    ROW_NUMBER() OVER ( ORDER BY [backup_start_date] ) AS _IncSeq
                           FROM     @tvBackupSet
                           WHERE    [type] = 'I'
                                    AND [database_backup_lsn] = @first_full_backup_checkpoint
                         ),
                    INCMax
                      AS ( SELECT   CASE WHEN COALESCE(MAX(_IncSeq), 0) = 0 THEN 0
                                         WHEN @initialDiffSeq >= 0 THEN CASE WHEN MAX(_IncSeq) < @initialDiffSeq THEN MAX(_IncSeq)
                                                                             ELSE MAX(@initialDiffSeq)
                                                                        END
                                         ELSE CASE WHEN MAX(_IncSeq) >= ABS(@initialDiffSeq) THEN MAX(_IncSeq) - ABS(@initialDiffSeq)
                                                   ELSE 0
                                              END
                                    END AS _IncSeqMax
                           FROM     INCList
                         ),
                    INCid
                      AS ( SELECT   backup_set_id
                           FROM     INCList
                           WHERE    _diff_seq = ( SELECT    _IncSeqMax
                                                  FROM      INCMax
                                                )
                         )
                SELECT  @backup_b4_logs = COALESCE(( SELECT backup_set_id
                                                     FROM   INCid
                                                   ), @first_backup_set_id)
                FROM    INCList

            IF @@ROWCOUNT = 0
                SET @backup_b4_logs = @first_backup_set_id;

		--
		--	Output the list of non-Log RESTORE backup candidates
		--
            IF CHARINDEX(N'LISTFULL', @options) > 0
                BEGIN
                    SELECT  DISTINCT
                            BKF.device_type ,
                            BKS.*
                    FROM    @tvBackupSet BKS
                            INNER JOIN @backupMediaFamily BKF ON ( BKS.media_set_id = BKF.media_set_id )
                    WHERE   BKS.[type] <> 'L'
                    ORDER BY BKS.[checkpoint_lsn] DESC;
                END

            IF CHARINDEX(N'VERBOSE', @options) > 0
                BEGIN
                    SELECT  BKF.device_type ,
                            BKS.*
                    FROM    @tvBackupSet BKS
                            INNER JOIN @backupMediaFamily BKF ON ( BKS.media_set_id = BKF.media_set_id )
                    ORDER BY BKS.[checkpoint_lsn] DESC;
                END;

		--
		--	Now start building the restore commands
		--
            WITH    BKS
                      AS ( SELECT TOP 1
                                    *
                           FROM     @tvBackupSet
                           WHERE    [type] = 'D'
                                    AND ( CHARINDEX(N'NOFULL', @options) <= 0 )
                                    AND [backup_set_id] = @first_backup_set_id
                           ORDER BY [backup_start_date]
                           UNION ALL
                           SELECT TOP 1
                                    *
                           FROM     @tvBackupSet
                           WHERE    [type] = 'I'
                                    --AND [_diff_seq] = 1
                                    AND ( CHARINDEX(N'NOINC', @options) <= 0 )
                                    AND [backup_set_id] = @backup_b4_logs
                           ORDER BY [backup_start_date]
                           UNION ALL
                           SELECT   *
                           FROM     @tvBackupSet
                           WHERE    [type] = 'L'
                                    AND ( CHARINDEX(N'NOLOG', @options) <= 0 )
                                    AND [backup_set_id] > @backup_b4_logs
                         ),
                    INP
                      AS ( SELECT   BKFM.media_set_id ,
                                    BKFM.family_sequence_number ,
                                    BKFM.physical_device_name ,
                                    BKFM.device_type ,
                                    CASE WHEN CHARINDEX('\', BKFM.[physical_device_name]) > 0
                                         THEN REVERSE(SUBSTRING(REVERSE(BKFM.[physical_device_name]), 1,
                                                                CHARINDEX('\', REVERSE(BKFM.[physical_device_name])) - 1))
                                         ELSE BKFM.physical_device_name
                                    END AS bk_filename
                           FROM     @backupMediaFamily BKFM
                         ),
                    OUTP
                      AS ( SELECT   BKF.backup_set_id ,
                                    BKF.[filegroup_name] ,
                                    BKF.logical_name ,
                                    BKF.file_number ,
                                    BKF.physical_name ,
                                    LEFT(BKF.physical_name, LEN(BKF.physical_name) - CHARINDEX('\', REVERSE(BKF.physical_name))) AS physical_path ,
                                    BKF.file_type ,
                                    CASE WHEN CHARINDEX('\', BKF.physical_name) > 0
                                         THEN RIGHT(BKF.physical_name, CHARINDEX('\', REVERSE(BKF.physical_name)) - 1)
                                         --THEN REVERSE(SUBSTRING(REVERSE(BKF.physical_name), 1, CHARINDEX('\', REVERSE(BKF.physical_name)) - 1))
                                         ELSE BKF.physical_name
                                    END AS db_filename
                           FROM     @backupFile BKF
                         ),
                    PRECMD
                      AS ( SELECT   BKS.backup_set_id ,
                                    BKS.media_set_id ,  --
                                    BKS._diff_seq AS seq_no ,
                                    BKS._max_seq AS seq_max ,
                                    BKS.[_backup_step] AS seq_all ,
                                    BKS.[type] ,
                                    BKS.position ,
                                    BKS.checkpoint_lsn ,
                                    BKS.[backup_start_date] ,
                                    STUFF(( SELECT  ', DISK='''
					--
                                                    + CASE WHEN INP.device_type = 7 THEN '[AVAMAR]'
                                                           ELSE ''
                                                      END + CASE WHEN BKS.[type] = 'L'
                                                                 THEN COALESCE(@srcBackupLogPath + '\' + INP.bk_filename, @srcBackupPath + '\' + INP.bk_filename,
                                                                               CASE WHEN ( SUBSTRING(INP.physical_device_name, 2, 1) = ':' )
                                                                                         AND ( @useUNC = 1 )
                                                                                    THEN '\\' + @physicalServerName + '\' + LEFT(INP.physical_device_name, 1)
                                                                                         + '$'
                                                                                    ELSE LEFT(INP.physical_device_name, 2)
                                                                               END + RIGHT(INP.physical_device_name, LEN(INP.physical_device_name) - 2))
                                                                 WHEN BKS.[type] = 'I'
                                                                 THEN COALESCE(@srcBackupDiffPath + '\' + INP.bk_filename,
                                                                               CASE WHEN ( SUBSTRING(INP.physical_device_name, 2, 1) = ':' )
                                                                                         AND ( @useUNC = 1 )
                                                                                    THEN '\\' + @physicalServerName + '\' + LEFT(INP.physical_device_name, 1)
                                                                                         + '$'
                                                                                    ELSE LEFT(INP.physical_device_name, 2)
                                                                               END + RIGHT(INP.physical_device_name, LEN(INP.physical_device_name) - 2))
                                                                 ELSE COALESCE(@srcBackupPath + '\' + INP.bk_filename,
                                                                               CASE WHEN ( SUBSTRING(INP.physical_device_name, 2, 1) = ':' )
                                                                                         AND ( @useUNC = 1 )
                                                                                    THEN '\\' + @physicalServerName + '\' + LEFT(INP.physical_device_name, 1)
                                                                                         + '$'
                                                                                    ELSE LEFT(INP.physical_device_name, 2)
                                                                               END + RIGHT(INP.physical_device_name, LEN(INP.physical_device_name) - 2))
                                                            END + ''''
                                            FROM    INP
                                            WHERE   INP.media_set_id = BKS.media_set_id
                                            ORDER BY INP.family_sequence_number
                                          FOR
                                            XML PATH('')
                                          ), 1, 2, '') AS bk_files ,
                                    STUFF(( SELECT  CONVERT(VARCHAR(MAX), ', MOVE ''') + OUTP.logical_name + ''' TO '''
                                                    --+ CASE WHEN OUTP.file_type = 'L'
                                                    --       THEN COALESCE(@dstDefaultLogPath + '\' + OUTP.db_filename,
                                                    --                     @dstDefaultDataPath + '\' + OUTP.db_filename, OUTP.physical_name)
                                                    --       ELSE COALESCE(@dstDefaultDataPath + '\' + OUTP.db_filename, OUTP.physical_name)
                                                    --  END + ''''
                                                    + CASE WHEN PT.dstPath IS NOT NULL THEN PT.dstPath
                                                           WHEN OUTP.file_type <> 'L' THEN CASE WHEN @dstDefaultDataPath IS NULL THEN OUTP.physical_path
                                                                                                ELSE @dstDefaultDataPath
                                                                                           END
                                                           ELSE CASE WHEN @dstDefaultLogPath IS NULL THEN OUTP.physical_path
                                                                     ELSE @dstDefaultLogPath
                                                                END
                                                      END + '\' + OUTP.db_filename + ''''
                                            FROM    OUTP
                                                    LEFT OUTER JOIN @pathTable PT ON ( OUTP.logical_name = PT.logicalName )
                                                                                     AND ( BKS.database_name = PT.dbName )
                                            WHERE   OUTP.backup_set_id = BKS.backup_set_id
                                            ORDER BY OUTP.file_type ,
                                                    OUTP.logical_name
                                          FOR
                                            XML PATH('')
                                          ), 1, 2, '') AS db_files
                           FROM     BKS
                         ),
                    CMDS ( SeqNo, SeqAll, BackupCmd )
                      AS ( SELECT TOP 10000000
                                    seq_no AS SeqNo ,
                                    seq_all AS SeqAll ,
                                    '' + CASE WHEN [type] = 'D'
                                              THEN 'RAISERROR(''Restoring Full backup: [LSN:' + CONVERT(VARCHAR, checkpoint_lsn)
                                                   + '] ...'', 0, 1) WITH NOWAIT; ' + CHAR(13)
                                              WHEN [type] = 'I'
                                              THEN 'RAISERROR(''Restoring Differential backup: [' + CAST(seq_no AS VARCHAR(10)) + ']: ' + SUBSTRING(bk_files, 7,
                                                                                                                                                LEN(bk_files)
                                                                                                                                                - 7) + ' [LSN:'
                                                   + CONVERT(VARCHAR, checkpoint_lsn) + '] ...'', 0, 1) WITH NOWAIT; ' + CHAR(13)
                                              WHEN [type] = 'L'
                                              THEN 'RAISERROR(''Restoring Log: [' + CAST(seq_no AS VARCHAR(9)) + ' of ' + CAST(seq_max AS VARCHAR(9)) + ']: '
                                                   + CONVERT(VARCHAR(20), [backup_start_date], 120) + ' ' + +SUBSTRING(bk_files, 7, LEN(bk_files) - 7)
                                                   + ' [LSN:' + CONVERT(VARCHAR, checkpoint_lsn) + '] ...'', 0, 1) WITH NOWAIT; ' + CHAR(13)
                                              ELSE ''
                                         END
				--
                                    + 'RESTORE ' + CASE WHEN [type] = 'D' THEN 'DATABASE'
                                                        WHEN [type] = 'L' THEN 'LOG'
                                                        WHEN [type] = 'I' THEN 'DATABASE'
                                                        ELSE 'DATABASE'
                                                   END + ' [' + COALESCE(@dstDatabaseName, @databaseName) + '] ' + CHAR(13) 
				--				 
                                    + 'FROM ' + CHAR(13)
				--
                                    + REPLACE(bk_files, ', ', ', ' + CHAR(13)) 
				--
                                    + CHAR(13) + 'WITH FILE=' + CONVERT(VARCHAR, position) + ', NOUNLOAD, NORECOVERY' + ', STATS = '
                                    + CASE WHEN ( @stats >= 20 )
                                                OR ( [type] <> 'L' ) THEN CONVERT(VARCHAR, @stats)
                                           ELSE '20'
                                      END + CASE WHEN @maxTransferSize > 0 THEN ', MAXTRANSFERSIZE = ' + CONVERT(VARCHAR, @maxTransferSize)
                                                 ELSE ''
                                            END + CASE WHEN @bufferCount > 0 THEN ', BUFFERCOUNT = ' + CONVERT(VARCHAR, @bufferCount)
                                                       ELSE ''
                                                  END + CASE WHEN [type] = 'D' THEN CASE WHEN @replace = 1 THEN ', REPLACE'
                                                                                         ELSE ''
                                                                                    END + ',' + CHAR(13) + REPLACE(db_files, ', ', ', ' + CHAR(13))
                                                             ELSE ''
                                                        END + ';' + CHAR(13) AS BackupCmd
                           FROM     PRECMD
                           ORDER BY backup_set_id
                         )
                SELECT  @xmlCommands = ( SELECT *
                                         FROM   ( SELECT    SeqNo ,
                                                            SeqAll ,
                                                            BackupCmd
                                                  FROM      CMDS
                                                  UNION ALL
                                                  SELECT    ( ( SELECT  MAX(SeqNo)
                                                                FROM    CMDS
                                                              ) + 1 ) AS SeqNo ,
                                                            9999999 AS SeqAll ,
                                                            'RAISERROR(''Restoring With Recovery - FINAL ...'', 0, 1) WITH NOWAIT; ' + CHAR(13)
                                                            + 'RESTORE DATABASE [' + COALESCE(@dstDatabaseName, @databaseName) + '] WITH RECOVERY ' + CHAR(13)
                                                  WHERE     ( @recover = 1 )
												  --ORDER BY 1
                                                ) CMDS2
                                       FOR
                                         XML RAW('Restore') ,
                                             ROOT('Restores')
                                       );

            SET @xmlCmds = @xmlCommands;

            IF CHARINDEX(N'LISTCMDS', @options) > 0
                BEGIN
                    SELECT  R.C.value('(@BackupCmd)[1]', 'varchar(max)') AS RestoreCmd
                    FROM    @xmlCmds.nodes('/Restores/Restore') AS R ( C )
                    ORDER BY R.C.value('(@SeqAll)[1]', 'int')
                END;

		--
		--	DEBUGGING Output
		--
            IF ( CHARINDEX(N'DEBUG', @options) > 0 )
                BEGIN
                    SELECT  *
                    FROM    @tvBackupSet
                    ORDER BY [backup_set_id];

                    SELECT  *
                    FROM    @backupMediaSet
                    ORDER BY [media_set_id];

                    SELECT  *
                    FROM    @backupMediaFamily
                    ORDER BY [media_set_id];

                    SELECT  *
                    FROM    @backupFilegroup
                    ORDER BY [backup_set_id];

                    SELECT  *
                    FROM    @backupFile
                    ORDER BY [backup_set_id];
                END;

        END TRY

--
--	Process any intercepted error
--
        BEGIN CATCH
            SELECT  @ErrorMessage = ERROR_MESSAGE() ,
                    @ErrorSeverity = ERROR_SEVERITY() ,
                    @ErrorState = ERROR_STATE() ,
                    @ErrorLine = ERROR_LINE();

            IF @@TRANCOUNT > @trnCount
                ROLLBACK TRANSACTION

            RAISERROR ('[Line %d] %s',@ErrorSeverity,@ErrorState, @ErrorLine, @ErrorMessage);
        END CATCH

    END

GO


