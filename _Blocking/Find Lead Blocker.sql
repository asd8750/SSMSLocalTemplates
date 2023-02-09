SELECT  loginame ,
        cpu ,
        memusage ,
        physical_io ,
        *
FROM    master..sysprocesses a
WHERE   EXISTS ( SELECT b.*
                 FROM   master..sysprocesses b
                 WHERE  b.blocked > 0
                        AND b.blocked = a.spid )
        AND NOT EXISTS ( SELECT b.*
                         FROM   master..sysprocesses b
                         WHERE  b.blocked > 0
                                AND b.spid = a.spid )
ORDER BY spid
