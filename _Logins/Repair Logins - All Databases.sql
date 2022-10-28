--EXEC sp_change_users_login 'Auto_Fix', 'GlobalFEDSSIS';

--EXEC sp_change_users_login 'Report';

--EXEC sp_change_users_login 'Auto_Fix', 'user', 'login', 'password';

--EXEC sp_changedbowner 'sa';

-- =================================================================
-- Run the script below to repair orphan logins
-- =================================================================
DECLARE @thisUser VARCHAR(128);
DECLARE @thisSid BINARY(16);
DECLARE @user1 TABLE
    (
      UserName VARCHAR(128) ,
      UserSid BINARY(16)
    );

--
--	Repeat through all user databases
--
DECLARE @curDB CURSOR;
SET 
@curDB = CURSOR FORWARD_ONLY FOR SELECT name AS DBName
	FROM sys.databases
	WHERE (database_id >= 5) AND (state_desc = 'ONLINE');
OPEN @curDB;
DECLARE @DBName VARCHAR(256);

FETCH NEXT FROM @curDB INTO @DBName;
WHILE @@FETCH_STATUS = 0
    BEGIN
		DECLARE @FixCmd NVARCHAR(MAX);
		RAISERROR ('', 0, 1, @DBName);	
		RAISERROR ('Examining: %s', 0, 1, @DBName) WITH NOWAIT;	

--	Repair the logins for the current database
--
		SET @FixCmd = '' + 
					'	USE ' + QUOTENAME(@DBName, '[') + CHAR(13) + 
					'	SET NOCOUNT ON; ' + CHAR(13) + 
					'	DECLARE @thisUser VARCHAR(128); ' + CHAR(13) + 
					'	DECLARE @thisSid BINARY(16); ' + CHAR(13) + 
					'	DECLARE @user1 TABLE ( UserName VARCHAR(128), UserSid BINARY(16) ); ' + CHAR(13) + 
					'	INSERT  @user1 ( UserName, UserSid ) ' + CHAR(13) + 
                	'	EXEC sp_change_users_login ''Report''; ' + CHAR(13) + 

                	'	DECLARE @curUsers CURSOR; ' + CHAR(13) + 
                	'	SET @curUsers = CURSOR FORWARD_ONLY FOR SELECT * FROM @user1; ' + CHAR(13) + 
                	'	OPEN @curUsers; ' + CHAR(13) + 

                	'	FETCH NEXT FROM @curUsers INTO @thisUser, @thisSid  ' + CHAR(13) + 
                	'	WHILE @@FETCH_STATUS = 0 ' + CHAR(13) + 
                	'	    BEGIN  ' + CHAR(13) + 
                	'			--PRINT ''Attempt to fix: '' + @thisUser; ' + CHAR(13) + 
                 	'			BEGIN TRY ' + CHAR(13) + 
                 	'	           EXEC sp_change_users_login ''Auto_Fix'', @thisUser; ' + CHAR(13) + 
                	'			END TRY ' + CHAR(13) + 
                 	'			BEGIN CATCH ' + CHAR(13) + 
                 	'				PRINT ''  Cannot fix: '' + @thisUser; ' + CHAR(13) + 
                 	'			END CATCH ' + CHAR(13) + 
                	'			FETCH NEXT FROM @curUsers INTO @thisUser, @thisSid  ' + CHAR(13) + 
               		'	     END ' + CHAR(13) + 

                	'	CLOSE @curUsers; ' + CHAR(13) + 
                	'	DEALLOCATE @curUsers; ' + CHAR(13) + 
		        	'	DELETE @user1; ' + CHAR(13)

		RAISERROR (@FixCmd, 0, 1) WITH NOWAIT;
		EXEC (@FixCmd);
--
--
		FETCH NEXT FROM @curDB INTO @DBName;
    END;

CLOSE @curDB;
DEALLOCATE @curDB;