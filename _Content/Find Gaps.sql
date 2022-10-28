
-- DROP TABLE [DBA].[Gaps]

IF (OBJECT_ID('tempdb..#islands') IS NOT NULL)  DROP TABLE [#islands];
CREATE TABLE [#islands] (
	EquipmentID		VARCHAR(25) NOT NULL,
	GrpID			INT			NOT NULL,
	PD_Start		BIGINT		NOT NULL,
	PD_End			BIGINT		NOT NULL
)

DECLARE	@PtNum	INT = 2;

WHILE (@PtNum <= 160)
  BEGIN
	RAISERROR ('Starting Partition %i', 0, 1, @PtNum) WITH NOWAIT;
	;WITH  cte2 AS (

			SELECT	TOP (2000000000)
					EquipmentID,
					ProcessData_ID,
					ProcessData_ID - ROW_NUMBER() OVER (PARTITION BY EquipmentID  ORDER BY ProcessData_ID) AS GrpID
				FROM [dbo].[PSLProcessData]
				WHERE ($PARTITION.PtFunc_dbo_PSLProcessData(DateUpdated) = @PtNum)
		)
	INSERT INTO #islands (EquipmentID, GrpID, PD_Start, PD_End) 
		SELECT	EquipmentID, 
				GrpID,
				MIN(ProcessData_ID) AS iStart,
				MAX(ProcessData_ID) AS iEnd
			FROM cte2
			GROUP BY EquipmentID, GrpID
			ORDER BY EquipmentID, iStart;

	SET @PtNum = @PtNum + 1
  END

SELECT	I2.EquipmentID,
		I2.GapStart,
		I2.GapEnd,
		((I2.GapEnd - I2.GapStart) + 1) AS [Rows],
		CONCAT( '((EquipmentID = ',
				QUOTENAME(I2.EquipmentID, ''''),
				') AND (ProcessData_ID BETWEEN ',
				CONVERT(VARCHAR(20), I2.GapStart),
				' AND ',
				CONVERT(VARCHAR(20), I2.GapEnd),
				')) OR  -- Row Count: ',
				CONVERT(VARCHAR(20), ((I2.GapEnd - I2.GapStart) + 1)),
				CHAR(13) + CHAR(10)
			) AS WherePart
	INTO [DBA].[Gaps]
	FROM (
		SELECT  I.EquipmentID,
				I.PD_Start,
				I.PD_End,		
				CASE
					WHEN I.PD_Start = 1 THEN 0
					WHEN LAG(I.PD_END) OVER (PARTITION BY I.EquipmentID ORDER BY I.PD_Start) IS NULL THEN 1
					WHEN LAG(I.PD_END) OVER (PARTITION BY I.EquipmentID ORDER BY I.PD_Start) + 1 = I.PD_Start THEN 0
					ELSE LAG(I.PD_END) OVER (PARTITION BY I.EquipmentID ORDER BY I.PD_Start) + 1
					END AS GapStart,
				I.PD_Start-1 AS GapEnd
			FROM #islands I
			) I2	
	WHERE (I2.GapStart > 0)
	ORDER BY EquipmentID, GapStart

SELECT *
	from [DBA].[Gaps]
	order by EquipmentID, GapStart
