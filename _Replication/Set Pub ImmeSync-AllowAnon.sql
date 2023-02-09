
 DECLARE @pubName NVARCHAR(256);
 SET @pubName = 'Reporting - RT_Sequence';
 

 EXEC sp_changepublication @publication=@pubName, @property = N'allow_anonymous', @value = false;
 EXEC sp_changepublication @publication=@pubName, @property = N'immediate_sync', @value = false;