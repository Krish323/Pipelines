###############################################################################
# Script: Add-ADSqlUsers.ps1
# Purpose: Add AD users to given SQL Server databases.
# Parameters:
#       $SqlServerName : SQL server name
#       $UserName : AD user name which must belongs to admin AD group
#       $UserPassword : AD user name passwords which must belongs to admin AD group
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
    [string] $UserName,
    [Parameter(Mandatory = $true)]
    [string] $UserPassword,
    [Parameter(Mandatory = $true)]
    [string[]] $ActiveDirectoryUsersArray,
    [Parameter(Mandatory = $true)]
    [string[]] $DatabaseRolesArray,
    [string[]] $DatabaseNamesArray,
    [switch] $GrantExecute
)


function Invoke-ExecuteSqlCommand(
    [string] $SqlServerName,
    [string] $DatabaseName,
    [string] $DbUsername,
    [string] $DbPassword,
    [string] $Query,
    [int] $Port = 1433,
    [switch] $Results
) {
    # Create the SqlConnection Object Connection String
    Write-Host "ExecuteSqlCommand: Create SqlConnection object"

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
    $builder.Authentication = "Active Directory Password"

    $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection($builder.ConnectionString)

    try {
        Write-Host "ExecuteSqlCommand: Open Connection"
        $connection.Open()

        Write-Host "ExecuteSqlCommand: Create SqlCommand object"
        $command = New-Object -TypeName System.Data.SqlClient.SqlCommand($Query, $connection)

        if ($Results) {
            $dataTable = New-Object System.Data.DataTable

            $sqlDataReader = $command.ExecuteReader()
            $dataTable.Load($sqlDataReader)

            return $dataTable.Rows
        }
        else {
            $command.CommandType = [System.Data.CommandType]::Text

            Write-Host "ExecuteSqlCommand: Execute SqlCommand"
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

function Get-AddADUserQuery(
    [string] $ActiveDirectoryUser,
    [string[]] $DatabaseRoles,
    [switch] $AddGrantExecute
) {
    $query = @"
IF EXISTS (
    SELECT  *
    FROM    sys.database_principals
    WHERE   [name] = '##Username##'
)
BEGIN
    DROP USER [##Username##]
END
CREATE USER [##Username##] FROM EXTERNAL PROVIDER
"@

    # Replace tokens in query
    $query = $query -replace '##Username##', $ActiveDirectoryUser

    foreach ($role in $DatabaseRoles) {
        $query += "`nEXEC sp_addrolemember N'$($role)', N'$($ActiveDirectoryUser)'"
    }

    if ($AddGrantExecute) {
        $query += "`nGRANT EXECUTE TO [$($ActiveDirectoryUser)]"
    }

    return $query
}

if ($DatabaseNamesArray.Count -eq 0) {
    # No databases supplied. Get a list of all User DB's on the server.
    Write-Host "Loading db names from the server"
    $databasesQuery = "SELECT name FROM master.dbo.sysdatabases where [name] != 'master'"

    $queryResults = Invoke-ExecuteSqlCommand -SqlServerName $SqlServerName -DatabaseName "master" -DbUserName $UserName -DbPassword $UserPassword -Query $databasesQuery -Port 1433 -Results

    # Flatten the hashtable of results into a string array
    $databaseNames = ($queryResults).Name
}
else {
    Write-Host "Using the db names supplied in the script arguments"
    $databaseNames = $DatabaseNamesArray
}

if ($databaseNames.Count -gt 0) {
    foreach ($databaseName in $databaseNames) {
        Write-Host "`n`nProcessing Database: $($databaseName)"

        foreach ($activeDirectoryUser in $activeDirectoryUsersArray) {
            Write-Host "Build the query to Create the Active Directory User"
            $query = Get-AddADUserQuery -ActiveDirectoryUser "$($activeDirectoryUser)" -DatabaseRoles $DatabaseRolesArray -AddGrantExecute:$GrantExecute
    
            Write-Host "Setting/Permissioning Active Directory User: $($activeDirectoryUser) in Database: $($databaseName)"
            Invoke-ExecuteSqlCommand -SqlServerName $SqlServerName -DatabaseName $databaseName -DbUsername $UserName -DbPassword $UserPassword -Query $query
        }
    }
}
else {
    throw "Couldn't found any databases in the $SqlServerName"
}
