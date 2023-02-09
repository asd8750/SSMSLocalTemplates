--EXEC sp_change_users_login 'Auto_Fix', 'GlobalFEDSSIS';

--EXEC sp_change_users_login 'Report';

--EXEC sp_change_users_login 'Auto_Fix', 'user', 'login', 'password';

--EXEC sp_changedbowner 'sa';

-- =================================================================
-- Run the script below to repair orphan logins
-- =================================================================
DECLARE @thisUser VARCHAR(128) ;
DECLARE @thisSid BINARY(16) ;
DECLARE @user1 TABLE
    (
      UserName VARCHAR(128) ,
      UserSid BINARY(16)
    ) ;
INSERT  @user1
        ( UserName, UserSid )
        EXEC sp_change_users_login 'Report' ;	
DECLARE @curUsers CURSOR ;
SET @curUsers = CURSOR FOR SELECT * FROM @user1;
OPEN @curUsers ;

FETCH NEXT FROM @curUsers INTO @thisUser, @thisSid 
WHILE @@FETCH_STATUS = 0 
    BEGIN 
        PRINT 'Attempt to fix: ' + @thisUser ;
        BEGIN TRY
            EXEC sp_change_users_login 'Auto_Fix', @thisUser ;
        END TRY
        BEGIN CATCH
            PRINT '  Cannot fix: ' + @thisUser ;
        END CATCH
        FETCH NEXT FROM @curUsers INTO @thisUser, @thisSid 
    END

CLOSE @curUsers ;
DEALLOCATE @curUsers ;


