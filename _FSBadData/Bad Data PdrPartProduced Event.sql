/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP (1000) [PdrPartProducedEventId]
      ,[EventTypeId]
      ,[SourceLocation]
      ,[TimestampUtc]
      ,[ID]
      ,[Location]
      ,[EntryProductStatus]
      ,[ExitProductStatus]
      ,[ProcessApplied]
      ,[LastModifiedTimeUtc]
      ,[LastModifiedUser]
      ,[TimeStamp]
  FROM [ModuleAssembly].[ProcessHistory].[PdrPartProducedEvent]
  WHERE $PARTITION.PtFunc_ProcessHistory_PdrPartProducedEvent_V2(TimeStampUtc) = 1;


  DROP TABLE ODS.[DBA].[PdrPartProducedEvent_Latency]
  SELECT DISTINCT 
		SourceLocation,
		COUNT(*) AS RowCnt,
		MIN(PdrPartProducedEventId) AS MinID,
		MAX(PdrPartProducedEventId) AS MaxID,
		MIN(LastModifiedTimeUtc) AS MinLastModifiedTimeUtc,
		MAX(LastModifiedTimeUtc) AS MaxLastModifiedTimeUtc,
		MIN(TimeStampUtc) AS MinTimestampUtc,
		MAX(TimeStampUtc) AS MaxTimestampUtc,
		MIN(CAST(DATEDIFF(MINUTE,TimeStampUtc, LastModifiedTimeUtc) AS DECIMAL(20,2))) AS MinLetency,
		AVG(CAST(DATEDIFF(MINUTE,TimeStampUtc, LastModifiedTimeUtc) AS DECIMAL(20,2))) AS AvgLetency,
		MAX(CAST(DATEDIFF(MINUTE,TimeStampUtc, LastModifiedTimeUtc) AS DECIMAL(20,2))) AS MaxLetency,
		$PARTITION.PtFunc_ProcessHistory_PdrPartProducedEvent_V2(TimeStampUtc) AS PtNum
	INTO ODS.[DBA].[PdrPartProducedEvent_Latency]
	FROM [ModuleAssembly].[ProcessHistory].[PdrPartProducedEvent]
	GROUP BY SourceLocation,
			$PARTITION.PtFunc_ProcessHistory_PdrPartProducedEvent_V2(TimeStampUtc)
	ORDER BY PTNum, SourceLocation

	
