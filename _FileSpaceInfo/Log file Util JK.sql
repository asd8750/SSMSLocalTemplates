SELECT instance_name AS DatabaseName, 
       [Data File(s) Size (KB)], 
       [LOG File(s) Size (KB)], 
       [Log File(s) Used Size (KB)], 
       [Percent Log Used] 
FROM 
( 
   SELECT * 
   FROM sys.dm_os_performance_counters 
   WHERE counter_name IN 
   ( 
       'Data File(s) Size (KB)', 
       'Log File(s) Size (KB)', 
       'Log File(s) Used Size (KB)', 
       'Percent Log Used' 
   ) 
     AND instance_name != '_Total' 
) AS Src 
PIVOT 
( 
   MAX(cntr_value) 
   FOR counter_name IN 
   ( 
       [Data File(s) Size (KB)], 
       [LOG File(s) Size (KB)], 
       [Log File(s) Used Size (KB)], 
       [Percent Log Used] 
   ) 
) AS pvt 


/** SQL 2000

SELECT instance_name AS 'Database Name', 
   MAX(CASE 
           WHEN counter_name = 'Data File(s) Size (KB)' 
               THEN cntr_value 
           ELSE 0 
       END) AS 'Data File(s) Size (KB)', 
   MAX(CASE 
           WHEN counter_name = 'Log File(s) Size (KB)' 
               THEN cntr_value 
           ELSE 0 
       END) AS 'Log File(s) Size (KB)', 
   MAX(CASE 
           WHEN counter_name = 'Log File(s) Used Size (KB)' 
               THEN cntr_value 
           ELSE 0 
       END) AS 'Log File(s) Used Size (KB)', 
   MAX(CASE 
           WHEN counter_name = 'Percent Log Used' 
               THEN cntr_value 
           ELSE 0 
       END) AS 'Percent Log Used' 
FROM sysperfinfo 
WHERE counter_name IN 
   ( 
       'Data File(s) Size (KB)', 
       'Log File(s) Size (KB)', 
       'Log File(s) Used Size (KB)', 
       'Percent Log Used' 
   ) 
  AND instance_name != '_total' 
GROUP BY instance_name 

**/
