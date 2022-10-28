	SELECT
      N'CREATE PARTITION FUNCTION ' 
    + QUOTENAME(pf.name)
    + N'(' + t.name  + N')'
    + N' AS RANGE ' 
    + CASE WHEN pf.boundary_value_on_right = 1 THEN N'RIGHT' ELSE N'LEFT' END
    + ' FOR VALUES('
    +
    (SELECT
        STUFF((SELECT
            N','
            + CASE
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') IN(N'char', N'varchar') 
                    THEN QUOTENAME(CAST(r.value AS nvarchar(4000)), '''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') IN(N'nchar', N'nvarchar') 
                    THEN N'N' + QUOTENAME(CAST(r.value AS nvarchar(4000)), '''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') = N'date' 
                    THEN QUOTENAME(FORMAT(CAST(r.value AS date), 'yyyy-MM-dd'),'''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') = N'datetime' 
                    THEN QUOTENAME(FORMAT(CAST(r.value AS datetime), 'yyyy-MM-ddTHH:mm:ss'),'''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') IN(N'datetime', N'smalldatetime') 
                    THEN QUOTENAME(FORMAT(CAST(r.value AS datetime), 'yyyy-MM-ddTHH:mm:ss.fff'),'''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') = N'datetime2' 
                    THEN QUOTENAME(FORMAT(CAST(r.value AS datetime2), 'yyyy-MM-ddTHH:mm:ss.fffffff'),'''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') = N'datetimeoffset' 
                    THEN QUOTENAME(FORMAT(CAST(r.value AS datetimeoffset), 'yyyy-MM-dd HH:mm:ss.fffffff K'),'''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') = N'time' 
                    THEN QUOTENAME(FORMAT(CAST(r.value AS time), 'hh\:mm\:ss\.fffffff'),'''') --'HH\:mm\:ss\.fffffff'
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') = N'uniqueidentifier' 
                    THEN QUOTENAME(CAST(r.value AS nvarchar(4000)), '''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') IN (N'binary', N'varbinary') 
                    THEN CONVERT(nvarchar(4000), r.value, 1)
                  ELSE CAST(r.value AS nvarchar(4000))
              END
    FROM sys.partition_range_values AS r
    WHERE pf.[function_id] = r.[function_id]
    FOR XML PATH(''), TYPE).value('.', 'nvarchar(MAX)'),1,1,N'')
    )
    + N');'
FROM sys.partition_functions pf
JOIN sys.partition_parameters AS pp ON
    pp.function_id = pf.function_id
JOIN sys.types AS t ON
    t.system_type_id = pp.system_type_id
    AND t.user_type_id = pp.user_type_id
WHERE pf.name = N'PF_Year';

SELECT
      N'CREATE PARTITION SCHEME ' + QUOTENAME(ps.name)
    + N' AS PARTTITION ' + QUOTENAME(pf.name)
    + N' TO ('
    +
    (SELECT
        STUFF((SELECT
            N',' + QUOTENAME(fg.name)
    FROM sys.data_spaces ds
    JOIN sys.destination_data_spaces AS dds ON dds.partition_scheme_id = ps.data_space_id
    JOIN sys.filegroups AS fg ON fg.data_space_id = dds.data_space_id
    WHERE ps.data_space_id = ds.data_space_id
    ORDER BY dds.destination_id
    FOR XML PATH(''), TYPE).value('.', 'nvarchar(MAX)'),1,1,N'')
    )
    + N');'
FROM sys.partition_schemes AS ps
JOIN sys.partition_functions AS pf ON pf.function_id = ps.function_id
WHERE ps.name = N'PSC_Year';																			 SELECT
      N'CREATE PARTITION FUNCTION ' 
    + QUOTENAME(pf.name)
    + N'(' + t.name  + N')'
    + N' AS RANGE ' 
    + CASE WHEN pf.boundary_value_on_right = 1 THEN N'RIGHT' ELSE N'LEFT' END
    + ' FOR VALUES('
    +
    (SELECT
        STUFF((SELECT
            N','
            + CASE
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') IN(N'char', N'varchar') 
                    THEN QUOTENAME(CAST(r.value AS nvarchar(4000)), '''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') IN(N'nchar', N'nvarchar') 
                    THEN N'N' + QUOTENAME(CAST(r.value AS nvarchar(4000)), '''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') = N'date' 
                    THEN QUOTENAME(FORMAT(CAST(r.value AS date), 'yyyy-MM-dd'),'''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') = N'datetime' 
                    THEN QUOTENAME(FORMAT(CAST(r.value AS datetime), 'yyyy-MM-ddTHH:mm:ss'),'''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') IN(N'datetime', N'smalldatetime') 
                    THEN QUOTENAME(FORMAT(CAST(r.value AS datetime), 'yyyy-MM-ddTHH:mm:ss.fff'),'''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') = N'datetime2' 
                    THEN QUOTENAME(FORMAT(CAST(r.value AS datetime2), 'yyyy-MM-ddTHH:mm:ss.fffffff'),'''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') = N'datetimeoffset' 
                    THEN QUOTENAME(FORMAT(CAST(r.value AS datetimeoffset), 'yyyy-MM-dd HH:mm:ss.fffffff K'),'''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') = N'time' 
                    THEN QUOTENAME(FORMAT(CAST(r.value AS time), 'hh\:mm\:ss\.fffffff'),'''') --'HH\:mm\:ss\.fffffff'
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') = N'uniqueidentifier' 
                    THEN QUOTENAME(CAST(r.value AS nvarchar(4000)), '''')
                  WHEN SQL_VARIANT_PROPERTY(r.value, 'BaseType') IN (N'binary', N'varbinary') 
                    THEN CONVERT(nvarchar(4000), r.value, 1)
                  ELSE CAST(r.value AS nvarchar(4000))
              END
    FROM sys.partition_range_values AS r
    WHERE pf.[function_id] = r.[function_id]
    FOR XML PATH(''), TYPE).value('.', 'nvarchar(MAX)'),1,1,N'')
    )
    + N');'
FROM sys.partition_functions pf
JOIN sys.partition_parameters AS pp ON
    pp.function_id = pf.function_id
JOIN sys.types AS t ON
    t.system_type_id = pp.system_type_id
    AND t.user_type_id = pp.user_type_id
WHERE pf.name = N'PF_Year';

SELECT
      N'CREATE PARTITION SCHEME ' + QUOTENAME(ps.name)
    + N' AS PARTTITION ' + QUOTENAME(pf.name)
    + N' TO ('
    +
    (SELECT
        STUFF((SELECT
            N',' + QUOTENAME(fg.name)
    FROM sys.data_spaces ds
    JOIN sys.destination_data_spaces AS dds ON dds.partition_scheme_id = ps.data_space_id
    JOIN sys.filegroups AS fg ON fg.data_space_id = dds.data_space_id
    WHERE ps.data_space_id = ds.data_space_id
    ORDER BY dds.destination_id
    FOR XML PATH(''), TYPE).value('.', 'nvarchar(MAX)'),1,1,N'')
    )
    + N');'
FROM sys.partition_schemes AS ps
JOIN sys.partition_functions AS pf ON pf.function_id = ps.function_id
WHERE ps.name = N'PSC_Year';