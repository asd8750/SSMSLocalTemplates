
USE [master];  
DROP CREDENTIAL [https://corpitdatabase0100.blob.core.windows.net/longterm-globalfed-2028-1231];
CREATE CREDENTIAL [https://corpitdatabase0100.blob.core.windows.net/longterm-globalfed-2028-1231] WITH IDENTITY = 'SHARED ACCESS SIGNATURE', 
SECRET = 'sp=racwdl&st=2021-12-01T21:31:28Z&se=2022-01-09T04:59:59Z&spr=https&sv=2020-08-04&sr=c&sig=f2s05ZP6zhe2hvJFHjIZmgdoVnQ8b%2B6zeuC%2FAe2ZuH4%3D';


--
--	https://corpitdatabase0100.blob.core.windows.net/longterm-globalfed-2028-1231
--	sp=racwdl&st=2021-12-01T21:31:28Z&se=2022-01-09T04:59:59Z&spr=https&sv=2020-08-04&sr=c&sig=f2s05ZP6zhe2hvJFHjIZmgdoVnQ8b%2B6zeuC%2FAe2ZuH4%3D
--	https://corpitdatabase0100.blob.core.windows.net/longterm-globalfed-2028-1231?sp=racwdl&st=2021-12-01T21:31:28Z&se=2022-01-09T04:59:59Z&spr=https&sv=2020-08-04&sr=c&sig=f2s05ZP6zhe2hvJFHjIZmgdoVnQ8b%2B6zeuC%2FAe2ZuH4%3D

