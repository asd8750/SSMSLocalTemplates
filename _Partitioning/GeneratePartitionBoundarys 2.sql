
DECLARE @today DATETIME2(7) = N'2020-07-01T00:00:00.000'
DECLARE @newCount INT = 30;
DECLARE @gap INT = 1;

DECLARE @fileGroup VARCHAR(128) = 'PRIMARY';
DECLARE @schemeName	VARCHAR(256) = 'PtSch_dbo_TrackData_V2';
DECLARE @FuncName	VARCHAR(256) = 'PtFunc_dbo_TrackData_V2';

DECLARE @cmd VARCHAR(2000);

WHILE (@newCount > 0)
	BEGIN
		SET @today = DATEADD(MONTH, @gap, @today)
		SET @newCount = @newCount - 1
		SELECT	--@today, 
				--@newCount,
				@cmd = CONCAT('ALTER PARTITION SCHEME [', @schemeName, '] NEXT USED [', @fileGroup, '];', CHAR(13),
				'ALTER PARTITION FUNCTION [', @funcName, ']() SPLIT RANGE (''', CONVERT(VARCHAR(35),@today, 126), ''');');
		PRINT @cmd;
		--EXECUTE (@cmd);
	END;
