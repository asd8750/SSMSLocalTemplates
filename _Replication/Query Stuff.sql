--	List publishing/distributing databases

SELECT * 
	FROM sys.databases
	WHERE (is_published=1 OR is_merge_published=1 OR is_distributor=1)

--	List subscribers

DECLARE @BIGCMD nvarchar(max);
SELECT @BIGCMD=STUFF((SELECT 'UNION SELECT DISTINCT srvname from [' + RplDB.name + '].dbo.syssubscriptions WHERE LEN(SRVNAME)>0 ' AS 'data()' 
	FROM (select name from sys.databases WHERE (is_published=1 OR is_merge_published=1 OR is_distributor=1)) RplDB FOR XML PATH(''),TYPE).value('text()[1]','nvarchar(max)'), 1, 6, N'');
exec sp_executesql @BIGCMD;
	

