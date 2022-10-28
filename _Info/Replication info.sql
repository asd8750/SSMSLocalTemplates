SELECT s.[name] AS [Publication name] FROM syspublications AS s INNER JOIN sysarticles
AS s2 ON s.pubid = s2.pubid WHERE s2.NAME = 'EdgePinch_RecipeCalculations'