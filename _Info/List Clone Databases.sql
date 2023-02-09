-- List clone databases

SELECT	db.[name] AS DBName, 
		Inf.IsClone, 
		AG.[name] AS AGName -- db.*
	FROM sys.databases db
	CROSS APPLY (
		SELECT CAST(DATABASEPROPERTYEX(DB.name, 'IsVerifiedClone') AS BIT) IsClone
			) inf
    LEFT OUTER JOIN 
		(sys.dm_hadr_database_replica_states DRS
			INNER JOIN sys.availability_groups AG
				ON (DRS.group_id = AG.group_id)
				)
		ON (db.group_database_id = DRS.group_database_id)
	WHERE (inf.IsClone <> 0)
	ORDER BY AGName, DBName