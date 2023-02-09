WITH XP
  AS
  (
      SELECT EX.class_desc,
             EX.major_id,
             EX.value
         FROM sys.extended_properties EX
         WHERE
          ( EX.[name] = 'PartitionManager' )
  ),
     PTI
  AS
  (
      SELECT PTI3.PtFuncName,
			 PTI3.function_id,
             PTI3.fanout,
			 PTI3.boundary_value_on_right,
             PTI3.IsDate,
             PTI3.BndFirst,
             PTI3.BndSecondLast,
             PTI3.BndSecond,
             PTI3.BndLast
         FROM
             (
                 SELECT PTI2.PtFuncName,
						PTI2.function_id,
                        PTI2.fanout,
						PTI2.boundary_value_on_right,
                        PTI2.[IsDate],
						MIN(CASE WHEN PTI2.boundary_id = 1 THEN PTI2.[value] ELSE NULL END) AS BndFirst,
						MIN(CASE WHEN PTI2.boundary_id = 2 THEN PTI2.[value] ELSE NULL END) AS BndSecond,
						MIN(CASE WHEN PTI2.boundary_id = ( PTI2.fanout - 2 ) THEN PTI2.[value] ELSE NULL END) AS BndSecondLast,
						MIN(CASE WHEN PTI2.boundary_id = ( PTI2.fanout - 1 ) THEN PTI2.[value] ELSE NULL END) AS BndLast
                    FROM
                        (
                            SELECT TOP ( 100000000 )
								   PTF.[name] AS PtFuncName,
                                   PTV.function_id,
                                   PTV.boundary_id,
                                   PTF.fanout,
								   PTF.boundary_value_on_right,
                                   CASE
                                       WHEN CONVERT(VARCHAR, SQL_VARIANT_PROPERTY(PTV.[value], 'BaseType')) LIKE 'date%' THEN
                                           CONVERT(DATETIME2, PTV.[value], 1)
                                       ELSE
                                           PTV.[value]
                                   END AS [value],
                                   CASE
                                       WHEN CONVERT(VARCHAR, SQL_VARIANT_PROPERTY(PTV.[value], 'BaseType')) LIKE 'date%' THEN
                                           1
                                       ELSE
                                           0
                                   END AS [IsDate]
                               FROM sys.partition_range_values PTV
                                   INNER JOIN sys.partition_functions PTF
                                      ON ( PTV.function_id = PTF.function_id )
							   WHERE (PTV.boundary_id IN (1, 2, (PTF.fanout - 2), (PTF.fanout - 1)))
                               ORDER BY
                                PTV.function_id,
                                PTV.boundary_id
                        ) PTI2
					GROUP BY PTI2.PtFuncName,
							 PTI2.function_id,
							 PTI2.fanout,
							 PTI2.boundary_value_on_right,
							 PTI2.[IsDate]
             ) PTI3
  )
   SELECT PTI.PtFuncName,
          PTI.function_id AS FunctionId,
          CASE
              WHEN PTI.boundary_value_on_right = 0 THEN
                  'L'
              ELSE
                  'R'
          END AS [Range],
          PTI.fanout AS PartCount,
          CASE
              WHEN TYP.[name] = 'datetime2' THEN
                  TYP.[name] + '(' + CONVERT(NVARCHAR(3), PP.scale) + ')'
              WHEN ( TYP.[name] LIKE 'var%' )
                   OR ( TYP.[name] LIKE 'nvar%' ) THEN
                  TYP.[name] + '(' + CASE
                                         WHEN ( PP.max_length = -1 ) THEN
                                             'MAX'
                                         ELSE
                                             CONVERT(NVARCHAR(4), PP.max_length)
                                     END + ')'
              WHEN ( TYP.[name] IN ( 'char', 'nchar', 'binary', 'time' )) THEN
                  TYP.[name] + '(' + CONVERT(NVARCHAR(4), PP.max_length) + ')'
              WHEN ( TYP.[name] IN ( 'decimal', 'numeric' )) THEN
                  TYP.[name] + '(' + CONVERT(NVARCHAR(4), PP.[precision]) + ',' + CONVERT(NVARCHAR(4), PP.[scale]) + ')'
              WHEN ( TYP.[name] IN ( 'float' )) THEN
                  TYP.[name] + CASE
                                   WHEN PP.[precision] < 53 THEN
                                       '(' + CONVERT(NVARCHAR(4), PP.[precision]) + ')'
                                   ELSE
                                       ''
                               END
              WHEN ( TYP.[name] IN ( 'datetimeoffset' )) THEN
                  TYP.[name] + '(' + CONVERT(NVARCHAR(4), PP.[scale]) + ')'
              ELSE
                  TYP.[name]
          END AS Datatype,
		  PTI.BndFirst,
		  PTI.BndSecond,
		  PTI.BndSecondLast,
		  PTI.BndLast,
          COUNT(PS.[name]) OVER ( PARTITION BY PTI.function_id ) AS SchemeCnt,
          ISNULL(PS.[name], '') AS PtSchemeName,
          TAB.[object_id] AS ObjectID,
          OBJECT_SCHEMA_NAME(TAB.[object_id]) AS TableSchema,
          TAB.[name] AS TableName,
          CASE
              WHEN ( IDXC.partition_ordinal IS NOT NULL )
                   AND ( IDXC.partition_ordinal = 1 ) THEN
                  COL.[name]
              ELSE
                  NULL
          END AS PtColumn,
          CASE
              WHEN PS.[name] IS NULL THEN
                  ''
              WHEN TAB.[name] IS NULL THEN
                  ''
              ELSE
                  ISNULL(IDX.[name], '[Heap]')
          END AS IndexName,
          IDX.[index_id] AS IndexID,
          IDX.[type] AS IndexType,
          CASE
              WHEN XPF.major_id IS NULL THEN
                  ''
              WHEN XPF.major_id = PTI.function_id THEN
                  XPF.[value]
              ELSE
                  ''
          END AS PFConfig,
          CASE
              WHEN XPS.major_id IS NULL THEN
                  ''
              WHEN XPS.major_id = PS.data_space_id THEN
                  XPS.[value]
              ELSE
                  ''
          END AS PSConfig,
          CASE
              WHEN XPT.major_id IS NULL THEN
                  ''
              WHEN XPT.major_id = TAB.[object_id] THEN
                  XPT.[value]
              ELSE
                  ''
          END AS TabConfig

      FROM PTI
          INNER JOIN sys.partition_parameters PP
             ON ( PTI.function_id = PP.function_id )
          INNER JOIN sys.types TYP
             ON ( PP.user_type_id = TYP.user_type_id )
          LEFT OUTER JOIN sys.partition_schemes PS
            ON ( PTI.function_id = PS.function_id )
          LEFT OUTER JOIN(sys.indexes IDX
          INNER JOIN sys.tables TAB
             ON ( IDX.[object_id] = TAB.[object_id] )
          LEFT OUTER JOIN(sys.index_columns IDXC
          INNER JOIN sys.columns COL
             ON ( IDXC.[object_id] = COL.[object_id] )
                AND ( IDXC.column_id = COL.column_id ))
            ON ( IDXC.[object_id] = IDX.[object_id] )
               AND ( IDXC.index_id = IDX.index_id )
               AND ( IDXC.partition_ordinal = 1 ))
            ON ( PS.data_space_id = IDX.data_space_id )
          LEFT OUTER JOIN XP XPF
            ON ( XPF.major_id = PTI.function_id )
               AND ( XPF.class_desc = 'PARTITION_FUNCTION' )
          LEFT OUTER JOIN XP XPS
            ON ( XPS.major_id = PS.data_space_id )
               AND ( XPS.class_desc = 'DATASPACE' )
          LEFT OUTER JOIN XP XPT
            ON ( XPT.major_id = TAB.[object_id] )
               AND ( XPT.class_desc = 'OBJECT_OR_COLUMN' )

		ORDER BY PtFuncName, PtSchemeName, TableSchema, TableName

