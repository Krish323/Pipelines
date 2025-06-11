###############################################################################
# Script: Invoke-RotateSqlAdministratorPassword.ps1
# Purpose: Updates a sql server and key vault with a new db admin password
# Parameters:
#   $ResourceGroupName: Resource Group containing aql Server to update
#   $SqlServerName: Sql Server Name to Update
#   $KeyVaultName: Key Vault the Sql Login's password is stored in
#   $SecretName: Secret Name the Sql Login's password is stored in
###############################################################################
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $SqlServerName,
    [Parameter(Mandatory = $true)]
    [string] $KeyVaultName,
    [Parameter(Mandatory = $true)]
    [string] $SecretName
)

. "$($PSScriptRoot)\Convert-SecureStringToString.ps1"

Write-Host "Enter Invoke-RotateSqlAdministratorPassword.ps1`nParameters:"
Write-Host "ResourceGroupName: $($ResourceGroupName)"
Write-Host "SqlServerName: $($SqlServerName)"
Write-Host "KeyVaultName: $($KeyVaultName)"
Write-Host "SecretName: $($SecretName)"

Write-Host "`nCreating User Password Secret if it doesn't exist. Secret Name: $($SecretName)"
& "$($PSScriptRoot)\Set-PasswordInKeyVault.ps1" -KeyVaultName $KeyVaultName -SecretName $SecretName -Randomize -Reset

Write-Host "Get Password from KeyVault"
$passwordSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName

Write-Host "Set the Sql Server Admin Password"
Set-AzSqlServer -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName -SqlAdministratorPassword $passwordSecret.SecretValue | Out-Null

Write-Host "Exit Invoke-RotateSqlAdministratorPassword.ps1"
