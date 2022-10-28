
USE	[ReliabilityDB]

SELECT	OBJECT_SCHEMA_NAME(OBJ.[object_id]) AS SchemaName,
		OBJECT_NAME(OBJ.[object_id]) AS ObjectName,
		OBJ.[type],
		OBJ.[type_desc],
		
		CASE OBJ.[type]
			--WHEN 'U' THEN
			--	'CREATE SYNONYM ' +
			--			QUOTENAME(OBJECT_SCHEMA_NAME(OBJ.[object_id]), '[') + '.' + QUOTENAME(OBJECT_NAME(OBJ.[object_id]), '[') +
			--			' FOR ' +
			--			'[Internal_RL].[ReliabilityDB].' +
			--			QUOTENAME(OBJECT_SCHEMA_NAME(OBJ.[object_id]), '[') + '.' + QUOTENAME(OBJECT_NAME(OBJ.[object_id]), '[') +
			--			';'
			WHEN 'FN' THEN
				'CREATE SYNONYM ' +
						QUOTENAME(OBJECT_SCHEMA_NAME(OBJ.[object_id]), '[') + '.' + QUOTENAME(OBJECT_NAME(OBJ.[object_id]), '[') +
						' FOR ' +
						'[Internal_RL].[ReliabilityDB].' +
						QUOTENAME(OBJECT_SCHEMA_NAME(OBJ.[object_id]), '[') + '.' + QUOTENAME(OBJECT_NAME(OBJ.[object_id]), '[') +
						';'
			ELSE ''
		END AS Cmd
		--,*
	--FROM sys.tables TAB
	FROM sys.objects OBJ
	WHERE (OBJ.is_ms_shipped = 0)
		AND (OBJ.[type] NOT IN ('PK','D', 'FK'))
		AND (OBJ.[type] IN ('FN'))
	ORDER BY SchemaName, ObjectName

