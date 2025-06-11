[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [string]$Username,
    [parameter(Mandatory=$true)]
    [string]$Password
)

$databaseRolesArray = @('db_datareader', 'db_datawriter', 'db_ddladmin')
$query = & "$($PSScriptRoot)\Get-AddAzureSqlUserQuery.ps1" -Username "$($Username)" -Password "$($Password)" -DatabaseRoles $databaseRolesArray

# Add View Defintion permission
$query += "`nGRANT VIEW DEFINITION TO [$($Username)]"
$query += "`nGRANT IMPERSONATE ON USER:: dbo TO [$($Username)]"

return $query
