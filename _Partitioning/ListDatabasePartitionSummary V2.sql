
        WITH PtFuncs
        AS (SELECT TOP (2000000) PTF.[name] AS PtFunc, 
                                 PTF.function_id, 
                                 PTF.boundary_value_on_right AS [RR], 
                                 PTF.fanout,
                                 CASE
                                     WHEN TYP.[name] = 'datetime2'
                                     THEN TYP.[name] + '(' + CONVERT(NVARCHAR(3), PTP.scale) + ')'
                                     WHEN(TYP.[name] LIKE 'var%')
                                         OR (TYP.[name] LIKE 'nvar%')
                                     THEN TYP.[name] + '(' + CASE
                                                                 WHEN (PTP.max_length = -1)
                                                                 THEN 'MAX'
                                                                 ELSE CONVERT(NVARCHAR(4), PTP.max_length)
                                                             END + ')'
                                     WHEN(TYP.[name] IN('char', 'nchar', 'binary', 'time'))
                                     THEN TYP.[name] + '(' + CONVERT(NVARCHAR(4), PTP.max_length) + ')'
                                     WHEN(TYP.[name] IN('decimal', 'numeric'))
                                     THEN TYP.[name] + '(' + CONVERT(NVARCHAR(4), PTP.[precision]) + ',' + CONVERT(NVARCHAR(4), PTP.[scale]) + ')'
                                     WHEN(TYP.[name] IN('float'))
                                     THEN TYP.[name] + CASE
                                                           WHEN PTP.[precision] < 53
                                                           THEN '(' + CONVERT(NVARCHAR(4), PTP.[precision]) + ')'
                                                           ELSE ''
                                                       END
                                     WHEN(TYP.[name] IN('datetimeoffset'))
                                     THEN TYP.[name] + '(' + CONVERT(NVARCHAR(4), PTP.[scale]) + ')'
                                     ELSE TYP.[name]
                                 END AS Datatype, 
                                 '{"PTB":[' + STUFF(
                (
                    SELECT ', "' + CASE
                                       WHEN PTRV.[value] IS NULL
                                       THEN NULL
                                       WHEN SQL_VARIANT_PROPERTY(PTRV.[value], 'BaseType') = 'date'
                                       THEN CONVERT(VARCHAR, PTRV.[value], 102)
                                       WHEN SQL_VARIANT_PROPERTY(PTRV.[value], 'BaseType') = 'datetime'
                                       THEN CONVERT(VARCHAR, PTRV.[value], 120)
                                       WHEN SQL_VARIANT_PROPERTY(PTRV.[value], 'BaseType') = 'datetime2'
                                       THEN CONVERT(VARCHAR, PTRV.[value], 120)
                                       WHEN SQL_VARIANT_PROPERTY(PTRV.[value], 'BaseType') = 'datetimeoffset'
                                       THEN CONVERT(VARCHAR, PTRV.[value], 127)
                                       ELSE CONVERT(VARCHAR, PTRV.[value])
                                   END + '"'
                        FROM sys.partition_range_values PTRV
                        WHERE (PTF.function_id = PTRV.function_id)
                        ORDER BY PTRV.boundary_id FOR XML PATH('')
                ), 1, 2, '') + ']}' AS PTB
                FROM sys.partition_functions PTF
                     INNER JOIN sys.partition_parameters PTP
                         ON (PTF.function_id = PTP.function_id) 
                     INNER JOIN sys.types TYP
                         ON (PTP.user_type_id = TYP.user_type_id) ),
        PtSchemes
        AS (SELECT TOP (2000000) PTS.[name] AS PtScheme, 
                                 PTS.data_space_id, 
                                 PTS.function_id, 
                                 '{"FGList":[' + STUFF(
                (
                    SELECT ', "' + DSP.[name] + '"'
                        FROM sys.destination_data_spaces DDSP
                             INNER JOIN sys.data_spaces DSP
                                 ON (DDSP.data_space_id = DSP.data_space_id)
                        WHERE (DDSP.partition_scheme_id = PTS.data_space_id)
                        ORDER BY DDSP.destination_id FOR XML PATH('')
                ), 1, 2, '') + ']}' AS FGList
                FROM sys.partition_schemes PTS),
        PTB
        AS (SELECT TOP (2000000) OBJECT_SCHEMA_NAME(TBL.[object_id]) AS TableSchema, 
                                 OBJECT_NAME(TBL.[object_id]) AS TableName, 
                                 TBL.[object_id],
                                 --COUNT(IDX.[index_id]) AS IdxCnt, 
                                 COUNT(DISTINCT IDX.data_space_id) AS PtSchs
            --COUNT(PS.data_space_id) AS PtCnt
                FROM sys.tables TBL
                     INNER JOIN sys.indexes IDX
                         ON (TBL.[object_id] = IDX.[object_id]) 
                     LEFT OUTER JOIN sys.partition_schemes PS
                         ON (IDX.data_space_id = PS.data_space_id)
                GROUP BY TBL.[object_id]
                HAVING (COUNT(PS.data_space_id) > 0) ),
        PtTables
        AS (SELECT TOP (2000000) TBL.TableSchema, 
                                 TBL.TableName, 
                                 ISNULL(IDX.[name], '[Heap]') AS IndexName, 
                                 PTS.data_space_id, 
                                 IIF(TBL.PtSchs = 1, 1, 0) AS isAligned, 
                                 IDX.index_id AS IndexID, 
                                 IDX.[type] AS IndexType, 
                                 TBL.[object_id] AS TableObjID,
                                 CASE
                                     WHEN(IDXC.partition_ordinal IS NOT NULL)
                                         AND (IDXC.partition_ordinal = 1)
                                     THEN COL.[name]
                                     ELSE NULL
                                 END AS PtColumn
                FROM PTB TBL
                     INNER JOIN(sys.indexes IDX
                     INNER JOIN sys.partition_schemes PTS
                         ON (IDX.[data_space_id] = PTS.data_space_id) 
                     LEFT OUTER JOIN(sys.index_columns IDXC
                     INNER JOIN sys.columns COL
                         ON (IDXC.[object_id] = COL.[object_id])
                            AND (IDXC.column_id = COL.column_id) )
                         ON (IDXC.[object_id] = IDX.[object_id])
                            AND (IDXC.index_id = IDX.index_id)
                            AND (IDXC.partition_ordinal = 1) )
                         ON (TBL.[object_id] = IDX.[object_id]) ),
        XP
        AS (SELECT TOP (2000000)
				   EX.class_desc, 
                   EX.major_id, 
                   EX.value
                FROM sys.extended_properties EX
                WHERE (EX.[name] = 'FSPtManager') 
				)
        SELECT PF.PtFunc, 
               PF.function_id, 
               PF.RR, 
               PF.fanout, 
               PF.Datatype, 
               PF.PTB,
			   ISNULL(XDB.[value],'') AS DbConfig,
               CASE
                   WHEN XPF.major_id IS NULL
                   THEN ''
                   WHEN XPF.major_id = PF.function_id
                   THEN XPF.[value]
                   ELSE ''
               END AS PFConfig, 
               PS.PtScheme, 
               PS.data_space_id, 
               PS.FGList,
               CASE
                   WHEN XPS.major_id IS NULL
                   THEN ''
                   WHEN XPS.major_id = PS.data_space_id
                   THEN XPS.[value]
                   ELSE ''
               END AS PSConfig, 
               PT.TableSchema, 
               PT.TableName, 
               PT.IndexName, 
               PT.PtColumn, 
               PT.IndexID, 
               PT.IndexType, 
               PT.TableObjID, 
               PT.isAligned,
               CASE
                   WHEN XPT.major_id IS NULL
                   THEN ''
                   WHEN XPT.major_id = PT.TableObjID
                   THEN XPT.[value]
                   ELSE ''
               END AS TabConfig, 
               '{"Rows":[' + STUFF(
            (
                SELECT ', "' + CONVERT(VARCHAR(15), PT2.[rows]) + '"'
                    FROM sys.partitions PT2
                    WHERE (PT2.[object_id] = PT.TableObjID)
                          AND (PT2.index_id = PT.IndexID)
                    ORDER BY PT2.partition_number FOR XML PATH('')
            ), 1, 2, '') + ']}' AS [Rows]
            FROM PtFuncs PF
                 LEFT OUTER JOIN PtSchemes PS
                     ON (PF.function_id = PS.function_id) 
                 LEFT OUTER JOIN PtTables PT
                     ON (PS.data_space_id = PT.data_space_id) 
                 LEFT OUTER JOIN XP AS XDB
                     ON (XDB.major_id = 0)
                        AND (XDB.class_desc = 'DATABASE') 
                 LEFT OUTER JOIN XP AS XPF
                     ON (XPF.major_id = PF.function_id)
                        AND (XPF.class_desc = 'PARTITION_FUNCTION') 
                 LEFT OUTER JOIN XP AS XPS
                     ON (XPS.major_id = PS.data_space_id)
                        AND (XPS.class_desc = 'DATASPACE') 
                 LEFT OUTER JOIN XP AS XPT
                     ON (XPT.major_id = PT.TableObjID)
                        AND (XPT.class_desc = 'OBJECT_OR_COLUMN');
