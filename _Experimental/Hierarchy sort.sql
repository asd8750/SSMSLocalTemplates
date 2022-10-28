declare @hier TABLE (id int, parent int, name varchar(128), [path] varchar(1024));

INSERT INTO @hier (id, parent, name, [path]) VALUES (0, NULL, '', '');

DECLARE @lvl int
SET @lvl=-1
DECLARE @rcnt int
SELECT @rcnt=count(*) FROM HIERarchy where level=0
WHILE (@@ROWCOUNT > 0)
BEGIN
SET @LVL= @LVL+1
insert into @hier
	SELECT hrc.id, hrc.parent, hrc.name, ISNULL(hrp.[Path],'') + '/' + hrc.Name as path
		from Hierarchy hrc
			INNER JOIN @hier hrp
		on (hrp.id = hrc.Parent)
		where (hrc.level = @lvl)
END
				
select id, [path] from @hier order by [path] where parent is not null
			

