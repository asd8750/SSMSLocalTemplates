DROP EVENT SESSION [AlwaysOn_autoseed] ON SERVER ;

CREATE EVENT SESSION [AlwaysOn_autoseed] ON SERVER 
	ADD EVENT sqlserver.hadr_automatic_seeding_state_transition,
	ADD EVENT sqlserver.hadr_automatic_seeding_timeout,
	ADD EVENT sqlserver.hadr_db_manager_seeding_request_msg,
	ADD EVENT sqlserver.hadr_physical_seeding_backup_state_change,
	ADD EVENT sqlserver.hadr_physical_seeding_failure,
	ADD EVENT sqlserver.hadr_physical_seeding_forwarder_state_change,
	ADD EVENT sqlserver.hadr_physical_seeding_forwarder_target_state_change,
	ADD EVENT sqlserver.hadr_physical_seeding_progress,
	ADD EVENT sqlserver.hadr_physical_seeding_restore_state_change,
	ADD EVENT sqlserver.hadr_physical_seeding_submit_callback

	ADD TARGET package0.event_file(SET filename=N'E:\Backup\autoseed.xel',max_file_size=(20),max_rollover_files=(4))
	WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,
			MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,
			MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON);
	ALTER EVENT SESSION  [AlwaysOn_autoseed] ON SERVER STATE = START;
GO