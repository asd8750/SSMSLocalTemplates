
DECLARE	@schemaName		VARCHAR(128) = 'WIP';
DECLARE	@schemaNameU	VARCHAR(128);
DECLARE @sqlSetupPerms	VARCHAR(MAX);

SET @schemaName = SCHEMA_NAME(SCHEMA_ID(@schemaName));	-- Get the current case name from the database
SET @schemaNameU = STUFF(@schemaName,1,1,UPPER(LEFT(@schemaName,1))); -- Upper case the first character for Camel casing

SET @sqlSetupPerms = '
	IF DATABASE_PRINCIPAL_ID(''roleSch_<<SchU>>_Admin'') IS NULL 
		CREATE ROLE [roleSch_<<SchU>>_Admin] AUTHORIZATION [dbo]; 
	GRANT SELECT, UPDATE, INSERT, DELETE, EXECUTE, ALTER, REFERENCES ON SCHEMA::[<<Sch>>] TO [roleSch_<<SchU>>_Admin]; 
	GRANT CREATE TABLE     TO  [roleSch_<<SchU>>_Admin]; 
	GRANT CREATE PROCEDURE TO  [roleSch_<<SchU>>_Admin]; 
	GRANT CREATE FUNCTION  TO  [roleSch_<<SchU>>_Admin]; 
	GRANT CREATE VIEW      TO  [roleSch_<<SchU>>_Admin]; 
	GRANT VIEW DEFINITION ON SCHEMA::[<<Sch>>] TO [roleSch_<<SchU>>_Admin]; 
	 
	IF DATABASE_PRINCIPAL_ID(''roleSch_<<SchU>>_Update'') IS NULL 
		CREATE ROLE [roleSch_<<SchU>>_Update] AUTHORIZATION [dbo]; 
	GRANT SELECT, UPDATE, INSERT, DELETE, EXECUTE ON SCHEMA::[<<Sch>>] TO [roleSch_<<SchU>>_Update]; 
	GRANT VIEW DEFINITION ON SCHEMA::[<<Sch>>] TO [roleSch_<<SchU>>_Update]; 
	 
	IF DATABASE_PRINCIPAL_ID(''roleSch_<<SchU>>_ReadExecute'') IS NULL 
		CREATE ROLE [roleSch_<<SchU>>_ReadExecute] AUTHORIZATION [dbo]; 
	GRANT SELECT, EXECUTE ON SCHEMA::[<<Sch>>] TO [roleSch_<<SchU>>_ReadExecute]; 
	GRANT VIEW DEFINITION ON SCHEMA::[<<Sch>>] TO [roleSch_<<SchU>>_ReadExecute]; 
	 
	IF DATABASE_PRINCIPAL_ID(''roleSch_<<SchU>>_Reader'') IS NULL 
		CREATE ROLE [roleSch_<<SchU>>_Reader] AUTHORIZATION [dbo]; 
	GRANT SELECT ON SCHEMA::[<<Sch>>] TO [roleSch_<<SchU>>_Reader]; 
	GRANT VIEW DEFINITION ON SCHEMA::[<<Sch>>] TO [roleSch_<<SchU>>_Reader]; 
';

SET @sqlSetupPerms = REPLACE(@sqlSetupPerms, '<<Sch>>', @schemaName);
SET @sqlSetupPerms = REPLACE(@sqlSetupPerms, '<<SchU>>', @schemaNameU);
-- SET @sqlSetupPerms = REPLACE(@sqlSetupPerms, '', CHAR(13)+CHAR(10));

PRINT @sqlSetupPerms;
SELECT @schemaName, @schemaNameU, @sqlSetupPerms;
--EXECUTE (@sqlSetupPerms);