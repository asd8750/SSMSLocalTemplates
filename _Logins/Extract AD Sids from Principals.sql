
WITH TinyNumbers (number)
AS (SELECT TOP (256)
           ROW_NUMBER() OVER (ORDER BY number) - 1
    FROM master.dbo.spt_values)
SELECT sp.[name],
	   LEFT(sp.[name], CHARINDEX('\',sp.[name])-1) AS domain,
	   SUBSTRING(sp.[name], CHARINDEX('\',sp.[name])+1, LEN(sp.[name])) AS username,
       sp.[sid],
       GetWindowsSID.ADsid,
       sp.type_desc
FROM sys.server_principals AS sp
    CROSS APPLY
( -- dbo.GetWindowsSID(sp.[sid]) AS ad
    SELECT ADsid = STUFF(
                            (
                                SELECT '-' + part
                                FROM
                                (
                                    SELECT Number = -1,
                                           part = 'S-'
                                                  + CONVERT(
                                                               VARCHAR(30),
                                                               CONVERT(
                                                                          TINYINT,
                                                                          CONVERT(VARBINARY(30), LEFT(sp.[sid], 1))
                                                                      )
                                                           ) + '-'
                                                  + CONVERT(
                                                               VARCHAR(30),
                                                               CONVERT(
                                                                          INT,
                                                                          CONVERT(
                                                                                     VARBINARY(30),
                                                                                     SUBSTRING(sp.[sid], 3, 6)
                                                                                 )
                                                                      )
                                                           )
                                    UNION ALL
                                    SELECT TOP ((LEN(sp.[sid]) - 5) / 4)
                                           number,
                                           part = CONVERT(
                                                             VARCHAR(30),
                                                             CONVERT(
                                                                        BIGINT,
                                                                        CONVERT(
                                                                                   VARBINARY(30),
                                                                                   REVERSE(CONVERT(
                                                                                                      VARBINARY(30),
                                                                                                      SUBSTRING(
                                                                                                                   sp.[sid],
                                                                                                                   9
                                                                                                                   + number
                                                                                                                   * 4,
                                                                                                                   4
                                                                                                               )
                                                                                                  )
                                                                                          )
                                                                               )
                                                                    )
                                                         )
                                    FROM TinyNumbers
                                    ORDER BY Number
                                ) AS x
                                ORDER BY Number
                                FOR XML PATH(''), TYPE
                            ).value(N'.[1]', 'nvarchar(max)'),
                            1,
                            1,
                            ''
                        )
) GetWindowsSID
WHERE [type] IN ( 'U', 'G' )
      AND LEN([sid]) % 4 = 0;
