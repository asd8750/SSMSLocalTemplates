SELECT	DatabaseName,
		BackupType,
		threads AS MaxThreads,
		RIGHT('            '+FORMAT([backup_size],'#,###,###,###,##0'),21) AS BackupSize,
		BackupStartTime,
		BackupFinishTime,
		BackupSetFile
	FROM (
		SELECT   [database_name] AS DatabaseName ,
				 CASE WHEN [type] = 'D' THEN 'Full'
					  WHEN [type] = 'I' THEN 'Incremental'
					  WHEN [type] = 'L' THEN 'Transaction'
					  ELSE [type]
				 END AS BackupType ,
				-- [backup_set_id],
				-- BKS2.[media_set_id],
				 BKS2.[backup_size],
				 --[backup_size] AS BackupSize,
				 BKF.family_sequence_number,
				 FIRST_VALUE(BKF.family_sequence_number) OVER (PARTITION BY BKF.media_set_id ORDER BY BKF.family_sequence_number DESC) AS threads,
				 [backup_start_date] AS BackupStartTime,
				 [backup_finish_date] AS BackupFinishTime,
				 BKF.physical_device_name AS BackupSetFile
		 
		FROM     (   SELECT BKS.[database_name] ,
							BKS.[backup_start_date] ,
							BKS.[backup_finish_date] ,
							BKS.[type] ,
							BKS.[backup_size],
							BKS.[backup_set_id],
							BKS.[media_set_id],
							ROW_NUMBER() OVER ( PARTITION BY BKS.[database_name], BKS.[type]
												ORDER BY BKS.[backup_start_date] DESC
											  ) AS RowNum
					 FROM   [msdb].[dbo].[backupset] BKS
					 WHERE  ( BKS.[type] IN ( 'D', 'I'))
				 ) BKS2
				 INNER JOIN [msdb].[dbo].[backupmediafamily] BKF ON (BKS2.media_set_id = BKF.media_set_id) 
		WHERE    ( BKS2.RowNum = 1 )
				 AND ( BKS2.[database_name] NOT IN ('master', 'msdb', 'tempdb', 'model' ))
		 ) BKS3
			WHERE (BKS3.family_sequence_number = 1)
ORDER BY DatabaseName;

