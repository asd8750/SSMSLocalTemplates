SELECT OPAR.name AS TableName, 
		OBJ.*
	FROM sys.objects OPAR
		INNER JOIN sys.objects OBJ
			ON (OPAR.object_id = OBJ.parent_object_id)
	WHERE (OPAR.[type] = 'U')
	ORDER BY OPAR.[name], OBJ.[type], obj.name