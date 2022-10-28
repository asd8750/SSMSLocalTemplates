SELECT  OBJECT_SCHEMA_NAME(ddps.object_id) + '.' + OBJECT_NAME(ddps.object_id) AS name ,
        SUM(ddps.row_count) AS row_count
FROM    sys.dm_db_partition_stats AS ddps
        JOIN sys.indexes ON indexes.object_id = ddps.object_id
                            AND indexes.index_id = ddps.index_id
WHERE   indexes.type_desc IN ( 'CLUSTERED', 'HEAP' )
        AND OBJECTPROPERTY(ddps.object_id, 'IsMSShipped') = 0
GROUP BY ddps.object_id
ORDER BY row_Count DESC