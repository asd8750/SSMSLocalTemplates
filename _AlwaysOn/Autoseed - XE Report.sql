DECLARE @XFiles VARCHAR(300) = 'E:\BU\autoseed*'

;WITH cXEvent
AS (
     SELECT    object_name AS event
              ,CONVERT(XML,event_data) AS  EventXml
     FROM      sys.fn_xe_file_target_read_file(@XFiles, NULL,NULL,NULL)
     where object_name like 'hadr_physical_seeding_progress')
 
 SELECT
c1.value('(/event/@timestamp)[1]','datetime') AS time
,c1.value('(/event/@name)[1]','varchar(200)') AS XEventType
,c1.value('(/event/data[@name="database_id"]/value)[1]','int') AS database_id
,c1.value('(/event/data[@name="database_name"]/value)[1]','sysname') AS [database_name]
,c1.value('(/event/data[@name="transfer_rate_bytes_per_second"]/value)[1]','float') AS [transfer_rate_bytes_per_second]
,(c1.value('(/event/data[@name="transfer_rate_bytes_per_second"]/value)[1]','float')*8)/1000000.00 AS [transfer_Mbps]
,c1.value('(/event/data[@name="transferred_size_bytes"]/value)[1]','float') AS [transferred_size_bytes]
,c1.value('(/event/data[@name="database_size_bytes"]/value)[1]','float') AS [database_size_bytes]
,(c1.value('(/event/data[@name="transferred_size_bytes"]/value)[1]','float') / c1.value('(/event/data[@name="database_size_bytes"]/value)[1]','float'))*100.00 AS [PctCompleted]
,c1.value('(/event/data[@name="is_compression_enabled"]/value)[1]','varchar(200)') AS [is_compression_enabled]
,c1.value('(/event/data[@name="total_disk_io_wait_time_ms"]/value)[1]','bigint') AS [total_disk_io_wait_time_ms]
,c1.value('(/event/data[@name="total_network_wait_time_ms"]/value)[1]','int') AS [total_network_wait_time_ms]
,c1.value('(/event/data[@name="role_desc"]/value)[1]','varchar(300)') AS [role_desc]
,c1.value('(/event/data[@name="remote_machine_name"]/value)[1]','varchar(300)') AS [remote_machine_name]
,c1.value('(/event/data[@name="internal_state_desc"]/value)[1]','varchar(300)') AS [internal_state_desc]
,c1.value('(/event/data[@name="failure_code"]/value)[1]','int') AS [failure_code]
,c1.value('(/event/data[@name="failure_message"]/value)[1]','varchar(max)') AS [failure_message]
 
FROM cXEvent
    CROSS APPLY EventXml.nodes('//event') as t1(c1)