Declare @user varchar(128);
Set @user = 'CDCExtract';

 declare @name varchar(100), @qry varchar(2000);
 declare cursor_temp cursor 
 for select name from dbo.sysobjects where OBJECTPROPERTY (id, 'IsScalarFunction') = 1
 open cursor_temp
 fetch next from cursor_temp into @name
 while @@fetch_status = 0
 begin
 set @qry = ' grant execute on [dbo].[' + @name + '] to ' + @user
 PRINT @qry
exec (@qry)
 fetch next from cursor_temp into @name
 end
 close cursor_temp
 deallocate cursor_temp

 declare cursor_temp cursor 
 for select name from dbo.sysobjects where OBJECTPROPERTY (id, 'IsProcedure') = 1
 open cursor_temp
 fetch next from cursor_temp into @name
 while @@fetch_status = 0
 begin
 set @qry = ' grant execute on [dbo].[' + @name + '] to ' + @user
 PRINT @qry
exec (@qry)
 fetch next from cursor_temp into @name
 end
 close cursor_temp
 deallocate cursor_temp