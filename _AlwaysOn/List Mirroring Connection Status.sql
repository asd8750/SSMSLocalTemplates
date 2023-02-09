--	Display the mirroring connection status of each session
--
--	Author: F. LaForest
--  History
--	2020		F. LaForest	- Initial Version
--  2021-11-29	F. LaForest - Display the associated cert name
--
SELECT	EC.connection_id,
		EC.connect_time,
		EC.protocol_type,
		EC.net_transport,
		EC.endpoint_id,
		ec.encrypt_option,
		MC.encryption_algorithm_desc,
		EC.auth_scheme,
		MC.authentication_method,
		MC.principal_name,
		EC.local_net_address,
		EC.local_tcp_port,
		MC.remote_user_name,
		MC.peer_certificate_id,
		CT.[name] AS CertName,
		EC.client_net_address,
		EC.client_tcp_port,
		MC.is_accept,
		MC.login_state,
		MC.login_state_desc,
		MC.state,
		MC.state_desc
		--,EC.*, MC.*
	FROM sys.dm_exec_connections EC
	FULL OUTER JOIN sys.dm_db_mirroring_connections MC
		ON (EC.connection_id = MC.connection_id)
	LEFT OUTER JOIN sys.certificates CT
		ON (MC.peer_certificate_id = CT.certificate_id)
	WHERE 
	(EC.protocol_type IN ('Database Mirroring')) 
	--((EC.local_tcp_port = 5022) OR (EC.client_tcp_port = 5022))
	ORDER BY EC.protocol_type, MC.principal_name