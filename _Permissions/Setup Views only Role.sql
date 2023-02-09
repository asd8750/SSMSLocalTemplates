USE [ODS]
CREATE USER [Reports] FOR LOGIN [Reports] WITH DEFAULT_SCHEMA = Reports
GO
CREATE SCHEMA Reports AUTHORIZATION Reports --Auth as Reports was the key piece of information that I had missed.
GO
CREATE ROLE Reporting AUTHORIZATION db_securityadmin
GO
exec sp_addrolemember @rolename = 'Reporting', @membername = 'Reports'
GO
GRANT SELECT, VIEW DEFINITION ON [dbo].[vwPanelCdCl] TO Reporting;
