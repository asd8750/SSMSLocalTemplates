
USE [Performance_Global02]
GO
/****** Object:  UserDefinedFunction [dbo].[ufn_CreateBackfillTriggerSrc]    Script Date: 11/8/2016 1:44:52 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		F. LaForest
-- Create date: 2016-10-26
-- Description:	Create a trigger to mirror updates to the source table onto a destination table
--				that is being back filled.
-- History:
-- 2016-10-27 -- F. LaForest -- Initial version
-- 2016-10-27 -- F. LaForest -- Add documentation comments to the source code
-- 2016-10-27 -- F. LaForest -- Debugging
-- 2016-11-08 -- F. LaForest -- Remove schema name from trigger name
-- 2016-11-08 -- F. LaForest -- Add non-key cols to CRUD CTE and simplify MERGE "ON" clause
-- =============================================
ALTER FUNCTION [dbo].[ufn_CreateBackfillTriggerSrc]
    (
      @srcTable VARCHAR(256) ,
      @destTable VARCHAR(256)
    )
RETURNS VARCHAR(4000)
AS
    BEGIN

--	(Debugging) initial values
--
--DECLARE @srcTable VARCHAR(256);
--DECLARE @destTable VARCHAR(256);

--SET @srcTable = '[dbo].[PanelScribeDeadZone]';
--SET @destTable = '[Temporary].[PanelScribeDeadZone]';

--	Internal variables
--
        DECLARE @errMsgs VARCHAR(4000);
        DECLARE @errCnt INT;

        DECLARE @srcObjID INT;
        DECLARE @destObjID INT;
        DECLARE @srcTableName VARCHAR(128);
        DECLARE @srcSchemaName VARCHAR(128);
        DECLARE @destTableName VARCHAR(128);
        DECLARE @destSchemaName VARCHAR(128);

        DECLARE @colCnt INT;
        DECLARE @identCnt INT;
        DECLARE @indexID INT;
        DECLARE @keyCnt INT;

--	Initial variable setup
--
        SET @errCnt = 0;
	-- No errors yet
        SET @errMsgs = '';

--	Validate input tables exist
--
        SET @srcObjID = OBJECT_ID(@srcTable, 'U');
        IF @srcObjID IS NULL
            BEGIN
                SET @errMsgs = @errMsgs + 'Unknown source table: "' + @srcTable + '"' + CHAR(13);
                SET @errCnt = @errCnt + 1;
            END;

        SET @destObjID = OBJECT_ID(@destTable, 'U');
        IF @destObjID IS NULL
            BEGIN
                SET @errMsgs = @errMsgs + 'Unknown destination table: "' + @destTable + '"' + CHAR(13);
                SET @errCnt = @errCnt + 1;
            END;

--SELECT  @srcTable ,
--        @srcObjID;
--SELECT  @destTable ,
--        @destObjID;

--	Source Table name information
--
        SELECT  @srcSchemaName = SCH.name ,
                @srcTableName = TAB.name
        FROM    sys.tables TAB
                INNER JOIN sys.schemas SCH ON ( TAB.[schema_id] = SCH.[schema_id] )
        WHERE   ( TAB.[object_id] = @srcObjID )
		
--	Destination Table name information
--
        SELECT  @destSchemaName = SCH.name ,
                @destTableName = TAB.name
        FROM    sys.tables TAB
                INNER JOIN sys.schemas SCH ON ( TAB.[schema_id] = SCH.[schema_id] )
        WHERE   ( TAB.[object_id] = @destObjID )

--	Get information on the source table
--
        SELECT  @colCnt = COUNT(*) ,
                @identCnt = SUM(CASE WHEN COL.is_identity = 1 THEN 1
                                     ELSE 0
                                END)
        FROM    sys.columns COL
        WHERE   ( COL.[object_id] = @srcObjID )

--SELECT  'ColCnt' ,
--        @colCnt ,
--        'IdentCnt' ,
--        @identCnt;

--	Determine a unique index for this match
--
;
        WITH    IDXS
                  AS ( SELECT TOP 1
                                COALESCE(IDX.index_id, 0) AS IndexID ,
                                COUNT(COL.Column_id) AS KeyCnt
                       FROM     sys.indexes IDX
                                INNER JOIN sys.index_columns IDXC ON ( IDX.[object_id] = IDXC.[object_id] )
                                                                     AND ( IDX.[index_id] = IDXC.[index_id] )
                                INNER JOIN sys.columns COL ON ( IDX.[object_id] = COL.[object_id] )
                                                              AND ( IDXC.column_id = COL.column_id )
                       WHERE    ( IDX.[object_id] = @srcObjID )
                                AND ( IDXC.key_ordinal > 0 )
                                AND ( IDX.is_unique > 0 )
                       GROUP BY IDX.name ,
                                IDX.index_id
                       HAVING   ( COUNT(CASE WHEN COL.is_nullable <> 0 THEN 1
                                             ELSE NULL
                                        END) = 0 )
                       ORDER BY IDX.index_id
                     )
            SELECT  @indexID = COALESCE(IndexID, 0) ,
                    @keyCnt = KeyCnt
            FROM    IDXS;

        IF ( @indexID IS NULL )
            BEGIN
                SET @errMsgs = @errMsgs + 'No unique index found. "' + CHAR(13);
                SET @errCnt = @errCnt + 1;
            END;

--SELECT  'Index ID' ,
--        @indexID ,
--        'Key Cnt' ,
--        @keyCnt;

--	Get information on the source table columns
--
        DECLARE @cols TABLE
            (
              ColName VARCHAR(128) ,
              ColID INT ,
              isNullable BIT ,
              MaxLen INT ,
              KeyOrdinal INT ,
              isCopyable BIT ,
              Compare VARCHAR(512) ,
              Datatype VARCHAR(128)
            );

        INSERT  INTO @cols
                ( ColName ,
                  ColID ,
                  isNullable ,
                  MaxLen ,
                  KeyOrdinal ,
                  isCopyable ,
                  Compare ,
                  Datatype
                )
                SELECT  COL.name AS ColName ,
                        COL.column_id AS ColID ,
                        COL.is_nullable AS isNullable ,
                        COL.max_length AS MaxLen ,
                        COALESCE(IDXC.key_ordinal, 0) AS KeyOrdinal ,
                        CASE WHEN TYP.name IN ( 'timestamp' ) THEN 0
                             ELSE 1
                        END AS isCopyable ,
                        CASE WHEN TYP.name IN ( 'ntext', 'xml' ) THEN 'CONVERT(NVARCHAR(MAX), SRC.[' + COL.name + '])'
                             WHEN TYP.name IN ( 'text' ) THEN 'CONVERT(VARCHAR(MAX), SRC.[' + COL.name + '])'
                             ELSE 'SRC.[' + COL.name + ']'
                        END AS Compare ,
                        TYP.name AS Datatype
        -- ,TYP.*
		-- ,IDX.*, IDXC.*, COL.*
                FROM    sys.columns COL
                        INNER JOIN sys.types TYP ON ( COL.user_type_id = TYP.user_type_id )
                        LEFT OUTER JOIN ( sys.indexes IDX
                                          INNER JOIN sys.index_columns IDXC ON ( IDX.[object_id] = IDXC.[object_id] )
                                                                               AND ( IDX.[index_id] = IDXC.[index_id] )
                                        ) ON ( IDX.[object_id] = COL.[object_id] )
                                             AND ( IDXC.column_id = COL.column_id )
                                             AND ( IDX.[index_id] = @indexID )
                WHERE   ( COL.[object_id] = @srcObjID )
                ORDER BY COL.column_id;

--SELECT  *
--FROM    @cols;

--	Build the matching expression template
--
        DECLARE @cmpExpr VARCHAR(4000);
        SELECT  @cmpExpr = STUFF((SELECT    ' AND (<<LTAB>>.[' + COL.ColName + '] = <<RTAB>>.[' + COL.ColName + '])'
                                  FROM      @cols COL
                                  WHERE     ( COL.KeyOrdinal > 0 )
                                  ORDER BY  COL.KeyOrdinal
                FOR              XML PATH('') ,
                                     TYPE
	).value('.', 'nvarchar(max)'), 1, 5, '')

--	Build the CRUD key column list
--
        DECLARE @keyList VARCHAR(4000);
        SELECT  @KeyList = STUFF((SELECT    ', COALESCE(INS.[' + COL.ColName + '], DEL.[' + COL.ColName + ']) AS [' + COL.ColName + '] |'
                                  FROM      @cols COL
                                  WHERE     ( COL.KeyOrdinal > 0 )
                                  ORDER BY  COL.KeyOrdinal
                FOR              XML PATH('') ,
                                     TYPE
	).value('.', 'nvarchar(max)'), 1, 0, '')

--	Build the CRUD non-key column list
--
        DECLARE @nonKeyCols VARCHAR(4000);
        SELECT  @nonKeyCols = STUFF((SELECT ', INS.[' + COL.ColName + '] |'
                                     FROM   @cols COL
                                     WHERE  ( COL.isCopyable > 0 )
                                            AND ( COL.KeyOrdinal = 0 )
                                     ORDER BY COL.ColID
                FOR                 XML PATH('') ,
                                        TYPE
	).value('.', 'nvarchar(max)'), 1, 0, '')


--	Build the insert column list
--
        DECLARE @insertCols VARCHAR(4000);
        SELECT  @insertCols = STUFF((SELECT ', <<TAB>>[' + COL.ColName + '] |'
                                     FROM   @cols COL
                                     WHERE  ( COL.isCopyable > 0 )
                                     ORDER BY COL.ColID
                FOR                 XML PATH('') ,
                                        TYPE
	).value('.', 'nvarchar(max)'), 1, 2, '')

--	Build the update column list
--
        DECLARE @updateCols VARCHAR(4000);
        SELECT  @updateCols = STUFF((SELECT ', [' + COL.ColName + '] = SRC.[' + COL.ColName + '] |'
                                     FROM   @cols COL
                                     WHERE  ( COL.isCopyable > 0 )
                                            AND ( COL.KeyOrdinal = 0 )
                                     ORDER BY COL.ColID
                FOR                 XML PATH('') ,
                                        TYPE
	).value('.', 'nvarchar(max)'), 1, 2, '')

--	Build the trigger MATCH command
--
        DECLARE @firstKey VARCHAR(128);
        SELECT  @firstKey = ColName
        FROM    @cols
        WHERE   ( KeyOrdinal = 1 );

        DECLARE @cmdMerge VARCHAR(4000);
        SET @cmdMerge = '' + --
            '-- ============================================= ' + CHAR(13) + --
            '-- Source Database: ' + QUOTENAME(DB_NAME(), ']') + CHAR(13) + --
            '-- Source Table: ' + QUOTENAME(@srcSchemaName, '[') + '.' + QUOTENAME(@srcTableName, '[') + CHAR(13) + --
            '-- Destination Table: ' + QUOTENAME(@destSchemaName, '[') + '.' + QUOTENAME(@destTableName, '[') + CHAR(13) + --
            '-- Date Created: ' + CONVERT(VARCHAR(30), GETDATE(), 120) + CHAR(13) + --
            '-- Created By: : ' + SYSTEM_USER + CHAR(13) + --
            '--  ' + CHAR(13) + --
            'CREATE TRIGGER [utrg_' + @srcSchemaName + '_' + @srcTableName + '_Backfill] ON ' + @srcTable + CHAR(13) + --
            '    AFTER INSERT, UPDATE, DELETE ' + CHAR(13) + --
            'AS ' + CHAR(13) + --
            '    BEGIN ' + CHAR(13) + -- 
            '        SET NOCOUNT ON; ' + CHAR(13);
 --

--	Enable IDENTITY INSERT if this table has identity columns
--
        IF ( @identCnt > 0 )
            BEGIN
                SET @cmdMerge = '		SET IDENTITY_INSERT ' + @destTable + ' ON; ' + CHAR(13);
            END

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
--		-- An INSERT to a row present in the destination table will force an UPDATE instead
--	4) "CRUD" is an acronym for [C]reate, [R]ead, [U]pdate, [D]elete
--
        SET @cmdMerge = @cmdMerge + --
            ';WITH CRUD AS ( ' + CHAR(13) + --
            '	SELECT	CASE WHEN INS.[' + @firstKey + '] IS NULL THEN ''DEL'' ' + CHAR(13) + --
            '				WHEN DEL.[' + @firstKey + '] IS NULL THEN ''INS'' ' + CHAR(13) + --
            '				ELSE ''UPD'' ' + CHAR(13) + --
            '				END AS [__CMD__] ' + CHAR(13) + --
            '			' + REPLACE(@keyList, '|', CHAR(13) + '			') + CHAR(13) + --
            '			' + REPLACE(@nonKeyCols, '|', CHAR(13) + '			') + CHAR(13) + --
            '	FROM [inserted] INS ' + CHAR(13) + --
            '		FULL OUTER JOIN [deleted] DEL ' + CHAR(13) + --
            '			ON ( ' + REPLACE(REPLACE(@cmpExpr, '<<LTAB>>', 'INS'), '<<RTAB>>', 'DEL') + ' ) ' + CHAR(13) + --
            '		) ' + CHAR(13) + --
            'MERGE INTO ' + @destTable + ' AS DST ' + CHAR(13) + --
            '	USING CRUD AS SRC ' + CHAR(13) + --
           -- '		LEFT OUTER JOIN [inserted] AS SRC ' + CHAR(13) + --
           -- '			ON ( ' + REPLACE(REPLACE(@cmpExpr, '<<LTAB>>', 'CRUD'), '<<RTAB>>', 'SRC') + ' ) ' + CHAR(13) + --
            '	ON ( ' + REPLACE(REPLACE(@cmpExpr, '<<LTAB>>', 'SRC'), '<<RTAB>>', 'DST') + ' ) ' + CHAR(13) + --
            '	WHEN MATCHED AND ( SRC.[__CMD__] = ''DEL'' ) THEN ' + CHAR(13) + --
            '		DELETE ' + CHAR(13) + --
            '	WHEN MATCHED THEN ' + CHAR(13) + --
            '		UPDATE SET ' + CHAR(13) + --
            '				' + REPLACE(@updateCols, '|', CHAR(13) + '				') + CHAR(13) + --
            '	WHEN NOT MATCHED BY TARGET THEN  ' + CHAR(13) + --
            '		INSERT (' + REPLACE(REPLACE(@insertCols, '<<TAB>>', ''), '|', CHAR(13) + '				') + ') ' + CHAR(13) + --
            '		VALUES (' + REPLACE(REPLACE(@insertCols, '<<TAB>>', 'SRC.'), '|', CHAR(13) + '				') + ') ' + CHAR(13) + --
            ';' + CHAR(13)

--	Turn off IDENTITY INSERT is we turned it on
--
        IF ( @identCnt > 0 )
            BEGIN
                SET @cmdMerge = @cmdMerge + '		SET IDENTITY_INSERT ' + @destTable + ' OFF; ' + CHAR(13);
            END;

        SET @cmdMerge = @cmdMerge + '	END; ';
 --
--	Prepare the output
--
        IF ( @errCnt > 0 )
            BEGIN 
                SET @cmdMerge = @errMsgs;
            END;

		--PRINT @cmdMerge;

       RETURN (@cmdMerge); 

    END
