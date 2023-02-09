WITH PtInfo
  AS
  (
      SELECT TOP (2000000)
			 PTI.SchemeName,
             PTI.FuncName,
             PTI.Boundary,
             PTI.BoundaryM1,
             DATEDIFF(DAY, PTI.BoundaryM1, PTI.Boundary) AS PtWidth
         FROM
             (
                 SELECT ps.name AS SchemeName, -- Partition scheme name
                        pf.name AS FuncName,   -- Associated function name
                        CAST(prv.[value] AS DATE) AS Boundary,
                        CAST(LEAD(prv.[value]) OVER ( PARTITION BY pf.name ORDER BY prv.[value] DESC
                                                    ) AS DATE) AS BoundaryM1,
                        ROW_NUMBER() OVER ( PARTITION BY pf.name ORDER BY prv.[value] DESC
                                          ) AS RowNum
                    --,CONVERT(DATE, MAX(value)) AS MaxBndry -- Last defined date partition boundary
                    FROM sys.partition_schemes ps WITH ( NOLOCK )
                        INNER JOIN sys.partition_functions pf WITH ( NOLOCK )
                           ON ( ps.function_id = pf.function_id )
                        INNER JOIN sys.partition_range_values prv WITH ( NOLOCK )
                           ON ( pf.function_id = prv.function_id )
             ) PTI
         WHERE
          ( PTI.RowNum = 1 )
  )
   SELECT PT2.SchemeName,
          PT2.FuncName,
          PT2.Boundary,
          PT2.BoundaryM1,
          PT2.PtWidth,
          CASE	
			  WHEN (PT2.PtWidth = 1) THEN  'DAY'
			  WHEN (PT2.PtWidth BETWEEN 3 AND 5) THEN 'DAYS=' + CONVERT(VARCHAR(3), PT2.PtWidth)
			  WHEN (PT2.PtWidth BETWEEN 6 AND 8) THEN 'WEEK'
              WHEN ( PT2.PtWidth BETWEEN 28 AND 31 ) THEN
                  'MONTH'
              ELSE
                  'DAYS=' + CONVERT(VARCHAR(3), PT2.PtWidth)
          END AS Unit,
          CASE
              WHEN ( DATEPART(DAY, PT2.Boundary) = 1 )
                   AND ( DATEPART(DAY, PT2.BoundaryM1) = 1 ) THEN
                  DATEDIFF(MONTH, PT2.BoundaryM1, PT2.Boundary)
              ELSE
                  DATEDIFF(DAY, PT2.BoundaryM1, PT2.Boundary)
          END AS UWidth
      FROM PtInfo PT2

      ORDER BY SchemeName;