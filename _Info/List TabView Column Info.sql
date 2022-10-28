--
--	List out Table / View column information
--
--	History:
--		2020-07-01 - F. LaForest - Initial version
--
DECLARE @FullObjectName  VARCHAR(256) = '[Vision].[Defect_CSI]';

WITH TBL AS (
		SELECT	TOP (2000000)
				OBJECT_SCHEMA_NAME(OBJ.[object_id]) AS SchemaName,
				OBJ.[name] AS ObjectName,
				OBJ.[type] AS ObjectType,
				OBJ.[object_id]
			FROM sys.objects OBJ
			WHERE (OBJECT_ID(@FullObjectName) = OBJ.[object_id])
				AND (OBJ.is_ms_shipped = 0)
				AND (OBJ.[type] IN ('U', 'V'))
		)

	, COLS_TV AS (
		SELECT	TBL.SchemaName,
				TBL.ObjectName,
				TBL.ObjectType,
				TBL.[object_id],
				COL.[name] AS ColumnName,
				COL.[column_id],
				COL.user_type_id,
				COL.collation_name,
				COL.max_length,
				COL.[precision],
				COL.[scale],
				COL.[is_identity],
				COL.[is_computed],
				ISNULL(CC.[is_persisted], 0) AS [is_persisted],
				COL.[is_nullable],
				COL.default_object_id,
				TYP.[name] AS Datatype,
				CC.[definition] AS Computed_Def
			FROM TBL
				INNER JOIN sys.columns COL
					ON (TBL.[object_id] = COL.[object_id])
				INNER JOIN sys.types TYP
					ON (COL.user_type_id = TYP.user_type_id)
				LEFT OUTER JOIN sys.computed_columns CC
					ON ((COL.[object_id] = CC.[object_id])
					 AND (COL.[column_id] = CC.[column_id]))
		)

	SELECT	CTV.*,
			CASE
				   WHEN CTV.Datatype = 'datetime2' THEN
					   CTV.Datatype + '(' + CONVERT(VARCHAR(3), CTV.scale) + ')'
				   WHEN ( CTV.Datatype LIKE 'var%' )
						OR ( CTV.Datatype LIKE 'nvar%' ) THEN
					   CTV.Datatype + '(' + CASE
											  WHEN CTV.max_length = -1 THEN
												  'MAX'
											  ELSE
												  CONVERT(VARCHAR(4), CTV.max_length)
										  END + ')'
				   WHEN ( CTV.Datatype IN ( 'char', 'nchar', 'binary', 'time' )) THEN
					   CTV.Datatype + '(' + CONVERT(VARCHAR(4), CTV.max_length) + ')'
				   WHEN ( CTV.Datatype IN ( 'decimal', 'numeric' )) THEN
					   CTV.Datatype + '(' + CONVERT(VARCHAR(4), CTV.[precision]) + ',' + CONVERT(VARCHAR(4), CTV.[scale]) + ')'
				   WHEN ( CTV.Datatype IN ( 'float' )) THEN
					   CTV.Datatype + CASE WHEN CTV.[precision] < 53 THEN '(' + CONVERT(VARCHAR(4), CTV.[precision]) + ')' ELSE '' END
				   WHEN ( CTV.Datatype IN ( 'datetimeoffset' )) THEN
					   CTV.Datatype + '(' + CONVERT(VARCHAR(4), CTV.[scale]) + ')'
				   ELSE
					   CTV.Datatype
			   END AS FullDatatype,
			DEF.[definition] AS Default_Def
		FROM COLS_TV CTV
			LEFT OUTER JOIN sys.default_constraints DEF
				ON (CTV.default_object_id = DEF.[object_id])

	ORDER BY [object_id], CTV.[column_id]
