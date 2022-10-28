DECLARE @DbLIst	TABLE ( DbID INT, DbName VARCHAR(256), DbRole VARCHAR(32), DbState VARCHAR(128));
DECLARE @DbCmd  NVARCHAR(MAX);

IF(SERVERPROPERTY('IsHadrEnabled') IS NOT NULL)
  AND (SERVERPROPERTY('IsHadrEnabled') = 1)
    BEGIN
		INSERT INTO @DbList (DbID, DbName, DbRole, DbState)
        SELECT   DB.database_id,
				 DB.[name] AS DatabaseName,
				 ISNULL(HARS.role_desc, ISNULL(DBM.mirroring_role_desc, '')) AS DBRole,
				 CASE
					WHEN (DB.state_desc <> 'ONLINE') THEN DB.state_desc
					WHEN (DB.database_id <= 4) THEN 'System DB'
					WHEN (DB.user_access_desc <> 'MULTI_USER') THEN DB.user_access_desc
					WHEN (DB.source_database_id IS NOT NULL) THEN 'SNAPSHOT'
					WHEN ((DBM.mirroring_state_desc IS NULL)
                      OR (DBM.mirroring_role_desc = 'PRINCIPAL')) THEN 'OK'
					WHEN ((HARS.role_desc IS NULL)
                      OR (HARS.role_desc = 'PRIMARY'))	THEN 'OK'
					ELSE 'OK'
					END AS DbState

				 --,DB.*
                -- ,DBM.*
            FROM sys.databases DB
                 INNER JOIN sys.database_mirroring DBM
                      ON(DB.database_id = DBM.database_id)
				 LEFT OUTER JOIN (sys.dm_hadr_database_replica_states HDRS
		INNER JOIN  sys.dm_hadr_availability_replica_states HARS
			ON (HDRS.replica_id = HARS.replica_id) AND (HDRS.group_id = HARS.group_id)
				AND (HDRS.is_local = 1) AND (HARS.is_local = 1))
					ON (DB.database_id = HDRS.database_id) 
     --       WHERE 
				 --(DB.state_desc = 'ONLINE')
				 --AND (DB.database_id > 4)
     --            AND (DB.user_access_desc = 'MULTI_USER')
     --            AND (DB.source_database_id IS NULL)
     --            AND ((DBM.mirroring_state_desc IS NULL)
     --                 OR (DBM.mirroring_role_desc = 'PRINCIPAL'))
     --            AND ((HARS.role_desc IS NULL)
     --                 OR (HARS.role_desc = 'PRIMARY'))
            ORDER BY DB.database_id;
    END;
    ELSE
    BEGIN;
		INSERT INTO @DbList (DbID, DbName, DbRole, DbState)
        SELECT   DB.database_id,
				 DB.[name] AS DatabaseName,
				 COALESCE(DBM.mirroring_role_desc, '') AS DBRole,
				 CASE
					WHEN (DB.state_desc <> 'ONLINE') THEN DB.state_desc
					WHEN (DB.database_id <= 4) THEN 'System DB'
					WHEN (DB.user_access_desc <> 'MULTI_USER') THEN DB.user_access_desc
					WHEN (DB.source_database_id IS NOT NULL) THEN 'SNAPSHOT'
					WHEN ((DBM.mirroring_state_desc IS NULL)
                      OR (DBM.mirroring_role_desc = 'PRINCIPAL')) THEN 'OK'
					ELSE 'OK'
					END AS DbState
            FROM sys.databases DB
                 INNER JOIN sys.database_mirroring DBM
                      ON(DB.database_id = DBM.database_id)
            --WHERE(DB.[database_id] > 4)
            --     AND (DB.state_desc = 'ONLINE')
            --     AND (DB.user_access_desc = 'MULTI_USER')
            --     AND (DB.source_database_id IS NULL)
            --     AND ((DBM.mirroring_state_desc IS NULL)
            --          OR (DBM.mirroring_role_desc = 'PRINCIPAL'))
            ORDER BY DB.database_id;
    END;
	SELECT *
		FROM @DbList;

WITH DData AS (
	SELECT 'SELECT   CAST(SERVERPROPERTY(''ComputerNamePhysicalNetBIOS'') AS VARCHAR(256)) AS ServerName, '+ CHAR(13) +
			'	CAST(DB_NAME(DB_ID(' + QUOTENAME(DbName, '''') +')) AS VARCHAR(256)) AS DatabaseName, '+ CHAR(13) +
			'	COL.[TABLE_SCHEMA], '+ CHAR(13) +
			'	COL.[TABLE_NAME], '+ CHAR(13) +
			'	COL.[COLUMN_NAME], '+ CHAR(13) +
			'	COL.[ORDINAL_POSITION], '+ CHAR(13) +
			'	COL.[COLUMN_DEFAULT], '+ CHAR(13) +
			'	COL.[IS_NULLABLE], '+ CHAR(13) +
			'	COL.[DATA_TYPE], '+ CHAR(13) +
			'	COL.[CHARACTER_MAXIMUM_LENGTH], '+ CHAR(13) +
			'	COL.[CHARACTER_OCTET_LENGTH], '+ CHAR(13) +
			'	COL.[NUMERIC_PRECISION], '+ CHAR(13) +
			'	COL.[NUMERIC_PRECISION_RADIX], '+ CHAR(13) +
			'	COL.[NUMERIC_SCALE], '+ CHAR(13) +
			'	COL.[DATETIME_PRECISION], '+ CHAR(13) +
			'	COL.[CHARACTER_SET_CATALOG], '+ CHAR(13) +
			'	COL.[CHARACTER_SET_SCHEMA], '+ CHAR(13) +
			'	COL.[CHARACTER_SET_NAME], '+ CHAR(13) +
			'	COL.[COLLATION_CATALOG], '+ CHAR(13) +
			'	COL.[COLLATION_SCHEMA], '+ CHAR(13) +
			'	COL.[COLLATION_NAME], '+ CHAR(13) +
			'	COL.[DOMAIN_CATALOG], '+ CHAR(13) +
			'	COL.[DOMAIN_SCHEMA], '+ CHAR(13) +
			'	COL.[DOMAIN_NAME] '+ CHAR(13) +
		'	FROM ' + QUOTENAME(DbName, '[') +'.[INFORMATION_SCHEMA].[TABLES] TBL '+ CHAR(13) +
        '		INNER JOIN ' + QUOTENAME(DbName, '[') +'.[INFORMATION_SCHEMA].[COLUMNS] COL '+ CHAR(13) +
        '			ON(TBL.TABLE_CATALOG = COL.TABLE_CATALOG) '+ CHAR(13) +
        '				AND (TBL.TABLE_SCHEMA = COL.TABLE_SCHEMA) '+ CHAR(13) +
        '				AND (TBL.TABLE_NAME = COL.TABLE_NAME) '+ CHAR(13) +
		'	WHERE(TBL.TABLE_TYPE = ''BASE TABLE'')' AS  DbInfoCmd
	FROM @DbList
	WHERE (DbState = 'OK')
	)

SELECT @DbCmd = COALESCE(@DbCmd + ' UNION ALL ' + CHAR(13), '') + DbInfoCmd
FROM DData;

EXEC ( @DbCmd ) ;


