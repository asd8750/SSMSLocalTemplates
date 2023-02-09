SELECT	session_id, start_time, duration, tran_count, log_record_count, command_count, latency, last_commit_cdc_time, last_commit_cdc_lsn
	 --SELECT *
	FROM sys.dm_cdc_log_scan_sessions
	ORDER BY session_id DESC
	
	
-- SELECT TOP 100 * FROM fn_dblog('0x001A5C4D:0000927B:0002', null) ; -- The '0x' prefix is needed when the hex LSN is used