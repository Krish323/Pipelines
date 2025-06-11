###############################################################################
# Script: Set-SqlUserInDatabases.ps1
# Purpose:  Creates the passed in user name in a list of DB's
#				retrieving the password for the user from the specified KeyVault
# Parameters:
#		$AppDatabaseNames : CSV or JSON string containing the database names to create the user in.
#		$AppDatabaseNameFormat : Format of AppDatabaseNames - either csv or json
#		$SqlServerName : App Sql Server Name to Update
#		$AdminDbUserName : Sql Server Admin Username that has permissions to add the user
#		$AdminDbPassword : Sql Server Admin password
#		$AppKeyVaultName : Key Vault the Application User password is stored in
#		$PasswordSecretName : Secret Name the Application User password is stored in
#		$SqlUserName : Username to create
#		$SqlUserPassword : Optional. Password to use for the Sql User.
#		$DatabaseRoles : CSV list of Database Roles to grant to the user
#		$RandomPassword : If set, a random password is generated and used. This overrides -SqlUserPassword.
#		$ResetPassword : If set, the password be changed if it already exists. Otherwise,
#			existing passwords will not be updated.
#		$GrantExecute : If set, user will be able to execute Stored Procedures in the databases.
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
	[string]$AppKeyVaultName,
	[string]$PasswordSecretName,
	[Parameter(Mandatory = $true)]
	[string]$SqlUserName,
	[string]$SqlUserPassword,
	[Parameter(Mandatory = $true)]
	[string]$DatabaseRoles,
	[switch]$RandomPassword,
	[switch]$ResetPassword,
	[switch]$GrantExecute
)

. "$($PSScriptRoot)\Convert-SecureStringToString.ps1"

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

	if ([string]::IsNullOrWhiteSpace($PasswordSecretName)) {
		$secretName = "$($database.replace('_', ''))Password"
	}
	else {
		$secretName = $PasswordSecretName
	}

	Write-Host "Creating User Password Secret if it doesn't exist. Secret Name: $($secretName)"
	& "$($PSScriptRoot)\Set-PasswordInKeyVault.ps1" -KeyVaultName $AppKeyVaultName -SecretName $secretName -CustomPassword $SqlUserPassword -Randomize:$RandomPassword -Reset:$ResetPassword

	Write-Host "Get Password from KeyVault"
	$result = Get-AzKeyVaultSecret -VaultName $AppKeyVaultName -Name $secretName
	$dbUserPassword = Convert-SecureStringToString $result.SecretValue

	Write-Host "Build the query to Create the User"
	$query = & "$($PSScriptRoot)\Get-AddAzureSqlUserQuery.ps1" -Username "$($SqlUserName)" -Password "$($dbUserPassword)" -DatabaseRoles $databaseRolesArray -AddGrantExecute:$GrantExecute

	Write-Host "Setting/Permissioning Application User: $($SqlUserName) in Database: $($database)"
	& "$($PSScriptRoot)\Invoke-ExecuteSqlCommand.ps1" -SqlServerName $SqlServerName -DatabaseName $database -DbUsername $AdminDbUserName -DbPassword $AdminDbPassword -Query $query
}