USE [msdb]

DECLARE @TrimDate DATETIME = '2018-01-01';

DECLARE @erMsg VARCHAR(4000);

WHILE (@TrimDate < DATEADD(MONTH, -2, GETDATE()))
BEGIN
    SET @erMsg = CONCAT('Trimming before: ', CONVERT(VARCHAR(35), @TrimDate, 126));
    RAISERROR(@erMsg, 0, 1) WITH NOWAIT;
    EXEC sp_delete_backuphistory @oldest_date = @TrimDate;
    SET @TrimDate = DATEADD(MONTH, 1, @TrimDate);
END;

