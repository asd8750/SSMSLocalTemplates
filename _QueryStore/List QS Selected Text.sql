SELECT DISTINCT TOP (100) 
		[query_sql_text]

  FROM [ODS].[sys].[query_store_query_text]
  WHERE (query_sql_text LIKE '%ProcessData%')
  ORDER BY query_sql_text
