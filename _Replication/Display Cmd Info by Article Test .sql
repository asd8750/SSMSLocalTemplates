use distribution;

WITH TRINFO AS (
		SELECT  [publisher_database_id]
				,MIN(xact_seqno) AS LSN_Low
				,MAX(xact_seqno) AS LSN_High
				,CONVERT(DATE,[entry_time]) AS EntryDate
				,COUNT(*) AS TranCnt
			  FROM [distribution].[dbo].[MSrepl_transactions] WITH (NOLOCK)
			  GROUP BY [publisher_database_id], CONVERT(DATE,[entry_time])
			 -- ORDER BY publisher_database_id, entryDate
  			)
	--,CMDINFO AS (
		SELECT	cmds.publisher_database_id
				,cmds.article_id
				,TRINFO.EntryDate
				,TRINFO.TranCnt
				,COUNT(*) AS CmdCnt
			FROM [distribution].[dbo].[MSrepl_commands] cmds WITH (NOLOCK)
				INNER JOIN TRINFO
					ON (cmds.publisher_database_id = TRINFO.publisher_database_id) 
					AND (cmds.xact_seqno >= TRINFO.LSN_Low) AND (cmds.xact_seqno <= TRINFO.LSN_High)
			GROUP BY cmds.publisher_database_id, cmds.article_id, TRINFO.EntryDate, TRINFO.TranCnt
	)
SELECT  db.publisher_db 
		,CMDINFO.article_id
		,art.source_owner
		,art.destination_object
		,CMDINFO.EntryDate
		,count(*) as cmd_cnt
		,pub.publication AS [Pub Name]
    FROM CMDINFO
		INNER JOIN [dbo].[MSpublisher_databases] db WITH (NOLOCK)
			ON (CMDINFO.publisher_database_id = db.id)
		INNER JOIN [dbo].[MSarticles] art WITH (NOLOCK)
			ON (CMDINFO.article_id = art.article_id) and (db.publisher_id = art.publisher_id) and (db.publisher_db = art.publisher_db)
		INNER JOIN [dbo].[MSpublications] pub WITH (NOLOCK)
			ON (art.publication_id = pub.publication_id)
  --WHERE cmds.publisher_database_id = 46
  GROUP BY db.publisher_db 
		,CMDINFO.article_id
		,art.source_owner
		,art.destination_object
		,CMDINFO.EntryDate
		,pub.publication
  ORDER BY db.publisher_db ,cmd_cnt DESC
  --OPTION (MAXDOP 1)