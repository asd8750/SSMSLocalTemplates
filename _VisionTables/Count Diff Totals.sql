WITH SRC AS (
	SELECT	VT.[DataCollectionConfigurationId],
			COUNT(*) AS RowCnt
		FROM [ProcessData].[Vision].[Job] VT WITH (NOLOCK)
		WHERE (VT.LastModifiedTime >= '2019-02-01 00:00:00')
		GROUP BY VT.[DataCollectionConfigurationId]
		--ORDER BY VT.[DataCollectionConfigurationId]
		),
	DST AS (
	SELECT	VT.[DataCollectionConfigurationId],
			COUNT(*) AS RowCnt
		FROM [ProcessData].[DBA-STG].[Job] VT WITH (NOLOCK)
		WHERE (VT.LastModifiedTime >= '2019-02-01 00:00:00')
		GROUP BY VT.[DataCollectionConfigurationId]
		--ORDER BY VT.[DataCollectionConfigurationId];
		)
	SELECT	SRC.DataCollectionConfigurationId,
			SRC.RowCnt AS SrcRowCnt,
			ISNULL(DST.RowCnt, 0) AS DstRowCnt,
			(ISNULL(DST.RowCnt, 0) - SRC.RowCnt) AS Delta
		FROM SRC 
			FULL OUTER JOIN DST	
				ON (SRC.DataCollectionConfigurationId = DST.DataCollectionConfigurationId)
		ORDER BY DataCollectionConfigurationId;


