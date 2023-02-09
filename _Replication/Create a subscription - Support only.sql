-----------------BEGIN: Script to be run at Publisher 'PBG1SQL01V103'-----------------
use [ReliabilityDB]
exec sp_addsubscription @publication = N'Reporting - Reliability_TempCorrect', @subscriber = N'PBG1SQL01V400', @destination_db = N'ReliabilityDB_Report', @subscription_type = N'Push', @sync_type = N'replication support only', @article = N'all', @update_mode = N'read only', @subscriber_type = 0
exec sp_addpushsubscription_agent @publication = N'Reporting - Reliability_TempCorrect', @subscriber = N'PBG1SQL01V400', @subscriber_db = N'ReliabilityDB_Report', @job_login = N'FS\zSvc_SQLRepl_02', @job_password = 'gut-Psjk5v', @subscriber_security_mode = 1, @frequency_type = 64, @frequency_interval = 0, @frequency_relative_interval = 0, @frequency_recurrence_factor = 0, @frequency_subday = 0, @frequency_subday_interval = 0, @active_start_time_of_day = 0, @active_end_time_of_day = 235959, @active_start_date = 20160217, @active_end_date = 99991231, @enabled_for_syncmgr = N'False', @dts_package_location = N'Distributor'
GO
-----------------END: Script to be run at Publisher 'PBG1SQL01V103'-----------------

