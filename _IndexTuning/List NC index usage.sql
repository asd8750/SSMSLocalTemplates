SELECT  OBJECT_NAME(s.OBJECT_ID) AS [TableName],
        i.name AS [IndexName],
        i.index_id AS [IndexID],
		MAX(p.partition_number) AS PtCnt,
        user_seeks + user_scans + user_lookups AS [TotalReads],
        user_updates AS [Updates],
        SUM(p.ROWS) AS [Records],
        SUM((ps.used_page_count * 8 )/ 1024) AS [IndexSize(MB)]
FROM sys.dm_db_index_usage_stats s
        JOIN sys.indexes i
            ON i.index_id = s.index_id
            AND s.OBJECT_ID = i.OBJECT_ID
        JOIN sys.partitions p
            ON p.index_id = s.index_id
            AND s.OBJECT_ID = p.OBJECT_ID
        JOIN sys.dm_db_partition_stats ps
            ON ps.index_id = i.index_id
            AND ps.OBJECT_ID = i.OBJECT_ID
			AND (p.partition_number = ps.partition_number)
WHERE OBJECTPROPERTY(s.OBJECT_ID,'IsUserTable') = 1
    AND s.database_id = DB_ID()
    AND i.type_desc = 'NonClustered'
    -- Adjust the following values as needed
    AND p.ROWS > 10000
    AND user_seeks + user_scans + user_lookups < 100

	GROUP BY OBJECT_NAME(s.OBJECT_ID),
			 i.name,
			 i.index_id,
			 user_seeks + user_scans + user_lookups,
			 user_updates
ORDER BY TotalReads, Records DESC