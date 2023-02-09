SELECT OBJECT_SCHEMA_NAME([object_id]) AS SchemaName,
       OBJECT_NAME([object_id]) AS TableName,
       last_value
   FROM sys.identity_columns
   ORDER BY
    1,
    2;

-- DBCC CHECKIDENT ('[Global].[Unit]', RESEED, 40)