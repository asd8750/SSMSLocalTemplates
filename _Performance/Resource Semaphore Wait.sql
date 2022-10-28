SELECT SP.*
	, MG.*
	, ST.*
	FROM SYSPROCESSES SP
		INNER JOIN sys.dm_exec_query_memory_grants MG
			ON (SP.spid = MG.session_id)
		CROSS APPLY sys.dm_exec_sql_text(MG.sql_handle) ST
WHERE SP.lastwaittype = 'RESOURCE_SEMAPHORE'
ORDER BY SP.lastwaittype;


--SELECT schema_name(so.schema_id) + N'.' + so.[name] AS [Name]
--      , so.create_date, so.modify_date
--      , sa.permission_set_desc AS [Access]
--FROM sys.objects AS so
--      INNER JOIN sys.module_assembly_usages AS sau
--            ON so.object_id = sau.object_id
--      INNER JOIN sys.assemblies AS sa
--            ON sau.assembly_id = sa.assembly_id
--WHERE so.type_desc = N'CLR_SCALAR_FUNCTION'


