--  
--	View Partition Detail and Sizing
--
--	History
--	2018-04-01	F. LaForest	-- Initial Version
--	2020-05-04  F. LaForest -- Add Partitioning Column info, changed rows/pg estimate, Rearranged output columns
--

BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

WITH PTCol
  AS
  (
      SELECT TOP ( 2000000000 )
             IDXC.[object_id],
             IDXC.[index_id],
             IDXC.[column_id],
             IDXC.[partition_ordinal],
             COL.[name] AS ColName,
             TYP.[name] AS DataType,
             CASE
                 WHEN TYP.[name] = 'datetime2' THEN
                     TYP.[name] + '(' + CONVERT(VARCHAR(3), COL.scale) + ')'
                 WHEN ( TYP.[name] LIKE 'var%' )
                      OR ( TYP.[name] LIKE 'nvar%' ) THEN
                     TYP.[name] + '(' + CASE
                                            WHEN ( COL.max_length = -1 ) THEN
                                                'MAX'
                                            ELSE
                                                CONVERT(VARCHAR(4), COL.max_length)
                                        END + ')'
                 WHEN ( TYP.[name] IN ( 'char', 'nchar', 'binary', 'time' )) THEN
                     TYP.[name] + '(' + CONVERT(VARCHAR(4), COL.max_length) + ')'
                 WHEN ( TYP.[name] IN ( 'decimal', 'numeric' )) THEN
                     TYP.[name] + '(' + CONVERT(VARCHAR(4), COL.[precision]) + ',' + CONVERT(VARCHAR(4), COL.[scale]) + ')'
                 WHEN ( TYP.[name] IN ( 'float' )) THEN
                     TYP.[name] + CASE
                                      WHEN COL.[precision] < 53 THEN
                                          '(' + CONVERT(VARCHAR(4), COL.[precision]) + ')'
                                      ELSE
                                          ''
                                  END
                 WHEN ( TYP.[name] IN ( 'datetimeoffset' )) THEN
                     TYP.[name] + '(' + CONVERT(VARCHAR(4), COL.[scale]) + ')'
                 ELSE
                     TYP.[name]
             END AS DeclaredType
         --,*
         FROM sys.index_columns IDXC
             INNER JOIN sys.columns COL
                ON ( COL.[object_id] = IDXC.[object_id] )
                   AND ( COL.column_id = IDXC.column_id )
             INNER JOIN sys.types TYP
                ON ( TYP.user_type_id = COL.user_type_id )
         WHERE
          ( IDXC.partition_ordinal = 1 )
  ),
     DBS
  AS
  (
      SELECT DISTINCT
             SCHEMA_NAME(STAB.schema_id) AS TableSchema,
             STAB.name AS TableName,
             CASE
                 WHEN SIDX.index_id = 1 THEN
                     ''
                 ELSE
                     SIDX.name
             END AS IndexName, -- 1 = Clustered index
             SIDX.index_id AS [IDX#],
             SIDX.[type] AS IType,
             SSCH.name AS Scheme,
             SFNC.name AS [Function],
             CASE
                 WHEN SSCH.name IS NULL THEN
                     NULL
                 WHEN SFNC.boundary_value_on_right = 1 THEN
                     '<R'
                 ELSE
                     'L>'
             END AS PB,
             SPAR.partition_number AS [P#],
             SPAR.data_compression_desc AS [Compression],
             SPAR.[partition_id],
                               --CONVERT(VARCHAR, ISNULL(SPRNG.value, '---')) AS PartitionBoundary,
                               --SQL_VARIANT_PROPERTY(SPRNG.value, 'BaseType') AS DataType,
             SFG.name AS [FileGroup],
             SALL.type_desc AS [Content],
             SPAR.rows,
             CONVERT(NUMERIC(15, 1), CONVERT(FLOAT, SALL.total_pages * 8196.0) / 1024.0 / 1024.0) AS TotalSizeMB,
             SALL.total_pages,
             SALL.data_pages,
             ( SALL.total_pages - SALL.used_pages ) AS unused_pages,
             CASE
                 WHEN SALL.used_pages = 0 THEN
                     0
                 ELSE
                     CONVERT(DECIMAL(12, 1), CONVERT(DECIMAL(12), SPAR.rows) / CONVERT(DECIMAL(12), SALL.used_pages))
             END AS AvgRowsPg,
             PTCol.DeclaredType AS PtColType,
             PTCol.ColName AS PtColName,
             CASE
                 WHEN PTCol.DeclaredType IS NULL THEN
                     NULL
                 WHEN SPRNG.value IS NULL THEN
                     '---'
                 WHEN SQL_VARIANT_PROPERTY(SPRNG.value, 'BaseType') = 'date' THEN
                     CONVERT(VARCHAR, SPRNG.value, 102)
                 WHEN SQL_VARIANT_PROPERTY(SPRNG.value, 'BaseType') = 'datetime' THEN
                     CONVERT(VARCHAR, SPRNG.value, 120)
                 WHEN SQL_VARIANT_PROPERTY(SPRNG.value, 'BaseType') = 'datetime2' THEN
                     CONVERT(VARCHAR, SPRNG.value, 120)
                 WHEN SQL_VARIANT_PROPERTY(SPRNG.value, 'BaseType') = 'datetimeoffset' THEN
                     CONVERT(VARCHAR, SPRNG.value, 0)
                 ELSE
                     CONVERT(VARCHAR, SPRNG.value)
             END AS PartitionBoundary
         --,SFNC.*,STAB.*, SSCH.*, SFNC.*, SPAR.*, SALL.*, SFG.*, SFL.*
         FROM sys.tables STAB
             INNER JOIN sys.indexes SIDX
                ON ( STAB.object_id = SIDX.object_id )
             LEFT OUTER JOIN PTCol
               ON ( PTCol.[object_id] = SIDX.[object_id] )
                  AND ( PTCol.index_id = SIDX.index_id )
             LEFT OUTER JOIN sys.partitions SPAR
               ON ( SIDX.object_id = SPAR.object_id )
                  AND ( SIDX.index_id = SPAR.index_id )
             LEFT OUTER JOIN sys.partition_schemes SSCH
               ON ( SIDX.data_space_id = SSCH.data_space_id )
             LEFT OUTER JOIN sys.partition_functions SFNC
               ON ( SSCH.function_id = SFNC.function_id )
             LEFT OUTER JOIN sys.partition_parameters SPRM
               ON ( SSCH.function_id = SPRM.function_id )
             LEFT OUTER JOIN sys.partition_range_values SPRNG
               ON ( SFNC.function_id = SPRNG.function_id )
                  AND ( SPAR.partition_number = SPRNG.boundary_id )
                  AND ( SPRM.parameter_id = SPRNG.parameter_id )
             LEFT OUTER JOIN sys.allocation_units SALL
               ON ( SPAR.[partition_id] = SALL.container_id )
             LEFT OUTER JOIN sys.filegroups SFG
               ON ( SALL.data_space_id = SFG.data_space_id )
             LEFT OUTER JOIN sys.sysfiles SFL
               ON ( SALL.data_space_id = SFL.groupid )
  --ORDER BY TableName, SPAR.partition_number, SIDX.index_id, FileGroupName  
  )
  , PerTab AS (
   SELECT	DBS.TableSchema,
			DBS.TableName,
			SUM(CASE WHEN DBS.Content = 'IN_ROW_DATA' THEN [DBS].[rows] ELSE 0 END) AS [RowCount],
			SUM(CASE WHEN DBS.IType IN (0,1,5) THEN DBS.TotalSizeMB ELSE 0 END) AS TableSizeMB,
			SUM(CASE WHEN DBS.IType NOT IN (0,1,5) THEN DBS.TotalSizeMB ELSE 0 END) AS IndexSizeMB,
			SUM(CASE WHEN DBS.IType IN (0,1,5) THEN DBS.TotalSizeMB ELSE 0 END) +
			SUM(CASE WHEN DBS.IType NOT IN (0,1,5) THEN DBS.TotalSizeMB ELSE 0 END) AS TotalSizeMB
		FROM DBS
		GROUP BY DBS.TableSchema,
				DBS.TableName
				)

	SELECT	*,
			SUM(PerTab.TotalSizeMB) OVER (ORDER BY PerTab.TotalSizeMB DESC) AS RunningTot,
			SUM(PerTab.TotalSizeMB) OVER (ORDER BY (SELECT NULL)) AS GrandTot,
			CAST(CAST(SUM(PerTab.TotalSizeMB) OVER (ORDER BY PerTab.TotalSizeMB DESC) AS DOUBLE PRECISION) /
				SUM(PerTab.TotalSizeMB) OVER (ORDER BY (SELECT NULL)) * 100.0 AS NUMERIC(12,2))AS Pct
		FROM PerTab


      ORDER BY
	   TotalSizeMB DESC,
	   --[RowCount] DESC,
       TableSchema,
       TableName

COMMIT TRANSACTION;