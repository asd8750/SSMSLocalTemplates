/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000
        MP.[z_TargetCode] ,
        MP.[z_CaptureDateTime] ,
        MP.[Win32_Directory.Name] ,
        MP.[Win32_Volume.DeviceID] ,
        VOL.Capacity ,
        Vol.FreeSpace ,
        CONVERT(DECIMAL(10, 1), CAST(Vol.FreeSpace AS FLOAT)
        / CAST(Vol.Capacity AS FLOAT) * 100.0) AS FreePct ,
        Vol.Label ,
        VOL.*
FROM    [Site].[Info-WMIMountPoints] MP
        INNER JOIN [Status].[tfn_LastTaskStatus]('DBInfoWmi', NULL) LTS ON ( MP.z_CaptureDateTime = LTS.StartTime )
        INNER JOIN [Site].[Info-WMIVolumes] VOL ON ( MP.z_TargetCode = VOL.z_TargetCode )
                                                   AND ( MP.[Win32_Volume.DeviceID] = VOL.DeviceID )
WHERE   MP.z_TargetCode IN ( 3608, 3609 ) -- 3609
        AND VOL.DriveType = 3
ORDER BY 1 ,
        3