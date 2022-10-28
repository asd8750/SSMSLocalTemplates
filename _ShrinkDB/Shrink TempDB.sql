--	Script #1 -- Target TempDB specifically
--
DECLARE @intDBID INTEGER SET @intDBID = (SELECT dbid FROM master. dbo.sysdatabases WHERE name = 'TempDB' )
--Flush stored procedure/plan cache for the specific database
 DBCC FLUSHPROCINDB (@intDBID )

 --	Script #2 - Another method, but nore impact
 --
 DBCC FREEPROCCACHE

 --	Script #3 -- Another user's script
 --
-- Report existing file sizes
 use tempdb
 GO
 SELECT name, size
 FROM sys.master_files
 WHERE database_id = DB_ID(N'tempdb');
GO
-- Shrink attempt
 DBCC FREEPROCCACHE -- clean cache
 DBCC DROPCLEANBUFFERS -- clean buffers
 DBCC FREESYSTEMCACHE ('ALL') -- clean system cache
 DBCC FREESESSIONCACHE -- clean session cache
 DBCC SHRINKDATABASE(tempdb, 10); -- shrink tempdb
 dbcc shrinkfile ('tempdev') -- shrink default db file
 dbcc shrinkfile ('tempdev2') -- shrink db file tempdev2
 dbcc shrinkfile ('tempdev3') -- shrink db file tempdev3
 dbcc shrinkfile ('tempdev4') -- shrink db file tempdev4
 dbcc shrinkfile ('templog') -- shrink log file
 GO
-- report the new file sizes
 SELECT name, size
 FROM sys.master_files
 WHERE database_id = DB_ID(N'tempdb');
GO