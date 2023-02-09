WITH PTF
  AS
  (
      SELECT TOP ( 200000000 )
             SFNC.fanout AS PartCount,
             SFNC.boundary_value_on_right,
             SFNC.is_system,
             SFNC.[name] AS PtFuncName,
             SPRNG.function_id,
             SPRNG.parameter_id,
             SPRNG.boundary_id,
             ( SPRNG.boundary_id + IIF(SFNC.boundary_value_on_right = 1, 0, 1)) AS PtNum,
             LAG(SPRNG.[value], SFNC.boundary_value_on_right, CAST('1900-01-01' AS DATETIME)) OVER ( PARTITION BY SPRNG.function_id
ORDER BY SPRNG.boundary_id
                                                                                                ) AS ValueStart,
             LEAD(   SPRNG.[value],
                     CASE
                         WHEN SFNC.boundary_value_on_right = 1 THEN
                             0
                         ELSE
                             1
                     END,
                     CAST('2099-01-01' AS DATETIME)
                 ) OVER ( PARTITION BY SPRNG.function_id
ORDER BY SPRNG.boundary_id
                     ) AS ValueEnd
         FROM sys.partition_functions SFNC
             INNER JOIN sys.partition_range_values SPRNG
                ON ( SPRNG.function_id = SFNC.function_id ) 
      UNION ALL
      SELECT TOP ( 1000000 )
             SFNC.fanout AS PartCount,
             SFNC.boundary_value_on_right,
             SFNC.is_system,
             SFNC.[name] AS PtFuncName,
             SPRNG.function_id,
             SPRNG.parameter_id,
             IIF(SFNC.boundary_value_on_right = 1, SFNC.fanout, 0) AS boundary_id,
             IIF(SFNC.boundary_value_on_right = 1, SFNC.fanout, 1) AS PtNum,
             IIF(SFNC.boundary_value_on_right = 1, SPRNG.[value], CAST('1900-01-01' AS DATETIME)) AS ValueStart,
             IIF(SFNC.boundary_value_on_right = 1, CAST('2099-01-01' AS DATETIME), SPRNG.[value]) AS ValueEnd
         FROM sys.partition_range_values SPRNG
             INNER JOIN sys.partition_functions SFNC
                ON ( SPRNG.function_id = SFNC.function_id )
         WHERE
          ( SPRNG.boundary_id = IIF(SFNC.boundary_value_on_right = 1, SFNC.fanout - 1, 1))
  )
   SELECT PTF.*
      FROM PTF
      ORDER BY
       PTF.PtFuncName,
       PTF.boundary_id;
