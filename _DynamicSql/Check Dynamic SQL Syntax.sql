-- =============================================
-- Author:  Eli Leiba
-- Create date: 06-2017
-- Description: Check Dynamic SQL Statement Syntax
-- =============================================
CREATE FUNCTION dbo.CheckDynaSQL
    (
        @p1 VARCHAR(2000)
    )
RETURNS VARCHAR(1000)
AS
    BEGIN
        DECLARE @Result VARCHAR(1000);

        IF EXISTS (   SELECT 1
                      FROM   sys.dm_exec_describe_first_result_set(@p1, NULL, 0)
                      WHERE  [error_message] IS NOT NULL
                             AND [error_number] IS NOT NULL
                             AND [error_severity] IS NOT NULL
                             AND [error_state] IS NOT NULL
                             AND [error_type] IS NOT NULL
                             AND [error_type_desc] IS NOT NULL
                  )
            BEGIN
                SELECT @Result = [error_message]
                FROM   sys.dm_exec_describe_first_result_set(@p1, NULL, 0)
                WHERE  column_ordinal = 0;
            END;
        ELSE
            BEGIN
                SET @Result = 'OK';
            END;

        RETURN ( @Result );
    END;
GO