USE [master];

DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10);
DECLARE @version INT;
SET @version =
    (
        SELECT CONVERT(INT, REPLACE(LEFT(CONVERT(VARCHAR, SERVERPROPERTY('ProductVersion')), 2), '.', ''))
    );

DROP TABLE IF EXISTS [#RGInfo];

DROP TABLE IF EXISTS [#RGCmds];
CREATE TABLE #RGCmds ( ID INT IDENTITY(1, 1) NOT NULL, Cmd NVARCHAR(2000) NOT NULL );


SELECT 
			CONCAT(
                 QUOTENAME(OBJECT_SCHEMA_NAME(RSC.classifier_function_id, DB_ID('master')), '['),
                 '.',
                 QUOTENAME(OBJECT_NAME(RSC.classifier_function_id, DB_ID('master')), ']')
             ) 
			AS ClassifierName,
       RSC.classifier_function_id,
       RSC.is_enabled,
       DRSC.is_reconfiguration_pending,
       (
           SELECT COUNT(*)
              FROM sys.resource_governor_resource_pools
              WHERE
               pool_id > 2
       ) AS PoolCnt,
       (
           SELECT COUNT(*)
              FROM sys.resource_governor_workload_groups
              WHERE
               group_id > 2
       ) AS WGroupCnt,
       LTRIM(RTRIM(OBJECT_DEFINITION(RSC.classifier_function_id))) AS FunctionBody
   INTO #RGInfo
   FROM sys.resource_governor_configuration RSC
       CROSS APPLY sys.dm_resource_governor_configuration DRSC;


INSERT INTO #RGCmds ( Cmd )
            SELECT CASE
                       WHEN RG1.classifier_function_id IS NOT NULL THEN
                           CONCAT('ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = NULL)' + @CRLF,
									'GO', @CRLF, @CRLF)
                       ELSE
                           ''
                   END
               FROM #RGInfo RG1
            UNION ALL
            SELECT CASE
                       WHEN RG1.is_enabled > 0 THEN
                           CONCAT('ALTER RESOURCE GOVERNOR DISABLE;' + @CRLF,
									'GO', @CRLF, @CRLF)
                       ELSE
                           ''
                   END
               FROM #RGInfo RG1;

;WITH RG2
   AS
   (
       SELECT TOP ( 2000000000 )
              CASE
                  WHEN RG.[name] IS NOT NULL THEN
                      CONCAT('BEGIN TRY DROP WORKLOAD GROUP ', QUOTENAME(RG.[name], '['), ' END TRY BEGIN CATCH END CATCH;', @CRLF)
                  ELSE
                      ''
              END AS DropGroup,
              CASE
                  WHEN RP.[name] IS NOT NULL THEN
                      CONCAT('BEGIN TRY DROP RESOURCE POOL ', QUOTENAME(RP.[name], '['), ' END TRY BEGIN CATCH END CATCH;', @CRLF)
                  ELSE
                      ''
              END AS DropPool,
              CASE
                  WHEN RP.[name] IS NOT NULL THEN
                      CONCAT(
                                'USE [master]; BEGIN TRY',
                                @CRLF,
                                'CREATE RESOURCE POOL ',
                                QUOTENAME(RP.[name], '['),
                                ' WITH (',
                                @CRLF,
                                '  min_cpu_percent=',
                                CAST(RP.min_cpu_percent AS VARCHAR(3)),
                                ',',
                                @CRLF,
                                '  MAX_CPU_PERCENT=',
                                CAST(RP.max_cpu_percent AS VARCHAR(3)),
                                ',',
                                @CRLF,
                                '  min_memory_percent=',
                                CAST(RP.min_memory_percent AS VARCHAR(3)),
                                ',',
                                @CRLF,
                                '  max_memory_percent=',
                                CAST(RP.max_memory_percent AS VARCHAR(3)),
                                ',',
                                @CRLF,
                                CASE
                                    WHEN @version > 10 THEN
                                        '  cap_cpu_percent=' + CAST(RP.cap_cpu_percent AS VARCHAR(3)) + ','
                                    ELSE
                                        ''
                                END,
                                @CRLF,
                                CASE
                                    WHEN @version > 11 THEN
                                        '  min_iops_per_volume=' + CAST(RP.min_iops_per_volume AS VARCHAR(3)) + ','
                                    ELSE
                                        ''
                                END,
                                @CRLF,
                                CASE
                                    WHEN @version > 11 THEN
                                        '  max_iops_per_volume=' + CAST(RP.max_iops_per_volume AS VARCHAR(3))
                                    ELSE
                                        ''
                                END,
                                @CRLF,
                                '   )  END TRY BEGIN CATCH END CATCH ',
                                @CRLF
                            )
                  ELSE
                      ''
              END AS CreatePool,
              CASE
                  WHEN RG.[name] IS NOT NULL THEN
                      CONCAT(
                                'USE [master]; BEGIN TRY',
                                @CRLF,
                                'CREATE WORKLOAD GROUP ',
                                QUOTENAME(RG.[name], '['),
                                ' WITH (',
                                @CRLF,
                                '   group_max_requests=',
                                CAST(RG.group_max_requests AS VARCHAR(4)),
                                ', ',
                                @CRLF,
                                '   importance=',
                                RG.importance,
                                ', ',
                                @CRLF,
                                '   request_max_cpu_time_sec=',
                                CAST(RG.request_max_cpu_time_sec AS VARCHAR(5)),
                                ', ',
                                @CRLF,
                                '   request_max_memory_grant_percent=',
                                CAST(RG.request_max_memory_grant_percent AS VARCHAR(5)),
                                ', ',
                                @CRLF,
                                '   request_memory_grant_timeout_sec=',
                                CAST(RG.request_memory_grant_timeout_sec AS VARCHAR(5)),
                                ', ',
                                @CRLF,
                                '   max_dop=',
                                CAST(RG.max_dop AS CHAR(2)),
                                @CRLF,
                                '   ) ',
                                @CRLF,
                                '   USING ',
                                QUOTENAME(RP.[name]),
                                ' END TRY BEGIN CATCH END CATCH;',
                                @CRLF
                            )
                  ELSE
                      ''
              END AS CreateGroup
          -- ,RP.*, RG.* 
          FROM sys.resource_governor_resource_pools RP
              FULL OUTER JOIN sys.resource_governor_workload_groups RG
                ON ( RP.pool_id = RG.pool_id )
          WHERE
           ( RG.group_id > 2 )
           AND ( RP.pool_id > 2 )
          ORDER BY
           RG.[name],
           RP.[name]
   )
INSERT INTO #RGCmds ( Cmd )
            SELECT RG2.DropGroup
               FROM RG2
            UNION ALL
            SELECT RG2.DropPool
               FROM RG2
            UNION ALL
            SELECT RG2.CreatePool
               FROM RG2
            UNION ALL
            SELECT RG2.CreateGroup
               FROM RG2
            UNION ALL
            SELECT CONCAT('ALTER RESOURCE GOVERNOR RECONFIGURE;', @CRLF);

INSERT INTO #RGCmds ( Cmd )
VALUES ( N'GO' + @CRLF + @CRLF);

--	Now redefine the classifier function
--
INSERT INTO #RGCmds ( Cmd )
	SELECT	CONCAT('DROP FUNCTION IF EXISTS '+ RG1.ClassifierName, @CRLF,
				'GO', @CRLF, @CRLF)
		FROM #RGInfo RG1;

INSERT INTO #RGCmds ( Cmd )
            SELECT CONCAT(CASE
						   WHEN CHARINDEX('CREATE ', RG1.FunctionBody) > 1 THEN
							   RIGHT(RG1.FunctionBody, LEN(RG1.FunctionBody) - CHARINDEX('CREATE ', RG1.FunctionBody) + 1)
						   ELSE
							   RG1.FunctionBody
                   END, @CRLF,
					'GO', @CRLF, @CRLF)
               FROM #RGInfo RG1
            UNION ALL
            SELECT CONCAT('ALTER RESOURCE GOVERNOR with (CLASSIFIER_FUNCTION = ', RG1.ClassifierName, ');', @CRLF,
									'GO', @CRLF, @CRLF)
               FROM #RGInfo RG1
            UNION ALL
            SELECT CONCAT('ALTER RESOURCE GOVERNOR RECONFIGURE;', @CRLF,
									'GO', @CRLF, @CRLF);

SELECT *
   FROM #RGCmds;

DROP TABLE #RGCmds;
