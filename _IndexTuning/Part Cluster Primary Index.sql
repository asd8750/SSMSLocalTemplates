ALTER TABLE [dbo].[ProcessCdClExhaust]
	ADD CONSTRAINT [PK_ProcessCdClExhaust] PRIMARY KEY CLUSTERED (LineageID, ReadTime)
	WITH (FILLFACTOR = 75, PAD_INDEX = ON) ON [ptsch_2000_CurPlus3_By_Year_Offset](ReadTime);

CREATE UNIQUE CLUSTERED INDEX [PK_ProcessCdClExhaust] ON [dbo].[ProcessCdClExhaust] (LineageID, ReadTime)
	WITH (DROP_EXISTING=ON, ONLINE=ON, ALLOW_ROW_LOCKS=ON, ALLOW_PAGE_LOCKS=ON, DATA_COMPRESSION=PAGE )
	ON [ptsch_2000_CurPlus3_By_Year_Offset](ReadTime);