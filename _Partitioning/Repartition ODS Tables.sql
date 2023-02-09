WITH    TC
          AS ( SELECT   STAB.[object_id] AS TableObjID ,
                        SIDX.[index_id] AS IndexID ,
                        SIDX.[type] AS Indextype ,
                        SIDX.[is_primary_key] ,
                        SIDXC.[key_ordinal] AS IndexOrdinal ,
                        TC.[name] AS ColumnName ,
                        SIDXC.column_id AS ColumnID ,
                        SIDXC.is_descending_key ,
                        SIDXC.is_included_column ,
                        SIDXC.partition_ordinal
               FROM     sys.tables STAB
                        LEFT OUTER JOIN sys.indexes SIDX ON ( STAB.[object_id] = SIDX.[object_id] )
                        LEFT OUTER JOIN sys.index_columns SIDXC ON ( STAB.[object_id] = SIDXC.[object_id] )
                                                                   AND ( SIDX.index_id = SIDXC.index_id )
                        INNER JOIN sys.columns TC ON ( STAB.[object_id] = TC.[object_id] )
                                                     AND ( SIDXC.column_id = TC.column_id )
             ),
        PT
          AS ( SELECT   SSCH.name AS SchemeName ,
                        PF.name AS FunctionName ,
                        PF.[type_desc] AS FType ,
                        PF.boundary_value_on_right AS RR ,
                        TYP.name AS PtColDataType ,
                        PP.system_type_id ,
                        PP.max_length ,
                        PP.[precision] ,
                        PP.[scale] ,
                        SCHEMA_NAME(STAB.schema_id) AS TableSchema ,
                        STAB.[name] AS TableName ,
                        STAB.[object_id] AS TableObjID ,
                        TC.ColumnID ,
                        COALESCE(COL_NAME(STAB.object_id, TC.ColumnID), '') AS PtCol ,
                        COALESCE(SIDX.name, '[Heap]') AS IndexName ,
                        SIDX.index_id AS [IndexID] ,
                        SIDX.[type] AS IndexType ,
                        SIDX.is_unique AS is_index_unique ,
                        SUM(ISNULL(SALL.total_pages, 0)) AS TotalPages
               FROM     sys.tables STAB
                        LEFT OUTER JOIN sys.indexes SIDX ON ( STAB.[object_id] = SIDX.[object_id] )
                        LEFT OUTER JOIN TC ON ( STAB.[object_id] = TC.TableObjID )
                                              AND ( SIDX.index_id = TC.IndexID )
                        LEFT OUTER JOIN sys.partitions PS ON ( SIDX.[object_id] = PS.[object_id] )
                                                             AND ( SIDX.index_id = PS.index_id )
                        LEFT OUTER JOIN sys.partition_schemes SSCH ON ( SIDX.data_space_id = SSCH.data_space_id )
                        INNER JOIN sys.partition_functions PF ON ( SSCH.function_id = PF.function_id )
                        INNER JOIN sys.partition_parameters PP ON ( SSCH.function_id = PP.function_id )
                        INNER JOIN sys.types TYP ON ( PP.system_type_id = TYP.system_type_id )
                        LEFT OUTER JOIN sys.allocation_units SALL ON ( PS.[partition_id] = SALL.container_id )
               WHERE    ( TC.partition_ordinal = 1 )
                        AND ( TYP.name NOT IN ( 'sysname' ) )
                        AND ( SSCH.name NOT LIKE '%2000%' )
               GROUP BY SSCH.name ,
                        PF.name ,
                        PF.[type_desc] ,
                        PF.boundary_value_on_right ,
                        TYP.name ,
                        PP.system_type_id ,
                        PP.max_length ,
                        PP.[precision] ,
                        PP.[scale] ,
                        SCHEMA_NAME(STAB.schema_id) ,
                        STAB.[name] ,
                        STAB.[object_id] ,
                        TC.ColumnID ,
                        COALESCE(COL_NAME(STAB.object_id, TC.ColumnID), '') ,
                        COALESCE(SIDX.name, '[Heap]') ,
                        SIDX.[type] ,
                        SIDX.index_id ,
                        SIDX.is_unique
             ),
        NewPT
          AS ( SELECT   SchemeName ,
                        FunctionName ,
                        FType ,
                        Rr ,
                        PtColDataType ,
                        system_type_id ,
                        max_length ,
                        [precision] ,
                        [scale]
               FROM     ( SELECT    SSCH.name AS SchemeName ,
                                    PF.name AS FunctionName ,
                                    PF.[type_desc] AS FType ,
                                    PF.boundary_value_on_right AS RR ,
                                    TYP.name AS PtColDataType ,
                                    PP.system_type_id ,
                                    PP.max_length ,
                                    PP.[precision] ,
                                    PP.[scale] ,
                                    ROW_NUMBER() OVER ( PARTITION BY TYP.name, PP.max_length ORDER BY LEN(SSCH.name) DESC ) AS RowNum
                          FROM      sys.partition_schemes SSCH --ON ( SIDX.data_space_id = SSCH.data_space_id )
                                    INNER JOIN sys.partition_functions PF ON ( SSCH.function_id = PF.function_id )
                                    INNER JOIN sys.partition_parameters PP ON ( SSCH.function_id = PP.function_id )
                                    INNER JOIN sys.types TYP ON ( PP.system_type_id = TYP.system_type_id )
                          WHERE     ( TYP.name NOT IN ( 'sysname' ) )
                                    AND ( SSCH.name LIKE '%2000%' ) /* AND (SSCH.name NOT IN ('ptsch_2000_Cycle_By_Month')) */
                        ) NS2
               WHERE    RowNum = 1
             ),
        PT2
          AS ( SELECT   PT.* ,
                        ( STUFF(( SELECT    ', ' + QUOTENAME(TC.ColumnName, '[') + CASE WHEN TC.is_descending_key = 0 THEN ''
                                                                                        ELSE ' DESC'
                                                                                   END
                                  FROM      TC
                                  WHERE     ( PT.TableObjID = TC.TableObjID )
                                            AND ( PT.IndexID = TC.IndexID )
                                            AND ( TC.IndexOrdinal > 0 )
                                  ORDER BY  TC.IndexOrdinal
                                FOR
                                  XML PATH('')
                                ), 1, 1, '') ) AS IdxKeys ,
                        ( STUFF(( SELECT    ', ' + QUOTENAME(TC.ColumnName, '[')
                                  FROM      TC
                                  WHERE     ( PT.TableObjID = TC.TableObjID )
                                            AND ( PT.IndexID = TC.IndexID )
                                            AND ( TC.is_included_column > 0 )
                                  ORDER BY  TC.ColumnID
                                FOR
                                  XML PATH('')
                                ), 1, 1, '') ) AS Included ,
                        ( SELECT    NS.SchemeName
                          FROM      NewPT NS
                          WHERE     ( PT.PtColDataType = NS.PtColDataType )
                                    AND ( PT.max_length = NS.max_length )
                        ) AS NewScheme
               FROM     PT
             )
    SELECT  * ,
            CONVERT(NUMERIC(15, 1), CONVERT(FLOAT, TotalPages * 8196.0) / 1024.0 / 1024.0) AS TotalSizeMB ,
            CASE
		-- 
                 WHEN [IndexType] = 0
                 THEN 'RAISERROR (''Repartitioning [Heap] - ' + QUOTENAME(TableSchema, '[') + '.' + QUOTENAME(TableName, '[') + ' - ' + QUOTENAME(IndexName, '[')
                      + '...'', 0, 1) WITH NOWAIT; ' + CHAR(13) + ' TRUNCATE TABLE ' + QUOTENAME(TableSchema, '[') + '.' + QUOTENAME(TableName, '[') + ';  '
                      + CHAR(13) + 'CREATE ' + CASE WHEN PT2.is_index_unique = 1 THEN 'UNIQUE '
                                                    ELSE ''
                                               END + ' CLUSTERED INDEX [CI_' + TableSchema + '_' + TableName + '] ON ' + QUOTENAME(TableSchema, '[') + '.'
                      + QUOTENAME(TableName, '[') + ' ( ' + QUOTENAME(PtCol, '[') + ' ) ' + CHAR(13)
                      + ' WITH ( PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, ONLINE = ON, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, '
                      + ' DROP_EXISTING = OFF, DATA_COMPRESSION = PAGE, FILLFACTOR = 95 ) ' + CHAR(13) + ' ON ' + QUOTENAME(NewScheme, '[') + QUOTENAME(PtCol,
                                                                                                                                                '(') + CHAR(13)
		-- 
                 WHEN [IndexType] = 1
                 THEN 'RAISERROR (''Repartitioning CI - ' + QUOTENAME(TableSchema, '[') + '.' + QUOTENAME(TableName, '[') + ' - ' + QUOTENAME(IndexName, '[')
                      + '...'', 0, 1) WITH NOWAIT; ' + CHAR(13) + 'TRUNCATE TABLE ' + QUOTENAME(TableSchema, '[') + '.' + QUOTENAME(TableName, '[') + '; '
                      + CHAR(13) + 'CREATE ' + CASE WHEN PT2.is_index_unique = 1 THEN 'UNIQUE '
                                                    ELSE ''
                                               END + ' CLUSTERED INDEX ' + QUOTENAME(IndexName, '[') + ' ON ' + QUOTENAME(TableSchema, '[') + '.'
                      + QUOTENAME(TableName, '[') + ' ( ' + IdxKeys + ' ) ' + CHAR(13)
                      + ' WITH ( PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, ONLINE = ON, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, '
                      + ' DROP_EXISTING = ON, DATA_COMPRESSION = PAGE, FILLFACTOR = 95 ) ' + CHAR(13) + ' ON ' + QUOTENAME(NewScheme, '[') + QUOTENAME(PtCol,
                                                                                                                                                '(') + CHAR(13)
		--
                 WHEN [IndexType] = 2
                 THEN 'RAISERROR (''Repartitioning NC - ' + QUOTENAME(TableSchema, '[') + '.' + QUOTENAME(TableName, '[') + ' - ' + QUOTENAME(IndexName, '[')
                      + '...'', 0, 1) WITH NOWAIT; ' + CHAR(13) + 'CREATE ' + CASE WHEN PT2.is_index_unique = 1 THEN 'UNIQUE '
                                                                                   ELSE ''
                                                                              END + 'NONCLUSTERED INDEX ' + QUOTENAME(IndexName, '[') + ' ON '
                      + QUOTENAME(TableSchema, '[') + '.' + QUOTENAME(TableName, '[') + ' ( ' + IdxKeys + ' ) ' + CHAR(13)
                      + CASE WHEN ( Included IS NOT NULL ) THEN 'INCLUDE ( ' + Included + ' ) ' + CHAR(13)
                             ELSE ''
                        END
                      + ' WITH ( PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, ONLINE = ON, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, '
                      + ' DROP_EXISTING = ON, DATA_COMPRESSION = PAGE, FILLFACTOR = 95 ) ' + CHAR(13) + ' ON ' + QUOTENAME(NewScheme, '[') + QUOTENAME(PtCol,
                                                                                                                                                '(') + CHAR(13)
                 ELSE '???'
            END AS RPCmd
    FROM    PT2
    WHERE   IndexType IN ( 0, 1, 2 )
    ORDER BY IndexType ,
            IndexID ,
            TotalPages 

