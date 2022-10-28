USE [master];
GO
--***** Object:  StoredProcedure [dbo].[BackupToAzure]    Script Date: 12/1/2021 6:29:43 PM *****

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Author:		Fred LaForest
-- Description:	Backup all the non-system databases to an Azure blob container
-- History:
--	2021-07-13	F. LaForest		Initial version
--	2021-11-02	F. LaForest		Sorted by DB name and exclude Staging DBs
--
-- =============================================
ALTER PROCEDURE [dbo].[BackupToAzure] @command     INT           = 0, -- Set to 0 to backup all databases
									  @stripeCnt   INT           = 0, -- Set to number of backup stripe files per database (or 0 to calc based on size)
									  @URL         NVARCHAR(256), -- Set to the URL of the Azure Storage Container to place backup files
									  @DBMask      NVARCHAR(512) = '%', -- Database name mask		
									  @Folder      NVARCHAR(256) = '', 
									  @IgnoreAfter DATETIME      = NULL, -- Only consider backups since
									  @debug       INT           = 0                -- Set non-zero to debug and NOT execute the backup command
AS
	BEGIN
		-- SET NOCOUNT ON added to prevent extra result sets from
		-- interfering with SELECT statements.
		SET NOCOUNT ON;

		DECLARE @MaxMB INT= 400000; -- For compressed backups, use this number to divide the full database size to get stripe count
		--DECLARE @URL VARCHAR(256) = 'https://stfirstsolarsqlbackups.blob.core.windows.net/sqlbackups/';
		--DECLARE @TodaysDate  VARCHAR(20) = REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR(27), GETDATE(), 120), '-', ''), ' ', '-'), ':', '');
		SET @URL = @URL + CASE
							  WHEN RIGHT(@URL, 1) = '/'
							  THEN ''
							  ELSE '/'
						  END;

		IF OBJECT_ID('tempdb..#NSBackup', 'U') IS NOT NULL
			BEGIN
				DROP TABLE #NSBackup;;
		END;
		--
		WITH DBS
			 AS (SELECT DB_NAME(database_id) AS DBName, 
						database_id, 
						SUM(CAST(size AS BIGINT) * 8 / 1024) AS TotsizeMB
					 FROM sys.master_files
					 WHERE (database_id > 4)
						   AND ([type_desc] = 'ROWS')
					 GROUP BY DB_NAME(database_id), 
							  database_id),
			 HIST
			 AS (SELECT CAST(MAX(ISNULL(BKS.backup_size / 1048576, DBS.TotsizeMB)) AS BIGINT) AS [BackupSize (MB)], 
						DBS.TotsizeMB,
						CASE
							WHEN @stripeCnt = 0
							THEN CAST((MAX(ISNULL(BKS.backup_size / 1048576, DBS.TotsizeMB)) + (@MaxMB - 1)) / @MaxMB AS INT)
							ELSE @stripeCnt
						END AS [Stripes], -- Force 10 stripes from each database backup
						DBS.[DBName], 
						MAX(BKS.backup_start_date) AS LastStart
					 FROM DBS
						  LEFT OUTER JOIN msdb.dbo.backupset BKS
							  ON (DBS.DBName = BKS.[database_name])
					 WHERE (BKS.[type] = 'D') -- Only Full backups 
						   AND (BKS.backup_finish_date >= DATEADD(MONTH, -3, GETDATE())) --  
						   AND (DBName NOT LIKE 'Stag%')
					 GROUP BY DBS.[DBName], 
							  DBS.TotsizeMB
					 HAVING (MAX(BKS.backup_start_date) < @IgnoreAfter) )
			 SELECT HIST.DBName AS DatabaseName, 
					REPLACE(CONCAT('BACKUP DATABASE ', QUOTENAME(HIST.DBName, '['), '  ', 'TO ', STP.BackupURL, ' ', ' WITH COMPRESSION, MAXTRANSFERSIZE=4194304, CHECKSUM, INIT, FORMAT, STATS = 99', ', NAME = ', QUOTENAME('NSBackupToAzure', ''''), ';'), '<CRLF>', CHAR(13) + CHAR(10)) AS BackupCmd
			 --,BackupURL
			 INTO #NSBackup
				 FROM HIST
					  CROSS APPLY
				 (
					 SELECT STUFF(
						 (
							 SELECT CONCAT(', URL = ''', @URL,
														 CASE
															 WHEN ISNULL(@Folder, '') = ''
															 THEN ''
															 ELSE @Folder + '-'
														 END,
									--@TodaysDate,
									--'-',
									HIST.DBName, '-', SEQ.RowNumber, '.bak''', '<CRLF>')
								 FROM
								 (
									 SELECT RowNumber
										 FROM
										 (
											 SELECT TOP (HIST.Stripes) ROW_NUMBER() OVER(
																	   ORDER BY
												 (
													 SELECT NULL
												 )) AS RowNumber
												 FROM sys.objects
											 ORDER BY RowNumber
										 ) SEQ2
								 ) SEQ FOR XML PATH(''), TYPE
						 ).value('text()[1]', 'varchar(max)'), 1, LEN(','), '') AS BackupURL
				 ) STP
			 ORDER BY DatabaseName;

		DECLARE @BackupCmd VARCHAR(MAX);
		DECLARE @DatabaseName VARCHAR(128);

		DECLARE db_cursor CURSOR
		FOR SELECT DatabaseName, 
				   BackupCmd
				FROM #NSBackup
				WHERE(DatabaseName NOT LIKE 'Staging%')
					 AND (DatabaseName NOT LIKE '_Server%')
					 AND (DatabaseName LIKE @DBMask)
				ORDER BY DatabaseName;

		OPEN db_cursor;
		FETCH NEXT FROM db_cursor INTO @DatabaseName, @BackupCmd;

		WHILE @@FETCH_STATUS = 0
			BEGIN
				PRINT @BackupCmd;
				INSERT INTO [master].[dbo].[BackupCommands]
				(DatabaseName, 
				 [Label], 
				 [Command]
				)
				VALUES
				(@DatabaseName, 
				 'Begin', 
				 @BackupCmd
				);
				IF (@debug = 0) 
					BEGIN
						EXECUTE (@BackupCmd);
				END;
				INSERT INTO [master].[dbo].[BackupCommands]
				(DatabaseName, 
				 [Label], 
				 [Command]
				)
				VALUES
				(@DatabaseName, 
				 'Completed', 
				 @BackupCmd
				);
				FETCH NEXT FROM db_cursor INTO @DatabaseName, @BackupCmd;
			END;

		CLOSE db_cursor;
		DEALLOCATE db_cursor;

	END;
