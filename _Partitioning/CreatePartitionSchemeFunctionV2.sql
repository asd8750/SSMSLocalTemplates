SET NOCOUNT ON;

DECLARE	@DateStart	DATETIME = '20170101';
DECLARE @IgnoreAfterDate DATETIME = '20400101'   -- If not null, then provide a boundary at this date for ignoring bad data

DECLARE @PartInterval	VARCHAR(16) = 'WEEK'; -- 'DAY', 'DAYS x', 'WEEK', 'MONTH'
DECLARE @PartLR		CHAR(1) = 'R';  -- L-RANGE LEFT, R-RANGE RIGHT
--DECLARE @PartAHEAD	INT = 60;
DECLARE @DaysAhead  INT = 120;

DECLARE @SchemaName VARCHAR(64) = 'ProcessHistory';
DECLARE @TableName	VARCHAR(64) = 'PdrBarCodeEvent';
DECLARE @PartDataType VARCHAR(64) = 'DATETIME2(7)';

--	Next two lines must have the same number of items separated by commas
DECLARE @PartFGS	VARCHAR(64) = 'ModuleAssembly_UserDataFG';  -- List of filegroups to use
DECLARE @PartFGDates VARCHAR(1000) = '2099-01-01'  -- List of dates showing the date when we switch to the NEXT filegroup in the list 


--	Internal variables
--
DECLARE	@sqlPFunc	VARCHAR(2000) = '';
DECLARE @sqlPSch	VARCHAR(2000) = '';

DECLARE @maxLineLen	INT = 200;

DECLARE	@DateToday	DATETIME = CAST(GETDATE() AS DATE);
DECLARE @PartCount	INT = 0;

--	Output tables
DECLARE @sqlOutput   TABLE (Seq INT NOT NULL, Cmd VARCHAR(1000) NOT NULL);

DECLARE @idFunc	INT = 1;
DECLARE @idSch  INT = 100000;

--  Build the partition schema and function commands
--
DECLARE @CurBoundaryDate	DATETIME = @DateStart;

DECLARE @PartFGCurrent VARCHAR(64);  -- Current Filegroup
DECLARE @PartNextFGDate DATETIME
DECLARE @PartListOffset INT = 0;

SET @PartFGCurrent = (SELECT TOP (1) value FROM STRING_SPLIT(@PartFGS, ','));  -- Get the first file group
SET @PartNextFGDate = (SELECT TOP (1) CONVERT(DATETIME,value) FROM STRING_SPLIT(@PartFGDates, ','));

DECLARE @eol INT = 0;   -- Set non-zero to trigger a new line

--
--	Start building the CREATE PARTION SCHEME and FUNCTION statements now
--
SET @sqlPSch = 'CREATE PARTITION SCHEME ' + QUOTENAME('PtSch_' + @SchemaName + '_' + @TableName ,'[') + 
				' AS PARTITION ' + QUOTENAME('PtFunc_' + @SchemaName + '_' + @TableName ,'[') + ' TO (';

SET @sqlPFunc = CONCAT('CREATE PARTITION FUNCTION ', 
						QUOTENAME(CONCAT('PtFunc_', @SchemaName, '_', @TableName) ,'['), 
						'(', @PartDataType,') AS RANGE RIGHT FOR VALUES (');

IF (@PartLR = 'R')
	SET @sqlPSch = @sqlPSch + QUOTENAME(@PartFGCurrent, '[') + ', ';

DECLARE @futureLimit DATETIME = DATEADD(DAY, @DaysAhead, CONVERT(DATE,GETDATE()))
--WHILE @PartAHEAD > 0
WHILE @CurBoundaryDate <= @futureLimit
	BEGIN
		--SELECT @DateStart, @CurBoundaryDate, @DateToday, @PartCount, @sqlPSch, @sqlPFunc
		IF (@PartCount > 0) 
			BEGIN
				SET @sqlPSch = @sqlPSch + ', ';
				SET @sqlPFunc = @sqlPFunc + ', ';
			END
		--SET @sqlPSch = @sqlPSch + REPLACE(QUOTENAME(@PartFG, '['), '<<Year>>', );
		SET @sqlPSch = @sqlPSch + REPLACE(QUOTENAME(@PartFGCurrent, '['), '<<Year>>', CONVERT(VARCHAR(4), DATEPART(YEAR, @CurBoundaryDate)));
		SET @sqlPFunc = @sqlPFunc + QUOTENAME(CONVERT(VARCHAR(40), @CurBoundaryDate, 126), '''');
		--IF (@CurBoundaryDate > @DateToday) SET @PartAHEAD = @PartAHEAD - 1;
		SET @PartCount = @PartCount + 1;
		IF @PartInterval = 'DAY'
			SET @CurBoundaryDate = DATEADD(DAY, 1, @CurBoundaryDate);
		ELSE IF @PartInterval LIKE 'DAYS%'
			BEGIN
				SET @CurBoundaryDate = DATEADD(DAY, ISNULL(TRY_PARSE(SUBSTRING(@PartInterval,5,5) AS INT),1), @CurBoundaryDate);
			END;
		ELSE IF @PartInterval = 'WEEK' -- Divide a month into 4 slices or "weeks", more or less
			BEGIN
				IF DATEPART(DAY,@CurBoundaryDate) <= 23 
					SET @CurBoundaryDate = DATEADD(DAY, 8, @CurBoundaryDate);  -- Yes, I know, a real week is 7 days. This works out better
				ELSE
					SET @CurBoundaryDate = DATEADD(MONTH, 1, DATEADD(DAY, -(DATEPART(DAY,@CurBoundaryDate)-1), @CurBoundaryDate)) -- Remainder of the month
			END;
		ELSE IF @PartInterval = 'MONTH'
			SET @CurBoundaryDate = DATEADD(MONTH, 1, @CurBoundaryDate);
		ELSE 
			SET @CurBoundaryDate = DATEADD(MONTH, 1, @CurBoundaryDate);

		--
		--	Get the proper filegroup
		--
		IF (@CurBoundaryDate >= @PartNextFGDate)
			BEGIN
				SET @PartListOffset = @PartListOffset + 1
				SET @PartFGCurrent  = (SELECT [value] FROM STRING_SPLIT(@PartFGS, ',') ORDER BY 1 OFFSET @PartListOffset ROWS FETCH NEXT 1 ROW ONLY);  -- Get the first file group
				SET @PartNextFGDate = (SELECT CONVERT(DATETIME,[value]) FROM STRING_SPLIT(@PartFGDates, ',') ORDER BY 1 OFFSET @PartListOffset ROWS FETCH NEXT 1 ROW ONLY);
				SET @eol = 1  -- Trigger a new output line start
			END

		--
		--	Output output line when it gets to a max length
		--
		IF (LEN(@sqlPFunc) > @maxLineLen) OR (@eol <> 0)
			BEGIN
				INSERT INTO @sqlOutput ( Seq, Cmd )  VALUES( @idFunc, @sqlPFunc )
				SET @sqlPFunc = '    ' -- Default next line indent
				SET @idFunc = @idFunc + 1;
			END;
		IF (LEN(@sqlPSch) > @maxLineLen) OR (@eol <> 0)
			BEGIN
				INSERT INTO @sqlOutput ( Seq, Cmd )  VALUES( @idSch,  @sqlPSch )
				SET @sqlPSch = '    ' -- Default next line indent
				SET @idSch = @idSch + 1;
			END;
		SET @eol = 0;
	END;

IF (@IgnoreAfterDate IS NOT NULL) AND (@CurBoundaryDate < @IgnoreAfterDate)
	BEGIN
		SET @sqlPSch = @sqlPSch + ', ' + REPLACE(QUOTENAME(@PartFGCurrent, '['), '<<Year>>', CONVERT(VARCHAR(4), DATEPART(YEAR, @IgnoreAfterDate)));
		SET @sqlPFunc = @sqlPFunc + ', ' + QUOTENAME(CONVERT(VARCHAR(40), @IgnoreAfterDate, 126), '''');
	END;

IF (@PartLR = 'L')
	SET @sqlPSch = @sqlPSch + ', ' + QUOTENAME(@PartFGCurrent, '[');
SET @sqlPSch = @sqlPSch + ');';
SET @sqlPFunc = @sqlPFunc + ');';

INSERT INTO @sqlOutput ( Seq, Cmd )  VALUES( @idFunc, @sqlPFunc );
INSERT INTO @sqlOutput ( Seq, Cmd )  VALUES( @idSch,  @sqlPSch );



--
--  Print out the results
--
SELECT Cmd FROM @sqlOutput ORDER BY seq;
