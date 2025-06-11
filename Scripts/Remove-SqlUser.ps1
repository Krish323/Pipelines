###############################################################################
# Script: Remove-SqlUser.ps1
# Purpose: Remove SQL users to given SQL Server databases.
# Parameters:
#       $SqlServerName : SQL server name
#       $UserName : Admin SQL user name
#       $UserPassword : Admin SQL user name password
#       $SqlUserToRemove: SQL user name which will be removed
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
    [string] $SqlUserToRemove
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

$databasesQuery = "SELECT name FROM master.dbo.sysdatabases"

$databases = Invoke-ExecuteSqlCommand -SqlServerName $SqlServerName -DatabaseName "master" -DbUserName $UserName -DbPassword $UserPassword -Query $databasesQuery -Results

if ($databases.Count -gt 0) {
    Write-Host "Build the query to Drop the User"
    $query = & "$($PSScriptRoot)\Get-DropAzureSqlUserQuery.ps1" -Username "$($SqlUserToRemove)"

    foreach ($database in $databases) {
        $databaseName = $database.name

        if ($databaseName -ne "master") {
            Write-Host "Dropping User: $($SqlUserToRemove) in Database: $($databaseName)"
            Invoke-ExecuteSqlCommand -SqlServerName $SqlServerName -DatabaseName $databaseName -DbUsername $UserName -DbPassword $UserPassword -Query $query
        }
    }
}
else {
    throw "Couldn't found any databases in the $SqlServerName"
}

Write-Host "`nExit Remove-SqlUser"