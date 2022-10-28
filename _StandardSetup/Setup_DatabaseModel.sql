--	
--	Setup base database settings for the Model database.
--

--	Set the minimum file size and growth increment size
--
USE [master]
GO
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modeldev', SIZE = 1048576KB , FILEGROWTH = 1048576KB )
GO
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modellog', SIZE = 1048576KB , FILEGROWTH = 1048576KB )
GO

--	Setup the Role_ViewDefinitions
--
USE [model]
GO
IF DATABASE_PRINCIPAL_ID('Role_QueryDebug') IS NULL 
	CREATE ROLE [Role_QueryDebug]
GO
GRANT VIEW DEFINITION TO [Role_QueryDebug]
GRANT SHOWPLAN TO [Role_QueryDebug]
GO
