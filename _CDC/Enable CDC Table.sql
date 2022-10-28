USE [MaxQA]

CREATE ROLE [cdc_admin]
ALTER DATABASE [MaxQA] MODIFY FILEGROUP [CDC1] DEFAULT;

EXEC sys.sp_cdc_enable_db

ALTER DATABASE [MaxQA] MODIFY FILEGROUP [PRIMARY] DEFAULT;


EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo'
  , @source_name = N'asset'
  , @role_name = N'cdc_admin'
  , @capture_instance = N'dbo_asset' 
  , @supports_net_changes = 1
  , @index_name = N'asset_ndx1' 
  , @filegroup_name = N'CDC1';

EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo'
  , @source_name = N'workorder'
  , @role_name = N'cdc_admin'
  , @capture_instance = N'dbo_workorder' 
  , @supports_net_changes = 1
  , @index_name = N'workorder_ndx1' 
  , @filegroup_name = N'CDC1';
