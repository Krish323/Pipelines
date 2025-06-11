[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [string]$Username,
    [parameter(Mandatory=$true)]
    [string]$UserSid,
    [string[]]$DatabaseRoles,
    [switch]$AddGrantExecute
)

$query = @"
CREATE USER [##Username##] WITH sid = ##SID##, TYPE = E, DEFAULT_SCHEMA = dbo
"@

# Replace tokens in query
$query = $query -replace '##SID##', $UserSid
$query = $query -replace '##Username##', $Username

foreach ($role in $DatabaseRoles) {
    $query += "`nEXEC sp_addrolemember N'$($role)', N'$($Username)'"
}

if ($AddGrantExecute) {
    $query += "`nGRANT EXECUTE TO [$($Username)]"
}

return $query