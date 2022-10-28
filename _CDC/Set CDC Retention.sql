EXECUTE sys.sp_cdc_change_job 
    @job_type = N'cleanup',
    @retention = 8640;

EXECUTE sys.sp_cdc_help_jobs