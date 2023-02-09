																											   DECLARE @VersionDate DATETIME;
EXEC master.dbo.sp_BlitzIndex @DatabaseName = N'ClipProcessData',               -- nvarchar(128)
                              --@SchemaName = N'ProcessHistory',                 -- nvarchar(128)
                              --@TableName = N'PdrPartProducedEvent',                  -- nvarchar(128)
                              @Mode = 0, --,                         -- tinyint
                              --@Filter = 0,                       -- tinyint
                              --@SkipPartitions = NULL,            -- bit
                              --@SkipStatistics = NULL,            -- bit
                              --@GetAllDatabases = NULL,           -- bit
                              @BringThePain = 1 --,              -- bit
                              --@ThresholdMB = 0,                  -- int
                              --@OutputType = '',                  -- varchar(20)
                              --@OutputServerName = N'',           -- nvarchar(256)
                              --@OutputDatabaseName = N'',         -- nvarchar(256)
                              --@OutputSchemaName = N'',           -- nvarchar(256)
                              --@OutputTableName = N'',            -- nvarchar(256)
                              --@Help = 0,                         -- tinyint
                              --@VersionDate = @VersionDate OUTPUT -- datetime
