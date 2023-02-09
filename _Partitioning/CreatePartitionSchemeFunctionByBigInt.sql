	SET NOCOUNT ON;

DECLARE	@IntStart	BIGINT = 0;
DECLARE @IntInc		BIGINT = 5000000;
DECLARE @IntMax		BIGINT = 500000000

DECLARE @SchemaName VARCHAR(64) = 'erp';
DECLARE @TableName	VARCHAR(64) = 'OBJK';
DECLARE @PartDataType VARCHAR(64) = 'INT';
DECLARE @PartFG		VARCHAR(64) = 'PRIMARY';
DECLARE @PartFG0	VARCHAR(64) = 'PRIMARY';

DECLARE @PartLR		CHAR(1) = 'R';  -- L-RANGE LEFT, R-RANGE RIGHT

DECLARE	@sqlPFunc	VARCHAR(3000) = '';
DECLARE @sqlPSch	VARCHAR(3000) = '';

DECLARE @PartCount	INT = 0;
DECLARE @IntNow		BIGINT;

--  Build the partition schema and function commands
--

SET @sqlPSch = 'CREATE PARTITION SCHEME ' + QUOTENAME('PtSch_' + @SchemaName + '_' + @TableName ,'[') + 
				' AS PARTITION ' + QUOTENAME('PtFunc_' + @SchemaName + '_' + @TableName ,'[') + ' TO (';

SET @sqlPFunc = CONCAT('CREATE PARTITION FUNCTION ', 
						QUOTENAME(CONCAT('PtFunc_', @SchemaName, '_', @TableName) ,'['), 
						'(', @PartDataType,') AS RANGE RIGHT FOR VALUES (');

IF (@PartLR = 'R')
	SET @sqlPSch = @sqlPSch + QUOTENAME(@PartFG0, '[') + ', ';

SET @IntNow = @IntStart
WHILE @IntNow <= @IntMax
	BEGIN
		IF (@PartCount > 0) 
			BEGIN
				SET @sqlPSch = @sqlPSch + ', ';
				SET @sqlPFunc = @sqlPFunc + ', ';
			END
		SET @sqlPSch = @sqlPSch + QUOTENAME(@PartFG, '[');
		SET @sqlPFunc = @sqlPFunc + CONVERT(VARCHAR(25), @IntNow);

		SET @PartCount = @PartCount + 1;
		SET @IntNow = @IntNow + @IntInc;
	END;

IF (@PartLR = 'L')
	SET @sqlPSch = @sqlPSch + ', ' + QUOTENAME(@PartFG0, '[');
SET @sqlPSch = @sqlPSch + ');';
SET @sqlPFunc = @sqlPFunc + ');';

PRINT 'Partitions: ' + CONVERT(VARCHAR(10),@PartCount)
PRINT @sqlPFunc;
PRINT @sqlPSch;