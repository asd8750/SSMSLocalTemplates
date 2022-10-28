DECLARE @baseDate DATETIME2(7) = '2016-12-01';
DECLARE @daysInPartition INT = 14;
DECLARE @maxDaysAhead INT = 90;

SET @baseDate = DATEADD(DAY, - (DATEPART(WEEKDAY, @baseDate) - 1), @baseDate);

WITH SEQ
  AS (SELECT TOP 10000 ROW_NUMBER() OVER (ORDER BY OBJ.[object_id]) AS RowNum
        FROM sys.objects OBJ
       CROSS JOIN sys.objects OBJ2),
     DList
  AS (SELECT DATEADD(DAY, @daysInPartition * (SEQ.RowNum - 1), CAST(@baseDate AS DATE)) AS Today,
             (DATEPART(DAY, DATEADD(DAY, @daysInPartition * (SEQ.RowNum - 1), CAST(@baseDate AS DATE))) - 1) AS MonStart,
             (DATEPART(DAY, DATEADD(DAY, @daysInPartition * (SEQ.RowNum - 1), CAST(@baseDate AS DATE))) - 1)
             / @daysInPartition AS PartInMonth
        FROM SEQ)
SELECT Today,
       MonStart,
       PartInMonth,
       DATEADD(DAY, (PartInMonth * @daysInPartition), DATEADD(DAY, - (DATEPART(DAY, Today) - 1), Today)) AS Boundary
  FROM DList
 WHERE (DATEADD(DAY, @maxDaysAhead + (@daysInPartition - 1), GETDATE()) >= Today)
   AND (((PartInMonth + 1) * @daysInPartition)                          <= 31);