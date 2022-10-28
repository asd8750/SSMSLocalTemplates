-- =============================================
-- Author: Alejandro Pelc
-- Create date: 02/19/2009
-- Description: List all DBs permission
--
-- =============================================
SET NOCOUNT ON;
DECLARE @permission TABLE (
    Database_Name sysname,
    User_Role_Name sysname,
    Account_Type NVARCHAR(60),
    Action_Type NVARCHAR(128),
    Permission NVARCHAR(60),
    ObjectName sysname NULL,
    Object_Type NVARCHAR(60));
DECLARE @dbs TABLE (dbname sysname);
DECLARE @Next sysname;
INSERT INTO @dbs
SELECT name
  FROM sys.databases
 ORDER BY name;
SELECT TOP 1 @Next = dbname
  FROM @dbs;
WHILE (@@rowcount <> 0)
BEGIN
    INSERT INTO @permission
    EXEC ('use [' + @Next + ']
declare @objects table (obj_id int, obj_type char(2))
insert into @objects
select id, xtype from master.sys.sysobjects
insert into @objects
select object_id, type from sys.objects

SELECT ''' + @Next + ''', a.name as ''User or Role Name'', a.type_desc as ''Account Type'',
d.permission_name as ''Type of Permission'', d.state_desc as ''State of Permission'',
OBJECT_SCHEMA_NAME(d.major_id) + ''.'' + object_name(d.major_id) as ''Object Name'',
case e.obj_type
when ''AF'' then ''Aggregate function (CLR)''
when ''C'' then ''CHECK constraint''
when ''D'' then ''DEFAULT (constraint or stand-alone)''
when ''F'' then ''FOREIGN KEY constraint''
when ''PK'' then ''PRIMARY KEY constraint''
when ''P'' then ''SQL stored procedure''
when ''PC'' then ''Assembly (CLR) stored procedure''
when ''FN'' then ''SQL scalar function''
when ''FS'' then ''Assembly (CLR) scalar function''
when ''FT'' then ''Assembly (CLR) table-valued function''
when ''R'' then ''Rule (old-style, stand-alone)''
when ''RF'' then ''Replication-filter-procedure''
when ''S'' then ''System base table''
when ''SN'' then ''Synonym''
when ''SQ'' then ''Service queue''
when ''TA'' then ''Assembly (CLR) DML trigger''
when ''TR'' then ''SQL DML trigger''
when ''IF'' then ''SQL inline table-valued function''
when ''TF'' then ''SQL table-valued-function''
when ''U'' then ''Table (user-defined)''
when ''UQ'' then ''UNIQUE constraint''
when ''V'' then ''View''
when ''X'' then ''Extended stored procedure''
when ''IT'' then ''Internal table''
end as ''Object Type''
FROM [' + @Next + '].sys.database_principals a 
left join [' + @Next + '].sys.database_permissions d on a.principal_id = d.grantee_principal_id
left join @objects e on d.major_id = e.obj_id
order by a.name, d.class_desc');
    DELETE @dbs
     WHERE dbname = @Next;
    SELECT TOP 1 @Next = dbname
      FROM @dbs;
END;
SET NOCOUNT OFF;
SELECT *
  FROM @permission

ORDER BY [Database_Name], User_Role_Name, Account_Type
