
SELECT TOP (100) 
		BKS.[database_name] AS DatabaseName,
		DATEDIFF(MINUTE, BKS.backup_start_date, BKS.backup_finish_date) AS DurationMin,
		FORMAT((BKS.backup_size/1024/1024), '###,###,###,###,###') AS BackupSizeMB,
		FORMAT((BKS.compressed_backup_size/1024/1024), '###,###,###,###') AS CompressedSizeMB,
		CAST((CAST(BKS.compressed_backup_size AS FLOAT) / BKS.backup_size * 100.0) AS DECIMAL(9,1)) AS ComprRatio
		-- ,BKS.*
	FROM msdb.dbo.backupset BKS
	WHERE (BKS.[type] = 'D')
		AND (BKS.[name] LIKE 'NSBackupToAzure')
		AND (BKS.backup_start_date > '2021/07/01')
	ORDER BY DatabaseName, BKS.backup_set_id DESC
