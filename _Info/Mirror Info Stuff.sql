use master;
SELECT db_name(dbm.database_id) as DBname,dbm.* from sys.database_mirroring dbm
	WHERE dbm.mirroring_guid is not null
	Order By DBname;

SELECT * From sys.dm_db_mirroring_connections

SELECT * FROM sys.endpoints dme

SELECT	*  
	FROM	sys.dm_exec_connections dec
	inner join sys.dm_db_mirroring_connections ddmc
		on (dec.connection_id = ddmc.connection_id)
	left outer JOIN sys.database_mirroring_endpoints dme
		on (dec.endpoint_id = dme.endpoint_id);

SELECT	dec.protocol_type, dec.encrypt_option, dec.endpoint_id, dec.local_net_address, dec.local_tcp_port, dec.client_net_address, dec.client_tcp_port,
		ddmc.authentication_method, dme.connection_auth_desc, ddmc.principal_name, ddmc.remote_user_name, dme.state_desc, ddmc.login_state_desc, ddmc.total_bytes_sent, ddmc.total_bytes_received,
		ddmc.total_fragments_sent, ddmc.total_fragments_received, ddmc.total_sends, ddmc.total_receives,
		dec.num_reads, dec.last_read, dec.num_writes, 
		dec.connect_time, dec.last_write, ddmc.last_activity_time, ddmc.login_time
FROM	sys.dm_exec_connections dec
	inner join sys.dm_db_mirroring_connections ddmc
		on (dec.connection_id = ddmc.connection_id)
	left outer JOIN sys.database_mirroring_endpoints dme
		on (dec.endpoint_id = dme.endpoint_id);

select distinct 'MAX(CASE WHEN RTRIM(pfc.counter_name) = ''' + RTRIM(cn.counter_name) + ''' THEN pfc.cntr_value ELSE NULL END) AS ''' + RTRIM(cn.counter_name) + ''','
	from (SELECT DISTINCT counter_name from sys.dm_os_performance_counters 
		where object_name like '%mirror%') cn


select DISTINCT pfc.object_name,pfc.counter_name, pfc.cntr_type
FROM sys.dm_os_performance_counters pfc
where pfc.object_name like '%mirror%'

DECLARE @timeNow datetime;
SET @timeNow = GETDATE();
SELECT pfc.instance_name as DBname, ISNULL(dbs.database_id,0) AS DBid, @TimeNow AS TimeNow,
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Bytes Received/sec' THEN pfc.cntr_value ELSE NULL END) AS 'Bytes Received/sec',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Bytes Sent/sec' THEN pfc.cntr_value ELSE NULL END) AS 'Bytes Sent/sec',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Log Bytes Received/sec' THEN pfc.cntr_value ELSE NULL END) AS 'Log Bytes Received/sec',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Log Bytes Redone from Cache/sec' THEN pfc.cntr_value ELSE NULL END) AS 'Log Bytes Redone from Cache/sec',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Log Bytes Sent from Cache/sec' THEN pfc.cntr_value ELSE NULL END) AS 'Log Bytes Sent from Cache/sec',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Log Bytes Sent/sec' THEN pfc.cntr_value ELSE NULL END) AS 'Log Bytes Sent/sec',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Log Compressed Bytes Rcvd/sec' THEN pfc.cntr_value ELSE NULL END) AS 'Log Compressed Bytes Rcvd/sec',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Log Compressed Bytes Sent/sec' THEN pfc.cntr_value ELSE NULL END) AS 'Log Compressed Bytes Sent/sec',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Log Harden Time (ms)' THEN pfc.cntr_value ELSE NULL END) AS 'Log Harden Time (ms)',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Log Remaining for Undo KB' THEN pfc.cntr_value ELSE NULL END) AS 'Log Remaining for Undo KB',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Log Scanned for Undo KB' THEN pfc.cntr_value ELSE NULL END) AS 'Log Scanned for Undo KB',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Log Send Flow Control Time (ms)' THEN pfc.cntr_value ELSE NULL END) AS 'Log Send Flow Control Time (ms)',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Log Send Queue KB' THEN pfc.cntr_value ELSE NULL END) AS 'Log Send Queue KB',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Mirrored Write Transactions/sec' THEN pfc.cntr_value ELSE NULL END) AS 'Mirrored Write Transactions/sec',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Pages Sent/sec' THEN pfc.cntr_value ELSE NULL END) AS 'Pages Sent/sec',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Receives/sec' THEN pfc.cntr_value ELSE NULL END) AS 'Receives/sec',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Redo Bytes/sec' THEN pfc.cntr_value ELSE NULL END) AS 'Redo Bytes/sec',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Redo Queue KB' THEN pfc.cntr_value ELSE NULL END) AS 'Redo Queue KB',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Send/Receive Ack Time' THEN pfc.cntr_value ELSE NULL END) AS 'Send/Receive Ack Time',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Sends/sec' THEN pfc.cntr_value ELSE NULL END) AS 'Sends/sec',
		MAX(CASE WHEN RTRIM(pfc.counter_name) = 'Transaction Delay' THEN pfc.cntr_value ELSE NULL END) AS 'Transaction Delay'
FROM sys.dm_os_performance_counters pfc 
	left outer join sys.databases dbs
		on (pfc.instance_name = dbs.name)
WHERE pfc.object_name like '%mirror%'
GROUP BY pfc.instance_name, dbs.database_id
