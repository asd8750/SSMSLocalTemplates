
SELECT	PTF.[name] AS PtFunc,
		PTS.[name] AS PtScheme,
		DDSP.destination_id,
		DSP.[name] AS FGName,
		CONCAT('ALTER PARTITION FUNCTION ', 
				QUOTENAME(PTF.[name], '['), 
				'() MERGE RANGE (',
				QUOTENAME(CONVERT(VARCHAR, PTRV.[value], 126), ''''), '); ') + CHAR(13) + CHAR(10) +
		CONCAT('ALTER PARTITION SCHEME ',
				QUOTENAME(PTS.[name], '['), 
				' NEXT USED [FG_2020_Q1Q2]; ') + CHAR(13) + CHAR(10) +
		CONCAT('ALTER PARTITION FUNCTION ', 
				QUOTENAME(PTF.[name], '['), 
				'() SPLIT RANGE (',
				QUOTENAME(CONVERT(VARCHAR, PTRV.[value], 126), ''''), '); ')

	FROM sys.partition_functions PTF
		INNER JOIN sys.partition_schemes PTS
			ON (PTF.function_id = PTS.function_id) 
		INNER JOIN sys.destination_data_spaces DDSP
			ON (PTS.data_space_id = DDSP.partition_scheme_id) 
		INNER JOIN sys.data_spaces DSP
			ON (DDSP.data_space_id = DSP.data_space_id)
		INNER JOIN sys.partition_range_values PTRV
			ON (PTF.function_id = PTRV.function_id) AND (DDSP.destination_id = (PTRV.[boundary_id]+1))

	WHERE (DSP.[name] = 'PRIMARY')