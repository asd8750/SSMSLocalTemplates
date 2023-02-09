WITH TotMinCpu
  AS
  (
      SELECT SUM(min_cpu_percent) AS TotMIN
         FROM sys.resource_governor_resource_pools
         WHERE
          pool_id > 1
  ),
     EffMaxCpu
  AS
  (
      SELECT RP1.pool_id,
             SUM(IIF(( RP1.pool_id <> RP2.pool_id ), RP2.min_cpu_percent, 0)) AS SumMinCpu
         FROM sys.resource_governor_resource_pools RP1
             CROSS JOIN sys.resource_governor_resource_pools RP2
         WHERE
          ( RP1.pool_id > 1 )
          AND ( RP2.pool_id > 1 )
         GROUP BY RP1.pool_id
  )
   SELECT RP.pool_id,
          RP.min_cpu_percent,
          RP.max_cpu_percent,
          RP.cap_cpu_percent,
          EffMaxCpu.SumMinCpu,
          IIF(( 100 - EffMaxCpu.SumMinCpu ) < 100, ( 100 - EffMaxCpu.SumMinCpu ), 100) AS EffMaxCpu,
          IIF(IIF(( 100 - EffMaxCpu.SumMinCpu ) < 100, ( 100 - EffMaxCpu.SumMinCpu ), 100) > RP.cap_cpu_percent,
              RP.cap_cpu_percent,
              IIF(( 100 - EffMaxCpu.SumMinCpu ) < 100, ( 100 - EffMaxCpu.SumMinCpu ), 100)) AS EffCappedCpu,
          IIF(( 100 - EffMaxCpu.SumMinCpu ) < 100, ( 100 - EffMaxCpu.SumMinCpu ), 100) - RP.min_cpu_percent AS CalcShare
      FROM sys.resource_governor_resource_pools RP
          INNER JOIN EffMaxCpu
             ON ( RP.pool_id = EffMaxCpu.pool_id )
          CROSS JOIN TotMinCpu
      WHERE
       RP.pool_id > 1;

