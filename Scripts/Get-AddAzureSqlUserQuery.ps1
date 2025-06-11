[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [string]$Username,
    [parameter(Mandatory=$true)]
    [string]$Password,
    [string[]]$DatabaseRoles,
    [switch]$AddGrantExecute
)

$query = @"
IF EXISTS (
    SELECT  *
    FROM    sys.database_principals
    WHERE   [name] = '##Username##'
)
BEGIN
    DROP USER [##Username##]
END

CREATE USER [##Username##] WITH PASSWORD = '##Password##', DEFAULT_SCHEMA = dbo
"@

# Replace tokens in query
$query = $query -replace '##Password##', $password
$query = $query -replace '##Username##', $username

foreach ($role in $DatabaseRoles) {
    $query += "`nEXEC sp_addrolemember N'$($role)', N'$($Username)'"
}

if ($AddGrantExecute) {
    $query += "`nGRANT EXECUTE TO [$($Username)]"
}

return $query
