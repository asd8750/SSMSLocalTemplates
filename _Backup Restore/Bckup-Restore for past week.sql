
--------------------------------------------------------------------------------- 
--Database Backups for all databases For Previous Week 
--------------------------------------------------------------------------------- 



	DECLARE @DB_NAME VARCHAR(200)
	Declare @P_DBNAME Varchar(200)
	declare @PLAN VARCHAR(200)
	declare @DestLoc varchar(200)
	
	set @P_DBNAME='ODS'
	SET @DB_NAME=@P_DBNAME
SELECT  
   CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server, 
   msdb.dbo.backupset.database_name,  
   msdb.dbo.backupset.backup_start_date,  
   msdb.dbo.backupset.backup_finish_date, 
   msdb.dbo.backupset.first_lsn,
   msdb.dbo.backupset.last_lsn,
  
   CASE msdb..backupset.type  
       WHEN 'D' THEN 'Database'  
       WHEN 'L' THEN 'Log'  
	   WHEN 'i' THEN 'Differential'
   END AS backup_type,  
    
   replace(physical_device_name,physical_device_name,'RESTORE DATABASE'+' '+'['+@P_DBNAME+']'+' '+'FROM  DISK ='+' '+''''+physical_device_name+''' '+'WITH  FILE = 1,  NORECOVERY,  NOUNLOAD,  REPLACE,  STATS = 10') [LOCATION]
FROM   msdb.dbo.backupmediafamily  
   INNER JOIN msdb.dbo.backupset ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id 
WHERE  (CONVERT(datetime, msdb.dbo.backupset.backup_start_date, 102) >= GETDATE() - 14)  
--and last_lsn ='216221000020988100001 '
and msdb.dbo.backupset.database_name=@P_DBNAME
ORDER BY  
   msdb.dbo.backupset.database_name, 
   msdb.dbo.backupset.backup_finish_date 