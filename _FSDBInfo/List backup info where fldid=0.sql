/****** Script for SelectTopNRows command from SSMS  ******/
SELECT -- TOP (1000) 
	DINST.FullInstanceName,
	DDB.DatabaseName,
	XFS.TargetCode,
    FBD.[FBDID],
    FBD.[DBID],
    FBD.[backup_set_id],
    FBD.[media_set_id],
	IBK.[name],
    FBD.[backup_start_time],
    FBD.[backup_finish_time],
    FBD.[type],
    FBD.[backup_size_MB],
    FBD.[backup_engine],
    FBD.[FldID],
    FBD.[is_copy_only],
    FBD.[cmp_ratio],
    FBD.[checkpoint_lsn],
    FBD.[database_backup_lsn],
    FBD.[prev_type_backup],
    FBD.[TCount]
FROM [FSDBInfo].[Fact].[BackupDetail] FBD
	INNER JOIN [FSDBInfo].Dimension.Databases DDB
		ON (FBD.[DBID] = DDB.[DBID])
	INNER JOIN [FSDBInfo].Dimension.Instances DINST
		ON (DDB.[InstID] = DINST.InstID)
	INNER JOIN [FSDBInfo].Dimension.tvf_InstID_DataSrc('FSSV3') XFS
		ON (DINST.InstID = XFS.InstID)
	INNER JOIN [FSSqlServerStatusV3].Site.[Info-BackupSet] IBK
		ON (XFS.TargetCode = IBK.z_TargetCode) AND (FBD.backup_set_id = IBK.backup_set_id)
WHERE (FBD.[backup_start_time] > '2019-01-01')
      AND (FBD.FldID = 0)
	  AND (FBD.[type] = 'D')
ORDER BY DINST.FullInstanceName,
		 DDB.DatabaseName,
         backup_start_time;