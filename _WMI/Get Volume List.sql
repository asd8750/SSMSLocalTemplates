
DECLARE @DrvLetter TABLE (Drive VARCHAR(500))
INSERT INTO @DrvLetter ( Drive )
EXEC xp_cmdshell 'wmic volume where drivetype=3 get caption, freespace, capacity, label'
DELETE FROM @DrvLetter WHERE drive IS NULL OR len(drive) < 4 OR Drive LIKE '%Capacity%' OR Drive LIKE  '%\\%\Volume%'

UPDATE @DrvLetter
	SET DRIVE = RTRIM(LTRIM(REPLACE(REPLACE(REPLACE(Drive,' ','><'), '<>', '') ,'><', ' ')))

SELECT *
	FROM @DrvLetter;

	SELECT	Capacity,
			(Capacity + (1024 * 1024 * 1024) - 1) / (1024 * 1024 * 1024) AS CapacityGB,
			[Path],
			FreeSpace,
			VolLabel,
			(Capacity - FreeSpace) AS UsedSpace,
			(FreeSpace * 100) / Capacity AS FreePct
		FROM (	
			SELECT	Capacity,
					[Path],
					CAST(LEFT(Drive, CHARINDEX(' ', DRIVE)-1) AS BIGINT) AS [FreeSpace],
					RTRIM(RIGHT(Drive, LEN(DRIVE)-CHARINDEX(' ', Drive))) AS VolLabel	
				FROM (	
					SELECT	Capacity,
							LEFT(Drive, CHARINDEX(' ', DRIVE)-1) AS [Path],
							RIGHT(Drive, LEN(DRIVE)-CHARINDEX(' ', Drive)) AS Drive
						FROM (
							SELECT	CAST(LEFT(Drive, CHARINDEX(' ', DRIVE)-1) AS BIGINT) AS Capacity,
									RIGHT(Drive, LEN(DRIVE)-CHARINDEX(' ', Drive)) AS Drive
								FROM @DrvLetter
							) V2
					) V3
			) V4
		WHERE ([V4].[Path] NOT LIKE 'C:%') AND  ([V4].[Path] NOT LIKE 'X:%')
		ORDER BY [V4].[Path]
