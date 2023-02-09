
--SELECT	DATEADD(DAY, -(DatePart(DAY, CAST(CVD.LastModifiedTime AS DATE))-1), CAST(CVD.LastModifiedTime AS DATE)) AS RepDate,
--		COUNT(*) AS [RowCount]

--	FROM Clip.ALTLED_IVData CVD
--	GROUP BY DATEADD(DAY, -(DatePart(DAY, CAST(CVD.LastModifiedTime AS DATE))-1), CAST(CVD.LastModifiedTime AS DATE))
--	ORDER BY RepDate

SELECT	DATEADD(DAY, -(DatePart(DAY, CAST(CVD.LastModifiedTime AS DATE))-1), CAST(CVD.LastModifiedTime AS DATE)) AS RepDate,
		COUNT(*) AS [RowCount]

	FROM Clip.ALTLED_MeasInfo CVD
	GROUP BY DATEADD(DAY, -(DatePart(DAY, CAST(CVD.LastModifiedTime AS DATE))-1), CAST(CVD.LastModifiedTime AS DATE))
	ORDER BY RepDate

