

	DECLARE @DB_NAME VARCHAR(200)
	Declare @P_DBNAME Varchar(200)
	declare @PLAN VARCHAR(200)
	declare @DestLoc varchar(200)
	--set @PLAN='R'
	set @P_DBNAME='FSLRCRM'
	SET @DB_NAME=@P_DBNAME
	


      -- IF @PLAN = 'R'
			BEGIN
			
             WITH
				backup_recent AS
				(
				SELECT MAX(backup_date) backup_date,MAX(id) id,[type],server_name,database_name
				FROM
				(
				SELECT  Row_number() OVER (ORDER BY database_name,[type],backup_finish_date) id,
						backup_finish_date backup_date, physical_device_name,a.media_set_id,
						server_name,database_name,[type]
						FROM msdb.dbo.backupset a JOIN msdb.dbo.backupmediafamily b
						ON(a.media_set_id=b.media_set_id)
				) backups
				GROUP BY [type],server_name,database_name
				),
				backup_all AS
				(
				SELECT  Row_number() OVER (ORDER BY database_name,[type],backup_finish_date) id,
						physical_device_name
						FROM msdb.dbo.backupset a JOIN msdb.dbo.backupmediafamily b
						ON(a.media_set_id=b.media_set_id)
				)

                SELECT * FROM(
				SELECT server_name [SERVER],database_name [DATABASE],bakuptype=
						CASE WHEN [type]='D' THEN 'FULL'
						WHEN [type]='I' THEN 'DIFFERENTIAL'
						WHEN [type]='L' THEN 'LOG'
						WHEN [type]='F' THEN 'FILE / FILEGROUP'
						WHEN [type]='G'  THEN 'DIFFERENTIAL FILE'
						WHEN [type]='P' THEN 'PARTIAL'
						WHEN [type]='Q' THEN 'DIFFERENTIAL PARTIAL'
						END,backup_date [RECENT BACKUP], 
						replace(physical_device_name,physical_device_name,'RESTORE DATABASE'+' '+'['+@P_DBNAME+']'+' '+'FROM  DISK ='+' '+''''+physical_device_name+''' '+'WITH  FILE = 1,  NORECOVERY,  NOUNLOAD,  REPLACE,  STATS = 10') [LOCATION] FROM backup_recent,backup_all
				WHERE backup_recent.id=backup_all.id AND database_name=@P_DBNAME AND  [type] IN ('D','I')

					
			 UNION

			SELECT
					 server_name,database_name,bakuptype='LOG',
					backup_finish_date backup_date,replace(physical_device_name,physical_device_name,'RESTORE LOG'+' '+'['+@P_DBNAME+']'+' '+'FROM  DISK ='+' '+''''+physical_device_name+''' '+'WITH  FILE = 1,  NORECOVERY,  NOUNLOAD,  REPLACE,  STATS = 10')
					
					FROM msdb.dbo.backupset a JOIN msdb.dbo.backupmediafamily b 
					ON(a.media_set_id=b.media_set_id)
					
					WHERE [type]='L'
					AND backup_finish_date>
			(
			SELECT TOP 1 backup_finish_date FROM msdb.dbo.backupset WHERE [type] IN ('D','I')
			AND  database_name= @DB_NAME ORDER BY backup_finish_date DESC
			)

			AND database_name= @DB_NAME  ) AS restore_plan
			ORDER BY [RECENT BACKUP]

			
			END



