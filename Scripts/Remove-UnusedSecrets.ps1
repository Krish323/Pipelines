###############################################################################
# Script: Remove-UnusedSecrets.ps1
# Purpose: Remove all secrets from given key vault which aren't in the given
#          list
# Parameters:
#       $KeyVaultName : Key vault resource name
#       $SecretsToKeep : List of key vault secrets to be keep
# Outputs:
# Returns:
###############################################################################
param(
    [Parameter(Mandatory = $true)]
    [string] $KeyVaultName,
    [Parameter(Mandatory=$true)]
    [string[]] $SecretsToKeep
)

Write-Host "Enter Remove-UnusedSecrets`n`nParameters:"
Write-Host "KeyVaultName: $($KeyVaultName)"
Write-Host "SecretsToKeep:"
$SecretsToKeep

if ($SecretsToKeep.Count -eq 0) {
    throw "-SecretsToKeep cannot be empty"
}

Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

Write-Host "`n`nGet existing secrets from $($KeyVaultName)`n"
$existingSecrets = Get-AzKeyVaultSecret -VaultName $KeyVaultName

foreach ($secret in $existingSecrets) {
    if ($secret.Name -in $SecretsToKeep) {
        Write-Host "Keeping secret $($secret.Name)"
    }
    else {
        Write-Host "Deleting secret $($secret.Name)"
        Remove-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secret.Name -Force | Out-Null
    }
}

Write-Host "`nRemove-UnusedSecrets completed successfully!"