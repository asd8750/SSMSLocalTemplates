--We will assume that my_table table is in my_published_db and it is part of my_publication.
USE my_published_db
GO
EXEC sp_scriptpublicationcustomprocs @publication='my_publication'