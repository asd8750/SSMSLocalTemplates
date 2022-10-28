/****** Script for SelectTopNRows command from SSMS  ******/
SELECT  MSRT.[publisher_database_id] ,
        MSPD.[publisher_db] ,
        CONVERT(DATE, MSRT.[entry_time]) AS EntryDay ,
        COUNT(*) AS CMDCnt
FROM    [distribution].[dbo].[MSrepl_transactions] MSRT WITH ( NOLOCK )
        INNER JOIN [distribution].[dbo].[MSpublisher_databases] MSPD ON ( MSRT.[publisher_database_id] = MSPD.[id] )
GROUP BY MSRT.[publisher_database_id] ,
        MSPD.[publisher_db] ,
        CONVERT(DATE, MSRT.[entry_time])
ORDER BY [publisher_db], EntryDay