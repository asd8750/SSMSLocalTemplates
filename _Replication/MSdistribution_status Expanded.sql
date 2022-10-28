SELECT	AG.publisher_db,
		AG.publication,
		QUOTENAME(ART.source_owner,'[') + '.' + QUOTENAME(ART.source_object,'[') AS [Table],
		RS.*,
		AG.[name] AS Subscriber
	FROM MSdistribution_status RS
		INNER JOIN [dbo].[MSdistribution_agents] AG
			ON (RS.agent_id = AG.id)
		INNER JOIN [dbo].[MSarticles] ART
			ON (RS.article_id = ART.article_id) AND (AG.publisher_id = ART.publisher_id) AND (AG.publisher_db = ART.publisher_db)
			
	ORDER BY publisher_db, [table], subscriber