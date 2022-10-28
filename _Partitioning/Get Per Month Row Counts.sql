--	Change table name and choice of partitioning column 
--
SELECT	DATEADD(DAY, -(DATEPART(DAY, CAST(CollectedTimeUtc AS DATE))-1), CAST(CollectedTimeUtc AS DATE)) AS RepMonth,
		COUNT(*) AS RCnt
	FROM [ProcessHistory].[InSituARC_Thickness]
	GROUP BY DATEADD(DAY, -(DATEPART(DAY, CAST(CollectedTimeUtc AS DATE))-1), CAST(CollectedTimeUtc AS DATE))
	ORDER BY RepMonth
