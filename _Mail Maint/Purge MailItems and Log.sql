
DECLARE @today DATETIME = '2022-04-09'
PRINT @today

EXEC msdb.dbo.sysmail_delete_mailitems_sp @sent_before = @today
EXEC msdb.dbo.sysmail_delete_log_sp @logged_before = @today

