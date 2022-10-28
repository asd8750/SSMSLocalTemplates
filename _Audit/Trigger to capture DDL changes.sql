ALTER TRIGGER object_changes
ON DATABASE
FOR CREATE_TABLE,DROP_TABLE,ALTER_TABLE,CREATE_VIEW,DROP_VIEW,ALTER_VIEW,CREATE_PROCEDURE,DROP_PROCEDURE,ALTER_PROCEDURE
AS 
   DECLARE @data XML = EVENTDATA();
   DECLARE @eventType nvarchar(100)= CONCAT ('EVENT: ',@data.value('(/EVENT_INSTANCE/EventType)[1]', 'nvarchar(100)'),+ CHAR(13));
   DECLARE @TsqlCommand nvarchar(2000)=CONCAT('COMMAND:   ',@data.value('(/EVENT_INSTANCE/TSQLCommand)[1]', 'nvarchar(2000)'));

   DECLARE @Subject NVARCHAR(200) = 'The following object(s) was/were changed';
   --DECLARE @BodyMsg nvarchar(2100) = CONCAT(@eventType,@TsqlCommand);
   DECLARE @BodyMsg nvarchar(2100) = CONVERT(VARCHAR(3000), @data);
 
   EXEC msdb.dbo.sp_send_dbmail  
   @profile_name = 'DBA_Admin_Alerts',  
   @recipients = 'fred.laforest@firstsolar.com',  
   @body = @BodyMsg,
   @subject = @Subject;