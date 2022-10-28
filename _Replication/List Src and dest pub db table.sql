/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000
        rsp.pubid ,
        rsp.name AS PubName ,
       -- rsp.[status] AS PubStatus ,
       -- rsp.allow_anonymous ,
       -- rsp.immediate_sync ,
       -- rsa.[artid] ,
       -- rsa.[description] ,
		@@SERVERNAME AS src_server,
		DB_NAME(DB_ID()) AS src_db,
		OBJECT_SCHEMA_NAME(rsa.[objid]) AS src_Schema,
		OBJECT_NAME(rsa.[objid]) AS src_table,
		rsrv.srvname,
		rsub.dest_db,
        rsa.[dest_owner] AS dest_schema ,
        rsa.[dest_table] 
        --,rsa.[objid] ,
        --rsa.[pubid] ,
        --rsa.[pre_creation_cmd] ,
        --rsa.[status] ,
        --rsa.[type] ,
        --rsa.[schema_option]
FROM    [dbo].[sysarticles] rsa
        INNER JOIN [dbo].[syspublications] rsp ON ( rsp.pubid = rsa.pubid )
		INNER JOIN [dbo].[syssubscriptions] rsub ON (rsa.artid = rsub.artid )
		INNER JOIN [sys].[sysservers] rsrv ON (rsub.srvid = rsrv.srvid)
ORDER BY PubName ,
        dest_owner ,
        dest_table