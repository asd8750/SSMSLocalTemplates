DECLARE @xact_Start NCHAR(22);

SET @xact_Start = '0x0013DF1C00026E1A010000000000';
exec sp_browsereplcmds @xact_seqno_start=@xact_Start, @xact_seqno_end=@xact_start
