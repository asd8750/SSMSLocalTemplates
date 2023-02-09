/************************************************************************ 
*                                                * 
*    Title:    msdb index creation                        * 
*    Author:    Geoff N. Hiten                            * 
*    Purpose: Index msdb database                            * 
*    Date:    12/12/2005                                    * 
*    Modifications:                                    * 
*                                                * 
*    01-01-2001                                        * 
*        Sample Entry                                * 
*                                                * 
*                                                * 
************************************************************************/ 

use msdb 
go 

--backupset 

Create index IX_backupset_backup_set_id on backupset(backup_set_id) 
go 

Create index IX_backupset_backup_set_uuid on backupset(backup_set_uuid) 
go 

Create index IX_backupset_media_set_id on backupset(media_set_id) 
go 

Create index IX_backupset_backup_finish_date on backupset(backup_finish_date) 
go 

Create index IX_backupset_backup_start_date on backupset(backup_start_date) 
go 

--backupmediaset 

Create index IX_backupmediaset_media_set_id on backupmediaset(media_set_id) 
go 

--backupfile 

Create index IX_backupfile_backup_set_id on backupfile(backup_set_id) 
go 

--backupmediafamily 

Create index IX_backupmediafamily_media_set_id on backupmediafamily(media_set_id) 
go 

--restorehistory 

Create index IX_restorehistory_restore_history_id on restorehistory(restore_history_id) 
go 

Create index IX_restorehistory_backup_set_id on restorehistory(backup_set_id) 
go 

--restorefile 

Create index IX_restorefile_restore_history_id on restorefile(restore_history_id) 
go 

--restorefilegroup 

Create index IX_restorefilegroup_restore_history_id on restorefilegroup(restore_history_id) 
go 

/************************************************************************ 
*    End Script                                        * 
************************************************************************/ 
