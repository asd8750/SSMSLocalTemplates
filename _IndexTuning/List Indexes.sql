SELECT	SCHEMA_NAME(TBL.schema_id) AS SchemaName,
		TBL.[name] AS TableName,
		IDX.[name] AS IndexName,
		IDX.index_id,
		IDX.is_unique AS IsUnique,
		IDXC.key_ordinal,
		IDXC.column_id,
		COL.[name] AS ColumnName,
		COL.is_identity AS IsIdentity,
		IC.last_value
		--,col.*
	FROM sys.tables TBL
		INNER JOIN sys.indexes IDX
			ON (TBl.[object_id] = IDX.[object_id])
		INNER JOIN sys.index_columns IDXC
			ON (TBL.[object_id] = IDXC.[object_id]) AND (IDX.index_id = IDXC.index_id)
		INNER JOIN sys.columns COL
			ON (TBL.[object_id] = COL.[object_id]) AND (IDXC.column_id = COL.column_id)
		LEFT OUTER JOIN sys.identity_columns IC
			ON (TBL.[object_id] = IC.[object_id]) AND (COL.column_id = IC.column_id)
	WHERE (IDX.type IN (1,2)) AND (IDXC.is_included_column = 0)
		AND ((SCHEMA_NAME(TBL.schema_id) = 'ProcessHistory') AND (TBL.[name] = 'CdClOvenFlow'))
	ORDER BY SchemaName, TableName, IDX.index_id, IDXC.key_ordinal