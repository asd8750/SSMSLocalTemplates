Set NOCOUNT ON
--Author: Saleem Hakani (http://sqlcommunity.com)
--This procedure allows you to check if your server workload can benefit from "Optimize for Ad Hoc Workload" Server Setting.
DECLARE @AdHocWorkloadSize decimal (14,2), 
        @TotalSizeInMB decimal (14,2),
        @AdHocSetting Varchar(20)
 
SELECT @AdHocWorkloadSize = SUM(CAST(
(
CASE 
   WHEN usecounts = 1 AND LOWER(objtype) = 'adhoc' THEN size_in_bytes
   ELSE 0
END
) as decimal(14,2))) / 1048576,
   @TotalSizeInMB = SUM (CAST (size_in_bytes as decimal (14,2))) / 1048576
   FROM sys.dm_exec_cached_plans
 
IF @AdHocWorkloadSize > 200 or ((@AdHocWorkloadSize / @TotalSizeInMB) * 100) > 25
Begin
   Select @AdHocSetting='ENABLE'
End
Else
Begin 
   Select @AdHocSetting='DO NOT ENABLE'
End
   
Select  @AdHocSetting as Recommendation, 
		@AdHocWorkloadSize as [Single_Plan_Memory_Usage],
		@TotalSizeInMB as [Cache Plan Size_MB],
		CAST((@AdHocWorkloadSize / @TotalSizeInMB) * 100 as decimal(14,2)) as [%_of_Single_Plan_Cache_Used]
