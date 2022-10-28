SELECT  RTRIM(name) AS [Segment Name] ,
        groupid AS [Group Id] ,
        filename AS [File Name] ,
        CAST(size / 128.0 AS DECIMAL(12, 2)) AS [Allocated Size in MB] ,
        CAST(FILEPROPERTY(name, 'SpaceUsed') / 128.0 AS DECIMAL(12, 2)) AS [Space Used in MB] ,
        CAST((CAST(FILEPROPERTY(name, 'SpaceUsed') AS DECIMAL(12, 2)) /
				CAST(CASE WHEN [size]> 0 THEN [size] ELSE 1.0 END  AS DECIMAL(12, 2))) * 100.0 AS DECIMAL(12,2))  AS [Percent Used]
FROM    sysfiles
ORDER BY [Segment Name] 
