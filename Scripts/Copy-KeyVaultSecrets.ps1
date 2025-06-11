###############################################################################
# Script: Copy-KeyVaultSecrets.ps1
# Purpose:  Copies all secrets from source to destination key vault
# Parameters:
#		$SourceKeyVaultName : Key Vault to copy from
#		$DestinationKeyVaultName : Key Vault to copy to
###############################################################################
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$SourceKeyVaultName,
  [Parameter(Mandatory = $true)]
  [string]$DestinationKeyVaultName,
  [string[]]$ExcludeSecrets
)

. "$($PSScriptRoot)\Convert-SecureStringToString.ps1"

Write-Host "`n`nEnter Copy-KeyVaultSecrets`nParameters:"
Write-Host "SourceKeyVaultName: $SourceKeyVaultName"
Write-Host "DestinationKeyVaultName: $DestinationKeyVaultName"
Write-Host "ExcludeSecrets:"
$ExcludeSecrets

Write-Host "`nGet all secrets from KeyVault [$($SourceKeyVaultName)]"
$copySecrets = Get-AzKeyVaultSecret -VaultName $SourceKeyVaultName

# Loop through the secrets and copy
foreach ($secret in $copySecrets) {
  $secretName = $secret.Name

  # Only copy if this secret is not in the list of excluded secrets
  if ($ExcludeSecrets -notcontains $secretName) {
    Write-Output "`nGetting [$secretName] value from [$SourceKeyVaultName]"
    $value = (Get-AzKeyVaultSecret -VaultName $SourceKeyVaultName -Name $secretName -ErrorAction Stop).SecretValue

    Write-Output "Setting [$secretName] in [$DestinationKeyVaultName]"
    Set-AzKeyVaultSecret -VaultName $DestinationKeyVaultName -Name $secretName -SecretValue $value -ErrorAction Stop | Out-Null
  }
}

Write-Host "`n`nExit Copy-KeyVaultSecrets"
