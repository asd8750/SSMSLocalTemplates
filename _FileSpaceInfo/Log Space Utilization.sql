--	Log Space Utilization
--
DECLARE @lg TABLE
    (
      DatabaseName VARCHAR(100) ,
      LOGSIZE_MB DECIMAL(18, 9) ,
      LOGSPACE_USED DECIMAL(18, 9) ,
      LOGSTATUS DECIMAL(18, 9)
    );

INSERT  @lg
        ( DatabaseName ,
          LOGSIZE_MB ,
          LOGSPACE_USED ,
          LOGSTATUS
        )
        EXEC ( 'DBCC SQLPERF (Logspace)'
            );
SELECT  LG.* ,
        CONVERT(DECIMAL(10, 2), ( LG.LOGSIZE_MB * LG.LOGSPACE_USED / 100.0 )) AS MB_Used ,
        DB.log_reuse_wait_desc
FROM    @lg LG
        INNER JOIN sys.databases db ON ( LG.DatabaseName = db.name )
