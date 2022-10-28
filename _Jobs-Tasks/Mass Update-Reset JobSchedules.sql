SELECT  j.name AS JobName
        ,sch.name AS ScheduleName
        ,'EXECUTE msdb..sp_update_jobschedule @job_name = ''' + j.name + ''', @name = ''' + sch.name + '''' AS ReloadJobSchedules
FROM    msdb.dbo.sysjobschedules s
INNER JOIN
        msdb.dbo.sysschedules sch
        ON  s.schedule_id = sch.schedule_id
INNER JOIN
        msdb.dbo.sysjobs j
        ON s.job_id = j.job_id
WHERE   sch.[enabled] = 1       
ORDER BY
        j.name