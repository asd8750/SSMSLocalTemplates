
select
        sf.FILEID AS [File ID]
        ,[File Size in MB] = convert(decimal(12,2),round(sf.size/128.000,2))
        ,[Max Size in MB] = convert(decimal(12,2),round(sf.maxsize/128.000,2))
        ,[Space Used in MB] = convert(decimal(12,2),round(fileproperty(sf.name,'SpaceUsed')/128.000,2))
        ,[Free Space in MB] = convert(decimal(12,2),round((sf.size-fileproperty(sf.name,'SpaceUsed'))/128.000,2)) 
        ,[Space Used in %] = convert(decimal(12,2),round(100*((fileproperty(sf.name,'SpaceUsed'))/128.000)/(sf.size/128.000),2)) 
        ,[Free Spaced in %] = convert(decimal(12,2),round(100*((sf.size-fileproperty(sf.name,'SpaceUsed'))/128.000)/(sf.size/128.000),2)) 
        ,[File Name] = left(sf.NAME,30)
        ,[File Location] = left(sf.FILENAME,100)
        from dbo.sysfiles sf
        order by fileid asc