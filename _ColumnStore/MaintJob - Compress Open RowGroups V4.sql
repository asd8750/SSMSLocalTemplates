IF ( OBJECT_ID ('tempdb..#PT') IS NOT NULL )
    DROP TABLE #PT;

DECLARE @MinimumRows INT = 0; -- Mimimum number of rows in a rowgroup to trigger a forced reorg
DECLARE @debug INT = 0; -- Set non-zero to debug (no execute)

  ;WITH   RG
  AS
  (
      SELECT TOP ( 2000000000 )
             CSRG.[object_id],
             CSRG.[index_id],
             CSRG.partition_number,
             SUM (ISNULL (CSRG.deleted_rows, 0)) AS DeletedRows,
             SUM (ISNULL (CSRG.total_rows, 0)) AS TotalRows,
             COUNT (*) AS TotalRG,
             ROW_NUMBER () OVER ( PARTITION BY CSRG.[object_id],
                                               CSRG.[index_id]
                                  ORDER BY CSRG.partition_number DESC
                                ) AS [Priority]
         FROM sys.column_store_row_groups CSRG
         WHERE
          ( CSRG.state_description = 'OPEN' )
         GROUP BY
          CSRG.[object_id],
          CSRG.[index_id],
          CSRG.partition_number
  )
   SELECT CONCAT (QUOTENAME (OBJECT_SCHEMA_NAME (RG.[object_id]), '['), '.', QUOTENAME (OBJECT_NAME (RG.[object_id]), '['), '.', QUOTENAME (SIDX.[name], '[')) AS ObjectName,
          OBJECT_SCHEMA_NAME (RG.[object_id]) AS SchemaName,
          OBJECT_NAME (RG.[object_id]) AS TableName,
          SIDX.[name] AS IndexName,
          SFNC.[name] AS PtFunc,
          RG.partition_number,
          RG.TotalRG,
          RG.TotalRows,
		  RG.DeletedRows,
          RG.[Priority],
          SFNC.fanout,
          BNDRY.Bndry1,
          BNDRY.Bndry2,
          IIF(CAST(GETDATE() AS DATE) BETWEEN BNDRY.Bndry1 AND BNDRY.Bndry2, 1, 0) AS Is_Current_PT,
          CONCAT (
                     'ALTER INDEX ',
                     QUOTENAME (SIDX.[name], '['),
                     ' ON ',
                     QUOTENAME (OBJECT_SCHEMA_NAME (RG.[object_id]), '['),
                     '.',
                     QUOTENAME (OBJECT_NAME (RG.[object_id]), '['),
                     ' REORGANIZE PARTITION = ',
                     RIGHT('     ' + CONVERT (VARCHAR(6), RG.partition_number), 6),
                     ' WITH ( COMPRESS_ALL_ROW_GROUPS = ON)',
                     CHAR (13) + CHAR (10),
                     '',
                     CHAR (13) + CHAR (10)
                 ) AS RebuildStmt
     INTO #PT
      FROM RG
          INNER JOIN sys.indexes SIDX
             ON ( RG.[object_id] = SIDX.[object_id] )
                AND ( RG.index_id = SIDX.index_id )
          INNER JOIN sys.partitions SPAR
             ON ( SIDX.object_id = SPAR.object_id )
                AND ( SIDX.index_id = SPAR.index_id )
                AND ( SPAR.partition_number = RG.partition_number )
          INNER JOIN sys.partition_schemes SSCH
             ON ( SIDX.data_space_id = SSCH.data_space_id )
          INNER JOIN sys.partition_functions SFNC
             ON ( SSCH.function_id = SFNC.function_id )
          INNER JOIN 
		    (
      SELECT TOP ( 2000000000 )
             COALESCE (SPRV1.function_id, SPRV2.function_id) AS function_id,
             COALESCE (SPRV2.boundary_id, SPRV1.boundary_id + 1) AS boundary_id,
             ISNULL (SPRV1.[value], CONVERT (DATE, '1900-01-01')) AS Bndry1,
             ISNULL (SPRV2.[value], CONVERT (DATE, '2200-01-01')) AS Bndry2
         FROM sys.partition_range_values SPRV1
             FULL OUTER JOIN sys.partition_range_values SPRV2
               ON ( SPRV1.function_id = SPRV2.function_id )
                  AND ( SPRV1.boundary_id = ( SPRV2.boundary_id - 1 ))
             INNER JOIN sys.partition_parameters SPP
                ON ( SPP.function_id = COALESCE (SPRV1.function_id, SPRV2.function_id))
             INNER JOIN
                 (
                     SELECT *
                        FROM sys.types
                        WHERE
                         ( [name] LIKE '%date%' ) 
                 ) FType
                ON ( SPP.user_type_id = FType.user_type_id )
  )
		  
		  BNDRY
             ON ( BNDRY.function_id = SFNC.function_id )
                AND ( BNDRY.boundary_id = SPAR.partition_number )
      WHERE
       ( SIDX.[type] IN ( 5, 6 ))
       AND ( GETDATE () NOT BETWEEN BNDRY.Bndry1 AND BNDRY.Bndry2 )
       AND ( RG.TotalRows > @MinimumRows )
       AND ( OBJECT_SCHEMA_NAME (RG.[object_id]) NOT LIKE 'DBA%' )
      ORDER BY
       [RG].[Priority],
       SchemaName,
       TableName,
       IndexName;

SELECT *
   FROM #PT
         ORDER BY
       [Priority],
       SchemaName,
       TableName,
       IndexName;;

DECLARE @PtSelect VARCHAR(MAX);

DECLARE @curDB CURSOR;
SET @curDB = CURSOR FORWARD_ONLY FOR
SELECT PT.ObjectName,
       PT.RebuildStmt
   FROM #PT PT
   WHERE (PT.Is_Current_PT = 0)
   ORDER BY
    [PT].[Priority],
    [PT].[SchemaName],
    [PT].[TableName],
    [PT].[IndexName];

OPEN @curDB;

DECLARE @ErrMsg VARCHAR(2000);

DECLARE @ObjectName VARCHAR(512),
        @ReorgCmd VARCHAR(2000),
		@strDate  VARCHAR(25);

FETCH NEXT FROM @curDB
INTO @ObjectName,
     @ReorgCmd;
WHILE ( @@FETCH_STATUS = 0 )
BEGIN
	SET @strDate = CONVERT(VARCHAR(25), GETDATE(), 120);
    RAISERROR ('%s - Reorg: %s', 0, 1, @strDate, @ReorgCmd) WITH NOWAIT;
    BEGIN TRY
        IF ( @debug = 0 )
        BEGIN
            EXEC ( @ReorgCmd );
            WAITFOR DELAY '00:00:05';
        END;
    END TRY
    BEGIN CATCH
        SELECT @ErrMsg = ERROR_MESSAGE ();
        RAISERROR ('  Error: %s', 0, 1, @ErrMsg) WITH NOWAIT;
    END CATCH;
    FETCH NEXT FROM @curDB
    INTO @ObjectName,
         @ReorgCmd;
END;

CLOSE @curDB;
DEALLOCATE @curDB;

DROP TABLE #PT;

