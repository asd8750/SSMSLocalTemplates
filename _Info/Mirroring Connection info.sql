SELECT    *  FROM      sys.dm_exec_connections dec
   inner join sys.dm_db_mirroring_connections ddmc
      on (dec.connection_id = ddmc.connection_id)
	  inner JOIN sys.database_mirroring_endpoints dme
	  on (dec.endpoint_id = dme.endpoint_id)