


WITH XP
  AS
  (
      SELECT EX.class_desc,
             EX.major_id,
             EX.value
         FROM sys.extended_properties EX
         WHERE
          ( EX.[name] = 'FSPtManager' )
  ),
     PtInfo
  AS
  (
      SELECT PTI2.SchemeName,
             PTI2.data_space_id,
             PTI2.FuncName,
             PTI2.function_id,
			 PTI2.fanout,
             PTI2.Boundary,
             PTI2.BoundaryM1,
             PTI2.PtWidth,
             CASE
                 WHEN ( PTI2.PtWidth = 1 ) THEN
                     'DAY'
                 WHEN ( PTI2.PtWidth BETWEEN 3 AND 6 ) THEN
                     'DAYS=' + CONVERT(VARCHAR(3), PTI2.PtWidth)
                 WHEN ( PTI2.PtWidth = 7 )
                      OR ( PTI2.PtWidth = 8 ) THEN
                     'WEEK'
                 WHEN ( PTI2.PtWidth BETWEEN 28 AND 31 ) THEN
                     'MONTH'
                 ELSE
                     'DAYS:' + CONVERT(VARCHAR(3), PTI2.PtWidth)
             END AS PtWidthCfg
         FROM
             (
                 SELECT PTI.SchemeName,
                        PTI.data_space_id,
                        PTI.FuncName,
                        PTI.function_id,
						PTI.fanout,
                        PTI.Boundary,
                        PTI.BoundaryM1,
                        DATEDIFF(DAY, PTI.BoundaryM1, PTI.Boundary) AS PtWidth
                    FROM
                        (
                            SELECT ps.name AS SchemeName, -- Partition scheme name
                                   ps.data_space_id,
                                   pf.name AS FuncName,   -- Associated function name
                                   pf.function_id,
								   pf.fanout,
                                   CAST(prv.[value] AS DATE) AS Boundary,
                                   CAST(LEAD(prv.[value]) OVER ( PARTITION BY pf.name  ORDER BY prv.[value] DESC
                                                               )        AS DATE) AS BoundaryM1,
                                   ROW_NUMBER() OVER ( PARTITION BY pf.name  ORDER BY prv.[value] DESC
                                                     )        AS RowNum
                               --,CONVERT(DATE, MAX(value)) AS MaxBndry -- Last defined date partition boundary
                               FROM sys.partition_schemes ps WITH ( NOLOCK )
                                   INNER JOIN sys.partition_functions pf WITH ( NOLOCK )
                                      ON ( ps.function_id = pf.function_id )
                                   INNER JOIN sys.partition_range_values prv WITH ( NOLOCK )
                                      ON ( pf.function_id = prv.function_id )
                        ) PTI
                    WHERE
                     ( PTI.RowNum = 1 )
             ) PTI2
  )
   SELECT PT2.SchemeName,
          PT2.FuncName,
          PT2.Boundary,
          PT2.BoundaryM1,
          PT2.PtWidth,
		  PT2.PtWidthCfg,
          ('EXEC ' + CASE
                        WHEN XPF.[value] IS NULL THEN
                            'sp_addextendedproperty'
                        ELSE
                            'sp_updateextendedproperty'
                    END + ' @name = ''FSPtManager'', @level0type = ''PARTITION FUNCTION'', @level0name = ' + QUOTENAME(PT2.FuncName, '''') +
           ', @value = ''{"Cfg":[{"Width":"' + PT2.PtWidthCfg + '"},{"PreAlloc":"' + 
					CONVERT(VARCHAR(3), CASE PT2.PtWidth WHEN 1 THEN 14 ELSE 3 END) + 
					'"}] }'';  ') AS EAFuncSql,
          ('EXEC ' + CASE
                        WHEN XPF.[value] IS NULL THEN
                            'sp_addextendedproperty'
                        ELSE
                            'sp_updateextendedproperty'
                    END + ' @name = ''FSPtManager'', @level0type = ''PARTITION SCHEME'', @level0name = ' + QUOTENAME(PT2.SchemeName, '''') +
           ', @value = ''{"Cfg":[{"FGList":"' + DSP.[name] + '"}] }'';  ') AS EASchSql
      FROM PtInfo PT2
		  LEFT OUTER JOIN (
				sys.destination_data_spaces DDSP 
					INNER JOIN sys.data_spaces DSP
						ON (DDSP.data_space_id = DSP.data_space_id) 
				)
			ON (PT2.data_space_id = DDSP.partition_scheme_id)
				AND (PT2.fanout = DDSP.destination_id)
          LEFT OUTER JOIN XP XPF
			ON ( XPF.major_id = PT2.function_id )
			LEFT OUTER JOIN XP XPS
            ON ( XPS.major_id = PT2.data_space_id )
      --LEFT OUTER JOIN XP XPT
      --	ON (XPT.major_id = TAB.[object_id])

      ORDER BY SchemeName;