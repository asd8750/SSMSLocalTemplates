DECLARE @SchemaName VARCHAR(128) = 'erp';

DECLARE @CdcTables TABLE ( TableName VARCHAR(128));

INSERT INTO @CdcTables ( TableName )
VALUES
( 'S028' );

WITH IDXC
  AS
  (
      SELECT IDXC2.[object_id],
             IDXC2.[index_id],
             COUNT(*) AS KeyColCnt
         FROM sys.index_columns IDXC2
         GROUP BY
          IDXC2.[object_id],
          IDXC2.[index_id]
  ),
     UIDX
  AS
  (
      SELECT TBL.[object_id],
             IDX.[name] AS IndexName,
             IDXC.KeyColCnt,
             ROW_NUMBER() OVER ( PARTITION BY TBL.[object_id]
ORDER BY IDXC.KeyColCnt, IDX.[index_id]
                               ) AS RowNum
         FROM sys.tables TBL
             INNER JOIN sys.indexes IDX
                ON ( TBL.[object_id] = IDX.[object_id] )
             INNER JOIN IDXC
                ON ( TBL.[object_id] = IDXC.[object_id] )
                   AND ( IDX.index_id = IDXC.index_id )
         WHERE
          ( IDX.is_unique = 1 )
  )
   SELECT @SchemaName AS SchemaName,
          CT.TableName,
          ISNULL(UIDX.IndexName, '--NoIndex--') AS IndexName,
          'EXEC sys.sp_cdc_enable_table
    @source_schema = N''' + @SchemaName + '''
  , @source_name = N''' + CT.TableName + '''
  , @role_name = N''cdc_admin''
  , @capture_instance = N''' + @SchemaName + '_' + CT.TableName + ''' 
  , @supports_net_changes = 1
  , @index_name = N''' + ISNULL(UIDX.IndexName, '--NoIndex--') + ''' 
  , @filegroup_name = N''CDC''; '
      FROM @CdcTables CT
          LEFT OUTER JOIN UIDX
            ON ( OBJECT_ID(QUOTENAME(@SchemaName, '[') + '.' + QUOTENAME(CT.TableName, '[')) = UIDX.[object_id] )
      WHERE
       ( UIDX.RowNum = 1 )
      ORDER BY
       SchemaName,
       TableName;