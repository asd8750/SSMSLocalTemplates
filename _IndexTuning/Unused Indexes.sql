SELECT  SCHEMA_NAME(o.Schema_id) AS SchemaName ,
        OBJECT_NAME(u.object_id) AS TableName ,
        i.name ,
        u.*
FROM    [sys].[indexes] i
        INNER JOIN [sys].[objects] o ON ( i.OBJECT_ID = o.OBJECT_ID )
        LEFT JOIN [sys].[dm_db_index_usage_stats] u ON ( i.OBJECT_ID = u.OBJECT_ID )
                                                       AND i.[index_id] = u.[index_id]
                                                       AND u.[database_id] = DB_ID() --returning the database ID of the current database
WHERE   o.[type] <> 'S' --shouldn't be a system base table
        AND i.[type_desc] <> 'HEAP'
        AND i.[name] NOT LIKE 'PK_%'
        AND u.[user_seeks] + u.[user_scans] + u.[user_lookups] = 0
        AND u.[last_system_scan] IS NOT NULL
ORDER BY 1 ,
        2, 3 ASC