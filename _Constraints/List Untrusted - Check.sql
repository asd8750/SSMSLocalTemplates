SELECT  OBJECT_SCHEMA_NAME(parent_object_id) AS ParentSchema,
		OBJECT_NAME(parent_object_id) AS ParentTable,
		OBJECT_SCHEMA_NAME(referenced_object_id) AS RefSchema,
		OBJECT_NAME(referenced_object_id) AS RefTable,
		[name] AS ConstraintName,
		is_not_trusted,
		is_disabled,
		CONCAT('ALTER TABLE ',
				QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id), '['), '.',
				QUOTENAME(OBJECT_NAME(parent_object_id), '['),
				' WITH CHECK CHECK CONSTRAINT ', QUOTENAME([name], '[')
				-- ,' WITH (ONLINE = ON)'
			) AS AlterCmd
		-- ,*
	FROM sys.foreign_keys
	WHERE (is_not_trusted = 1)
	ORDER BY ParentSchema, ParentTable, RefSchema, RefTable