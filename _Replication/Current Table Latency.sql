
WITH    LAT_PUB
          AS ( SELECT TOP 1
                        start_time ,
                        latency
               FROM     sys.dm_cdc_log_scan_sessions
               WHERE    ( scan_phase = 'Done' )
               ORDER BY start_time DESC
             ),
        SRC_OBJ
          AS ( SELECT   OBJECT_ID('History.ModuleScrap') AS [object_id]
               UNION ALL
               SELECT   OBJECT_ID('Dbo.Accepts') AS [object_id]
               UNION ALL
               SELECT   OBJECT_ID('Dbo.Marker') AS [object_id]
               UNION ALL
               SELECT   OBJECT_ID('Current.ModuleLabel') AS [object_id]
             ),
        PUBS
          AS ( SELECT   ART.[artid] ,
                        ART.[dest_owner] ,
                        ART.[dest_table] ,
                        ART.[objid] ,
                        DB_NAME() AS publisher_db ,
                        SERVERPROPERTY('SERVERNAME') AS publisher ,
                        PUB.name AS publication ,
                        ART.[pubid] ,
                        LAT_PUB.latency AS PubDistLatency
               FROM     [dbo].[sysarticles] ART
                        INNER JOIN SRC_OBJ OBJ ON ( ART.[objid] = OBJ.[object_id] )
                        INNER JOIN [dbo].[syspublications] PUB ON ( ART.pubid = PUB.pubid )
                        CROSS JOIN LAT_PUB
             ),
        DAHIST
          AS ( SELECT   agent_id ,
                        time ,
                        delivered_transactions ,
                        delivery_latency
               FROM     ( SELECT    * ,
                                    ROW_NUMBER() OVER ( PARTITION BY agent_id ORDER BY time DESC ) AS RowNum
                          FROM      [KLM1SQL01V501].[distribution].dbo.msdistribution_history WITH ( NOLOCK )
                          WHERE     ( time > ( GETDATE() - 1 ) )
                                    AND ( updateable_row = 0 )
                        ) AGH
               WHERE    ( AGH.RowNum = 1 )
             )
    SELECT  PUBS.artid ,
            PUBS.[dest_owner] ,
            PUBS.[dest_table] ,
            PUBS.[objid] ,
            PUBS.publisher_db ,
            PUBS.publisher ,
            PUBS.publication ,
            PUBS.[pubid] ,
            PUBS.PubDistLatency ,
            DSYS.server_id AS publisher_id ,
            DPUB.publication_id AS Dpub_id ,
            DSUB.article_id AS Dsub_art_id ,
            DAHIST.time AS last_repl_run ,
            DAHIST.delivery_latency AS DistSubLatencyMS ,
            ( PUBS.PubDistLatency + ( ( DAHIST.delivery_latency + 900 ) / 1000 ) ) AS TotalLatency
    FROM    PUBS
            INNER JOIN [KLM1SQL01V501].[distribution].sys.servers DSYS WITH ( NOLOCK ) ON ( PUBS.publisher = DSYS.[name] )
            INNER JOIN [KLM1SQL01V501].[distribution].sys.servers SSYS WITH ( NOLOCK ) ON ( SSYS.[name] = 'KLM1SQL01V401' )
            INNER JOIN [KLM1SQL01V501].[distribution].dbo.mspublications DPUB WITH ( NOLOCK ) ON ( DSYS.server_id = DPUB.publisher_id )
                                                                                                 AND ( PUBS.publisher_db = DPUB.publisher_db )
                                                                                                 AND ( PUBS.publication = DPUB.publication )
            INNER JOIN [KLM1SQL01V501].[distribution].dbo.mssubscriptions DSUB WITH ( NOLOCK ) ON ( DSYS.server_id = DSUB.publisher_id )
                                                                                                  AND ( DPUB.publisher_db = DSUB.publisher_db )
                                                                                                  AND ( DPUB.publication_id = DSUB.publication_id )
                                                                                                  AND ( DSUB.subscriber_id = SSYS.server_id )
                                                                                                  AND ( DSUB.article_id = PUBS.artid )
            --INNER JOIN [KLM1SQL01V501].[distribution].dbo.msdistribution_agents DAGT WITH ( NOLOCK ) ON ( DSUB.agent_id = DAGT.id );
            INNER JOIN DAHIST ON ( DSUB.agent_id = DAHIST.agent_id );
