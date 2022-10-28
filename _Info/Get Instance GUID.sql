select  TOP 1 * from [sys].[master_files]
	WHERE ([file_guid] IS NOT NULL) AND ([file_id] IN (1,2))
	ORDER BY database_id, [file_id]