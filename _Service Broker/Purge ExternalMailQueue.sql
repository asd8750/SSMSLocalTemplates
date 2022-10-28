declare @c uniqueidentifier
DECLARE @cntr INT = 0
DECLARE @Msg VARCHAR(1000)
DECLARE @IDX INT;

SET NOCOUNT ON

IF OBJECT_ID('tempdb..#CH') IS NOT NULL
	DROP TABLE #CH;

CREATE TABLE #CH (conversation_handle UNIQUEIDENTIFIER,  RN INT PRIMARY KEY);

while(1=1)
	begin
		INSERT INTO #CH (conversation_handle, RN)
			select	top 1000
					conversation_handle,
					ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RN
				from [dbo].[ExternalMailQueue] WITH (NOLOCK);
		if (@@ROWCOUNT = 0)
			break

		SET @IDX = 1
		
		--SELECT * FROM #CH
		WHILE (1=1)
			BEGIN
				SELECT @c = conversation_handle
					FROM #CH	
					WHERE (RN = @IDX);
				IF @@ROWCOUNT < 1 
					BREAK;
				end conversation @c with cleanup;
				SET @cntr = @cntr + 1
				SET @IDX = @IDX + 1
			END

		SET @Msg =  '... Deleted '+CONVERT(VARCHAR(15), @cntr);
		RAISERROR (@Msg, 0,1) WITH NOWAIT
		TRUNCATE TABLE #CH

		--if (@cntr % 100 = 0)
		--	BEGIN
		--	END
	end

--  ALTER QUEUE [dbo].[ExternalMailQueue] REBUILD WITH (MAXDOP = 2)   

SELECT * FROM #CH
