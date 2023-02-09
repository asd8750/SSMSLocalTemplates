/****** Script for SelectTopNRows command from SSMS  ******/
SELECT [DefectId]
		,[DataCollectionConfigurationId]
		,[LastModifiedTime]
		,CONCAT('(([DataCollectionConfigurationId] = ',
				CONVERT(VARCHAR(4), [DataCollectionConfigurationId]),
				') AND ([DefectId] > ',
				CONVERT(VARCHAR(20), DefectID),
				')) OR'
		) AS AndWhere
	FROM (
		SELECT [DefectId]
			  ,[DataCollectionConfigurationId]
			  ,[LastModifiedTime]
			  , ROW_NUMBER() OVER (PARTITION BY [DataCollectionConfigurationId]  ORDER BY DefectId DESC) AS Rownum
		  FROM [ProcessData].[DBA-Stg].[Defect_CSI] 
		  WHERE (LastModifiedTime > '2019-04-01 00:00:00') AND (LastModifiedTime < '2019-04-18 00:00:00')
		  ) DF
		WHERE (DF.Rownum = 1)
		ORDER BY [DataCollectionConfigurationId];

/****** Script for SelectTopNRows command from SSMS  ******/
SELECT [DefectId]
		,[DataCollectionConfigurationId]
		,[LastModifiedTime]
		,CONCAT('(([DataCollectionConfigurationId] = ',
				CONVERT(VARCHAR(4), [DataCollectionConfigurationId]),
				') AND ([DefectId] < ',
				CONVERT(VARCHAR(20), DefectID),
				')) OR'
		) AS AndWhere
	FROM (
		SELECT [DefectId]
			  ,[DataCollectionConfigurationId]
			  ,[LastModifiedTime]
			  , ROW_NUMBER() OVER (PARTITION BY [DataCollectionConfigurationId]  ORDER BY DefectId) AS Rownum
		  FROM [ProcessData].[DBA-Stg].[Defect_CSI] 
		  WHERE (LastModifiedTime >= '2019-04-18 00:00:00') --AND (LastModifiedTime < '2019-03-02 00:00:00')
		  ) DF
		WHERE (DF.Rownum = 1)
		ORDER BY [DataCollectionConfigurationId];
