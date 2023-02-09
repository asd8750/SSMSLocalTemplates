
DECLARE	@schemaName		VARCHAR(128) = 'IRA';
DECLARE	@schemaNameU	VARCHAR(128);
DECLARE @sqlSetupPerms	VARCHAR(MAX);

SET @schemaName = SCHEMA_NAME(SCHEMA_ID(@schemaName));	-- Get the current case name from the database
SET @schemaNameU = STUFF(@schemaName,1,1,UPPER(LEFT(@schemaName,1))); -- Upper case the first character for Camel casing

SET @sqlSetupPerms = '
	USE [' + DB_NAME() + ']
	IF DATABASE_PRINCIPAL_ID(''roleSch<<SchU>>_Admin'') IS NOT NULL
		DROP ROLE [roleSch<<SchU>>_Admin];
	CREATE ROLE [roleSch<<SchU>>_Admin] AUTHORIZATION [dbo];
	GRANT CREATE TABLE, CREATE PROCEDURE, CREATE FUNCTION, CREATE VIEW TO  [roleSch<<SchU>>_Admin];
	GRANT SELECT, UPDATE, INSERT, DELETE, EXECUTE, ALTER, REFERENCES ON SCHEMA::[<<Sch>>] TO [roleSch<<SchU>>_Admin];
	GRANT VIEW DEFINITION ON SCHEMA::[<<Sch>>] TO [roleSch<<SchU>>_Admin];

	IF DATABASE_PRINCIPAL_ID(''roleSch<<SchU>>_Update'') IS NOT NULL
		DROP ROLE [roleSch<<SchU>>_Update];
	CREATE ROLE [roleSch<<SchU>>_Update] AUTHORIZATION [dbo];
	GRANT SELECT, UPDATE, INSERT, DELETE, EXECUTE ON SCHEMA::[<<Sch>>] TO [roleSch<<SchU>>_Update];
	GRANT VIEW DEFINITION ON SCHEMA::[<<Sch>>] TO [roleSch<<SchU>>_Update];

	IF DATABASE_PRINCIPAL_ID(''roleSch<<SchU>>_ReadEX'') IS NOT NULL
		DROP ROLE [roleSch<<SchU>>_Reader];
	CREATE ROLE [roleSch<<SchU>>_Reader] AUTHORIZATION [dbo];
	GRANT SELECT, EXECUTE ON SCHEMA::[<<Sch>>] TO [roleSch<<SchU>>_Reader];
	GRANT VIEW DEFINITION ON SCHEMA::[<<Sch>>] TO [roleSch<<SchU>>_Reader];

	IF DATABASE_PRINCIPAL_ID(''roleSch<<SchU>>_ReadOnly'') IS NOT NULL
		DROP ROLE [roleSch<<SchU>>_Reader];
	CREATE ROLE [roleSch<<SchU>>_Reader] AUTHORIZATION [dbo];
	GRANT SELECT TO [roleSch<<SchU>>_Reader];
	GRANT VIEW DEFINITION ON SCHEMA::[<<Sch>>] TO [roleSch<<SchU>>_Reader];
';

SET @sqlSetupPerms = REPLACE(@sqlSetupPerms, '<<Sch>>', @schemaName);
SET @sqlSetupPerms = REPLACE(@sqlSetupPerms, '<<SchU>>', @schemaNameU);

PRINT @sqlSetupPerms;
EXECUTE (@sqlSetupPerms);