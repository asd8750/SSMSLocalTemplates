DECLARE	@CRLF NCHAR(2) = CHAR(13) + CHAR(10);
DECLARE @TableName VARCHAR(256) = '[ProcessHistory].[ELThinfilmInspectionResults]';
DECLARE @ObjectID INT = OBJECT_ID(@TableName);

WITH COLS AS (
		SELECT	TOP (2000000)
				COL.column_id AS ColID,
				CONCAT( '       COUNT(', QUOTENAME(COL.[name],']'), ') AS [', COL.[name], '_NonNull],', @CRLF,
						'       MIN(LEN(', QUOTENAME(COL.[name],']') ,')) AS [', COL.[name] ,'_MinLen],', @CRLF,
						'       AVG(LEN(', QUOTENAME(COL.[name],']') ,')) AS [', COL.[name] ,'_AvgLen],', @CRLF,
						'       MAX(LEN(', QUOTENAME(COL.[name],']') ,')) AS [', COL.[name] ,'_MaxLen],', @CRLF
						) AS Txt
			FROM sys.columns COL
				INNER JOIN sys.types TYP
					ON (COL.user_type_id = TYP.user_type_id)
			WHERE (COL.[object_id] = @ObjectID)
				AND ((TYP.[name] = 'nvarchar') AND (col.max_length = -1))
			ORDER BY COL.column_id
			)

		SELECT	CONCAT('SELECT COUNT(*) AS TotRows,', @CRLF,
						(SELECT Txt FROM COLS ORDER BY ColID FOR XML PATH(''), TYPE).value('.', 'nvarchar(MAX)'),
						'''''', @CRLF,
						'  FROM ', @TableName, @CRLF)		
						;

