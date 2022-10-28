WITH SEQS AS (
		SELECT  SERVERPROPERTY('ServerName') AS ThisInstance,
				MS.MasterServerID,
				SEQ.[name] AS SequenceName,
				(CAST(1000000000 AS BIGINT) * MS.MasterServerID) + 1 AS NewMinValue,
				(CAST(1000000000 AS BIGINT) * MS.MasterServerID) + 999999999 AS NewMaxValue,
				SEQ.start_value,
				SEQ.increment,
				SEQ.current_value,
				SEQ.minimum_value,
				SEQ.maximum_value,
				SEQ.user_type_id,
				TYP.[name] AS Datatype
				--,SEQ.*
			FROM sys.sequences SEQ
				CROSS JOIN dbo.vwMasterServers MS
				INNER JOIN sys.types TYP
					ON (SEQ.user_type_id = TYP.user_type_id)
			WHERE (SEQ.[name] LIKE 'seq%')
				--AND (SERVERPROPERTY('ServerName') = MS.ShortInstanceName)

			)

	SELECT CONCAT( 'ALTER SEQUENCE ',
					QUOTENAME(SEQS.SequenceName, '['),
					' INCREMENT BY 1',
					' RESTART WITH ', CONVERT(VARCHAR(11), SEQS.NewMinValue),
					' MINVALUE ', CONVERT(VARCHAR(11), SEQS.NewMinValue),
					' MAXVALUE ', CONVERT(VARCHAR(11), SEQS.NewMaxValue),
					' NO CYCLE'
					)
		FROM SEQS
		WHERE (SEQS.current_value < SEQS.NewMinValue);

--  ALTER SEQUENCE [seqXferTranID] INCREMENT BY 1 RESTART WITH 1000000001 MINVALUE 1000000001 MAXVALUE 1999999999 NO CYCLE


INSERT INTO dbo.XferTransaction ( XferAction, Details, DateInserted )
VALUES
(               -- XferTransactionID - bigint
    'Something',           -- XferAction - varchar(40)
    'Whatever',           -- Details - varchar(4000)
    SYSDATETIME() -- DateInserted - datetime2(7)
    )
 

