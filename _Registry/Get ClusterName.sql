
SELECT	SERVERPROPERTY('ISCLUSTERED') AS IsClustered,
		ISNULL((SELECT TOP (1) cluster_name FROM sys.dm_hadr_cluster), '') AS ClusterName;

    DECLARE @RegValue NVARCHAR(256);
    EXEC [master].[dbo].[xp_regread] @rootkey=N'HKEY_LOCAL_MACHINE', @key=N'Cluster', @value_name=N'ClusterName', @value=@RegValue OUTPUT;
    SELECT CONVERT(VARCHAR(256), UPPER(@RegValue)) AS ClusterName, NodeName
	    FROM sys.dm_os_cluster_nodes;

SELECT	*
	FROM sys.dm_os_cluster_nodes
