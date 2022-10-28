SET NOCOUNT ON;

--	C R E A T E   P A R T I T I O N   S C H E M E   &   F U N C T I O N
--

--	Author: F. LaForest
--	Purpose:  Create a matching set of a partitioning function and the partitioning scheme.  Usually targeted at one table.
--			  
--	History: 2020-01-01 - F.LaForest - Intial version written in 2020
--			 2021-04-27 - F.LaForest - Placed some documentation on the input parameters
--			 2022-02-14 - F.LaForest - Adapeted to handle SubID as partition key
--		

-- ========================================================================================================
--	Lines to change are below
-- ========================================================================================================

--	Table information
--
DECLARE @SchemaName VARCHAR(64) = 'WIP';				-- Schema name of the table to be partitioned
DECLARE @TableName	VARCHAR(64) = 'Accepts';			-- Table name
DECLARE @PartDataType VARCHAR(64) = 'varchar(15)';		-- Datatype of the partitioning column

DECLARE	@DateStart	DATETIME = '2019-06-01';			-- The "date" (YYYYMM) BEFORE all the rows to be partitioned (usually the first of the month before the date of the first data row)

DECLARE @IgnoreAfterDate DATETIME = '20300101'	-- If not null, then provide a boundary at this date for ignoring bad data AFTER this date (Used only to contain data with dates in the far future)

--	Define the partitioning interval
--
DECLARE @PartFGS		VARCHAR(64) = 'PRIMARY';		-- List of filegroups to use (comma separated)
DECLARE @PartFGDates	VARCHAR(1000) = '2199-01-01'	-- List of dates showing the date when we switch to the NEXT filegroup in the list (commas separated)

--	Define the filegroups and when to switch
--
--	YEAR, MONTH, WEEK, DAY
--
DECLARE @PartIntervals	VARCHAR(500) = 'MONTH';			-- Initial partitioning interval <comma> Date to switch the the next interval <comma> Next partitioning interval .........
--DECLARE @PartIntervals	VARCHAR(500) = 'YEAR,20180101,WEEK'; 

DECLARE @PartsAhead		INT = 90;						-- Pre-allocate XX number of partitions into the future 

DECLARE @PartLR			CHAR(1) = 'R';					-- L-RANGE LEFT, R-RANGE RIGHT

DECLARE @maxLineLen		INT = 120;						-- Maximum length of generated script lines

-- ========================================================================================================
--	Do not change any lines below this point 
-- ========================================================================================================

--	Internal variable setup
--
DECLARE	@sqlPFunc	VARCHAR(2000) = '';
DECLARE @sqlPSch	VARCHAR(2000) = '';

DECLARE @SubsetWidth INT;

DECLARE	@DateToday	DATETIME = CAST(GETDATE() AS DATE);
DECLARE @PartCount	INT = 0;

DECLARE @SubIDLen VARCHAR(5)		-- Parse the partition column datatype VARCHAR to find the max column width
SET @SubIDLen = SUBSTRING(@PartDataType, CHARINDEX('(', @PartDataType)+1,4);
SET @SubIDLen = SUBSTRING(@SubIDLen, 1, CHARINDEX(')', @SubIDLen)-1)

--	Output tables
DECLARE @sqlOutput	TABLE (Seq INT NOT NULL, Cmd VARCHAR(1000) NOT NULL);

DECLARE @idFunc		INT = 1;
DECLARE @idSch		INT = 100000;
DECLARE @CurBoundaryDate	DATETIME = @DateStart;

DECLARE @PartFGCurrent VARCHAR(64);  -- Current Filegroup
DECLARE @PartNextFGDate DATETIME
DECLARE @PartListOffset INT = 0;

SET @PartFGCurrent  = (SELECT TOP (1) [value] FROM STRING_SPLIT(@PartFGS, ','));  -- Get the first file group
SET @PartNextFGDate = (SELECT TOP (1) CONVERT(DATETIME,value) FROM STRING_SPLIT(@PartFGDates, ','));

DECLARE @eol INT = 0;   -- Set non-zero to trigger a new line

--  Build the partition width table
--
DECLARE @iCurrent INT = 1, @iNext INT;
DECLARE @intervals TABLE ( PtWidth	VARCHAR(20), PtEndDate DATETIME, PtFG VARCHAR(128));

DECLARE @IntervalWidth		VARCHAR(500);
DECLARE @IntervalBoundary	DATETIME; 

WHILE (@iCurrent < LEN(@PartIntervals))
  BEGIN
    SET @IntervalWidth = SUBSTRING(@PartIntervals, @iCurrent, ((LEN(@PartIntervals)-@iCurrent)+1));
	SET @IntervalBoundary = CONVERT(DATETIME, '21990101');
	SET @iNext = CHARINDEX(',',@PartIntervals,@iCurrent);
	IF (@iNext > 0)
	  BEGIN	
		SET @iNext = IIF((@iNext <= 0), (LEN(@PartIntervals)+1), @iNext);
		SET @IntervalWidth = SUBSTRING(@PartIntervals, @iCurrent, (@iNext - @iCurrent));
		SET @iCurrent = @iNext + 1;
		IF (@iCurrent < LEN(@PartIntervals))
		  BEGIN
			SET @iNext = CHARINDEX(',',@PartIntervals,@iCurrent);
			IF (@iNext > 0)
				SET @IntervalBoundary = CONVERT(DATETIME, SUBSTRING(@PartIntervals, @iCurrent, (@iNext - @iCurrent)));
			ELSE
				SET @iNext = LEN(@PartIntervals) + 1;
		  END
	  END
	ELSE
	  BEGIN
		SET @iNext = LEN(@PartIntervals) + 1;
	  END
	INSERT @intervals (PtWidth, PtEndDate) VALUES (@IntervalWidth, @IntervalBoundary);
	SET @iCurrent = @iNext + 1
  END

--
--	Start building the CREATE PARTION SCHEME and FUNCTION statements now
--

SET @sqlPSch = 'CREATE PARTITION SCHEME ' + QUOTENAME('PtSch_SubID_' + @SubIDLen + '_' + @SchemaName + '_' + @TableName ,'[') + 
				' AS PARTITION ' + QUOTENAME('PtFunc_SubID_' + @SubIDLen + '_' + @SchemaName + '_' + @TableName ,'[') + ' TO (';

SET @sqlPFunc = CONCAT('CREATE PARTITION FUNCTION ', 
						QUOTENAME(CONCAT('PtFunc_SubID_', @SubIDLen + '_' + @SchemaName, '_', @TableName) ,'['), 
						'(', @PartDataType,') AS RANGE RIGHT FOR VALUES (');

IF (@PartLR = 'R')
	SET @sqlPSch = @sqlPSch + QUOTENAME(@PartFGCurrent, '[') + ', ';

-- Now Get the current date and determine how far into the future to create partitions
--
DECLARE @futureLimit DATETIME;
SELECT	TOP (1)
		@IntervalBoundary = PtEndDate,
		@IntervalWidth = PtWidth
	FROM @intervals
	WHERE (PtEndDate > CONVERT(DATE,GETDATE()))
	ORDER BY PtEndDate ASC;

IF @IntervalWidth = 'MONTH'
	SET @futureLimit = DATEADD(MONTH, @PartsAhead, CONVERT(DATE, DATEADD(DAY, 1, GETDATE())));
ELSE IF @IntervalWidth = 'YEAR'
	BEGIN
		SET @futureLimit = DATEADD(YEAR, 1, CONVERT(DATE, DATEADD(DAY, 1, GETDATE())));
		SET @PartsAhead = 2
	END
ELSE
	SET @futureLimit = DATEADD(MONTH, @PartsAhead, CONVERT(DATE, DATEADD(DAY, 1, GETDATE())));


--	Start generating the individual partitions from the given first date
--
WHILE (@CurBoundaryDate < DATEADD(DAY, 1, GETDATE())) OR (@PartsAhead > 0)
	BEGIN
		SELECT	TOP (1)
				@IntervalBoundary = PtEndDate,
				@IntervalWidth = PtWidth
			FROM @intervals
			WHERE (PtEndDate > @CurBoundaryDate)
			ORDER BY PtEndDate ASC

		--SELECT @DateStart AS DateStart, @CurBoundaryDate AS CurBoundaryDate, @DateToday AS DateToday, @PartCount AS PartCount, @PartsAhead AS PartsAhead, @sqlPSch AS sqlPSch, @sqlPFunc AS sqlPFunc;

		DECLARE @DateStr VARCHAR(25) = CONVERT(VARCHAR(25), @CurBoundaryDate, 23)
		IF @IntervalWidth = 'MONTH'				
			SET @sqlPFunc = CONCAT(@sqlPFunc, CASE WHEN (@PartCount > 0) THEN ', ' ELSE '' END, QUOTENAME(SUBSTRING(@DateStr,3,2)+SUBSTRING(@DateStr,6,2), ''''));
		ELSE IF @IntervalWidth = 'YEAR'
			SET @sqlPFunc = CONCAT(@sqlPFunc, CASE WHEN (@PartCount > 0) THEN ', ' ELSE '' END, QUOTENAME(SUBSTRING(@DateStr,3,2), ''''));
		ELSE 
			SET @sqlPFunc = CONCAT(@sqlPFunc, CASE WHEN (@PartCount > 0) THEN ', ' ELSE '' END, QUOTENAME(SUBSTRING(@DateStr,3,2)+SUBSTRING(@DateStr,6,2), ''''));

		SET @sqlPSch = @sqlPSch + CASE WHEN (@PartCount > 0) THEN ', ' ELSE '' END + REPLACE(QUOTENAME(@PartFGCurrent, '['), '<<Year>>', CONVERT(VARCHAR(4), DATEPART(YEAR, @CurBoundaryDate)));

		SET @PartCount = @PartCount + 1;
		SET @PartsAhead = CASE WHEN (@CurBoundaryDate < DATEADD(DAY, 1, GETDATE())) THEN @PartsAhead ELSE @PartsAhead -1 END;

		IF @IntervalWidth = 'MONTH'
			SET @CurBoundaryDate = DATEADD(MONTH, 1, @CurBoundaryDate);
		ELSE IF @IntervalWidth = 'YEAR'
			SET @CurBoundaryDate = DATEADD(YEAR, 1, @CurBoundaryDate);
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
		SET @DateStr = CONVERT(VARCHAR(25), @IgnoreAfterDate, 23)
		IF @IntervalWidth = 'MONTH'				
			SET @sqlPFunc = CONCAT(@sqlPFunc, ', ', QUOTENAME(SUBSTRING(@DateStr,3,2)+SUBSTRING(@DateStr,6,2), ''''));
		ELSE IF @IntervalWidth = 'YEAR'
			SET @sqlPFunc = CONCAT(@sqlPFunc, ', ', QUOTENAME(SUBSTRING(@DateStr,3,2), ''''));
		ELSE 
			SET @sqlPFunc = CONCAT(@sqlPFunc, ', ', QUOTENAME(SUBSTRING(@DateStr,3,2)+SUBSTRING(@DateStr,6,2), ''''));
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
