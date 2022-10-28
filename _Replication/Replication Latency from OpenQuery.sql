SELECT maxTranCount, maxLatency
	FROM OPENQUERY(PBG1SQL01V103, '
	        WITH    LSS ( tran_count, latency )
                  AS ( SELECT TOP 5
                                tran_count ,
                                latency
                       FROM     Prod_Data.sys.dm_cdc_log_scan_sessions
                       WHERE    scan_phase = ''Done''
                       ORDER BY session_id DESC
                     )
            SELECT MAX(tran_count) AS maxTranCount, MAX(latency) AS maxLatency 
				FROM LSS')