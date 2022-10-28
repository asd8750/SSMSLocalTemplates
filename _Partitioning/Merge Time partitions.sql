

DECLARE	@CurBoundary DATETIME = '2025-01-01'
DECLARE @cmd VARCHAR(4000);
DECLARE @timeStart DATETIME
DECLARE @timeEnd DATETIME
DECLARE @duration INT


WHILE (@CurBoundary > '2020-01-01')
	BEGIN
		SET @cmd = 'ALTER PARTITION FUNCTION [PtFunc_Logging_LogEntryWeekly]() MERGE RANGE (''' + CONVERT(VARCHAR(40), @CurBoundary, 126) + ''')'
		Raiserror ( @cmd, 0, 1) WITH NOWAIT;
		SET @timeStart = GETDATE()
		BEGIN TRY
			EXEC (@cmd)
		END TRY
		BEGIN CATCH
			RAISERROR ('Catch Error', 0, 1) WITH NOWAIT
		END CATCH
		SET @timeEnd = GETDATE()
		SET @CurBoundary = DATEADD(DAY, -1, @CurBoundary)
		SET @duration = DATEDIFF(SECOND, @timeSTart, @timeEnd)
		Raiserror ('Duration: %d', 0, 1, @duration) WITH NOWAIT;
		IF (@duration <= 3)
			WAITFOR DELAY '00:00:02';
		ELSE
			WAITFOR DELAY '00:00:30';
	END