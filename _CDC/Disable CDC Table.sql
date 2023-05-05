exec sys.sp_cdc_disable_table  @source_schema=N'dbo', 
		@source_name=N'CDSim_BE', @capture_instance=N'dbo_CDSim_BE' -- Comment