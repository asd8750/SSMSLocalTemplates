IF NOT EXISTS (SELECT [name] from master.sys.server_principals WHERE [name] = 'MESViewState' and [type] = 'R')
	CREATE SERVER ROLE [MESViewState] AUTHORIZATION [sa];

EXEC master..sp_addsrvrolemember @loginame = N'MFG\MES DNM Developers', @rolename = N'MESViewState'
EXEC master..sp_addsrvrolemember @loginame = N'MFG\MES KLM Developers', @rolename = N'MESViewState'
EXEC master..sp_addsrvrolemember @loginame = N'MFG\MES PBG Developers', @rolename = N'MESViewState'

GRANT VIEW ANY DEFINITION TO [MESViewState]
GRANT VIEW SERVER STATE TO [MESViewState]