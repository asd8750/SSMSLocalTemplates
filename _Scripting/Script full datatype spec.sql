SELECT CASE
           WHEN TYP.[name] = 'datetime2' THEN
               TYP.[name] + '(' + CONVERT(VARCHAR(3), COL.scale) + ')'
           WHEN ( TYP.[name] LIKE 'var%' )
                OR ( TYP.[name] LIKE 'nvar%' ) THEN
               TYP.[name] + '(' + CASE
                                      WHEN COL.max_length = -1 THEN
                                          'MAX'
                                      ELSE
                                          CONVERT(VARCHAR(4), COL.max_length)
                                  END + ')'
           WHEN ( TYP.[name] IN ( 'char', 'nchar', 'binary', 'time' )) THEN
               TYP.[name] + '(' + CONVERT(VARCHAR(4), COL.max_length) + ')'
           WHEN ( TYP.[name] IN ( 'decimal', 'numeric' )) THEN
               TYP.[name] + '(' + CONVERT(VARCHAR(4), COL.[precision]) + ',' + CONVERT(VARCHAR(4), COL.[scale]) + ')'
           WHEN ( TYP.[name] IN ( 'float' )) THEN
               TYP.[name] + CASE WHEN COL.[precision] < 53 THEN '(' + CONVERT(VARCHAR(4), COL.[precision]) + ')' ELSE '' END
           WHEN ( TYP.[name] IN ( 'datetimeoffset' )) THEN
               TYP.[name] + '(' + CONVERT(VARCHAR(4), COL.[scale]) + ')'
           ELSE
               TYP.[name]
       END AS Datatype,
       COL.*
   FROM sys.columns COL
       INNER JOIN sys.types TYP
          ON ( COL.user_type_id = TYP.user_type_id )
   WHERE
    ( TYP.[name] NOT IN ( 'int', 'uniqueidentifier', 'bigint', 'tinyint', 'smallint', 'sysname' ));
--AND (TYP.[name] = 'datetimeoffset')
