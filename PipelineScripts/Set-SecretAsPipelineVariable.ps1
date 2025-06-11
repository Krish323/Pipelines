###############################################################################
# Script: Set-SecretAsPipelineVariable.ps1
# Purpose: Gets a secret from a key vault and adds it as a Secret Pipeline variable
# Parameters:
#		$KeyVaultName: Key Vault name containing the secret
#       $SecretName: Secret Name containing the DB Admin Password
#       $VariableName: Otional. Name of Pipeline Variable to store SecretName in
# Outputs:
#
# Returns:
###############################################################################
param(
    [parameter(Mandatory = $true)]
    [String] $KeyVaultName,
    [parameter(Mandatory = $true)]
    [String] $SecretName,
    [parameter(Mandatory = $true)]
    [String] $VariableName,
    [Switch] $IsOutput
)

. "$($PSScriptRoot)\Add-PipelineVariable.ps1"
. "$($PSScriptRoot)\..\Scripts\Convert-SecureStringToString.ps1"

Write-Host "Enter Set-SecretAsPipelineVariable`n`nParameters:"
Write-Host "KeyVaultName: $KeyVaultName"
Write-Host "SecretName: $SecretName"
Write-Host "VariableName: $VariableName"

Write-Host "Get [$SecretName] from [$KeyVaultName]"
$secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName

if ($null -eq $secret) {
    throw "Secret: $($SecretName) not found in Key Vault: $($KeyVaultName)"
}

$secretValuePlainText = Convert-SecureStringToString $secret.SecretValue
Add-PipelineVariable -VariableName $VariableName -Value $secretValuePlainText -IsSecret -IsOutput:$IsOutput
