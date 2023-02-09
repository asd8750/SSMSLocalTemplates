--SELECT *
--   FROM sys.foreign_keys
--   WHERE name = 'FK_PrinterModelLabelType_LabelType'
   
--SELECT *
--   FROM sys.foreign_key_columns;

;WITH FKL AS
(
    SELECT FK.[name] AS [FKConstName],
           FK.[object_id] AS constraint_object_id,
		   FK.is_not_trusted,
           FK.referenced_object_id,
           FK.parent_object_id,
           OBJECT_SCHEMA_NAME (FK.referenced_object_id) AS [PK_SchemaName],
           OBJECT_NAME (FK.referenced_object_id) AS [PK_TableName],
           OBJECT_SCHEMA_NAME (FK.parent_object_id) AS [FK_SchemaName],
           OBJECT_NAME (FK.parent_object_id) AS [FK_TableName],
		   ( STUFF (
                 (SELECT ',[' + COLREF.[name] + ']'
                    FROM sys.foreign_key_columns FKC
					    INNER JOIN sys.columns COLREF
							ON ( COLREF.object_id = FKC.referenced_object_id )
							AND ( COLREF.column_id = FKC.referenced_column_id )
                    WHERE
                     ( FKC.constraint_object_id = FK.object_id )
					 AND ( FK.referenced_object_id = FKC.referenced_object_id )
                    ORDER BY FKC.constraint_column_id
                 FOR XML PATH ('')
             ), 1, 1, '') ) AS REFCols,
			( STUFF (
                 (SELECT ',[' + COLPR.[name] + ']'
                    FROM sys.foreign_key_columns FKC
					    INNER JOIN sys.columns COLPR
							ON ( COLPR.object_id = FKC.parent_object_id )
							AND ( COLPR.column_id = FKC.parent_column_id )
                    WHERE
                     ( FKC.constraint_object_id = FK.object_id )
					 AND ( FK.parent_object_id = FKC.parent_object_id )
                    ORDER BY FKC.constraint_column_id
                 FOR XML PATH ('')
             ), 1, 1, '') ) AS PRCols
			 
       FROM sys.foreign_keys FK
)
   -- , FKCols AS (
   --SELECT --DISTINCT 
   --    FK.constraint_object_id,

   --   FROM FKL FK;
--)

SELECT	CONCAT('[',FK.PK_SchemaName,'].[',FK.PK_TableName,']') AS ParentTable,
		CONCAT ('ALTER TABLE [', OBJECT_SCHEMA_NAME (FK.parent_object_id), '].[', OBJECT_NAME (FK.parent_object_id), '] ',
						'DROP CONSTRAINT [', FK.FKConstName, ']') AS ConstDrop,
		CONCAT ('ALTER TABLE [', OBJECT_SCHEMA_NAME (FK.parent_object_id), '].[', OBJECT_NAME (FK.parent_object_id), '] ', 
				' WITH CHECK ADD  CONSTRAINT [', FK.FKConstName, '] FOREIGN KEY(',FK.PRCols ,') ',
				' REFERENCES [', OBJECT_SCHEMA_NAME (FK.referenced_object_id), '].[', OBJECT_NAME (FK.referenced_object_id), '] (',FK.REFCols,')') AS ConstCreate,
		CONCAT('ALTER TABLE [', OBJECT_SCHEMA_NAME (FK.parent_object_id), '].[', OBJECT_NAME (FK.parent_object_id), '] ',
						'CHECK CONSTRAINT [', FK.FKConstName, ']') AS ConstCheck,
       FK.*
   FROM FKL FK
   WHERE (FK.is_not_trusted = 1)
   ORDER BY ParentTable
