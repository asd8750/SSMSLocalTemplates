USE StagingEDW
GO

-- Purpose: Recreate an SLT table with a BIGINT clustered index and associte it with a partitioning scheme
-- History
--	2019-06-11 - V1.1 -- New version numbering scheme.
--  2019-06-13 - v1.2 -- Add cluster index type choice (row or column store)
--  2019-06-14 - v1.3 -- Add Partition column to non-clustered Unique index
--

-- Fill in the following variables
--
DECLARE @tblSchema  VARCHAR(256) = 'erp';
DECLARE @tblName    VARCHAR(256) = 'OBJK';

DECLARE @clusterIndexType VARCHAR(12) = 'COLUMN';	-- 'ROW' or 'COLUMN'  -- Set the cluster index type
DECLARE @tblIdentCol VARCHAR(128) = '' -- 'ZZ_IDENT';		--  Non-empty value, Create an identity column for the row store cluster index
DECLARE @isClusterUnique INT = 0;					--	Set non-zero if unique cluster row store index required
 
--DECLARE @ptScheme	VARCHAR(128) = '';			-- Non-empty value, partition scheme used to partition this table
--DECLARE @ptColName	VARCHAR(128) = '';			-- Column used as the partition value
--DECLARE @ptScheme	VARCHAR(128) = 'PtSch_SAP_5M';   -- Partition by BIGINT column, ZZ_IDENT
--DECLARE @ptColName	VARCHAR(128) = 'ZZ_IDENT';	 -- Column used as the partition value
--DECLARE @ptScheme	VARCHAR(128) = 'PtSch_EQUNR_5M';  -- Partition by N
--DECLARE @ptColName	VARCHAR(128) = 'EQUNR';		  -- Column used as the partition value
--DECLARE @ptScheme	VARCHAR(128) = 'PtSch_erp_ACDOCA';  -- Partition by N
--DECLARE @ptColName	VARCHAR(128) = 'ZSQL_PARTITION';		  -- Column used as the partition value
DECLARE @ptScheme	VARCHAR(128) = 'PtSch_erp_OBJK';  -- Partition by INT
DECLARE @ptColName	VARCHAR(128) = 'OBKNR';			-- Column used as the partition value
DECLARE @addPtColToUniqueIndex INT = 0;

DECLARE @pageCompress INT = 1;						-- SET non-zero if row store indexes will use PAGE compression

DECLARE @commit INT = 0;							-- Set non-zero to commit changes
DECLARE @debug INT = 1;								-- Set Non-zero to print out all commands

--	End of fill in section
--
DECLARE @tblFullName VARCHAR(256) = QUOTENAME(@tblSchema,'[') + '.' + QUOTENAME(@tblName,'[')
DECLARE @tblObjectId INT = OBJECT_ID(@tblFullName);

DECLARE @onClause  VARCHAR(256) = CASE WHEN ((@ptScheme IS NOT NULL) AND (LEN(@ptScheme) > 0)) THEN CONCAT(QUOTENAME(@ptScheme, '['),'(',QUOTENAME(@ptCOlName, '['),')') ELSE '[PRIMARY]' END;

DECLARE @CKeyCols	VARCHAR(512);
DECLARE @hasPrimaryKey INT = 0;

DECLARE @Cmds TABLE ( Seq INT NOT NULL IDENTITY (1,1), DropCmd NVARCHAR(MAX), CreateCmd NVARCHAR(MAX));

DECLARE @dropConstraintCmd VARCHAR(MAX);
DECLARE @execCmd VARCHAR(MAX);

DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10);

WITH CIDX AS (
		SELECT	[object_id],
				[name] AS IndexName,
				is_primary_key,
				[type],
				[index_id]
			FROM sys.indexes
			WHERE ([type] = 1) AND ([object_id] = @tblObjectId)
		)
SELECT  @hasPrimaryKey = (SELECT is_primary_key FROM CIDX),
		@CKeyCols = (STUFF( CONCAT((SELECT ',' + QUOTENAME(COL.[name], '[') + CASE WHEN IDXC.is_descending_key = 0 THEN ' ASC' ELSE ' DESC' END
                        FROM CIDX 
							INNER JOIN sys.indexes IDX
								ON (CIDX.[object_id] = IDX.[object_id]) AND (CIDX.[index_id] = IDX.[index_id])
							INNER JOIN sys.index_columns IDXC
								ON (IDX.[object_id] = IDXC.[object_id]) AND (IDX.[index_id] = IDXC.[index_id])
                            INNER JOIN sys.columns COL
                                ON (IDXC.[object_id] = COL.[object_id]) AND (IDXC.column_id = COL.[column_id])
                        WHERE (IDXC.key_ordinal > 0) AND (IDXC.is_included_column = 0)
							  AND (CIDX.[object_id] = IDX.[object_id])
                        ORDER BY IDXC.key_ordinal
                        FOR XML PATH('')),
							CASE WHEN (@addPtColToUniqueIndex <> 0) AND (@ptColName IS NOT NULL) AND (LEN(@ptColName) > 0)	
								THEN ',' + QUOTENAME(@ptColName, '[') + ' ASC' 
								END), 1, 1, ''));
PRINT @CKeyCols;

WITH IDXL AS (
              SELECT OBJ.[object_id],
                           IDX.[index_id],
                           IDX.[name] as IndexName,
                           IDX.[type],
						   IDX.is_unique
                     FROM sys.objects OBJ
                           INNER JOIN sys.indexes IDX
                                  ON (OBJ.[object_id] = IDX.[object_id])
                     WHERE (OBJECT_SCHEMA_NAME(OBJ.[object_id]) = @tblSchema) AND (OBJ.[name] = @tblName)
                           AND (IDX.[type] NOT IN (0,1,5))
						   AND (IDX.[object_id] = @tblObjectId)
              )
       , IDXCL AS (
                     SELECT IDXL.index_id,      
                                  (STUFF((SELECT ',' + QUOTENAME(COL.[name], '[') + CASE WHEN IDXC.is_descending_key = 0 THEN ' ASC' ELSE ' DESC' END
                                                FROM sys.index_columns IDXC
                                                       INNER JOIN sys.columns COL
                                                              ON (IDXL.[object_id] = COL.[object_id]) AND (IDXC.column_id = COL.[column_id])
                                                WHERE (IDXL.[object_id] = IDXC.[object_id]) AND (IDXL.[index_id] = IDXC.index_id)
                                                       AND (IDXC.key_ordinal > 0) AND (IDXC.is_included_column = 0)
                                                ORDER BY IDXC.key_ordinal
                                                FOR XML PATH('')), 1, 1, '')) AS IdxCols
                                   ,(STUFF((SELECT ',' + QUOTENAME(COL.[name], '[') 
                                                FROM sys.index_columns IDXC
                                                       INNER JOIN sys.columns COL
                                                              ON (IDXL.[object_id] = COL.[object_id]) AND (IDXC.column_id = COL.[column_id])
                                                WHERE (IDXL.[object_id] = IDXC.[object_id]) AND (IDXL.[index_id] = IDXC.index_id)
                                                       AND (IDXC.is_included_column = 1)
                                                ORDER BY IDXC.key_ordinal
                                                FOR XML PATH('')), 1, 1, '')) AS IncludeCols 
	                         FROM IDXL 
              )

INSERT INTO @Cmds (DropCmd, CreateCmd)
SELECT CONCAT('DROP INDEX [',
                           IDXL.IndexName,
                           '] ON [',
                           OBJECT_SCHEMA_NAME(IDXL.[object_id]),
                           '].[',
                           OBJECT_NAME(IDXL.[object_id]),
                           '];'
                     ),
              CONCAT(' CREATE ',
						CASE WHEN IDXL.is_unique = 1 THEN 'UNIQUE ' ELSE '' END,
						'NONCLUSTERED INDEX [',                   
						IDXL.[IndexName],
                           '] ON [',
                           OBJECT_SCHEMA_NAME(IDXL.[object_id]),
                           '].[',
                           OBJECT_NAME(IDXL.[object_id]),
                           '](',
                           IDXCL.IdxCols,
                           ') ',
						   CASE WHEN IDXCL.IncludeCols IS NOT NULL THEN CONCAT(' (',IDXCL.IncludeCols, ') ') ELSE ' ' END,
                           'WITH (DATA_COMPRESSION = PAGE) ',
						   ' ON ', @onClause,
						   ';'
                     )
       FROM IDXL     
              INNER JOIN IDXCL     
                     ON (IDXL.index_id = IDXCL.index_id);

IF (@debug <> 0)
	SELECT * FROM @Cmds;


SELECT @dropConstraintCmd = CONCAT('ALTER TABLE ',
                           @tblFullName,
                           ' DROP CONSTRAINT ',
                           QUOTENAME(CONSTRAINT_NAME, '['),
						   CASE WHEN ((@ptScheme IS NOT NULL) AND (LEN(@ptScheme) > 0)) THEN
								CONCAT(' WITH (MOVE TO ', @onClause, ')')
						   ELSE '' END,
						   ';'
						   ) 
       FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
       WHERE (TABLE_SCHEMA = @tblSchema) AND (TABLE_NAME = @tblName)
			AND (CONSTRAINT_TYPE = 'PRIMARY KEY');

RAISERROR ('Commands prepared -- Attempting table lock...', 0, 1) WITH NOWAIT; 

BEGIN TRANSACTION;

--SELECT TOP (10) * FROM erp.ACDOCA WITH (HOLDLOCK TABLOCKX);
SELECT @execCmd = CONCAT('SELECT TOP (10) * FROM ',
                                         QUOTENAME(@tblSchema,'['),
                                         '.',
                                         QUOTENAME(@tblName, '['),
                                         ' WITH (HOLDLOCK TABLOCKX);'
                                         )
RAISERROR (@execCmd, 0, 1) WITH NOWAIT;
IF (@debug=0) EXEC (@execCmd);
RAISERROR ('Table lock acquired', 0, 1) WITH NOWAIT; 
 
SELECT @execCmd = REPLACE((SELECT STUFF((SELECT ';' + DropCmd FROM @Cmds FOR XML PATH('')),1,1,'')), ';;', ';' + @CRLF)
RAISERROR (@execCmd, 0, 1) WITH NOWAIT;
IF (@debug=0) EXEC (@execCmd);

RAISERROR (@dropConstraintCmd, 0, 1) WITH NOWAIT;
IF (@debug=0) EXEC (@dropConstraintCmd);

--  Optional - Remove existing identity column and create a new identity column for the clustered index
--
IF ((@tblIdentCol IS NOT NULL) AND (LEN(@tblIdentCol) > 0))
  BEGIN
	SELECT	@execCmd = CONCAT('ALTER TABLE ', @tblFullName, ' DROP COLUMN IF EXISTS ',QUOTENAME(@tblIdentCol, '['), ';');
	RAISERROR (@execCmd, 0, 1) WITH NOWAIT;
	IF (@debug=0) EXEC (@execCmd);

	SELECT	@execCmd = CONCAT('ALTER TABLE ', @tblFullName, ' ADD ', QUOTENAME(@tblIdentCol, '['), ' BIGINT NOT NULL IDENTITY(1,1);');
	RAISERROR (@execCmd, 0, 1) WITH NOWAIT;
	IF (@debug=0) EXEC (@execCmd);
  END;


IF ((@clusterIndexType IS NOT NULL) AND (@clusterIndexType = 'COLUMN'))
  BEGIN
	SET @execCmd = CONCAT('CREATE CLUSTERED COLUMNSTORE INDEX ',
							CONCAT('[CCSI_', @tblSchema, '_', @tblName, ']'),
							' ON ', @tblFullName,
							' WITH (DROP_EXISTING = OFF, COMPRESSION_DELAY = 0)');
	RAISERROR (@execCmd, 0, 1) WITH NOWAIT;
	IF (@debug=0) EXEC (@execCmd);

	IF (@hasPrimaryKey <> 0)
	  BEGIN
		SET @execCmd = CONCAT('CREATE UNIQUE NONCLUSTERED INDEX ',
								CONCAT('[UNCI_', @tblSchema, '_', @tblName, '] '),
								' ON ', @tblFullName,
								CONCAT('(', @CKeyCols ,') '), @CRLF,
								'    WITH (DATA_COMPRESSION = PAGE, SORT_IN_TEMPDB = ON) ON ', @onClause, ';');
	RAISERROR (@execCmd, 0, 1) WITH NOWAIT;
	IF (@debug=0) EXEC (@execCmd);	  END;
  END;
ELSE
  BEGIN
	SELECT	@execCmd = CONCAT('CREATE ',
			CASE WHEN @isClusterUnique <> 0 THEN 'UNIQUE ' ELSE '' END,
			'CLUSTERED INDEX [', CASE WHEN @isClusterUnique <> 0 THEN 'U' ELSE '' END, 'CI_', @tblName, '] ON ', @tblFullName,	
			' (', QUOTENAME(@tblIdentCol, '['), ' ASC) WITH (DATA_COMPRESSION = PAGE, SORT_IN_TEMPDB = ON) ON ', @onClause, ';');
	RAISERROR (@execCmd, 0, 1) WITH NOWAIT;
	IF (@debug=0) EXEC (@execCmd);

	SELECT	@execCmd = CONCAT('ALTER TABLE ', @tblFullName, 
			  ' ADD CONSTRAINT ', QUOTENAME('PK_' + @tblName, '['), 
			  ' PRIMARY KEY  NONCLUSTERED (', @CKeyCols, ')',
			  ' WITH (DATA_COMPRESSION = PAGE)',
			  ' ON ', @onClause, ';')
	RAISERROR (@execCmd, 0, 1) WITH NOWAIT;
	IF (@debug=0) EXEC (@execCmd);
  END;



SELECT @execCmd = REPLACE((SELECT STUFF((SELECT ';' + CreateCmd FROM @Cmds FOR XML PATH('')),1,1,'')),';;',';' + @CRLF)
RAISERROR (@execCmd, 0, 1) WITH NOWAIT;
IF (@debug=0) EXEC (@execCmd);


SELECT OBJECT_SCHEMA_NAME(IDX.[object_id]),
              OBJECT_NAME(IDX.[object_id]),
              IDX.*
       FROM sys.indexes IDX
       WHERE (OBJECT_SCHEMA_NAME(IDX.[object_id]) = @tblSchema) AND (OBJECT_NAME(IDX.[object_id]) = @tblName);

IF (@commit = 1)
	COMMIT TRANSACTION;
ELSE
	ROLLBACK TRANSACTION;


SELECT OBJECT_SCHEMA_NAME(IDX.[object_id]),
              OBJECT_NAME(IDX.[object_id]),
              IDX.*
       FROM sys.indexes IDX
       WHERE (OBJECT_SCHEMA_NAME(IDX.[object_id]) = @tblSchema) AND (OBJECT_NAME(IDX.[object_id]) = @tblName);

