###############################################################################
# Script: Add-SGUserinDatabasesBySqlUser.ps1
# Purpose: Add Security Groups users to a given SQL Server databases using a Sql user.
# Parameters:
#       $SqlServerName : SQL server name
#       $AdminDbUserName : Sql Server Admin Username that has permissions to add the user
#       $AdminDbPassword : Sql Server Admin password
#		$ActiveDirectoryUsersArray : AD users that will be added to SQL server
#           databases
#       $DatabaseRolesArray: Database roles for the SQL Databases of the server.
#       $DatabaseNamesArray: Databases to update. If empty all User DB's on the server
#           will be updated.
#       $GrantExecute: Grants permission to execute all stored procedures in the DB's
# Outputs:
# Returns:
###############################################################################
param(
    [Parameter(Mandatory = $true)]
    [string] $SqlServerName,
    [Parameter(Mandatory = $true)]
    [string] $AdminDbUserName,
    [Parameter(Mandatory = $true)]
    [string] $AdminDbPassword,
    [Parameter(Mandatory = $true)]
    [string[]] $ActiveDirectoryUsersArray,
    [Parameter(Mandatory = $true)]
    [string[]] $DatabaseRolesArray,
    [string[]] $DatabaseNamesArray,
    [switch] $GrantExecute
)

function Get-AdUserSid (
    [string] $ActiveDirectoryUser
)
{
    # We need to have the ApplicationId of the Managed Identity. The SID is calculated based on the ApplicationId
    $userIdentity = Get-AzADGroup -DisplayName $ActiveDirectoryUser -ErrorAction SilentlyContinue
    if ($null -eq $userIdentity) {
        throw "Identity $($ActiveDirectoryUser) was not found!"
    }

    # Multiple versions of the Az.Resources module have been installed that have breaking changes.
    # Test for property existence and get the Client ID from the property that exists.
    if ($userIdentity.ApplicationId) {
        Write-Host 'Using ApplicationId Property'
        $clientId = $userIdentity.ApplicationId.Guid
    }

    if ($userIdentity.AppId) {
        Write-Host 'Using AppId Property'
        $clientId = $userIdentity.AppId
    }
    if ($userIdentity.id) {
        Write-Host 'Using ObjectId Property'
        $clientId = $userIdentity.id
    }

    [guid]$guid = [System.Guid]::Parse($clientId)

    foreach ($byte in $guid.ToByteArray()) {
        $byteGuid += [System.String]::Format("{0:X2}", $byte)
    }

    $sid = "0x" + $byteGuid

    return $sid
}

function Invoke-ExecuteSqlCommand(
    [string] $SqlServerName,
    [string] $DatabaseName,
    [string] $DbUsername,
    [string] $DbPassword,
    [string] $Query,
    [int] $Port = 1433,
    [switch] $Results
)
{
    Write-Host "`tExecuteSqlCommand: Create SqlConnection object"

    # SqlConnectionStringBuilder to correctly escape special characters in the connection string
    $builder = New-Object -TypeName System.Data.SqlClient.SqlConnectionStringBuilder("")
    $builder.Server = "tcp:$($SqlServerName).database.windows.net,$($Port)"
    $builder.Database = "$DatabaseName"
    $builder.User = "$DbUsername"
    $builder.Password = "$DbPassword"
    $builder.Encrypt = $true
    $builder.MultipleActiveResultSets = $false
    $builder.PersistSecurityInfo = $false
    $builder.TrustServerCertificate = $false
    $builder.Timeout = 15

    $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection($builder.ConnectionString)

    try {
        Write-Host "`tExecuteSqlCommand: Open Connection"
        $connection.Open()

        # Create the SqlCommand object"
        $command = New-Object -TypeName System.Data.SqlClient.SqlCommand($Query, $connection)
        $command.CommandType = [System.Data.CommandType]::Text

        if ($Results) {
            $dataTable = New-Object System.Data.DataTable

            Write-Host "`tExecuteSqlCommand: Execute Reader"
            $sqlDataReader = $command.ExecuteReader()
            $dataTable.Load($sqlDataReader)

            return $dataTable.Rows
        }
        else {
            Write-Host "`tExecuteSqlCommand: Execute SqlCommand"
            $command.ExecuteNonQuery()
        }
    }
    catch {
        Write-Host $_.Exception
        throw $_
    }
    finally {
        if ($null -ne $command) {
            $command.Dispose()
        }
        if ($null -ne $connection) {
            $connection.Dispose()
        }
        if ($null -ne $sqlDataReader) {
            $sqlDataReader.Dispose()
        }
    }
}

Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

Write-Host "`n`nEnter Add-AdUserInDatabasesBySqlUser.ps1`nParameters:"
Write-Host "SqlServerName: $($SqlServerName)"
Write-Host "AdminDbUserName: $($AdminDbUserName)"
Write-Host "ActiveDirectoryUsersArray: $($ActiveDirectoryUsersArray)"
Write-Host "DatabaseRolesArray: $($DatabaseRolesArray)"
Write-Host "GrantExecute: $($GrantExecute)"
Write-Host "DatabaseNamesArray:"
$DatabaseNamesArray
Write-Host "`n`n"

if ($DatabaseNamesArray.Count -eq 0) {
    # No databases supplied. Get a list of all User DB's on the server.
    Write-Host "Loading db names from the server"
    $databasesQuery = "SELECT name FROM master.dbo.sysdatabases where [name] != 'master'"
    $queryResults = Invoke-ExecuteSqlCommand -SqlServerName $SqlServerName -DatabaseName "master" -DbUserName $AdminDbUserName -DbPassword $AdminDbPassword -Query $databasesQuery -Results

    # Flatten the hashtable of results into a string array
    $databaseNames = ($queryResults).Name
}
else {
    Write-Host "Using the db names supplied in the script arguments"
    $databaseNames = $DatabaseNamesArray
}

$activeDirectoryUserInfo = @()

foreach ($activeDirectoryUser in $activeDirectoryUsersArray) {
    Write-Host "`nCreating user information for $($activeDirectoryUser)"
    $userSid = Get-AdUserSid -ActiveDirectoryUser $activeDirectoryUser
    $createQuery = & "$($PSScriptRoot)\Get-AddAzureSqlExternalUserQuery.ps1" -Username $activeDirectoryUser -UserSid $userSid -DatabaseRoles $databaseRolesArray -AddGrantExecute:$GrantExecute
    $dropQuery = & "$($PSScriptRoot)\Get-DropAzureSqlUserQuery.ps1" -Username $activeDirectoryUser

    $userInfo = @{
        name = $activeDirectoryUser
        createQuery = $createQuery
        dropQuery = $dropQuery
    }

    $activeDirectoryUserInfo += $userInfo
}

Write-Host "`n"

if ($databaseNames.Count -gt 0) {
    foreach ($databaseName in $databaseNames) {
        Write-Host "`nProcessing Database: $($databaseName)"

        foreach ($activeDirectoryUser in $activeDirectoryUserInfo) {
            Write-Host "`nProcessing User: $($activeDirectoryUser.name)`n"
            Write-Host "Dropping User: $($activeDirectoryUser.name) in Database: $($databaseName)"
            Invoke-ExecuteSqlCommand -SqlServerName $SqlServerName -DatabaseName $databaseName -DbUsername $AdminDbUserName -DbPassword $AdminDbPassword -Query $activeDirectoryUser.dropQuery

            Write-Output "Create User [$($activeDirectoryUser.name)] in Database: [$($databaseName)]"
            Invoke-ExecuteSqlCommand -SqlServerName $SqlServerName -DatabaseName $databaseName -DbUsername $AdminDbUserName -DbPassword $AdminDbPassword -Query $activeDirectoryUser.createQuery
        }
    }
}
else {
    $message = "`n`nCouldn't find any databases on $($SqlServerName)"
    throw $message
}

Write-Host "`n`nExit Add-AdUserInDatabasesBySGroup.ps1"
