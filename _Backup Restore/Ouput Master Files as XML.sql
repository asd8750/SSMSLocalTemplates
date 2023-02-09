DECLARE @xmlSrc XML;

SET @xmlSrc = (
SELECT  DB_NAME(database_id) AS dbName ,
        type_desc AS fileType ,
        state_desc AS [state] ,
        name AS logicalName ,
		LEFT(physical_name,LEN(physical_name) - charindex('\',reverse(physical_name),1) + 1) [srcPath],
       REVERSE(LEFT(REVERSE(physical_name),CHARINDEX('\', REVERSE(physical_name), 1) - 1)) [fileName] ,
		'' AS dstPath
FROM    sys.master_files srcPaths
ORDER BY dbName ,
		fileType ,
        logicalName
FOR     XML RAW('database') ,
            ROOT('srcInstance'), TYPE );

SELECT @xmlSrc AS XmlSrc;

--SET @xmlSrc = NULL;

-- SELECT * into tempdb.dbo.tfmasterfiles from sys.master_files

DECLARE @pathTable TABLE (
	dbName			nvarchar(128),
	fileType		nvarchar(60),
	logicalName		nvarchar(128),
	srcPath			nvarchar(260),
	[fileName]		nvarchar(260),
	dstPath			nvarchar(260)
	);

INSERT INTO @pathTable (dbName, fileType, logicalName, srcPath, dstPath, [fileName])
	SELECT r.value('@dbName','nvarchar(128)') AS dbName,
		   r.value('@fileType','nvarchar(60)') AS fileType,
		   r.value('@logicalName','nvarchar(128)') AS logicalName,
		   r.value('@srcPath','nvarchar(260)') AS srcPath,
		   CASE WHEN r.value('@dstPath','nvarchar(260)') IS NULL THEN NULL
				WHEN LEN(r.value('@dstPath','nvarchar(260)')) = 0 THEN NULL
				ELSE r.value('@dstPath','nvarchar(260)') END AS dstPath,
		   r.value('@fileName','nvarchar(260)') AS [fileName]
		FROM @xmlSrc.nodes('/srcInstance/database') AS X(r);

UPDATE @pathTable
	SET srcPath = CASE WHEN RIGHT(srcPath,1) = '\' THEN LEFT(srcPath, LEN(srcPath)-1) ELSE srcPath END,
		dstPath = CASE WHEN dstPath IS NULL THEN NULL WHEN RIGHT(dstPath,1) = '\' THEN LEFT(srcPath, LEN(srcPath)-1) ELSE srcPath END
	WHERE RIGHT(srcPATH,1) = '\';

SELECT * FROM @pathTable;