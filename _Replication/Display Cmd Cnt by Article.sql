
SELECT  db.publisher_db 
		,cmds.article_id
		,art.source_owner
		,art.destination_object
		,count(*) as cmd_cnt
		,pub.publication AS [Pub Name]
    FROM [dbo].[MSrepl_commands] cmds WITH (NOLOCK)
		INNER JOIN [dbo].[MSpublisher_databases] db WITH (NOLOCK)
			ON (cmds.publisher_database_id = db.id)
		INNER JOIN [dbo].[MSarticles] art WITH (NOLOCK)
			ON (cmds.article_id = art.article_id) and (db.publisher_id = art.publisher_id) and (db.publisher_db = art.publisher_db)
		INNER JOIN [dbo].[MSpublications] pub WITH (NOLOCK)
			ON (art.publication_id = pub.publication_id)
  --WHERE cmds.publisher_database_id = 46
  GROUP BY db.publisher_db ,cmds.article_id, art.source_owner, art.destination_object, pub.publication
  ORDER BY db.publisher_db ,cmd_cnt DESC