DROP TABLE IF EXISTS [#SED];

SELECT DB_NAME(DB_ID()) AS DatabaseName,
	   DB_ID() AS DatabaseID,
	   OBJECT_SCHEMA_NAME(SED.[referencing_id], DB_ID()) AS SchemaName,
	   OBJECT_NAME(SED.[referencing_id], DB_ID()) AS ObjectName,
	   ISNULL(OBJ.[type], '--') AS ObjType,
	   OBJECT_ID(CONCAT('[',SED.referenced_database_name,'].[',SED.referenced_schema_name,'].[',SED.referenced_entity_name,']')) AS RefObjID,
	   RIGHT(CONVERT(VARCHAR, ROW_NUMBER() OVER (ORDER BY SED.referencing_id,SED.referenced_database_name,SED.referenced_schema_name,SED.referenced_entity_name) - 
			ROW_NUMBER() OVER (PARTITION BY SED.referencing_id ORDER BY SED.referenced_database_name,SED.referenced_schema_name,SED.referenced_entity_name) + 10001), 3) AS [Node],
	   1 AS [Level],
	   SED.*
	INTO #SED
	FROM sys.sql_expression_dependencies SED
		LEFT OUTER JOIN sys.objects OBJ
			ON (SED.[referencing_id] = OBJ.[object_id])
--		LEFT OUTER JOIN sys.objects ROBJ
--			ON ( OBJECT_ID(CONCAT('[',SED.referenced_database_name,'].[',SED.referenced_schema_name,'].[',SED.referenced_entity_name,']')) = ROBJ.[object_id])

	WHERE (SED.referenced_database_name IS NOT NULL)
			AND (DB_ID(SED.referenced_database_name) IS NOT NULL)
			AND (OBJ.is_ms_shipped = 0)
		--	AND (ISNULL(ROBJ.is_ms_shipped,0) = 0)
			;

CREATE UNIQUE INDEX [#SED_REF] ON #SED(DatabaseName, SchemaName, ObjectName, referenced_database_name, referenced_schema_name, referenced_entity_name);

--SELECT * --OBJECT_ID('tempdb..#SED')
--	FROM TempDB.INFORMATION_SCHEMA.COLUMNS COL
--		INNER JOIN tempdb.sys.objects OBJ
--			ON (COL.TABLE_SCHEMA = OBJECT_SCHEMA_NAME(OBJECT_ID('tempdb..#SED'),DB_ID('tempdb')))
--			AND (COL.TABLE_NAME = OBJECT_NAME(OBJECT_ID('tempdb..#SED'),DB_ID('tempdb')))
--	WHERE OBJ.[object_id] = OBJECT_ID('tempdb..#SED');
		
-- SELECT * FROM #SED;

DECLARE @BigCmd VARCHAR(MAX);

;WITH MC AS (
		SELECT	DISTINCT	
				referenced_database_name AS DatabaseName,
				CONCAT(
'	UNION ALL
	SELECT ''', SED.referenced_database_name, ''' AS DatabaseName, 
			', CONVERT(VARCHAR,ISNULL(DB_ID(SED.referenced_database_name),0)), ' AS DatabaseID, 
			OBJECT_SCHEMA_NAME(SED.[referencing_id], DB_ID(''', SED.referenced_database_name ,''')) AS SchemaName,
			OBJECT_NAME(SED.[referencing_id], DB_ID(''', SED.referenced_database_name ,''')) AS ObjectName,
			ISNULL(OBJ.[type], ''--'') AS ObjType,
			OBJECT_ID(CONCAT(''['',SED.referenced_database_name,''].['',SED.referenced_schema_name,''].['',SED.referenced_entity_name,'']'')) AS RefObjID,
		    RIGHT(CONVERT(VARCHAR, ROW_NUMBER() OVER (ORDER BY SED.referencing_id,SED.referenced_database_name,SED.referenced_schema_name,SED.referenced_entity_name) - 
				ROW_NUMBER() OVER (PARTITION BY SED.referencing_id ORDER BY SED.referenced_database_name,SED.referenced_schema_name,SED.referenced_entity_name) + 10001), 3) AS [Depth],
			SED.*
		FROM [', SED.referenced_database_name , '].sys.sql_expression_dependencies SED
			LEFT OUTER JOIN [', SED.referenced_database_name , '].sys.objects OBJ
				ON (SED.[referencing_id] = OBJ.[object_id])
		WHERE (SED.referenced_database_name IS NOT NULL)
			AND (OBJ.is_ms_shipped = 0)
		'
						) AS SelectDB
			FROM #SED SED
			WHERE (SED.referenced_database_name <> DB_NAME(DB_ID()))
			)
	SELECT	@BigCmd = STUFF((SELECT SelectDB FROM MC ORDER BY DatabaseName FOR XML PATH(''), TYPE ).value('.','varchar(max)'), 1, 10, '')

--	SELECT @BigCmd

	SET @BigCmd = CONCAT('
	INSERT INTO #SED (
			DatabaseName,
			DatabaseID,
			SchemaName,
			ObjectName,
			ObjType,
			RefObjID,
			[Depth],
			referencing_id,
			referencing_minor_id,
			referencing_class,
			referencing_class_desc,
			is_schema_bound_reference,
			referenced_class,
			referenced_class_desc,
			referenced_server_name,
			referenced_database_name,
			referenced_schema_name,
			referenced_entity_name,
			referenced_id,
			referenced_minor_id,
			is_caller_dependent,
			is_ambiguous
			)
	', @BigCmd);

--SELECT @BigCmd

EXECUTE (@BigCmd)




SELECT *
	FROM #SED
	WHERE RefObjID IS NULL
	ORDER BY DatabaseName,SchemaName, ObjectName, referenced_database_name, referenced_schema_name, referenced_entity_name
