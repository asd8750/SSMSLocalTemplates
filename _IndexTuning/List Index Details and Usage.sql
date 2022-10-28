DROP TABLE IF EXISTS #IXCols;
--     Gather column specific information into a temp table
--
SELECT IDX.[object_id] AS TableObjectID, 
	   OBJECT_SCHEMA_NAME(IDX.[object_id]) AS SchemaName, 
	   OBJECT_NAME(IDX.[object_id]) AS TableName, 
	   IDX.index_id AS IndexID, 
	   IDX.[name] AS IndexName, 
	   IDC.column_id, 
	   QUOTENAME(COL.[name], '[') AS ColName, 
	   IDC.index_column_id AS IdxColId, 
	   IDC.key_ordinal AS KeyOrd, 
	   IDC.is_included_column AS IsIncluded, 
	   IDC.partition_ordinal AS PartOrd, 
	   IDC.is_descending_key AS IsDescending, 
	   IDX.is_unique AS IsUnique, 
	   ROW_NUMBER() OVER(PARTITION BY IDX.[object_id], 
									  IDX.index_id
	   ORDER BY IDC.index_column_id) AS RN
INTO #IXCols
	FROM sys.tables TAB
		 INNER JOIN sys.indexes IDX
			 ON (TAB.[object_id] = IDX.[object_id]) 
		 INNER JOIN sys.index_columns IDC
			 ON (IDX.[object_id] = IDC.[object_id])
				AND (IDX.index_id = IDC.index_id) 
		 INNER JOIN sys.columns COL
			 ON (TAB.[object_id] = COL.[object_id])
				AND (COL.column_id = IDC.column_id)
	WHERE (TAB.is_ms_shipped = 0);
--ORDER BY SchemaName, TableName, IndexName, IDC.index_id, IdxColId


CREATE CLUSTERED INDEX [IX_#IXCols]
	ON [#IXCols]
(TableObjectID, IndexID, IdxColId
);

--SELECT *
--   FROM #IXCols
--   ORDER BY
--    [SchemaName],
--	[TableName],
--	IndexID,
--	IdxColId,
--    [TableObjectID]
--    ;

--     Now get index physical size details
--
WITH IInfo1
	 AS (SELECT TOP (2000000000) @@SERVERNAME AS [InstanceName], 
								 DB_NAME() AS [DatabaseName], 
								 s.name AS [SchemaName], 
								 t.name AS [TableName], 
								 t.[object_id], 
								 i.name AS [IndexName], 
								 i.index_id, 
								 i.type_desc AS [IndexType], 
								 SUM(p.rows) AS [RowCount],
								 -- SUM(CASE WHEN i.type IN ( 1, 5 ) AND a.type = 1 THEN p.rows ELSE 0 END) [RowCount],
								 CASE
									 WHEN ps.name IS NULL
									 THEN 0
									 WHEN ps.name IS NOT NULL
									 THEN 1
									 ELSE 0
								 END AS isPartitioned, 
								 i.is_primary_key, 
								 ps.[name] AS PtScheme, 
								 CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS TotalSpaceMB, 
								 CAST(ROUND(((SUM(a.used_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS UsedSpaceMB,
								 --CAST(ROUND(((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.00, 2) AS NUMERIC(36, 2)) AS UnusedSpaceMB
								 GETDATE() AS [CollectionDate]
			 FROM sys.tables t
				  INNER JOIN sys.indexes i
					  ON t.object_id = i.object_id
				  INNER JOIN sys.partitions p
					  ON i.object_id = p.object_id
						 AND i.index_id = p.index_id
				  INNER JOIN sys.allocation_units a
					  ON p.partition_id = a.container_id
				  INNER JOIN sys.schemas s
					  ON t.schema_id = s.schema_id
				  LEFT OUTER JOIN sys.partition_schemes ps
					  ON i.data_space_id = ps.data_space_id
			 WHERE (t.is_ms_shipped = 0)
			 GROUP BY t.name, 
					  t.[object_id], 
					  s.name, 
					  i.name, 
					  i.index_id, 
					  i.is_primary_key, 
					  i.type_desc, 
					  ps.name
		 --ORDER BY SchemaName, TableName, IndexName
		 )
	, IDXS AS (
			SELECT	TOP (20000000) *
				FROM sys.dm_db_index_usage_stats
				WHERE (database_id = DB_ID())
				ORDER BY [object_id], [index_id]
			)
	 --  And finally merge it with index meta details and index usage stats
	 SELECT IInfo1.[InstanceName], 
			IInfo1.[DatabaseName], 
			IInfo1.[SchemaName], 
			IInfo1.[TableName], 
			IInfo1.[IndexName], 
			IInfo1.[IndexType], 
			IInfo1.index_id, 
			IInfo1.[RowCount], 
			IInfo1.isPartitioned, 
			IInfo1.TotalSpaceMB, 
			IInfo1.UsedSpaceMB, 
			IInfo1.CollectionDate, 
			IX.TableObjectID, 
			IX.IndexID, 
			IX.IsUnique, 
			IInfo1.is_primary_key, 
			IDXS.user_seeks, 
			IDXS.user_scans, 
			IDXS.user_lookups, 
			IDXS.user_updates, 
			IDXS.last_user_seek, 
			IDXS.last_user_scan, 
			IDXS.last_user_lookup, 
			IDXS.last_user_update, 
			STUFF(
		 (
			 SELECT CONCAT(',', I2.ColName,
								   CASE
									   WHEN I2.IsDescending = 1
									   THEN '<D>'
									   ELSE ''
								   END)
				 FROM #IXCols I2
				 WHERE (I2.TableObjectID = IX.TableObjectID)
					   AND (I2.IndexID = IX.IndexID)
					   AND (I2.KeyOrd > 0)
				 ORDER BY I2.IdxColId FOR XML PATH(''), TYPE
		 ).value('.', 'varchar(2000)'), 1, 1, '') AS Keys, 
			STUFF(
		 (
			 SELECT ',' + I2.ColName
				 FROM #IXCols I2
				 WHERE (I2.TableObjectID = IX.TableObjectID)
					   AND (I2.IndexID = IX.IndexID)
					   AND (I2.IsIncluded > 0)
				 ORDER BY I2.IdxColId FOR XML PATH(''), TYPE
		 ).value('.', 'varchar(2000)'), 1, 1, '') AS Included, 
			IInfo1.PtScheme, 
			STUFF(
		 (
			 SELECT ',' + I2.ColName
				 FROM #IXCols I2
				 WHERE (I2.TableObjectID = IX.TableObjectID)
					   AND (I2.IndexID = IX.IndexID)
					   AND (I2.PartOrd > 0)
				 ORDER BY I2.IdxColId FOR XML PATH(''), TYPE
		 ).value('.', 'varchar(256)'), 1, 1, '') AS PartCol
		 FROM #IXCols IX
			  INNER JOIN IInfo1
				  ON (IX.TableObjectID = IInfo1.[object_id])
					 AND (IX.IndexID = IInfo1.index_id) 
			  LEFT OUTER JOIN IDXS
				  ON (IInfo1.[object_id] = IDXS.[object_id])
					 AND (IInfo1.index_id = IDXS.index_id)
		 WHERE (IX.RN = 1)
	
		 ORDER BY --IDXS.user_lookups DESC,
					IInfo1.SchemaName, 
				  IInfo1.TableName, 
				  IInfo1.IndexName
				--  ,IX.TableObjectID;
