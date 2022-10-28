DECLARE @DSQL NVARCHAR(MAX)

SET NOCOUNT ON;
CREATE TABLE    #Logs
       (
         Archive INT,
         Archivedate DATETIME,
         FileSize INT
       )

INSERT  #Logs
EXEC    master.dbo.xp_enumerrorlogs

CREATE TABLE    #Log
       (
         LogDate DATETIME,
         ProcessInfo VARCHAR(255),
         [Text] NVARCHAR(MAX)
       )

DECLARE @CurrentLog INT,
    @MaxLog INT

SELECT  @CurrentLog = MIN(Archive),
    @MaxLog = MAX(Archive)
FROM    #Logs

WHILE @CurrentLog <= @MaxLog
    BEGIN
       --SELECT    @DSQL = 'EXEC master.dbo.sp_readerrorlog @p1 = ' + CONVERT(VARCHAR, @CurrentLog) + ', -- int
       --          @p2 = 1, -- int
       --          @p3 = ''The Current Node is :- ''' -- varchar(255)
       SELECT    @DSQL = 'EXEC master.dbo.sp_readerrorlog @p1 = ' + CONVERT(VARCHAR, @CurrentLog) + ', -- int
                 @p2 = 1, -- int
                 @p3 = ''NETBIOS''' -- varchar(255)

       --PRINT @DSQL

       INSERT    #Log
       EXEC  (@DSQL)

       SELECT    @CurrentLog = MIN(Archive)
       FROM  #Logs
       WHERE Archive > @CurrentLog
    END

SELECT * FROM #Log

DROP TABLE  #Logs, #Log