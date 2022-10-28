SELECT  dec.endpoint_id, dec.local_net_address, dec.local_tcp_port, dec.client_net_address, dec.client_tcp_port,
                                                    dec.protocol_type, dec.encrypt_option, ddmc.authentication_method, dme.connection_auth_desc
                                                FROM      sys.dm_exec_connections dec
                                                    inner join sys.dm_db_mirroring_connections ddmc
                                                        on (dec.connection_id = ddmc.connection_id)
                                                    left outer JOIN sys.database_mirroring_endpoints dme
                                                        on (dec.endpoint_id = dme.endpoint_id);

SELECT  dec.endpoint_id, dec.local_net_address, dec.local_tcp_port, dec.client_net_address, dec.client_tcp_port,
                                                    ddmc.authentication_method, dme.connection_auth_desc, ddmc.principal_name, ddmc.remote_user_name, dme.state_desc, ddmc.login_state_desc,
                                                    ddmc.total_bytes_sent, ddmc.total_bytes_received,
                                                    ddmc.total_fragments_sent, ddmc.total_fragments_received, ddmc.total_sends, ddmc.total_receives,
                                                    dec.num_reads, dec.last_read, dec.num_writes,
                                                    dec.connect_time, dec.last_write, ddmc.last_activity_time, ddmc.login_time
                                                FROM      sys.dm_exec_connections dec
                                                    inner join sys.dm_db_mirroring_connections ddmc
                                                        on (dec.connection_id = ddmc.connection_id)
                                                    left outer JOIN sys.database_mirroring_endpoints dme
                                                        on (dec.endpoint_id = dme.endpoint_id);
