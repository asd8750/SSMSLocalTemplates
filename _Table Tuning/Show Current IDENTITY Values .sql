            SELECT	OBJ.[object_id],
                    OBJ.create_date AS ObjCreateDate,
                    OBJ.[type],
                    OBJECT_SCHEMA_NAME(OBJ.[object_id]) AS SchemaName,
                    OBJECT_NAME(OBJ.[object_id]) AS TableName,
                    IDX.[type] AS IndexType,
                    CONCAT('[', OBJECT_SCHEMA_NAME(OBJ.[object_id]), '].[', OBJECT_NAME(OBJ.[object_id]), ']') AS FullTableName,
                    (SELECT SUM(PT.[rows]) FROM sys.partitions PT WHERE (PT.[object_id] = OBJ.[object_id]) AND (PT.index_id = IDX.index_id)) AS [RowCount],
                    ISNULL((SELECT	IC.last_value
                                FROM sys.identity_columns IC
                                WHERE (IC.[object_id] = OBJ.[object_id])), 0) AS IdentityValue,
					(SELECT MAX(CAST(TC.is_identity AS TINYINT)) 
								FROM sys.columns TC
								WHERE (TC.[object_id] = OBJ.[object_id])) AS is_identity
                FROM sys.objects OBJ
                    LEFT OUTER JOIN sys.indexes IDX
                        ON (OBJ.[object_id] = IDX.[object_id])
                WHERE (OBJ.[type] IN ('U')) AND
                    (OBJ.is_ms_shipped = 0)
                    AND (IDX.[type] IN (0,1,5))