SELECT @@SERVERNAME, SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS ComputerNamePhysicalNetBIOS, 
			SERVERPROPERTY('InstanceName') AS InstanceName, 
			SERVERPROPERTY('IsClustered') AS IsClustered, 
			SERVERPROPERTY('MachineName') AS MachineName,
			SERVERPROPERTY('ServerName') AS ServerName