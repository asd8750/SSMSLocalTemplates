--
--	Name: Delete_Old_sysjobhistory_rows
--	Purpose:	Delete older sysjobhistory rows to prevent slow job agent performance.
--				Add special delete job to remove history of very frequently scheduled jobs.
--
--	Revsions:
--	2017-12-01 - F. LaForest - Initial version (for Maximo)
--

DECLARE @retainAllDays INT = 30; -- Retain all entries that are not yet XX days old
DECLARE @retainAssetMeeterDays INT = 8; -- Retain all entries that are not yet XX days old for 'AssetMeter%' jobs


--	Delete all entries created before the set cutoff date
--
DELETE HIST
  FROM [msdb].dbo.sysjobhistory HIST
 WHERE (HIST.run_date <= CAST(FORMAT(DATEADD(DAY, -@retainAllDays, GETDATE()), 'yyyyMMdd') AS INT));

RAISERROR ('Deleted %d sysjobhistory entries', 0, 1, @@ROWCOUNT) WITH NOWAIT;

--	Delete all AssetMeter job entries created before the set cutoff date
--
WITH JOBS
  AS (SELECT [job_id],
             [originating_server_id],
             [name],
             [enabled],
             [category_id]
        FROM [msdb].[dbo].[sysjobs])
DELETE HIST
  FROM JOBS
 INNER JOIN [msdb].dbo.sysjobhistory HIST
    ON (JOBS.job_id = HIST.job_id)
 WHERE (JOBS.enabled  = 1)
   AND (JOBS.[name] LIKE 'AssetMeterProcessor%')
   AND (HIST.run_date <= CAST(FORMAT(DATEADD(DAY, -@retainAssetMeeterDays, GETDATE()), 'yyyyMMdd') AS INT));
--ORDER BY category_id,
--         name;

RAISERROR ('Deleted %d (AssetMeter) sysjobhistory entries', 0, 1, @@ROWCOUNT) WITH NOWAIT;

--	Rebuild the sysjobhistory table
--
ALTER TABLE [msdb].[dbo].[sysjobhistory] REBUILD PARTITION = ALL;

RAISERROR ('Rebuilt [msdb].[dbo].[sysjobhistory] table', 0, 1) WITH NOWAIT;
