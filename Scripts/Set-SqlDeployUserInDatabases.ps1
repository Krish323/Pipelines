###############################################################################
# Script: Add-UserToAppDatabases.ps1
# Purpose:  Creates the passed in user name in a list of DB's
#				retrieving the password for the user from the specified KeyVault
# Parameters:
#		$AppDatabaseNames : CSV or JSON string containing the database names to create the user in.
#		$AppDatabaseNameFormat : Format of AppDatabaseNames - either csv or json
#		$SqlServerName : App Sql Server Name to Update
#		$AdminDbUserName : Sql Server Admin Username that has permissions to add the user
#		$AdminDbPassword : Sql Server Admin password
#		$DeployUserName : Username to create
#		$DeployUserPassword : Optional. Password to use for the Sql User.
###############################################################################
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$AppDatabaseNames,
	[Parameter(Mandatory = $true)]
	[ValidateSet('csv', 'json')]
	[string]$AppDatabaseNameFormat,
	[Parameter(Mandatory = $true)]
	[string]$SqlServerName,
	[Parameter(Mandatory = $true)]
	[string]$AdminDbUserName,
	[Parameter(Mandatory = $true)]
	[string]$AdminDbPassword,
	[Parameter(Mandatory = $true)]
	[string]$DeployUserName,
	[string]$DeployUserPassword
)

# Convert the list of DB Names to an array
if ($AppDatabaseNameFormat -eq "csv") {
	Write-Host "Creating appDatabaseNamesArray from CSV"
	$appDatabaseNamesArray = $AppDatabaseNames.Split(',')
}
else {
	Write-Host "Creating appDatabaseNamesArray from JSON"
	$appDatabaseNamesArray = ConvertFrom-Json $AppDatabaseNames
}

Write-Host "Create array of Database Roles to add user to"
if ([System.string]::IsNullOrWhiteSpace($DatabaseRoles)) {
	$databaseRolesArray = @()
}
else {
	$databaseRolesArray = $DatabaseRoles.Split(',')
}

# Loop through the databases and add/update the user
foreach ($database in $appDatabaseNamesArray) {
	Write-Host "`n`nProcessing Database: $($database)"

	Write-Host "Build the query to Create the Deploy User"
	$query = & "$($PSScriptRoot)\Get-AddAzureSqlDeployUserQuery.ps1" -Username "$($DeployUserName)" -Password "$($DeployUserPassword)"

	Write-Host "Setting/Permissioning Application User: $($DeployUserName) in Database: $($database)"
	& "$($PSScriptRoot)\Invoke-ExecuteSqlCommand.ps1" -SqlServerName "$SqlServerName" -DatabaseName "$database" -DbUsername "$AdminDbUserName" -DbPassword "$AdminDbPassword" -Query "$query"
}
