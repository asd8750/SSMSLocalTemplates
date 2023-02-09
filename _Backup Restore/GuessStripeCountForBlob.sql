DECLARE @stripeCnt INT = 0;
DECLARE @MaxMB INT = 400000;
		WITH DBS AS (
				SELECT DB_NAME(database_id) AS DBName,
					   database_id,
					   SUM (CAST(size AS BIGINT) * 8 / 1024) AS TotsizeMB
				   FROM sys.master_files
				   WHERE
					( database_id > 4 )
					AND ( [type_desc] = 'ROWS' )
				   GROUP BY DB_NAME(database_id), database_id
				)
			SELECT	CAST(MAX(ISNULL(BKS.backup_size / 1048576, DBS.TotsizeMB)) AS BIGINT) AS [BackupSize (MB)],
					DBS.TotsizeMB,
					CASE WHEN @stripeCnt = 0  THEN
						CAST( ( MAX(ISNULL(BKS.backup_size / 1048576, DBS.TotsizeMB)) + (@MaxMB-1)) / @MaxMB AS INT)
					ELSE
						@stripeCnt
					END AS [Stripes],  -- Force 10 stripes from each database backup
					DBS.[DBname],
					MAX(BKS.backup_start_date) AS LastStart
			   FROM  DBS
					LEFT OUTER JOIN msdb.dbo.backupset BKS
						ON (DBS.DBName = BKS.[database_name])
			   WHERE (BKS.[type] = 'D')						-- Only Full backups
					AND (BKS.backup_finish_date >= DATEADD(MONTH, -3, GETDATE())) -- 
					AND (DBName NOT LIKE 'Stag%')
			   GROUP BY DBS.[DBname],DBS.TotsizeMB
			   --HAVING (MAX(BKS.backup_start_date) < '2021-12-01 18:34:01.000')
	 ORDER BY LastStart
