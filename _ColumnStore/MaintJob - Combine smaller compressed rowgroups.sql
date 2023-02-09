--	Columnstore Maintenance
--	Rebuild partitions where ther are multiple partially filled COMPRESSED rowgroups in a single partition.  Normally this happens when OPEN rowgroups are compressed 
--	before collecting 1048576 rows.  Then more data rows are inserted into this partition to create a new OPEN deltastore.
--
--	Author:	Fred LaForest
--	History
--		2020-07-22	Initial version
--

DECLARE @MaxRowGroupLimit INT = 20; --  Do not rebuild partitions with more than xxx rowgroups

IF ( OBJECT_ID ('tempdb..#RG1') IS NOT NULL )
    DROP TABLE #RG1;

WITH CSS AS
   (
       SELECT  TOP (2000000000) --object_name(phst.object_id) as TableName, 
           OBJECT_SCHEMA_NAME (phst.[object_id]) AS SchemaName,
           OBJECT_NAME (phst.[object_id]) AS TableName,
           ind.[name] AS IndexName,
           phst.[object_id],
           phst.index_id,
           phst.partition_number,
           phst.row_group_id,
           phst.generation,
           phst.[state],
           phst.state_desc,
           phst.total_rows,
           phst.deleted_rows,
           phst.size_in_bytes,
           phst.trim_reason,
           phst.trim_reason_desc,
           phst.transition_to_compressed_state,
           phst.transition_to_compressed_state_desc,
           phst.has_vertipaq_optimization,
           phst.created_time,
           CONCAT (
                      'ALTER INDEX ',
                      QUOTENAME (ind.[name], '['),
                      ' ON ',
                      QUOTENAME (OBJECT_SCHEMA_NAME (phst.[object_id]), '['),
                      '.',
                      QUOTENAME (OBJECT_NAME (phst.[object_id]), '['),
                      ' REBUILD PARTITION=',
                      CONVERT (VARCHAR(5), phst.partition_number),
                      ' WITH (ONLINE=ON)'
                  ) AS RebuildCmd
          FROM sys.dm_db_column_store_row_group_physical_stats phst
              INNER JOIN sys.indexes ind
                 ON phst.object_id = ind.object_id
                    AND phst.index_id = ind.index_id
          WHERE
           ( OBJECT_SCHEMA_NAME (phst.[object_id]) NOT LIKE 'DBA%' )
   )
   SELECT CSS.SchemaName,
          CSS.TableName,
          CSS.IndexName,
          CSS.index_id,
          CSS.partition_number,
          COUNT (*) AS RGCnt,
          SUM (IIF(CSS.state_desc = 'OPEN', 1, 0)) AS OpenCnt,
          SUM (IIF(CSS.state_desc = 'COMPRESSED', 1, 0)) AS CmpCnt,
          SUM (IIF(( CSS.state_desc = 'COMPRESSED' ) AND ( CSS.total_rows = 1048576 ), 1, 0)) AS FullCnt,
		  (SUM (CSS.total_rows) + 1048575) / 1048576 AS MinRG,
		  SUM (CSS.total_rows) AS TotalRows,
		  SUM (ISNULL(CSS.deleted_rows,0)) AS DeletedRows,
          CONCAT (
                     'ALTER INDEX [',
                     CSS.IndexName,
                     '] ON [',
                     CSS.SchemaName,
                     '].[',
                     CSS.TableName,
                     '] REBUILD PARTITION=(',
                     CONVERT (VARCHAR(7), CSS.partition_number),
                     ') WITH (ONLINE=ON)'
                 ) AS Cmd
      -- ,CSS.*
      INTO #RG1
      FROM CSS
      GROUP BY
       CSS.SchemaName,
       CSS.TableName,
       CSS.IndexName,
       CSS.index_id,
       CSS.partition_number
      HAVING
       ( COUNT (*) > 2 )
       AND ( COUNT (*) > (SUM (CSS.total_rows) + 1048575) / 1048576)  -- Is current RG count > minimum possible?
      ORDER BY
       CSS.SchemaName,
       CSS.TableName,
       CSS.IndexName,
       CSS.index_id,
       CSS.partition_number;


SELECT *
   FROM #RG1
   ORDER BY
    SchemaName,
    TableName,
    partition_number;

--
--	ALTER INDEX [CCSI_PSLProcessData] ON [dbo].[PSLProcessData] REBUILD PARTITION=(5) WITH (ONLINE=ON)


