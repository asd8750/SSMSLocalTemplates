	SET NOCOUNT ON;

DECLARE	@DateStart	DATETIME = '20170701';
--DECLARE @PartInterval	VARCHAR(10) = 'MONTH';
DECLARE @PartAHEAD	INT = 12;

DECLARE @SchemaName VARCHAR(64) = 'WIP';
DECLARE @TableName	VARCHAR(64) = 'Tables';
DECLARE @PartColumn VARCHAR(64) = 'ReadTime';
DECLARE @PartDataType VARCHAR(64) = 'DATETIME2(7)';
DECLARE @PartFG		VARCHAR(64) = 'ModuleAssembly_UserDataFG';
DECLARE @PartFG0	VARCHAR(64) = 'ModuleAssembly_UserDataFG';
DECLARE @PartInterval	VARCHAR(16) = 'WEEK';
DECLARE @PartLR		CHAR(1) = 'R';  -- L-RANGE LEFT, R-RANGE RIGHT

DECLARE	@sqlPFunc	VARCHAR(4000) = '';
DECLARE @sqlPSch	VARCHAR(4000) = '';

DECLARE	@DateToday	DATETIME = CAST(GETDATE() AS DATE);
DECLARE @PartCount	INT = 0;

--  Build the partition schema and function commands
--
DECLARE @DatePart	DATETIME = @DateStart;

SET @sqlPSch = 'CREATE PARTITION SCHEME ' + QUOTENAME('PtSch_' + @SchemaName + '_' + @TableName ,'[') + 
				' AS PARTITION ' + QUOTENAME('PtFunc_' + @SchemaName + '_' + @TableName ,'[') + ' TO (';

SET @sqlPFunc = CONCAT('CREATE PARTITION FUNCTION ', 
						QUOTENAME(CONCAT('PtFunc_', @SchemaName, '_', @TableName) ,'['), 
						'(', @PartDataType,') AS RANGE RIGHT FOR VALUES (');

IF (@PartLR = 'R')
	SET @sqlPSch = @sqlPSch + QUOTENAME(@PartFG0, '[') + ', ';

WHILE @PartAHEAD > 0
	BEGIN
		--SELECT @DateStart, @DatePart, @DateToday, @PartCount, @sqlPSch, @sqlPFunc
		IF (@PartCount > 0) 
			BEGIN
				SET @sqlPSch = @sqlPSch + ', ';
				SET @sqlPFunc = @sqlPFunc + ', ';
			END
		--SET @sqlPSch = @sqlPSch + REPLACE(QUOTENAME(@PartFG, '['), '<<Year>>', );
		SET @sqlPSch = @sqlPSch + REPLACE(QUOTENAME(@PartFG, '['), '<<Year>>', CONVERT(VARCHAR(4), DATEPART(YEAR, @DatePart)));
		SET @sqlPFunc = @sqlPFunc + QUOTENAME(CONVERT(VARCHAR(40), @DatePart, 126), '''');
		IF (@DatePart > @DateToday) SET @PartAHEAD = @PartAHEAD - 1;
		SET @PartCount = @PartCount + 1;
		IF @PartInterval = 'DAY'
			SET @DatePart = DATEADD(DAY, 1, @DatePart);
		ELSE IF @PartInterval = 'WEEK' 
			BEGIN
				IF DATEPART(DAY,@DatePart) < 22 
					SET @DatePart = DATEADD(DAY, 7, @DatePart);
				ELSE
					SET @DatePart = DATEADD(MONTH, 1, DATEADD(DAY, -(DATEPART(DAY,@DatePart)-1), @DatePart))
			END;
		ELSE IF @PartInterval = 'MONTH'
			SET @DatePart = DATEADD(MONTH, 1, @DatePart);
		ELSE 
			SET @DatePart = DATEADD(MONTH, 1, @DatePart);
	END;

IF (@PartLR = 'L')
	SET @sqlPSch = @sqlPSch + ', ' + QUOTENAME(@PartFG0, '[');
SET @sqlPSch = @sqlPSch + ');';
SET @sqlPFunc = @sqlPFunc + ');';

PRINT @sqlPFunc;
PRINT @sqlPSch;
