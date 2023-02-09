CREATE TABLE [auditlog].[ChangeLog](
    [ChangeLogID] [int] IDENTITY(1,1) NOT NULL,
    [CreateDate] [datetime] NULL,
    [LoginName] [sysname] NULL,
    [ComputerName] [sysname] NULL,
    [ProgramName] [nvarchar](255) NULL,
    [DBName] [sysname] NOT NULL,
    [SQLEvent] [sysname] NOT NULL,
    [SchemaName] [sysname] NULL,
    [ObjectName] [sysname] NULL,
    [SQLCmd] [nvarchar](max) NULL,
    [XmlEvent] [xml] NOT NULL,
    CONSTRAINT [PK_ChangeLog] PRIMARY KEY CLUSTERED (
	        [ChangeLogID] ASC
    )
) ;