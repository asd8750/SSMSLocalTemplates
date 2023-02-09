SELECT  DATEDIFF(DAY, sd.crdate, GETDATE()) AS days_history
FROM    sys.sysdatabases sd
WHERE   sd.[name] = 'tempdb';

SELECT  login_time AS [Started] ,
        DATEDIFF(DAY, login_time, CURRENT_TIMESTAMP) AS [Uptime in days]
FROM    sys.sysprocesses
WHERE   spid = 1;
