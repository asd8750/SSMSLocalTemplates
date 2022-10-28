
-- ALTER TABLE [msdb].[dbo].[sysmail_mailitems] REBUILD WITH (ONLINE=ON)


SELECT	MAX(LEN(recipients)) AS MaxLen_recipients,
		Avg(LEN(recipients)) AS AvgLen_recipients,
		MAX(LEN(copy_recipients)) AS MaxLen_copy_recipients,
		Avg(LEN(copy_recipients)) AS AvgLen_copy_recipients,
		MAX(LEN(blind_copy_recipients)) AS MaxLen_blind_copy_recipients,
		Avg(LEN(blind_copy_recipients)) AS AvgLen_blind_copy_recipients,
		MAX(LEN(from_address)) AS MaxLen_from_address,
		Avg(LEN(from_address)) AS AvgLen_from_address,
		MAX(LEN(body)) AS MaxLen_body,
		Avg(LEN(body)) AS AvgLen_body,
		MAX(LEN(file_attachments)) AS MaxLen_file_attachments,
		Avg(LEN(file_attachments)) AS AvgLen_file_attachments,
		MAX(LEN(query)) AS MaxLen_query,
		Avg(LEN(query)) AS AvgLen_query

	FROM [msdb].[dbo].[sysmail_mailitems]
GO

SELECT	--TOP (1) 
		mailitem_id,
		from_address,
		recipients,
		copy_recipients,
		blind_copy_recipients,
		LEFT(body,10000) AS Body,
		last_mod_date,
		last_mod_user
		FROM [msdb].[dbo].[sysmail_mailitems]
		WHERE LEN(body) > 1000000

DELETE FROM [msdb].[dbo].[sysmail_mailitems]
	WHERE mailitem_id = 78519