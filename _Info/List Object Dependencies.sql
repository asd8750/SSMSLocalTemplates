WITH TOBJ
  AS
  (
      SELECT OBJ.[object_id],
             OBJECT_SCHEMA_NAME (OBJ.[object_id]) AS ObjSchema,
             OBJ.[name] AS ObjName,
             OBJ.[type] AS ObjType
         FROM sys.objects OBJ
         WHERE
          ( OBJECT_SCHEMA_NAME (OBJ.[object_id]) IN ( 'clip', 'cpd', 'gdm' ))
  )
   SELECT TOBJ.[object_id] AS TobjID,
          OBJECT_SCHEMA_NAME (SED.referencing_id) AS ViewSchema,
          OBJECT_NAME (SED.referencing_id) AS ViewName,
          SED.*
      FROM TOBJ
          FULL OUTER JOIN sys.sql_expression_dependencies SED
            ON ( TOBJ.[object_id] = SED.referencing_id )
          INNER JOIN sys.objects OBJ
             ON ( SED.[referencing_id] = OBJ.[object_id] )
      WHERE
       ( OBJECT_SCHEMA_NAME (SED.referencing_id) IN ( 'clip', 'cpd', 'gdm' ))
      ORDER BY
       ViewSchema,
       ViewName,
       SED.referenced_database_name,
       SED.referenced_schema_name,
       SED.referenced_entity_name;
