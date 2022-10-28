SELECT TOP (1000) *
FROM [master].[dbo].[CommandLog]
WHERE(CommandType NOT IN('xp_create_subdir', 'BACKUP_LOG', 'xp_delete_file', 'DBCC_CHECKDB'));