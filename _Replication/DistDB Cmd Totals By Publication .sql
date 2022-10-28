USE distribution;

WITH    CMDCNT
          AS ( SELECT   db.publisher_db ,
                        cmds.article_id ,
                        art.source_owner ,
                        art.destination_object ,
                        COUNT(*) AS cmd_cnt ,
                        pub.publication AS [Pub Name]
               FROM     [distribution].[dbo].[MSrepl_commands] cmds WITH ( NOLOCK )
                        INNER JOIN [dbo].[MSpublisher_databases] db WITH ( NOLOCK ) ON ( cmds.publisher_database_id = db.id )
                        INNER JOIN [dbo].[MSarticles] art WITH ( NOLOCK ) ON ( cmds.article_id = art.article_id )
                                                              AND ( db.publisher_id = art.publisher_id )
                                                              AND ( db.publisher_db = art.publisher_db )
                        INNER JOIN [dbo].[MSpublications] pub WITH ( NOLOCK ) ON ( art.publication_id = pub.publication_id )
  --WHERE cmds.publisher_database_id = 46
               GROUP BY db.publisher_db ,
                        pub.publication ,
                        cmds.article_id ,
                        art.source_owner ,
                        art.destination_object
             ),
        BIGTOT
          AS ( SELECT   publisher_db ,
                        [Pub Name] ,
                        SUM(cmd_cnt) AS pub_cmd_cnt
               FROM     CMDCNT
               GROUP BY publisher_db ,
                        [Pub Name]
             )
    SELECT  CMDCNT.* ,
            BIGTOT.pub_cmd_cnt
    FROM    CMDCNT
            INNER JOIN BIGTOT ON ( CMDCNT.publisher_db = BIGTOT.publisher_db )
                                 AND ( CMDCNT.[Pub Name] = BIGTOT.[Pub Name] )
    ORDER BY CMDCNT.publisher_db ,
            BIGTOT.pub_cmd_cnt DESC ,
            CMDCNT.cmd_cnt DESC