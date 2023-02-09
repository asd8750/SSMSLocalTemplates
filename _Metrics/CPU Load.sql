SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @pastMinutes INT;
SET @pastMinutes = 60;

-- Get CPU Utilization History for last 30 minutes (SQL 2008)
DECLARE @ts_now BIGINT; 
DECLARE @ms_now BIGINT;
DECLARE @used_cpu_ratio DECIMAL(10, 2);

SELECT  @ms_now = SI.ms_ticks ,
        @ts_now = ( SI.cpu_ticks / ( SI.cpu_ticks / SI.ms_ticks ) ) ,
        @used_cpu_ratio = CAST(CAST(cpu_count AS DECIMAL(10, 2)) / CAST(scheduler_count AS DECIMAL(10, 2)) AS DECIMAL(10, 2))
FROM    sys.dm_os_sys_info SI;
						                   
WITH    CPU
          AS ( SELECT TOP ( 100 )
                        CAST(SQLProcessUtilization AS DECIMAL(10, 1)) AS [CPU Work] ,
                        CAST(( CAST(SQLProcessUtilization AS DECIMAL(10, 1)) * @used_cpu_ratio ) AS DECIMAL(10, 1)) AS [CPU Work Adjusted] ,
                        CAST(( 100.0 - SQLProcessUtilization - SystemIdle ) AS DECIMAL(10, 1)) AS [CPU Other] ,
                        CAST(SystemIdle AS DECIMAL(10, 1)) AS [CPU Idle] ,
                        DATEADD(ms, -1 * ( @ts_now - [timestamp] ), GETDATE()) AS [Event Time]
               FROM     ( SELECT    record.value('(./Record/@id)[1]', 'int') AS record_id ,
                                    record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS [SystemIdle] ,
                                    record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS [SQLProcessUtilization] ,
                                    [timestamp]
                          FROM      ( SELECT    [timestamp] ,
                                                CONVERT(XML, record) AS [record]
                                      FROM      sys.dm_os_ring_buffers
                                      WHERE     ( ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' )
                                                AND ( record LIKE '%<SystemHealth>%' )
                                                AND ( [timestamp] > ( @ms_now - ( 1000 * 60 * ( @pastMinutes * 2 ) ) ) )
                                    ) AS x
                        ) AS y
               ORDER BY record_id DESC
             )
    --INSERT  INTO [DBA_Control].[dbo].[CPU_Load] 
    --        ( SampleTime ,
    --          CpuWork ,
    --          CpuIdle ,
    --          CpuOther ,
    --          CpuWorkAdjusted
    --        )
            SELECT  DATEADD(ms, -DATEPART(ms, CPU.[Event Time]), CPU.[Event Time]) AS [ETime] ,
                    CPU.[CPU Work] ,
                    CPU.[Cpu Idle] ,
                    CPU.[CPU Other] ,
                    ( CPU.[CPU Work Adjusted] + CPU.[CPU Other] ) AS [Cpu Work Adjusted]
            FROM    CPU
            --        LEFT OUTER JOIN [DBA_Control].[dbo].[CPU_Load] CLOAD ON ( DATEADD(ms, -DATEPART(ms, CPU.[Event Time]), CPU.[Event Time]) = CLOAD.SampleTime )
            --WHERE   ( CLOAD.SampleTime IS NULL )
		

--- TRUNCATE TABLE [DBA_Control].[dbo].[CPU_Load]