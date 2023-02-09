--	Log Shipping Config - Primary
--
SELECT 
		--MONPRI.*, PRIDB.*, PRISEC.*,
		MONPRI.primary_id,
		MONPRI.primary_server,
		MONPRI.primary_database,
		SERVERPROPERTY('ServerName') AS act_server_name,
		PRISEC.secondary_server,
		PRISEC.secondary_database,
		PRIDB.backup_directory,
		PRIDB.backup_share,
		PRIDB.backup_job_id,
		PRIDB.backup_retention_period,
		PRIDB.monitor_server,
		PRIDB.backup_compression
	FROM [dbo].[log_shipping_monitor_primary] MONPRI
		FULL OUTER JOIN [dbo].[log_shipping_primary_databases] PRIDB
			ON (MONPRI.primary_id = PRIDB.primary_id)
		FULL OUTER JOIN [dbo].[log_shipping_primary_secondaries] PRISEC
			ON (MONPRI.primary_id = PRISEC.primary_id)

--	Log Shipping Config - Secondary
--
SELECT 
		--MONSEC.*, SEC.*, SECDB.*,
		MONSEC.secondary_id,
		MONSEC.primary_server,
		MONSEC.primary_database,
		MONSEC.secondary_server,
		MONSEC.secondary_database,
		SERVERPROPERTY('ServerName') AS act_server_name,
		SEC.backup_source_directory,
		SEC.backup_destination_directory,
		SEC.copy_job_id,
		SEC.restore_job_id,
		SEC.file_retention_period, 
		SECDB.restore_delay
	FROM [dbo].[log_shipping_monitor_secondary] MONSEC
		FULL OUTER JOIN [dbo].[log_shipping_secondary] SEC
			ON (MONSEC.secondary_id = SEC.secondary_id)
		FULL OUTER JOIN [dbo].[log_shipping_secondary_databases] SECDB
			ON (MONSEC.secondary_id = SECDB.secondary_id)
