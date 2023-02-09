select spid, status, loginame, hostname, blocked, db_name(dbid), cmd 
from master..sysprocesses 
order by hostname, loginame