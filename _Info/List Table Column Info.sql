    WITH IDXC
      AS
      (
          SELECT *,
                 ROW_NUMBER() OVER ( PARTITION BY IDXC2.[object_id],
                                                  IDXC2.column_id
                                     ORDER BY IDXC2.IndexPriority
                                   ) AS ColPrio
             FROM
                 (
                     SELECT DISTINCT
                            TBL.[object_id],
                            TBL.[type] AS ObjType,
                            COALESCE(IDX.index_id, 0) AS IndexID,
							IDX.[type] AS IndexType,
                            COALESCE(IDX.is_unique, 0) AS is_unique,
							COUNT(IDC.column_id) OVER (PARTITION BY TBL.[object_id], IDX.[Type]) AS KeyCnt,
                            COL.column_id,
                            COALESCE(IDC.key_ordinal, 0) AS key_ordinal,
                            COALESCE(IDC.is_descending_key, 0) AS is_descending_key,
                            COALESCE(IDC.partition_ordinal, 0) AS partition_ordinal,
                            DENSE_RANK() OVER ( PARTITION BY TBL.[object_id]
                                                ORDER BY
                                                    COALESCE(IDX.is_unique, 0) DESC,
													COUNT(IDC.column_id) OVER (PARTITION BY TBL.[object_id], IDX.[Type]),
                                                    COALESCE(IDX.index_id, 0)
                                              ) AS IndexPriority
                        FROM(sys.objects TBL
                            INNER JOIN sys.columns COL
                               ON ( TBL.[object_id] = COL.[object_id] ))
                            LEFT OUTER JOIN(sys.indexes IDX
                            INNER JOIN sys.index_columns IDC
                               ON ( IDX.[object_id] = IDC.[object_id] )
                                  AND ( IDX.[index_id] = IDC.[index_id] ))
                              ON ( TBL.[object_id] = IDX.[object_id] )
                                 AND ( COL.column_id = IDC.column_id )
                        WHERE
                         ( TBL.[type] IN ( 'U', 'V' ))
					    ORDER BY TBL.object_id, IndexID, COL.column_id
					
                 ) IDXC2
		    --ORDER BY IDXC2.object_id, IDXC2.column_id, IDXC2.IndexPriority
      )
       SELECT TAB.[object_id],
              TAB.[schema_id],
              SCH.[name] AS SchemaName,
              TAB.[name] AS TableName,
              TAB.[type] AS ObjType,
              COALESCE(IDX.[type], 0) AS IndexType,
              IC.[name] AS ColName,
              IC.column_id,
              TYP.[name] AS DataType,
              IC.max_length,
              IC.[precision],
              IC.[scale],
              IC.is_xml_document,
              IC.is_nullable,
              IC.is_identity,
              IC.is_computed + (ISNULL(cc.is_persisted,0)*2) AS is_computed, -- 0-Not computed, 1-computed, 3-computed+persisted
			  CASE WHEN TYP.[name] IN ('timestamp', 'rowversion') THEN 0
				ELSE 1
			  END AS is_updateable,
              COALESCE(IDXC.key_ordinal, 0) AS key_ordinal,
              COALESCE(IDXC.is_descending_key, 0) AS is_descending_key,
              COALESCE(IDXC.partition_ordinal, 0) AS partition_ordinal,
			  CONCAT(TYP.[name],
					CASE
						WHEN (TYP.[name] LIKE '%char') OR (TYP.[name] LIKE '%binary') THEN CONCAT('(', CASE WHEN IC.max_length = -1 THEN 'MAX' ELSE CONVERT(VARCHAR, IC.max_length) END,')')
						WHEN (TYP.[name] LIKE 'datetime2') THEN CONCAT('(', CONVERT(VARCHAR, IC.scale) ,')')
						WHEN (TYP.[name] LIKE 'decimal') THEN CONCAT('(', CONVERT(VARCHAR, IC.[precision]), ',', CONVERT(VARCHAR, IC.scale) ,')')
						WHEN (TYP.[name] LIKE 'float') THEN CASE WHEN IC.[precision] <> 53 THEN CONCAT('(', CONVERT(VARCHAR, IC.[precision]) ,')') END
						WHEN (TYP.[name] LIKE 'time') THEN 
														CASE (IC.[precision] * 10 + IC.scale)
															WHEN 80 THEN '(0)'
															WHEN 101 THEN '(1)'
															WHEN 112 THEN '(2)'
															WHEN 123 THEN '(3)'
															WHEN 134 THEN '(4)'
															WHEN 145 THEN '(5)'
															WHEN 156 THEN '(6)'
															WHEN 167 THEN '(7)'
															ELSE CONCAT('(?? ', CONVERT(VARCHAR, IC.[precision]), ',', CONVERT(VARCHAR, IC.scale), ')')
														END
					END
			  ) AS FullDatatype,
			  CC.[definition] AS cc_definition,
			  DF.[name] AS df_name,
			  DF.[definition] AS df_definition
          FROM sys.objects TAB
              INNER JOIN sys.schemas SCH
                 ON ( TAB.[schema_id] = SCH.[schema_id] )
              INNER JOIN sys.columns IC
                 ON ( TAB.[object_id] = IC.[object_id] )
              INNER JOIN sys.types TYP
                 ON ( IC.user_type_id = TYP.user_type_id )
              LEFT OUTER JOIN sys.indexes IDX
                ON ( TAB.[object_id] = IDX.[object_id] )
              LEFT OUTER JOIN /* sys.index_columns */ IDXC
                ON ( TAB.[object_id] = IDXC.[object_id] )
                   -- AND ( IDX.index_id = IDXC.index_id )
                   AND ( IC.column_id = IDXC.column_id )
			  LEFT OUTER JOIN sys.computed_columns CC
				ON (IC.[object_id] = CC.[object_id]) AND (IC.column_id = CC.column_id) AND (IC.is_computed = 1)
			  LEFT OUTER JOIN sys.default_constraints DF
				ON (TAB.[object_id] = DF.[parent_object_id]) AND (IC.column_id = DF.[parent_column_id])
          WHERE
           ( TAB.is_ms_shipped = 0 )
           AND ( TAB.[type] IN ( 'U', 'V' ))
           AND ( ISNULL(IDX.[type], 0) IN ( 0, 1, 5 ))
           AND ( IDXC.ColPrio = 1 )

		   --AND IC.is_computed = 1

          ORDER BY
           --[TAB].[object_id],
		   --FullDatatype,
           SchemaName ,
           TableName ,
           IC.column_id;