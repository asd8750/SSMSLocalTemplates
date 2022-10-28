EXECUTE AS LOGIN = 'FS\FS100674';  
SELECT * FROM [mfg].[FirstSolarCrew];
SELECT * FROM Global.Equipment;
SELECT * FROM fn_my_permissions('dbo.FinishedGoods', NULL)   
    ORDER BY subentity_name, permission_name ;    
REVERT;  												