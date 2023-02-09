SELECT *
	FROM (
			SELECT *, 
				ROW_NUMBER() OVER (PARTITION BY Container, TaskName,PluginName, WorkName ORDER BY StartTime DESC) AS RowNum
			  FROM [FSSqlServerStatus].[Status].[TaskStatus]
		) TSK
	WHERE TSK.RowNum = 1
	ORDER BY Container, TaskName,PluginName, WorkName