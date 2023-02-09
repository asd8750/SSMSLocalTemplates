DECLARE @Publisher sysname ,
    @PublisherDB sysname;

-- Set Publisher server name
SET @Publisher = 'PBG1SQL01V103';
-- Set Publisher database name
SET @PublisherDB = 'Prod_Data';

-- Refresh replication monitor data
EXEC sys.sp_replmonitorrefreshjob @iterations = 1;

WITH    MaxXact ( ServerName, PublisherDBID, XactSeqNo )
          AS ( SELECT   S.name ,
                        DA.publisher_database_id ,
                        MAX(H.xact_seqno)
               FROM     dbo.MSdistribution_history H WITH ( NOLOCK )
                        INNER JOIN dbo.MSdistribution_agents DA WITH ( NOLOCK ) ON DA.id = H.agent_id
                        INNER JOIN master.sys.servers S WITH ( NOLOCK ) ON S.server_id = DA.subscriber_id
               WHERE    DA.publisher_db = @PublisherDB
               GROUP BY S.name ,
                        DA.publisher_database_id
             ),
        OldestXact ( ServerName, OldestEntryTime )
          AS ( SELECT   MX.ServerName ,
                        MIN(entry_time)
               FROM     dbo.msrepl_transactions T WITH ( NOLOCK )
                        INNER JOIN MaxXact MX ON MX.XactSeqNo <= T.xact_seqno
                                                 AND MX.PublisherDBID = T.publisher_database_id
               GROUP BY MX.ServerName
             )
    SELECT  [Replication Status] = CASE MD.status
                                     WHEN 1 THEN 'Started'
                                     WHEN 2 THEN 'Succeeded'
                                     WHEN 3 THEN 'In progress'
                                     WHEN 4 THEN 'Idle'
                                     WHEN 5 THEN 'Retrying'
                                     WHEN 6 THEN 'Failed'
                                   END ,
            Subscriber = S.srvname ,
            [Subscriber DB] = A.subscriber_db ,
            [Publisher DB] = MD.publisher_db ,
            Publisher = MD.publisher ,
            A.Publication ,
            [Current Latency (sec)] = MD.cur_latency ,
            [Current Latency (hh:mm:ss)] = RIGHT('00' + CAST(MD.cur_latency / 3600 AS VARCHAR), 2) + ':' + RIGHT('00'
                                                                                                                 + CAST(( MD.cur_latency % 3600 ) / 60 AS VARCHAR),
                                                                                                                 2) + ':' + RIGHT('00'
                                                                                                                                  + CAST(MD.cur_latency % 60 AS VARCHAR),
                                                                                                                                  2) ,
            [Latency Threshold (min)] = CAST(T.value AS INT) ,
            [Agent Last Stopped (sec)] = DATEDIFF(HOUR, agentstoptime, GETDATE()) - 1 ,
            [Agent Last Sync] = MD.last_distsync ,
            [Last Entry TimeStamp] = OX.OldestEntryTime
    FROM    dbo.MSreplication_monitordata MD WITH ( NOLOCK )
            INNER JOIN dbo.MSdistribution_agents A WITH ( NOLOCK ) ON A.id = MD.agent_id
            INNER JOIN dbo.MSpublicationthresholds T WITH ( NOLOCK ) ON T.publication_id = MD.publication_id
                                                                        AND T.metric_id = 2 -- Latency
            INNER JOIN master.dbo.sysservers S ON S.srvid = A.subscriber_id
            LEFT JOIN OldestXact OX ON OX.ServerName = S.srvname
    WHERE   MD.publisher = @Publisher
            AND MD.publisher_db = @PublisherDB
            AND MD.publication_type = 0 -- 0 = Transactional publication
            AND MD.agent_type = 3 -- 3 = distribution agent
	ORDER BY [Replication Status] DESC, [Current Latency (sec)] desc

-- SELECT * FROM dbo.MSreplication_monitordata