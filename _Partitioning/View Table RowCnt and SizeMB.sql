WITH    cte
          AS ( SELECT   t.name AS TableName ,
                        sch.name AS TableSchema ,
                        t.object_id AS TableID ,
                        SUM(s.used_page_count) AS used_pages_count ,
                        SUM(CASE WHEN ( i.index_id < 2 )
                                 THEN ( in_row_data_page_count
                                        + lob_used_page_count
                                        + row_overflow_used_page_count )
                                 ELSE lob_used_page_count
                                      + row_overflow_used_page_count
                            END) AS pages
               FROM     sys.dm_db_partition_stats AS s
                        INNER JOIN sys.tables AS t ON s.object_id = t.object_id
                        INNER JOIN sys.schemas AS sch ON t.schema_id = sch.schema_id
                        INNER JOIN sys.indexes AS i ON i.[object_id] = t.[object_id]
                                                       AND s.index_id = i.index_id
               GROUP BY t.name ,
                        sch.name ,
                        t.object_id
             ),
        TRC
          AS ( SELECT   --sc.name AS TableSchema ,
                        ta.object_id AS TableID ,
                        SUM(pa.rows) RowCnt
               FROM     sys.tables ta
                        INNER JOIN sys.partitions pa ON pa.OBJECT_ID = ta.OBJECT_ID
                       -- INNER JOIN sys.schemas sc ON ta.schema_id = sc.schema_id
               WHERE    ta.is_ms_shipped = 0
                        AND pa.index_id IN ( 1, 0 )
               GROUP BY ta.object_id
             ),
        TSIZE
          AS ( SELECT   cte.TableID ,
                        CAST(( cte.pages * 8. ) / 1024 AS DECIMAL(10, 3)) AS TableSizeInMB ,
                        CAST(( ( CASE WHEN cte.used_pages_count > cte.pages
                                      THEN cte.used_pages_count - cte.pages
                                      ELSE 0
                                 END ) * 8. / 1024 ) AS DECIMAL(10, 3)) AS IndexSizeInMB
               FROM     cte
             )
    SELECT  cte.TableSchema ,
            cte.TableName ,
            TRC.RowCnt ,
            TSIZE.TableSizeInMB ,
            TSIZE.IndexSizeInMB ,
            ( TSIZE.TableSizeInMB + TSIZE.IndexSizeInMB ) AS TotalSizeMB ,
            CASE WHEN ( TSIZE.TableSizeInMB + TSIZE.IndexSizeInMB ) = 0 THEN 0
                 ELSE CAST(TSIZE.IndexSizeInMB / ( TSIZE.TableSizeInMB
                                                   + TSIZE.IndexSizeInMB )
                      * 100.0 AS DECIMAL(10, 2))
            END AS IdxPct
    FROM    cte
            INNER JOIN TRC ON ( cte.TableID = TRC.TableID )
            INNER JOIN TSIZE ON ( cte.TableID = TSIZE.TableID )
    ORDER BY 1,2;
