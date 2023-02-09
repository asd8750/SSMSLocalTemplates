WITH    DUPL
          AS ( SELECT   FullInstanceName ,
                        InstID ,
                        [DBID] ,
                        DatabaseName ,
                        DateCreated ,
                       -- max_backup_set_id ,
                       -- max_backup_start_time ,
                        ROW_NUMBER() OVER ( PARTITION BY InstID, [DatabaseName], DateCreated ORDER BY [DBID] DESC ) AS RowNum ,
                        COUNT([DBID]) OVER ( PARTITION BY InstID, [DatabaseName], DateCreated ) AS DBCnt ,
                        'EXEC  [dbo].[usp_RemoveDatabase] @DBID = ' + CONVERT(VARCHAR(8), [DBID]) AS Cmd
               FROM     ( SELECT    DINST.FullInstanceName ,
                                    DINST.InstID ,
                                    DDB.[DBID] ,
                                    DDB.[DatabaseName] ,
                                    DDB.DateCreated ,
                                    DDB.DateDeleted 
                                   -- ,MAX(FBD.backup_set_id) AS max_backup_set_id ,
                                   -- MAX(FBD.backup_start_time) AS max_backup_start_time
								--FBD.[type],
								--FBD.backup_start_time
                          FROM      [FSDBInfo].[Dimension].[Instances] DINST
                                    INNER JOIN [FSDBInfo].[Dimension].[Databases] DDB ON ( DINST.InstID = DDB.InstID )
                                   -- LEFT OUTER JOIN [FSDBInfo].[Fact].[BackupDetail] FBD ON ( DDB.[DBID] = FBD.[DBID] )
                        --  WHERE     ( DINST.FullInstanceName LIKE 'PBG1SQL01V304%' )
									
									--AND (DDB.DatabaseName = 'GTEP')
                                    --AND ( DINST.InstID = 224 )
                          GROUP BY  DINST.FullInstanceName ,
                                    DINST.InstID ,
                                    DDB.[DBID] ,
                                    DDB.[DatabaseName] ,
                                    DDB.DateCreated ,
                                    DDB.DateDeleted
                        ) DUPL2
             )
    SELECT  *
    FROM    DUPL
    WHERE   ( RowNum = 1 )
            AND ( DBCnt > 1 )
    ORDER BY [DatabaseName] ,
            [DBID] ,
            FullInstanceName;