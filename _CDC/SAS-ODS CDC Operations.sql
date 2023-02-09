USE ProcessData;

-- EXEC sys.sp_cdc_enable_db
-- EXEC sys.sp_cdc_disable_db

EXEC sys.sp_cdc_enable_table
		@source_schema = N'dbo',
		@source_name   = N'NPRRollcoater',
		@role_name     = N'CDC_Admin',
		@filegroup_name = N'CDC1',
		@supports_net_changes = 1,
		@allow_partition_switch = 1


-- EXEC sys.sp_cdc_disable_table @source_schema = N'dbo',@source_name = N'MyTable', @capture_instance = N'dbo_MyTable'
