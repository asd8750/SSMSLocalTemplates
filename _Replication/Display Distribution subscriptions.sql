  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;

WITH DHT AS (
		SELECT agent_id, min(time) as min_time
			FROM [dbo].[MSdistribution_history] WITH (NOLOCK)
			GROUP BY agent_id
		)

	, PubSub AS (
		-- Get the publication name based on article 
		SELECT DISTINCT  
		srv.srvname publication_server  
		, p.publisher_id 
		, a.publisher_db 
		, s.publisher_database_id
		, p.publication publication_name 
		, p.publication_id 
		, a.source_owner as TableSchema
		, a.source_object as TableName
		, a.article_id
		, a.destination_object 
		, ss.srvname subscription_server 
		, s.subscriber_id subscription_publisher_id
		, s.subscriber_db 
		, da.name AS distribution_agent_job_name, da.id, s.status, dh.xact_seqno, p.immediate_sync
		FROM MSArticles a  WITH (NOLOCK)
		JOIN MSpublications p WITH (NOLOCK) ON a.publication_id = p.publication_id 
		JOIN MSsubscriptions s WITH (NOLOCK) ON p.publication_id = s.publication_id 
		JOIN master..sysservers ss WITH (NOLOCK) ON s.subscriber_id = ss.srvid 
		JOIN master..sysservers srv WITH (NOLOCK) ON srv.srvid = p.publisher_id 
		JOIN MSdistribution_agents da WITH (NOLOCK) ON da.publisher_id = p.publisher_id  
				AND da.subscriber_id = s.subscriber_id AND s.agent_id = da.id
		JOIN [dbo].[MSdistribution_history] dh WITH (NOLOCK) ON (da.id = dh.agent_id)
		JOIN DHT ON (dh.agent_id = dht.agent_id AND dh.time = dht.min_time)
	)

	--,TRNS AS (
	--	SELECT mtr.publisher_database_id, ISNULL(PSX.Min_SeqNo,0) AS Min_SeqNo,  MIN(entry_time) AS Min_Entry_Time, MAX(entry_time) AS Max_Entry_Time, COUNT(*) AS tcnt
	--		FROM [dbo].[MSrepl_transactions] mtr WITH (NOLOCK)
	--			LEFT OUTER JOIN (
	--						SELECT publisher_database_id, MIN(xact_seqno) as Min_Seqno
	--							FROM PubSub
	--							GROUP BY publisher_database_id
	--							) PSX
	--				ON (mtr.publisher_database_id = PSX.publisher_database_id)
	--		WHERE mtr.xact_seqno < PSX.Min_Seqno OR PSX.Min_Seqno IS NULL
	--		GROUP BY mtr.publisher_database_id, ISNULL(PSX.Min_SeqNo,0)
	--		)

	SELECT pubsub.*  --, ISNULL(pubsub.publisher_database_id, trns.publisher_database_id) AS pub_dbid, trns.*
		FROM pubsub 
--			full outer JOIN TRNS	
--				ON (pubsub.publisher_database_id = trns.publisher_database_id)
		ORDER BY  publisher_db, publication_name, TableSchema, TableName , subscription_server