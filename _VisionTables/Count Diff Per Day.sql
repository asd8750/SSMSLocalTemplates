WITH SRC AS (
	SELECT	VT.[DataCollectionConfigurationId],
			CAST(VT.LastModifiedTime AS DATE) AS RepDay,
			COUNT(*) AS RowCnt
		FROM [ProcessData].[Vision].[Job] VT WITH (NOLOCK)
		WHERE (VT.LastModifiedTime >= '2019-02-01 00:00:00')
		GROUP BY VT.[DataCollectionConfigurationId], CAST(VT.LastModifiedTime AS DATE)
		--ORDER BY VT.[DataCollectionConfigurationId]
		),
	DST AS (
	SELECT	VT.[DataCollectionConfigurationId],
			CAST(VT.LastModifiedTime AS DATE) AS RepDay,
			COUNT(*) AS RowCnt
		FROM [ProcessData].[DBA-STG].[Job] VT WITH (NOLOCK)
		WHERE (VT.LastModifiedTime >= '2019-02-01 00:00:00')
		GROUP BY VT.[DataCollectionConfigurationId], CAST(VT.LastModifiedTime AS DATE)
		--ORDER BY VT.[DataCollectionConfigurationId];
		)
	SELECT	SRC.DataCollectionConfigurationId,
			SRC.RepDay,
			SRC.RowCnt AS SrcRowCnt,
			ISNULL(DST.RowCnt, 0) AS DstRowCnt,
			(ISNULL(DST.RowCnt, 0) - SRC.RowCnt) AS Delta
		FROM SRC 
			FULL OUTER JOIN DST	
				ON (SRC.DataCollectionConfigurationId = DST.DataCollectionConfigurationId)
				  AND (SRC.RepDay = DST.RepDay)
		ORDER BY RepDay, DataCollectionConfigurationId;


