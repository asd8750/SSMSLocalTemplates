USE [master]
GO
/****** Object:  StoredProcedure [dbo].[sp_CreateBackfillTriggerSrc]    Script Date: 6/11/2018 11:11:47 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		F. LaForest
-- Create date: 2016-10-26
-- Description:	Create a trigger to mirror updates to the source table onto a destination table
--				that is being back filled.--USE [master]
--GO
/****** Object:  StoredProcedure [dbo].[sp_CreateBackfillTriggerSrc]    Script Date: 6/11/2018 11:11:47 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		F. LaForest
-- Create date: 2016-10-26
-- Description:	Create a trigger to mirror updates to the source table onto a destination table
--				that is being back filled.
--				IMPORTANT!  Install this in he same database as the source table OR install in
--				the 'master' database and issue the following command:
--				EXEC sp_MS_marksystemobject sp_CreateBackfillTriggerSrc
-- History:
-- 2016-10-27 -- F. LaForest -- Initial version
-- 2016-10-27 -- F. LaForest -- Add documentation comments to the source code
-- 2016-10-27 -- F. LaForest -- Debugging
-- 2016-11-08 -- F. LaForest -- Remove schema name from trigger name
-- 2016-11-08 -- F. LaForest -- Add non-key cols to CRUD CTE and simplify MERGE "ON" clause
-- 2018-04-27 -- F. LaForest -- Replace MERGE with DELETE then INSERT commands and add key override
-- 2018-06-11 -- F. LaForest -- Correct syntax errors in generated script
-- 2018-11-13 -- F. LaForest -- Add @deploy - non-zero will execute command
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[usp_CreateBackfillTriggerSrc]
(
    @srcTable VARCHAR(256),
    @destDatabase VARCHAR(256) = NULL,
    @destTable VARCHAR(256),
    @overrideKeys VARCHAR(1024) = NULL,
	@deploy INT = 0,
    @sqlOutputScript VARCHAR(MAX) OUTPUT
)
AS
BEGIN

	SET NOCOUNT ON;

    --	(Debugging) initial values
    --
    --DECLARE @srcTable VARCHAR(256);
    --DECLARE @destTable VARCHAR(256);

    --SET @srcTable = '[dbo].[PanelScribeDeadZone]';
    --SET @destTable = '[Temporary].[PanelScribeDeadZone]';


    --SET @overrideKeys = 'DataId';
    --SET @overrideKeys = ''; -- No key override

    --	Internal variables
    --
    DECLARE @errMsgs VARCHAR(4000);
    DECLARE @errCnt INT;

    DECLARE @srcObjID INT;
    DECLARE @destObjID INT;
    DECLARE @tableName VARCHAR(128);
    DECLARE @schemaName VARCHAR(128);
    DECLARE @srcDatabase VARCHAR(256);

    DECLARE @colCnt INT;
    DECLARE @identCnt INT;
    DECLARE @indexID INT;
    DECLARE @keyCnt INT;

    DECLARE @LF VARCHAR(2);

    --	Initial variable setup
    --
    SET @errCnt = 0; -- No errors yet
    SET @errMsgs = '';
    SET @LF = CHAR(13) + CHAR(10);

    SET @keyCnt = 0;

    SET @srcDatabase = DB_NAME(DB_ID());

    IF (@destDatabase = NULL)
        SET @destDatabase = @srcDatabase;

    --	Validate input tables exist
    --
    SET @srcObjID = OBJECT_ID(@srcTable, 'U');
    IF @srcObjID IS NULL
    BEGIN
        SET @errMsgs = CONCAT(@errMsgs, 'Unknown source table: "', @srcDatabase, '.', @srcTable, '"', CHAR(13));
        SET @errCnt = @errCnt + 1;
    END;

    SET @destObjID = OBJECT_ID(CONCAT(@destDatabase, '.', @destTable), 'U');
    IF @destObjID IS NULL
    BEGIN
        SET @errMsgs
            = @errMsgs + 'Unknown destination table: "' + CONCAT(@destDatabase, '.', @destTable) + '"' + CHAR(13);
        SET @errCnt = @errCnt + 1;
    END;

 --   SELECT  @srcTable,
 --           @srcObjID;
 --   SELECT  @destTable,
 --           @destObjID;

	--SELECT * FROM INFORMATION_SCHEMA.COLUMNS;

	SET @destTable = CONCAT('[', @destDatabase, '].', @destTable);

	--SELECT @srcDatabase, @srcTable, @destDatabase, @destTable;

    --	Table name information
    --
    SELECT @schemaName = SCH.name,
           @tableName = TAB.name
    FROM sys.tables TAB
        INNER JOIN sys.schemas SCH
            ON (TAB.[schema_id] = SCH.[schema_id])
    WHERE (TAB.[object_id] = @srcObjID);

    --	Determine if the source table has an IDENTITY column
    --
    SELECT @colCnt = COUNT(*),
           @identCnt = SUM(   CASE
                                  WHEN COL.is_identity = 1 THEN
                                      1
                                  ELSE
                                      0
                              END
                          )
    FROM sys.columns COL
    WHERE (COL.[object_id] = @destObjID);

    --	Check for key column override
    --
    DECLARE @kCols TABLE
    (
        [name] VARCHAR(128) NOT NULL,
        [ordinal] INT NOT NULL
    );

    IF @overrideKeys IS NOT NULL
    BEGIN
        DECLARE @ovrKeys VARCHAR(512);
        SET @ovrKeys = @overrideKeys;
        SET @keyCnt = 1;
        WHILE CHARINDEX(',', @ovrKeys) > 0
        BEGIN
            INSERT INTO @kCols
            (
                [name],
                [ordinal]
            )
            VALUES
            (LEFT(@ovrKeys, CHARINDEX(',', @ovrKeys) - 1), @keyCnt);
            SET @ovrKeys = RIGHT(@ovrKeys, LEN(@ovrKeys) - CHARINDEX(',', @ovrKeys));
            SET @keyCnt = @keyCnt + 1;
        END;
        INSERT INTO @kCols
        (
            [name],
            [ordinal]
        )
        VALUES
        (@ovrKeys, @keyCnt);
        SET @indexID = 0;
    END;

    --	Determine a unique index for this match
    --
    IF (@indexID IS NULL)
    BEGIN;
        WITH IDXS
        AS (SELECT TOP 1
                   COALESCE(IDX.index_id, 0) AS IndexID,
                   COUNT(COL.column_id) AS KeyCnt
            FROM sys.indexes IDX
                INNER JOIN sys.index_columns IDXC
                    ON (IDX.[object_id] = IDXC.[object_id])
                       AND (IDX.[index_id] = IDXC.[index_id])
                INNER JOIN sys.columns COL
                    ON (IDX.[object_id] = COL.[object_id])
                       AND (IDXC.column_id = COL.column_id)
            WHERE (IDX.[object_id] = @srcObjID)
                  AND (IDXC.key_ordinal > 0)
                  AND (IDX.is_unique > 0)
            GROUP BY IDX.name,
                     IDX.index_id
            HAVING (COUNT(   CASE
                                 WHEN COL.is_nullable <> 0 THEN
                                     1
                                 ELSE
                                     NULL
                             END
                         ) = 0
                   )
            ORDER BY IDX.index_id)
        SELECT @indexID = COALESCE(IndexID, 0),
               @keyCnt = KeyCnt
        FROM IDXS;
    END;

    -- Override the default index choice
    --
    --PRINT '-- OVERRIDE!! -- The default index choice has been overriden';
    --SET @indexID = 0;
    --SET @keyCnt = 1;

    IF (@indexID IS NULL)
    BEGIN
        SET @errMsgs = @errMsgs + 'No unique index found. "' + CHAR(13);
        SET @errCnt = @errCnt + 1;
    END;

    --SELECT  'Index ID' ,
    --        @indexID ,
    --        'Key Cnt' ,
    --        @keyCnt;

    --	Get source table column information into the @cols table variable
    --
    DECLARE @cols TABLE
    (
        ColName VARCHAR(128) NOT NULL,
        ColID INT NOT NULL,
        isNullable BIT NOT NULL,
        MaxLen INT NOT NULL,
        KeyOrdinal INT NOT NULL,
        isCopyable BIT NOT NULL,
        Compare VARCHAR(512) NOT NULL,
        Datatype VARCHAR(128) NOT NULL
    );

    INSERT INTO @cols
    (
        ColName,
        ColID,
        isNullable,
        MaxLen,
        KeyOrdinal,
        isCopyable,
        Compare,
        Datatype
    )
    SELECT COL.[name] AS ColName,
           COL.column_id AS ColID,
           COL.is_nullable AS isNullable,
           COL.max_length AS MaxLen,
           CASE
               WHEN (@indexID = 0) THEN
                   COALESCE((SELECT TOP 1 [ordinal] FROM @kCols WHERE [name] = COL.[name]), 0)
               ELSE
                   COALESCE(IDXC.key_ordinal, 0)
           END AS KeyOrdinal,
           CASE
               WHEN TYP.name IN ( 'timestamp' ) THEN
                   0
               ELSE
                   1
           END AS isCopyable,
           CASE
               WHEN TYP.name IN ( 'ntext', 'xml' ) THEN
                   'CONVERT(NVARCHAR(MAX), SRC.[' + COL.name + '])'
               WHEN TYP.name IN ( 'text' ) THEN
                   'CONVERT(VARCHAR(MAX), SRC.[' + COL.name + '])'
               ELSE
                   'SRC.[' + COL.name + ']'
           END AS Compare,
           TYP.name AS Datatype
    -- ,TYP.*
    -- ,IDX.*, IDXC.*, COL.*
    FROM sys.columns COL
        INNER JOIN sys.types TYP
            ON (COL.user_type_id = TYP.user_type_id)
        LEFT OUTER JOIN(
			sys.indexes IDX
				INNER JOIN sys.index_columns IDXC
					ON (IDX.[object_id] = IDXC.[object_id])
					AND (IDX.[index_id] = IDXC.[index_id])
					)
				ON (IDX.[object_id] = COL.[object_id])
				   AND (IDXC.column_id = COL.column_id)
				   AND
				   (
					   (IDX.[index_id] = @indexID)
					   OR (@indexID < 0)
				   )
    WHERE (COL.[object_id] = @srcObjID)
    ORDER BY COL.column_id;

    --SELECT  *
    --FROM    @cols;

	--DECLARE @k2 INT;
	--SET @k2 = (SELECT COUNT(*) FROM @cols);
	--RAISERROR('Object: %i  Cols: %i', 0, 1, @srcObjID, @k2) WITH NOWAIT;


    --	Output any error messages
    --
    IF @errCnt > 0
    BEGIN
        --SELECT @errCnt,
        --       @errMsgs;
        RAISERROR(@errMsgs, 0, 1) WITH NOWAIT;
    END;

    --	Build the matching expression template
    --
    DECLARE @cmpExpr VARCHAR(4000);
    SELECT @cmpExpr = STUFF(
    (
        SELECT ' AND (<<LTAB>>.[' + COL.ColName + '] = <<RTAB>>.[' + COL.ColName + '])'
        FROM @cols COL
        WHERE (COL.KeyOrdinal > 0)
        ORDER BY COL.KeyOrdinal
        FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'),
    1   ,
    5   ,
    ''
                           );

    --	Build the Keyname list
    --
    DECLARE @keyNames VARCHAR(4000);
    SELECT @keyNames = STUFF(
    (
        SELECT ', [' + COL.ColName + ']'
        FROM @cols COL
        WHERE (COL.KeyOrdinal > 0)
        ORDER BY COL.KeyOrdinal
        FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'),
    1   ,
    2   ,
    ''
                            );
    --PRINT @keyNames;

    --	Build the matching expression template
    --
    DECLARE @coalescedKeyList VARCHAR(4000);
    SELECT @coalescedKeyList = STUFF(
    (
        SELECT ',|COALESCE(INS.[' + COL.ColName + '], DEL.[' + COL.ColName + ']) AS [' + COL.ColName + ']'
        FROM @cols COL
        WHERE (COL.KeyOrdinal > 0)
        ORDER BY COL.KeyOrdinal
        FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'),
    1   ,
    2   ,
    ''
                                    );
    --SET @coalescedKeyList = LEFT(@coalescedKeyList, LEN(@coalescedKeyList)-2);
    --PRINT @coalescedKeyList;

    --	Build the insert column list
    --
    DECLARE @insertCols VARCHAR(4000);
    SELECT @insertCols = STUFF(
    (
        SELECT ',|<<TAB>>[' + COL.ColName + ']'
        FROM @cols COL
        WHERE (COL.isCopyable > 0)
        ORDER BY COL.ColID
        FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'),
    1   ,
    2   ,
    ''
                              );

    --	Build the update column list
    --
    DECLARE @updateCols VARCHAR(4000);
    SELECT @updateCols = STUFF(
    (
        SELECT ',|[' + COL.ColName + '] = SRC.[' + COL.ColName + ']'
        FROM @cols COL
        WHERE (COL.isCopyable > 0)
              AND (COL.KeyOrdinal = 0)
        ORDER BY COL.ColID
        FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'),
    1   ,
    2   ,
    ''
                              );

    --	Build the trigger MATCH command
    --
    DECLARE @firstKey VARCHAR(128);
    SELECT @firstKey = ColName
    FROM @cols
    WHERE (KeyOrdinal = 1);

    DECLARE @cmdMerge VARCHAR(MAX);

    --	Build the trigger header
    --
    SET @cmdMerge
        = CONCAT(
                    '' + --
                    '-- ============================================= ' + @LF + --
                    '-- Created: ' + CONVERT(VARCHAR(40), GETDATE(), 126) + @LF + --
                    '-- Author: Fred LaForest - (Create_Backfill_Trigger.sql)' + @LF + --
                    '-- ============================================= ' + @LF + --
                    'CREATE TRIGGER [',
                    @schemaName,
                    '].[utrg_BackFill_',
                    @schemaName,
                    '_',
                    @tableName,
                    '] ' + @LF + 'ON ',
                    @srcTable,
                    @LF + --
                    'INSTEAD OF INSERT, UPDATE, DELETE '
                    + @LF + --
                    'AS '
                    + @LF + --
                    'BEGIN '
                    + @LF + -- 
                    '	SET NOCOUNT ON; '
                    + @LF
                );
    --
    --	Enable IDENTITY INSERT if this table has identity columns
    --
    IF (@identCnt > 0)
    BEGIN
        SET @cmdMerge = @cmdMerge + '	SET IDENTITY_INSERT ' + @destTable + ' ON; ' + @LF;
    END;

    --	Build the main MERGE command
    --	1) The CTE table name 'CRUD' looks at the "inserted" and "deleted" tables to detect the operation performed on 
    --		each modified row and fills the "__CMD__" column with the operation needed for each row.
    --	2) The CRUD table also supplies the key columns that uniquely identify each modified data row.
    --		-- A row whose keys have been modified will show as a DELETE/INSERT pair of rows in the CRUD table
    --		-- Rows whose keys appear in both "inserted" and "deleted" tables will trigger UPDATE command in the MERGE 
    --		-- Rows only in the "deleted" table will trigger the DELETE command in the MERGE
    --		-- Rows only in the "inserted" table will trigger the INSERT command in the MERGE
    --	3) For backfilling where the destination table differs from the source table.
    --		-- An UPDATE to a non-existent destination row forces an INSERT
    --		-- A DELETE to a non-existant destination row will be ignored
    --		-- An INSERT to a row present in the destination table will force an DELETE then INSERT instead
    --	4) "CRUD" is an acronym for [C]reate, [R]ead, [U]pdate, [D]elete
    --
    SET @cmdMerge = @cmdMerge + --
    '	SELECT	-- TOP (2000000000) ' + @LF + --
    '				CASE ' + @LF + '					WHEN INS.[' + @firstKey + '] IS NULL THEN ''DEL'' ' + @LF + --
    '					WHEN DEL.[' + @firstKey + '] IS NULL THEN ''INS'' ' + @LF + --
    '					ELSE ''UPD'' ' + @LF + --
    '				END AS [__CMD__], ' + @LF + --
    '				' + REPLACE(@coalescedKeyList, '|', @LF + '				') + @LF + --
	'			INTO #CRUD ' + @LF + --
    '			FROM [inserted] INS ' + @LF + --
    '				FULL OUTER JOIN [deleted] DEL ' + @LF + --
    '					ON ( ' + REPLACE(REPLACE(@cmpExpr, '<<LTAB>>', 'INS'), '<<RTAB>>', 'DEL') + ' ); ' + @LF + --
    '			--ORDER BY ' + @keyNames + ';' + @LF + --
	'	CREATE NONCLUSTERED INDEX [#CRUD_Key] ON #CRUD (' + @keyNames + '); ' + @LF + -- 
    @LF            + --
    '	DELETE FROM DST ' + @LF + --
	'		FROM ' + @destTable + ' AS DST ' + @LF + --
	'			INNER JOIN #CRUD UDI ' + @LF + --
	'				ON ( ' + REPLACE(REPLACE(@cmpExpr, '<<LTAB>>', 'UDI'), '<<RTAB>>', 'DST') + ' ) ' + @LF + --
	'		WHERE (UDI.[__CMD__] IN (''DEL'',''UPD''));' + @LF + --
    @LF            + --
    '	INSERT INTO ' + @destTable + @LF + --
	'			(' + REPLACE(REPLACE(@insertCols, '<<TAB>>', ''), '|', @LF + '			') + ') ' + @LF + --
	'		SELECT ' + @LF + --
	'			' + REPLACE(REPLACE(@insertCols, '<<TAB>>', 'SRC.'), '|', @LF + '			') + @LF + --
	'		FROM [inserted] AS SRC ' + @LF + --
	'			INNER JOIN #CRUD UDI ' + @LF + --
	'				ON ( ' + REPLACE(REPLACE(@cmpExpr, '<<LTAB>>', 'UDI'), '<<RTAB>>', 'SRC') + ' ) ' + @LF + --
	'		WHERE (UDI.[__CMD__] IN (''INS'',''UPD''));' + @LF + --
   -- '		VALUES (' + REPLACE(REPLACE(@insertCols, '<<TAB>>', 'SRC.'), '|', @LF + '				') + '); ' + @LF + --
    @LF            + --
	'	DROP TABLE [#CRUD];' + @LF + @LF;


    --	Turn off IDENTITY INSERT is we turned it on
    --
    IF (@identCnt > 0)
    BEGIN
        SET @cmdMerge = @cmdMerge + '	SET IDENTITY_INSERT ' + @destTable + ' OFF; ' + @LF;
    END;

    SET @cmdMerge = @cmdMerge + 'END; ';
    --
    RAISERROR(@cmdMerge, 0, 1) WITH NOWAIT;
    SET @sqlOutputScript = @cmdMerge; -- Return the completed script to the caller

	if (@deploy <> 0)
		EXECUTE (@cmdMerge);

END;
