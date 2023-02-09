ALTER TABLE dbo.WorkflowCrosstab
ADD CONSTRAINT PK_WorkflowCrosstab PRIMARY KEY CLUSTERED  
(SubID ASC) WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	ON [ptsch_2007_CurPlus3_By_Year_SubID_20](SubID)

CREATE UNIQUE CLUSTERED INDEX PK_PanelHistory
   ON dbo.PanelHistory (SubID)
   WITH (DROP_EXISTING=ON, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, ONLINE=ON, DATA_COMPRESSION=PAGE, SORT_IN_TEMPDB = OFF)
   ON [ptsch_2007_CurPlus3_By_Year_SubID](SubID)