USE [master]
GO

DECLARE @RestoreCmds TABLE ( [LineNo] INT IDENTITY(1,1), Cmd VARCHAR(4000) );


DECLARE SH CURSOR FAST_FORWARD
FOR
    WITH    DBList ( DBName )
              AS ( SELECT   'TfsActivityLogging'
                   UNION ALL
                   SELECT   'TfsBuild'
                   UNION ALL
                   SELECT   'TfsIntegration'
                   UNION ALL
                   SELECT   'TfsMigration'
                   UNION ALL
                   SELECT   'TfsToTfsMigration'
                   UNION ALL
                   SELECT   'TfsToTfsMigration58ffe5c5dcd446a0a63492ebd764dcc7'
                   UNION ALL
                   SELECT   'TfsVersionControl'
                   UNION ALL
                   SELECT   'TfsWarehouse'
                   UNION ALL
                   SELECT   'TfsWorkItemTracking'
                   UNION ALL
                   SELECT   'TfsWorkItemTrackingAttachments'
                 )
    SELECT  DBName
    FROM    DBList

DECLARE @DBName VARCHAR(256);
OPEN SH;

FETCH NEXT FROM SH INTO @DBName;
WHILE ( @@FETCH_STATUS = 0 )
    BEGIN
        DECLARE @return_value INT ,
            @xmlCmds XML

        EXEC @return_value = [dbo].[usp_Restore_Database] @databaseName = @DBName,
            @earliestDate = N'2015-05-15', @srcBackupLogPath = N'\\PBGSQLSHAREN31\n$\Vi32_Backup\Logs',
            @dstDefaultDataPath = N'E:\', @dstDefaultLogPath = N'D:\', @xmlCmds = @xmlCmds OUTPUT, @replace = 1,
            @recover = 0 --
            , @options = 'LISTNONE'

--		SELECT	@xmlCmds as N'@xmlCmds'

        INSERT  @RestoreCmds
                ( Cmd
                )
                SELECT  N.value('@BackupCmd', 'varchar(3000)') AS Cmd
                FROM    @xmlCmds.nodes('Restores/Restore') AS T ( N )
		FETCH NEXT FROM SH INTO @DBName;
    END

	CLOSE SH;
	DEALLOCATE SH;

	DECLARE @BigRestoreJob  VARCHAR(MAX);
	      Select Cmd + CHAR(13) 
                From @RestoreCmds
				ORDER by [LineNo]
                For XML PATH (''),TYPE

GO
