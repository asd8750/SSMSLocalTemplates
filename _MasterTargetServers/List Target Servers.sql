CREATE TABLE #tmp_sp_help_targetserver
(
    server_id INT NULL,
    server_name sysname NULL,
    location NVARCHAR(200) NULL,
    time_zone_adjustment INT NULL,
    enlist_date DATETIME NULL,
    last_poll_date DATETIME NULL,
    status INT NULL,
    unread_instructions INT NULL,
    local_time DATETIME NULL,
    enlisted_by_nt_user NVARCHAR(200) NULL,
    poll_interval INT NULL
);

INSERT INTO #tmp_sp_help_targetserver
EXEC msdb.dbo.sp_help_targetserver;

SELECT * --SERVER_NAME

   FROM #tmp_sp_help_targetserver
   --WHERE
   -- status = 5
   ORDER BY server_name

DROP TABLE #tmp_sp_help_targetserver;


--SELECT * FROM dbo.sysdownloadlist
