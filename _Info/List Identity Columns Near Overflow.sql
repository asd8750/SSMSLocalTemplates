SELECT OBJECT_SCHEMA_NAME(IC.[object_id]) AS SchemaName,
       OBJECT_NAME(IC.[object_id]) AS TableName,
       IC.last_value, 
	   TYP.[name] AS DataType,
	   *
   FROM sys.identity_columns IC
	INNER JOIN sys.types TYP
		ON (IC.user_type_id = TYP.user_type_id)
   WHERE (IC.last_value IS NOT NULL) 
   AND (IC.last_value > 500000000)
   AND (IC.max_length < 8)
    ORDER BY
    1,
    2;

-- DBCC CHECKIDENT ('[Global].[Unit]', RESEED, 40)