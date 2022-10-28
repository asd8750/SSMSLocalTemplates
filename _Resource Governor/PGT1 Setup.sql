USE master
GO
-- Create Pools
ALTER RESOURCE POOL SQLCPUSLOW
WITH
(
   max_cpu_percent = 40,
   CAP_CPU_PERCENT = 80
)
GO

CREATE WORKLOAD GROUP SQLCPUSLOW
WITH ( MAX_DOP = 2 )
  USING SQLCPUSLOW;
GO

  -- My classifier
IF OBJECT_ID('dbo.ResGovClassifier()','FN') IS NOT NULL
       DROP FUNCTION dbo.ResGovClassifier

USE master

CREATE OR ALTER FUNCTION dbo.ResGovClassifier2()
  RETURNS SYSNAME WITH SCHEMABINDING
AS
BEGIN

      DECLARE @val sysname;
	  SET @val = 'default';
      IF SUSER_SNAME() IN ('FS\zSvc_SAS_Temp_Reader',
							'FS\FS100186')
             SET @val = 'SQLCPUSLOW';

      RETURN @val;
END
GO

USE master
GO
ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = dbo.ResGovClassifier2);

ALTER RESOURCE GOVERNOR RECONFIGURE;