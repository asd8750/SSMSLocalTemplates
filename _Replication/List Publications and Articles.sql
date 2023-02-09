/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000
        rsp.pubid ,
        rsp.name AS PubName ,
        rsp.[status] AS PubStatus ,
        rsp.allow_anonymous ,
        rsp.immediate_sync ,
        rsa.[artid] ,
        rsa.[description] ,
        rsa.[dest_owner] ,
        rsa.[dest_table] ,
        rsa.[objid] ,
        rsa.[pubid] ,
        rsa.[pre_creation_cmd] ,
        rsa.[status] ,
        rsa.[type] ,
        rsa.[schema_option]
FROM    [dbo].[sysarticles] rsa
        INNER JOIN [dbo].[syspublications] rsp ON ( rsp.pubid = rsa.pubid )
ORDER BY PubName ,
        dest_owner ,
        dest_table