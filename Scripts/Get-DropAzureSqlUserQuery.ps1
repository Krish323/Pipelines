[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [string]$Username
)

$query = @"
IF EXISTS (
    SELECT  *
    FROM    sys.database_principals
    WHERE   [name] = '##Username##'
)
BEGIN
    PRINT 'User ##Username## exists in ' + DB_NAME()
    DECLARE @command nvarchar(4000) = ''

    PRINT 'Build script to update Schemas owned by this user'
    SELECT	@command = @command + 'ALTER AUTHORIZATION ON SCHEMA::' + s.name + ' TO [dbo]; '
    FROM	sys.schemas s
    JOIN	sys.database_principals dp
        ON	s.principal_id = dp.principal_id
    WHERE	dp.name = '##Username##'

    IF (@command != '')
    BEGIN
        PRINT 'Schemas found that are owned by ##Username##'
        SELECT @command
        PRINT 'Changing schema owners to dbo'
        EXEC sp_executesql @command
    END

    SET @command = ''

    -- Get Objects owned by the user and build change owner script
    SELECT	@command = @command + 'ALTER AUTHORIZATION ON OBJECT::' + o.name + ' TO [dbo]; '
    FROM    sys.objects o
    JOIN	sys.database_principals dp
        ON	o.principal_id = dp.principal_id
    WHERE   o.name = '##Username##'
        AND	o.is_ms_shipped = 0
        AND	o.type IN ( 'U', 'FN', 'FS', 'FT', 'IF', 'P', 'PC', 'TA', 'TF', 'TR', 'V' );

    IF (@command != '')
    BEGIN
        PRINT 'Objects found that are owned by ##Username##'
        SELECT @command
        PRINT 'Changing object owners to dbo'
        EXEC sp_executesql @command
    END

    DROP USER [##Username##]
END
ELSE
BEGIN
    PRINT 'User ##Username## NOT FOUND in ' + DB_NAME()
END
"@

# Replace tokens in query
$query = $query -replace '##Username##', $username

return $query
