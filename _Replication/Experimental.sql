WITH RCmds AS (
		select top 1000 publisher_database_id, from MSrepl_commands WITH (NOLOCK)
		)

	,RTxns AS (
		SELECT TOP 1000 * FROM MSrepl_transactions WITH (NOLOCK)
		)

select RTxns.publisher_Database_id, count_big(*) AS CmdCount
	from RTxns
		inner join RCMDS
			on RTxns.publisher_database_id=RCMDS.publisher_database_id
	group by RTxns.publisher_Database_id
	order by 2 desc;


 SELECT TOP 1000 * 
	FROM MSrepl_transactions;

select top 10 publisher_database_id, 
from MSrepl_commands WITH (NOLOCK);


WITH PubID AS (
		SELECT DISTINCT publisher_id, publisher_database_id, publisher_db, publication_id,
			FROM MSsubscriptions
		)

	,PubDB AS (
		SELECT DISTINCT publisher_id, publisher_database_id, publisher_db
			FROM MSsubscriptions
		)

	,RCmd AS (
		SELECT TOP 100 *
			FROM  MSrepl_commands WITH (NOLOCK)
		)

SELECT MSA.*, RCnt.*
	FROM RCnt
		INNER JOIN MSarticles MSA
			ON (RCnt.publisher_database_id = MSA.publisher_id) AND (RCnt.article_id =

SELECT * FROM sysarticles

SELECT * 
	FROM MSarticles
	ORDER BY publisher_id, article_id

SELECT *
	FROM MSpublications
	ORDER BY publisher_id, publisher_db, publication

SELECT *
	FROM MSsubscriptions
	ORDER BY publication_id, article_id, subscription_seqno, subscriber_db



SELECT TOP 100 *
	FROM MSrepl_commands



