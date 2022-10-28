/****** Script for SelectTopNRows command from SSMS  ******/
WITH XMLNAMESPACES ('http://algersoftware.com' AS ns)
SELECT TOP (1000) [ID],
       [DateInserted],
       [TargetTypeID],
       [TargetCode],
       COALESCE(Exception.value(
                    '(/ns:SerializableException/ns:InnerException/ns:InnerException/ns:Message)[1]', 'varchar(1000)'), 
					Exception.value(
                            '(/ns:SerializableException/ns:InnerException/ns:Message)[1]',
                            'varchar(1000)'), 
						Exception.value(
                                '(/ns:SerializableException/ns:Message)[1]',
                                'varchar(1000)')) AS ExMessage,
       Exception.value('(/ns:SerializableException/ns:Message)[1]', 'varchar(1000)') AS ExMessage1,
       Exception.value('(/ns:SerializableException/ns:InnerException/ns:Message)[1]', 'varchar(1000)') AS ExMessage2,
       Exception.value('(/ns:SerializableException/ns:InnerException/ns:InnerException/ns:Message)[1]', 'varchar(1000)') AS ExMessage3,
       --   ,SUBSTRING(CONVERT(VARCHAR(MAX),[Exception]),100,10000) AS Exception
       [Exception]
  FROM [FSSqlServerStatusV3].[Logging].[RequestException]
 ORDER BY ID DESC;