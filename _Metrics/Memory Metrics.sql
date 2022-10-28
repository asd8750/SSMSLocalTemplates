DECLARE @counters TABLE (
    [object_name] [NCHAR](128) NOT NULL,
    [counter_name] [NCHAR](128) NOT NULL,
    [instance_name] [NCHAR](128) NOT NULL,
    [cntr_value] [BIGINT] NOT NULL,
    [cntr_type] [INT] NOT NULL);

DECLARE @InstObjName VARCHAR(128);
SET @InstObjName = CASE
                        WHEN SERVERPROPERTY('INSTANCENAME') IS NULL THEN 'SQLServer'
                        ELSE CONCAT('MSSQL$', CAST(SERVERPROPERTY('INSTANCENAME') AS VARCHAR(64))) END;

DECLARE @InstName VARCHAR(128);
SET @InstName = ISNULL(CAST(SERVERPROPERTY('INSTANCENAME') AS VARCHAR(64)), 'MSSQLServer');

INSERT INTO @counters (object_name,
                       counter_name,
                       instance_name,
                       cntr_value,
                       cntr_type)
SELECT PC.[object_name],
       PC.counter_name,
       PC.instance_name,
       PC.cntr_value,
       PC.cntr_type
  FROM sys.dm_os_performance_counters PC
 WHERE (   PC.counter_name IN ( 'Buffer cache hit ratio', 'Total Server Memory (KB)', 'Connection Memory (KB)',
                                'Lock Memory (KB)', 'SQL Cache Memory (KB)', 'Optimizer Memory (KB) ',
                                'Granted Workspace Memory (KB) ', 'Cursor memory usage', 'Total pages',
                                'Database pages', 'Free pages', 'Reserved pages', 'Stolen pages', 'Cache Pages',
                                'Page life expectancy', 'Free list stalls/sec', 'Checkpoint pages/sec',
                                'Lazy writes/sec', 'Memory Grants Pending', 'Memory Grants Outstanding' )
     AND   (PC.[object_name] LIKE CONCAT(@InstObjName, '%')))
    OR (PC.instance_name = @InstName);

-- Get SQL Server instance name 
DECLARE @InstanceName VARCHAR(64);
SET @InstanceName = CONCAT(@InstObjName, ':');

DECLARE @BufferPoolKB BIGINT;
SET @BufferPoolKB = 0;
--SELECT  'Total Memory used by SQL Server Buffer Pool as reported by Perfmon counters' 
SELECT @BufferPoolKB = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Memory Manager'
   AND counter_name = 'Total Server Memory (KB)';
--
DECLARE @MemInstanceKB BIGINT;
SET @MemInstanceKB = 0;
--SELECT  'Memory needed as per current Workload for SQL Server instance' 
SELECT @MemInstanceKB = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Memory Manager'
   AND counter_name = 'Target Server Memory (KB)';
--
DECLARE @MemConnectionsKB BIGINT;
SET @MemConnectionsKB = 0;
--SELECT  'Total amount of dynamic memory the server is using for maintaining connections' 
SELECT @MemConnectionsKB = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Memory Manager'
   AND counter_name = 'Connection Memory (KB)';
--
DECLARE @MemLocksKB BIGINT;
SET @MemLocksKB = 0;
--SELECT  'Total amount of dynamic memory the server is using for locks' 
SELECT @MemLocksKB = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Memory Manager'
   AND counter_name = 'Lock Memory (KB)';
--
DECLARE @MemDynSqlCacheKB BIGINT;
SET @MemDynSqlCacheKB = 0;
--SELECT  'Total amount of dynamic memory the server is using for the dynamic SQL cache' 
SELECT @MemDynSqlCacheKB = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Memory Manager'
   AND counter_name = 'SQL Cache Memory (KB)';
--
DECLARE @MemDynQryOptKB BIGINT;
SET @MemDynQryOptKB = 0;
--SELECT  'Total amount of dynamic memory the server is using for query optimization' 
SELECT @MemDynQryOptKB = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Memory Manager'
   AND counter_name = 'Optimizer Memory (KB)';
--
DECLARE @MemDynHshIdxKB BIGINT;
SET @MemDynHshIdxKB = 0;
--SELECT  'Total amount of dynamic memory used for hash, sort and create index operations.' 
SELECT @MemDynHshIdxKB = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Memory Manager'
   AND counter_name = 'Granted Workspace Memory (KB)';
--
DECLARE @MemDynCursorKB BIGINT;
SET @MemDynCursorKB = 0;
--SELECT  'Total Amount of memory consumed by cursors' 
SELECT @MemDynCursorKB = cntr_value
  FROM @counters
 WHERE counter_name  = 'Cursor memory usage'
   AND instance_name = '_Total';
--
DECLARE @BufferPoolPgs BIGINT;
SET @BufferPoolPgs = 0;
--SELECT  'Number of pages in the buffer pool (includes database, free, and stolen).' 
SELECT @BufferPoolPgs = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Buffer Manager'
   AND counter_name = 'Total pages';
--
DECLARE @BufferDataPgs BIGINT;
SET @BufferDataPgs = 0;
---SELECT  'Number of Data pages in the buffer pool' 
SELECT @BufferDataPgs = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Buffer Manager'
   AND counter_name = 'Database pages';
--
DECLARE @BufferFreePgs BIGINT;
SET @BufferFreePgs = 0;
--SELECT  'Number of Free pages in the buffer pool' 
SELECT @BufferFreePgs = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Buffer Manager'
   AND counter_name = 'Free pages';
--
DECLARE @BufferRsvrdPgs BIGINT;
SET @BufferRsvrdPgs = 0;
--SELECT  'Number of Reserved pages in the buffer pool' 
SELECT @BufferRsvrdPgs = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Buffer Manager'
   AND counter_name = 'Reserved pages';
--
DECLARE @BufferStolenPgs BIGINT;
SET @BufferStolenPgs = 0;
--SELECT  'Number of Stolen pages in the buffer pool' 
SELECT @BufferStolenPgs = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Buffer Manager'
   AND counter_name = 'Stolen pages';
--
DECLARE @BufferPlanCachePgs BIGINT;
SET @BufferPlanCachePgs = 0;
--SELECT  'Number of Plan Cache pages in the buffer pool' 
SELECT @BufferPlanCachePgs = cntr_value
  FROM @counters
 WHERE object_name   = @InstanceName + 'Plan Cache'
   AND counter_name  = 'Cache Pages'
   AND instance_name = '_Total';
--
DECLARE @PLE_Secs BIGINT;
SET @PLE_Secs = 0;
--SELECT  'Page Life Expectancy - Number of seconds a page will stay in the buffer pool without references' 
SELECT @PLE_Secs = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Buffer Manager'
   AND counter_name = 'Page life expectancy';
--
DECLARE @ReqSecWaitFree BIGINT;
SET @ReqSecWaitFree = 0;
--SELECT  'Number of requests per second that had to wait for a free page' 
SELECT @ReqSecWaitFree = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Buffer Manager'
   AND counter_name = 'Free list stalls/sec';

DECLARE @CheckptPgsPerSec BIGINT;
SET @CheckptPgsPerSec = 0;
--SELECT  'Number of pages flushed to disk/sec by a checkpoint or other operation that require all dirty pages to be flushed' 
SELECT @CheckptPgsPerSec = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Buffer Manager'
   AND counter_name = 'Checkpoint pages/sec';
--
DECLARE @LazyBufferPerSec BIGINT;
SET @LazyBufferPerSec = 0;
--SELECT  'Number of buffers written per second by the buffer manager"s lazy writer' 
SELECT @LazyBufferPerSec = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Buffer Manager'
   AND counter_name = 'Lazy writes/sec';
--
DECLARE @MemGrantPending BIGINT;
SET @MemGrantPending = 0;
--SELECT  'Total number of processes waiting for a workspace memory grant' 
SELECT @MemGrantPending = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Memory Manager'
   AND counter_name = 'Memory Grants Pending';
--
DECLARE @MemGrantOutstanding BIGINT;
SET @MemGrantOutstanding = 0;
--SELECT  'Total number of processes that have successfully acquired a workspace memory grant' 
SELECT @MemGrantOutstanding = cntr_value
  FROM @counters
 WHERE object_name  = @InstanceName + 'Memory Manager'
   AND counter_name = 'Memory Grants Outstanding';
--
--	Now collect the results into one output row
--
SELECT @BufferPoolKB AS BufferPoolKB,
       @MemInstanceKB AS MemInstanceKB,
       @MemConnectionsKB AS MemConnectionsKB,
       @MemLocksKB AS MemLocksKB,
       @MemDynSqlCacheKB AS MemDynSqlCacheKB,
       @MemDynQryOptKB AS MemDynQryOptKB,
       @MemDynHshIdxKB AS MemDynHshIdxKB,
       @MemDynCursorKB AS MemDynCursorKB,
       @BufferPoolPgs AS BufferPoolPgs,
       @BufferDataPgs AS BufferDataPgs,
       @BufferFreePgs AS BufferFreePgs,
       @BufferRsvrdPgs AS BufferRsvrdPgs,
       @BufferStolenPgs AS BufferStolenPgs,
       @BufferPlanCachePgs AS BufferPlanCachePgs,
       @PLE_Secs AS PLE_Secs,
       @ReqSecWaitFree AS ReqSecWaitFree,
       @CheckptPgsPerSec AS CheckptPgsPerSec,
       @LazyBufferPerSec AS LazyBufferPerSec,
       @MemGrantPending AS MemGrantPending,
       @MemGrantOutstanding AS MemGrantOutstanding;