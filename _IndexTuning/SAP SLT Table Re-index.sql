USE StagingEDW;
GO
-- Purpose: Recreate an SLT table with a BIGINT clustered index and associte it with a partitioning scheme
-- History
--  2019-06-11 - V1.1 -- New version numbering scheme.
--  2019-06-13 - v1.2 -- Add cluster index type choice (row or column store)
--  2019-06-14 - v1.3 -- Add Partition column to non-clustered Unique index
--  2019-12-10 - v1.4 -- Add option to add non-clustered columnstore index 
--

-- =======================================================================
--
-- Fill in the following variables
--
-- =======================================================================
DECLARE @commit INT= 0; -- Set non-zero to commit changes
DECLARE @debug INT= 1; -- Set Non-zero to print out all commands

DECLARE @tblSchema VARCHAR(256)= 'erp';
DECLARE @tblName VARCHAR(256)= 'BKPF';

DECLARE @clusterIndexType VARCHAR(12)= 'ROW'; -- 'ROW' or 'COLUMN'  -- Set the cluster index type
DECLARE @createCCSI INT= 1; -- If non-zero, create a columnstore index.  @ClusterIndexType will determine if clustered/non-clustered

DECLARE @createSimpleClusterKey INT= 1;  -- Set non-zero if the existing cluster index key will replaced by an IDENTITY BIGINT col
DECLARE @tblIdentCol VARCHAR(128)= 'ZZ_IDENT'; -- Non-empty value, column name of new IDENTITY BIGINT column


--DECLARE @ptScheme  VARCHAR(128) = '';					-- Non-empty value, partition scheme used to partition this table
--DECLARE @ptColName VARCHAR(128) = '';					-- Column used as the partition value
--DECLARE @ptScheme  VARCHAR(128) = 'PtSch_SAP_5M';		-- Partition by BIGINT column, ZZ_IDENT
--DECLARE @ptColName VARCHAR(128) = 'ZZ_IDENT'; -- Column used as the partition value
--DECLARE @ptScheme  VARCHAR(128) = 'PtSch_EQUNR_5M';  -- Partition by N
--DECLARE @ptColName VARCHAR(128) = 'EQUNR';             -- Column used as the partition value
DECLARE @ptScheme VARCHAR(128)= 'PtSch_erp_GJAHR'; -- Partition by N
DECLARE @ptColName VARCHAR(128)= 'GJAHR'; -- Column used as the partition value

-- =======================================================================
--
-- Do not change anything below this line
--
-- =======================================================================

--DECLARE @isClusterUnique INT= 0; -- Set non-zero if unique cluster row store index required
DECLARE @addPtColToUniqueIndex INT= 0;

DECLARE @tblFullName VARCHAR(256)= QUOTENAME(@tblSchema, '[') + '.' + QUOTENAME(@tblName, '[');
DECLARE @tblObjectId INT= OBJECT_ID(@tblFullName);
DECLARE @onClause VARCHAR(256)= CASE
									WHEN((@ptScheme IS NOT NULL)
										 AND (LEN(@ptScheme) > 0) )
									THEN CONCAT(QUOTENAME(@ptScheme, '['), '(', QUOTENAME(@ptColName, '['), ')')
									ELSE '[PRIMARY]'
								END;

DECLARE @hasPrimaryKey INT= 0;  -- Non-zero if primary key is present
DECLARE @isClusterUnique INT= 0;  -- Non-zero if the cluster key is unique
DECLARE @CKeyCols VARCHAR(512); -- List of cols in cluster index
DECLARE @TblCols VARCHAR(4000); -- List of all table columns


--	Table to hold constructed commands
--
DECLARE @Cmds TABLE
(Seq       INT NOT NULL IDENTITY(1, 1), 
 DropCmd   NVARCHAR(MAX), 
 CreateCmd NVARCHAR(MAX)
);

DECLARE @execCmd VARCHAR(MAX);
DECLARE @CRLF CHAR(2)= CHAR(13) + CHAR(10);

--	Get the Primary Key column information (if exists)
--
WITH CIDX
	 AS (SELECT TOP (1) [object_id], 
						[name] AS IndexName, 
						[is_primary_key], 
						[is_unique], 
						[type], 
						[index_id]
			 FROM sys.indexes
			 WHERE ([object_id] = @tblObjectId)
				   AND (is_primary_key = 1)
			 ORDER BY [is_primary_key] DESC, 
					  [type] ASC)
	 SELECT @hasPrimaryKey =
		 (
			 SELECT is_primary_key
				 FROM CIDX
		 ), 
			@isClusterUnique =
		 (
			 SELECT CASE
						WHEN ([type] = 1)
							 AND ([is_unique] = 1)
						THEN 1
						ELSE 0
					END
				 FROM CIDX
		 ), 
			@CKeyCols = (STUFF(CONCAT(
		 (
			 SELECT ',' + QUOTENAME(COL.[name], '[') + CASE
														   WHEN IDXC.is_descending_key = 0
														   THEN ' ASC'
														   ELSE ' DESC'
													   END
				 FROM CIDX
					  INNER JOIN sys.indexes IDX
						  ON (CIDX.[object_id] = IDX.[object_id])
							 AND (CIDX.[index_id] = IDX.[index_id]) 
					  INNER JOIN sys.index_columns IDXC
						  ON (IDX.[object_id] = IDXC.[object_id])
							 AND (IDX.[index_id] = IDXC.[index_id]) 
					  INNER JOIN sys.columns COL
						  ON (IDXC.[object_id] = COL.[object_id])
							 AND (IDXC.column_id = COL.[column_id])
				 WHERE (IDXC.key_ordinal > 0)
					   AND (IDXC.is_included_column = 0)
					   AND (CIDX.[object_id] = IDX.[object_id])
				 ORDER BY IDXC.key_ordinal FOR XML PATH('')
		 ),
		 CASE
			 WHEN (@addPtColToUniqueIndex <> 0)
				  AND (@ptColName IS NOT NULL)
				  AND (LEN(@ptColName) > 0)
			 THEN ',' + QUOTENAME(@ptColName, '[') + ' ASC'
		 END), 1, 1, ''));
PRINT @CKeyCols;

--		Create a list of all table columns
--
SELECT @TblCols = (STUFF(
	(
		SELECT ',' + QUOTENAME(COL.[name], '[')
			FROM sys.tables TBL
				 INNER JOIN sys.columns COL
					 ON (TBL.[object_id] = COL.[object_id])
			WHERE (TBL.[object_id] = @tblObjectId)
			ORDER BY COL.column_id FOR XML PATH('')
	), 1, 1, ''));
PRINT @TblCols;

--		Create a a Drop index and re-create index for each non-clustered index
--
WITH IDXL
	 AS (SELECT OBJ.[object_id], 
				IDX.[index_id], 
				IDX.[name] AS IndexName, 
				IDX.[type], 
				IDX.is_unique
			 FROM sys.objects OBJ
				  INNER JOIN sys.indexes IDX
					  ON (OBJ.[object_id] = IDX.[object_id])
			 WHERE (OBJECT_SCHEMA_NAME(OBJ.[object_id]) = @tblSchema)
				   AND (OBJ.[name] = @tblName)
				   AND (IDX.[type] NOT IN(0, 1, 5))
				  AND (IDX.[object_id] = @tblObjectId) ),
	 IDXCL
	 AS (SELECT IDXL.index_id, 
				(STUFF(
			 (
				 SELECT ',' + QUOTENAME(COL.[name], '[') + CASE
															   WHEN IDXC.is_descending_key = 0
															   THEN ' ASC'
															   ELSE ' DESC'
														   END
					 FROM sys.index_columns IDXC
						  INNER JOIN sys.columns COL
							  ON (IDXL.[object_id] = COL.[object_id])
								 AND (IDXC.column_id = COL.[column_id])
					 WHERE (IDXL.[object_id] = IDXC.[object_id])
						   AND (IDXL.[index_id] = IDXC.index_id)
						   AND (IDXC.key_ordinal > 0)
						   AND (IDXC.is_included_column = 0)
					 ORDER BY IDXC.key_ordinal FOR XML PATH('')
			 ), 1, 1, '')) AS IdxCols, 
				(STUFF(
			 (
				 SELECT ',' + QUOTENAME(COL.[name], '[')
					 FROM sys.index_columns IDXC
						  INNER JOIN sys.columns COL
							  ON (IDXL.[object_id] = COL.[object_id])
								 AND (IDXC.column_id = COL.[column_id])
					 WHERE (IDXL.[object_id] = IDXC.[object_id])
						   AND (IDXL.[index_id] = IDXC.index_id)
						   AND (IDXC.is_included_column = 1)
					 ORDER BY IDXC.key_ordinal FOR XML PATH('')
			 ), 1, 1, '')) AS IncludeCols
			 FROM IDXL)
	 INSERT INTO @Cmds
	 (DropCmd, 
	  CreateCmd
	 )
	 SELECT CONCAT('DROP INDEX [', IDXL.IndexName, '] ON [', OBJECT_SCHEMA_NAME(IDXL.[object_id]), '].[', OBJECT_NAME(IDXL.[object_id]), '];'), 
			CONCAT(' CREATE ',
				   CASE
					   WHEN IDXL.is_unique = 1
					   THEN 'UNIQUE '
					   ELSE ''
				   END, 'NONCLUSTERED INDEX [', IDXL.[IndexName], '] ON [', OBJECT_SCHEMA_NAME(IDXL.[object_id]), '].[', OBJECT_NAME(IDXL.[object_id]), '](', IDXCL.IdxCols, ') ',
																																											 CASE
																																												 WHEN IDXCL.IncludeCols IS NOT NULL
																																												 THEN CONCAT(' (', IDXCL.IncludeCols, ') ')
																																												 ELSE ' '
																																											 END, 'WITH (DATA_COMPRESSION = PAGE) ', ' ON ', @onClause, ';')
		 FROM IDXL
			  INNER JOIN IDXCL
				  ON (IDXL.index_id = IDXCL.index_id);
IF (@debug <> 0) 
	BEGIN
		SELECT *
			FROM @Cmds;
END;

--	Create an ALTER Table to drop the primary key and, optionally, re-partition the table
--
DECLARE @dropConstraintCmd VARCHAR(MAX);
SELECT @dropConstraintCmd = CONCAT('ALTER TABLE ', @tblFullName, ' DROP CONSTRAINT ', QUOTENAME(CONSTRAINT_NAME, '['),
																													CASE
																														WHEN((@ptScheme IS NOT NULL)
																															 AND (LEN(@ptScheme) > 0) )
																														THEN CONCAT(' WITH (MOVE TO ', @onClause, ')')
																														ELSE ''
																													END, ';')
	FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
	WHERE (TABLE_SCHEMA = @tblSchema)
		  AND (TABLE_NAME = @tblName)
		  AND (CONSTRAINT_TYPE = 'PRIMARY KEY');

--	Lock the base table
--
BEGIN TRANSACTION;
RAISERROR('Commands prepared -- Attempting table lock...', 0, 1) WITH NOWAIT;
SELECT @execCmd = CONCAT('SELECT TOP (10) * FROM ', QUOTENAME(@tblSchema, '['), '.', QUOTENAME(@tblName, '['), ' WITH (HOLDLOCK TABLOCKX);');
RAISERROR(@execCmd, 0, 1) WITH NOWAIT;
IF (@debug = 0) 
	BEGIN
		EXEC (@execCmd);
END;
RAISERROR('  ...Table lock acquired', 0, 1) WITH NOWAIT;

--	Now Remove the non-clustered indexes
--
SELECT @execCmd = REPLACE(
	(
		SELECT STUFF(
			(
				SELECT ';' + DropCmd
					FROM @Cmds FOR XML PATH('')
			), 1, 1, '')
	), ';;', ';' + @CRLF);
RAISERROR(@execCmd, 0, 1) WITH NOWAIT;
IF (@debug = 0) 
	BEGIN
		EXEC (@execCmd);
END;
RAISERROR(@dropConstraintCmd, 0, 1) WITH NOWAIT;
IF (@debug = 0) 
	BEGIN
		EXEC (@dropConstraintCmd);
END;

--  Optional - Remove existing identity column and create a new identity column for the clustered index
--
IF (@createSimpleClusterKey <> 0) 
	BEGIN
		SELECT @execCmd = CONCAT('ALTER TABLE ', @tblFullName, ' DROP COLUMN IF EXISTS ', QUOTENAME(@tblIdentCol, '['), ';');
		RAISERROR(@execCmd, 0, 1) WITH NOWAIT;
		IF (@debug = 0) 
			BEGIN
				EXEC (@execCmd);
		END;
		SELECT @execCmd = CONCAT('ALTER TABLE ', @tblFullName, ' ADD ', QUOTENAME(@tblIdentCol, '['), ' BIGINT NOT NULL IDENTITY(1,1);');
		RAISERROR(@execCmd, 0, 1) WITH NOWAIT;
		IF (@debug = 0) 
			BEGIN
				EXEC (@execCmd);
		END;
END;

--	Create the required clustered index 
--
IF (@clusterIndexType = 'COLUMN') 
	BEGIN
		IF (@createCCSI <> 0) 
			BEGIN
				SET @execCmd = CONCAT('CREATE CLUSTERED COLUMNSTORE INDEX ', CONCAT('[CCSI_', @tblSchema, '_', @tblName, ']'), ' ON ', @tblFullName, ' WITH (DROP_EXISTING = OFF, COMPRESSION_DELAY = 0) ON ', @onClause, ';');
				RAISERROR(@execCmd, 0, 1) WITH NOWAIT;
				IF (@debug = 0) 
					BEGIN
						EXEC (@execCmd);
				END;
		END;
END;
	ELSE
	BEGIN
		SELECT @execCmd = CONCAT('CREATE ',
								 CASE
									 WHEN (@isClusterUnique <> 0)
										  AND (@createSimpleClusterKey = 0)
									 THEN 'UNIQUE '
									 ELSE ''
								 END, 'CLUSTERED INDEX [',
									  CASE
										  WHEN @isClusterUnique <> 0
										  THEN 'U'
										  ELSE ''
									  END, 'CI_', @tblName, '] ON ', @tblFullName, ' (',
																				   CASE
																					   WHEN @createSimpleClusterKey = 0
																					   THEN @CKeyCols
																					   ELSE QUOTENAME(@tblIdentCol, '[') + ' ASC'
																				   END, ') WITH (DATA_COMPRESSION = PAGE, SORT_IN_TEMPDB = ON) ON ', @onClause, ';');
		RAISERROR(@execCmd, 0, 1) WITH NOWAIT;
		IF (@debug = 0) 
			BEGIN
				EXEC (@execCmd);
		END;
		IF (@createCCSI <> 0) 
			BEGIN
				SET @execCmd = CONCAT('CREATE NONCLUSTERED COLUMNSTORE INDEX ', CONCAT('[CCSI_', @tblSchema, '_', @tblName, ']'), ' ON ', @tblFullName, ' (', @TblCols ,') WITH (DROP_EXISTING = OFF, COMPRESSION_DELAY = 0) ON ', @onClause, ';');
				RAISERROR(@execCmd, 0, 1) WITH NOWAIT;
				IF (@debug = 0) 
					BEGIN
						EXEC (@execCmd);
				END;
		END;

END;

IF (@hasPrimaryKey <> 0)
   AND ( (@createSimpleClusterKey <> 0)
		 OR (@clusterIndexType = 'COLUMN') )
	BEGIN
		SELECT @execCmd = CONCAT('ALTER TABLE ', @tblFullName, ' ADD CONSTRAINT ', QUOTENAME('PK_' + @tblName, '['), ' PRIMARY KEY  NONCLUSTERED (', @CKeyCols, ')', ' WITH (DATA_COMPRESSION = PAGE)', ' ON ', @onClause, ';');
		RAISERROR(@execCmd, 0, 1) WITH NOWAIT;
		IF (@debug = 0) 
			BEGIN
				EXEC (@execCmd);
		END;
				--SET @execCmd = CONCAT('CREATE UNIQUE NONCLUSTERED INDEX ', CONCAT('[UNCI_', @tblSchema, '_', @tblName, '] '), ' ON ', @tblFullName, CONCAT('(', @CKeyCols, ') '), @CRLF, '    WITH (DATA_COMPRESSION = PAGE, SORT_IN_TEMPDB = ON) ON ', @onClause, ';');
				--RAISERROR(@execCmd, 0, 1) WITH NOWAIT;
				--IF (@debug = 0) 
				--	BEGIN
				--		EXEC (@execCmd);
				--END;
END;

--	Add CR/LF at the end of each statement and exeute the completed set of changes
--
SELECT @execCmd = REPLACE(
	(
		SELECT STUFF(
			(
				SELECT ';' + CreateCmd
					FROM @Cmds FOR XML PATH('')
			), 1, 1, '')
	), ';;', ';' + @CRLF);

RAISERROR(@execCmd, 0, 1) WITH NOWAIT;
IF (@debug = 0) 
	BEGIN
		EXEC (@execCmd);
END;

-- List out table/index details after change actions
--
SELECT OBJECT_SCHEMA_NAME(IDX.[object_id]), 
	   OBJECT_NAME(IDX.[object_id]), 
	   IDX.*
	FROM sys.indexes IDX
	WHERE (OBJECT_SCHEMA_NAME(IDX.[object_id]) = @tblSchema)
		  AND (OBJECT_NAME(IDX.[object_id]) = @tblName);
		 
--	Commit or rollback based on @debug setting
--
IF (@commit = 1) 
	BEGIN
		COMMIT TRANSACTION;
END;
	ELSE
	BEGIN
		ROLLBACK TRANSACTION;
END;

-- List out table/index details after the commit/rollback
--
SELECT OBJECT_SCHEMA_NAME(IDX.[object_id]), 
	   OBJECT_NAME(IDX.[object_id]), 
	   IDX.*
	FROM sys.indexes IDX
	WHERE (OBJECT_SCHEMA_NAME(IDX.[object_id]) = @tblSchema)
		  AND (OBJECT_NAME(IDX.[object_id]) = @tblName);