USE [MesLogging];

SELECT OBJECT_SCHEMA_NAME (TBL.[object_id]) AS SchemaName,
       TBL.[name] AS TableName,
	   IDX.[Name] AS IndexName,
	   IDX.[index_id] AS IndexID,
       PTSCH.[name] AS PtScheme,
       PTFUNC.fanout,
       COL.[name] AS PtCol,
       ISNULL (IDXC.partition_ordinal, 0) AS PtOrdinal,
       IDXC.column_id,
       RC.RowCnt
   FROM sys.tables TBL
       INNER JOIN sys.indexes IDX
          ON ( TBL.[object_id] = IDX.[object_id] )
       LEFT OUTER JOIN(
			sys.partition_schemes PTSCH
				INNER JOIN sys.partition_functions PTFUNC
					ON ( PTSCH.function_id = PTFUNC.function_id )
					)
         ON ( IDX.data_space_id = PTSCH.data_space_id )
       LEFT OUTER JOIN(
			sys.index_columns IDXC
			   INNER JOIN sys.columns COL
				  ON ( IDXC.[object_id] = COL.[object_id] )
					 AND ( IDXC.column_id = COL.column_id )
					 )
         ON ( TBL.[object_id] = IDXC.[object_id] )
            AND ( IDX.index_id = IDXC.index_id )
            AND ( IDXC.partition_ordinal > 0 )
       OUTER APPLY
       (
           SELECT PT.[object_id],
                  PT.[index_id],
                  SUM (PT.[rows]) AS RowCnt
              FROM sys.partitions PT
              WHERE
               ( PT.index_id = IDX.index_id )
               AND ( PT.[object_id] = IDX.[object_id] )
              GROUP BY
               PT.[object_id],
               PT.[index_id]
       ) RC
   WHERE 
    ( TBL.is_ms_shipped = 0 )  -- Not Microsoft table
	AND ( IDX.[type] IN ( 0, 1, 5 ))  -- Only HEAP, Clustered index 
    AND ( OBJECT_SCHEMA_NAME (TBL.[object_id]) = 'Logging' )
  
   ORDER BY
    SchemaName,
    TableName,
	IndexID

