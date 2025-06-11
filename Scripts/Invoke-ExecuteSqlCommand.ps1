###############################################################################
# Script: Invoke-ExecuteSqlCommand.ps1
# Purpose:  Creates the passed in user name in a list of DB's
#				retrieving the password for the user from the specified KeyVault
# Parameters:
#       $SqlServerName : Sql Server to execute the query on
#		$DatabaseName : Database name to execute the query in
#		$DbUsername : Username to connect to sql
#		$DbPassword : Password to connect to sql
#		$Query : Query to execute
#       $Port : Optional. TCP Port to connect to Sql Server on
###############################################################################
[CmdletBinding()]
param (
    [string] $SqlServerName,
    [string] $DatabaseName,
    [string] $DbUsername,
    [string] $DbPassword,
    [string] $Query,
    [int] $Port = 1433
)

Write-Output "`nEnter Invoke-ExecuteSqlCommand.ps1`n"

# Create the SqlConnection Object Connection String
Write-Output "Create Connection String`n"

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
    Write-Output "Open Connection to [$($SqlServerName)]\[$($DatabaseName)]`n"
    $connection.Open()

    # Create the SqlCommand
    $command = New-Object -TypeName System.Data.SqlClient.SqlCommand($Query, $connection)
    $command.CommandType = [System.Data.CommandType]::Text

    Write-Output "Execute the Query`n"
    $result = $command.ExecuteNonQuery()
    $connection.Close()
}
finally {
    if ($null -ne $command) {
        $command.Dispose()
    }
    if ($null -ne $connection) {
        $connection.Dispose()
    }
}
Write-Output "Exit Invoke-ExecuteSqlCommand.ps1`n"
