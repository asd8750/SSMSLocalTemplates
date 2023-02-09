WITH VirtPub AS (
		SELECT publisher_id, publisher_db, publisher_database_id, publication_id, article_id, 
			SUM(CASE WHEN subscriber_id < 0 THEN 1 ELSE 0 END) AS vcnt,
			SUM(CASE WHEN subscriber_id >= 0 THEN 1 ELSE 0 END) AS pcnt
			FROM dbo.MSsubscriptions WITH (NOLOCK)
			GROUP BY publisher_id, publisher_db, publisher_database_id, publication_id, article_id
			HAVING SUM(CASE WHEN subscriber_id < 0 THEN 1 ELSE 0 END) > 0 AND SUM(CASE WHEN subscriber_id >= 0 THEN 1 ELSE 0 END) = 0
			)

SELECT vp.*, art.article, mp.publication
	FROM VirtPub vp
		full outer JOIN MSarticles art WITH (NOLOCK)
			ON (vp.article_id = art.article_id) and (vp.publication_id = art.publication_id)
		full outer join MSpublications mp WITH (NOLOCK)
			ON (vp.publication_id = mp.publication_id)
	WHERE vp.publication_id IS NOT NULL
