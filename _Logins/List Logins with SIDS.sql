--	Convert SID binary to string SID string format
--
--	Binary SID format derived from VBScript code:  https://froosh.wordpress.com/2005/10/21/hex-sid-to-decimal-sid-translation/
--  - Robin Frousheger - Oct 21, 2005
--
--	List of Well Known Sids - https://support.microsoft.com/en-us/topic/0fdcaf87-ee5e-8929-e54c-65e04235a634
--	- S-1-1-5-18 - Local System
--	- S-1-5-80-xxxx-xxx-xxx  - NT Service (An NT Service account prefix.)
--	
--	TSQL Version - F. LaForest - Dec 17, 2021
--	This version loads binary SIDS from an instances sys.server_principals DMV.  Some intermediate CTE table have columns for development/debug/discovery purposes only.
--
--	History:
--	2022-01-24 - F. LaForest - Eliminated the CONCAT function since it wasn't supported by SQL 2012.
--

DECLARE @Domain VARCHAR(100),
        @key VARCHAR(100);
SET @key = 'SYSTEM\ControlSet001\Services\Tcpip\Parameters\';
EXEC master..xp_regread @rootkey = 'HKEY_LOCAL_MACHINE',
                        @key = @key,
                        @value_name = 'Domain',
                        @value = @Domain OUTPUT;
WITH FullSID
  AS
  (
      SELECT FSD.principal_id,
			 FSD.sid,
             CASE
                 WHEN FSD.SidFirstAuthGroup = 18 THEN
                     'SYSTEM'
                 WHEN FSD.SidFirstAuthGroup = 21 THEN
                     'DOMAIN'
                 WHEN FSD.SidFirstAuthGroup = 80 THEN
                     'SERVICE'
                 ELSE
                     'OTHER'
             END AS SidType,
             CASE
                 WHEN FSD.SidFirstAuthGroup = 21 THEN
                     LEFT(FSD.BigSid, LEN (FSD.BigSid) - CHARINDEX ('-', REVERSE (FSD.BigSid)))
                 ELSE
                     ''
             END AS DomainSid,
             FSD.BigSid
         FROM
             (
                 SELECT SP.principal_id,
						SP.sid,
                        SP.[name] AS LoginName,
                        --CONCAT (
                                   'S-' +
                                   CONVERT (VARCHAR(3), CONVERT (INT, SUBSTRING (SP.sid, 1, 1))) +
                                   '-' +                                                           -- SID version
                                   CONVERT (VARCHAR(15), CONVERT (INT, SUBSTRING (SP.sid, 3, 6))) + -- SID authority group
                            (
                                SELECT TOP ( 10 )
                                       '-'
                                       + CONVERT (
                                                     VARCHAR(12),
                                                     CONVERT (
                                                                 BIGINT,
                                                                 CONVERT (BINARY(4), REVERSE (CONVERT (BINARY(4), SUBSTRING (SP.sid, ( POS.GrpNum * 4 ) + 5, 4))))
                                                             )
                                                 ) -- Sid auth sub group
                                   FROM
                                       (
                                           SELECT ROW_NUMBER () OVER ( ORDER BY ( SELECT NULL )) AS GrpNum
                                              FROM sys.objects
                                       ) POS -- Return a number sequence 1, 2, 3, 4, ...
                                   WHERE
                                    ( POS.GrpNum <= CONVERT (INT, SUBSTRING (SP.sid, 2, 1))) -- Number of Sid authority subgroups
                                   ORDER BY GrpNum
                                FOR XML PATH ('')
                            )
                                AS BigSid,
                        CONVERT (BIGINT, CONVERT (BINARY(4), REVERSE (CONVERT (BINARY(4), SUBSTRING (SP.sid, 9, 4))))) AS SidFirstAuthGroup
                    FROM sys.server_principals SP
                    WHERE
                     ( SP.[type] IN ( 'U', 'G' ))
             ) FSD -- Only consider Windows User or Widnows Group
  )
   SELECT @@SERVERNAME AS ServerName,
          @Domain AS ServerDomain,
		  SP.principal_id,
		  SP.[sid],
		  SP.[name] AS LoginName,
		  SP.[type_desc] AS LoginType,
		  SP.[is_disabled],
		  SP.create_date,
		  SP.modify_date,
		  SP.default_database_name,
		  --SP.owning_principal_id,
          FSID.SidType,
          FSID.DomainSid,
          FSID.BigSid AS SSID
      FROM sys.server_principals SP
		LEFT OUTER JOIN FullSID FSID
			ON (SP.principal_id = FSID.principal_id)
	  WHERE ([type] IN ('R','S','G', 'U'))
      ORDER BY LoginType, LoginName;
