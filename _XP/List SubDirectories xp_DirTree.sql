DECLARE @Path VARCHAR(256) = 'E:\';

DECLARE @dirtree TABLE
(
    ID INT IDENTITY(1, 1),
    subdirectory VARCHAR(256),
    depth INT,
    parent INT,
    fullpath VARCHAR(256) NULL
);

INSERT INTO @dirtree ( subdirectory, depth )
EXEC master.dbo.xp_dirtree @Path;

DECLARE @depth INT = 1;
DECLARE @rCnt INT = 1;
WHILE ( @rCnt > 0 )
BEGIN
    UPDATE C
       SET fullpath = REPLACE(CONCAT(ISNULL(P.fullpath, @Path), '\', C.subdirectory), '\\', '\')
       FROM @dirtree C
           OUTER APPLY
           (
               SELECT TOP ( 1 )
                      ID,
                      fullpath
                  FROM @dirtree D
                  WHERE
                   ( depth = @depth - 1 )
                   AND ( ID < C.ID )
                  ORDER BY ID DESC
           ) P
       WHERE
        ( C.depth = @depth );
    SET @rCnt = @@ROWCOUNT;
    SET @depth = @depth + 1;
END;

SELECT *
   FROM @dirtree
   WHERE
    NOT (( fullpath LIKE '%RECYCLE%' )
         OR ( fullpath LIKE '%System Volume Information%' )
        );