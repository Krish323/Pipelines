[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $KeyVaultName,
    [Parameter(Mandatory = $true)]
    [string] $SecretName,
    [Parameter(Mandatory = $true)]
    [string] $SecretValue
)

. "$($PSScriptRoot)\Convert-SecureStringToString.ps1"

Write-Output "`nEnter Add-SecretToKeyVault.ps1`n"

Write-Output "Check if [$SecretName] exists in [$KeyVaultName]`n"
$existingSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName
$updateSecret = $false

if ($null -eq $existingSecret) {
    Write-Output "Secret [$SecretName] not found in [$KeyVaultName]`n"
    $updateSecret = $true
}
else {
    $existingValue = Convert-SecureStringToString $existingSecret.SecretValue
    if ($existingValue -ne $SecretValue) {
        Write-Output "[$SecretName] exists in [$KeyVaultName] but does not have the correct value.`n"
        $updateSecret = $true
    }
}

if ($updateSecret) {
    $convertedSecret = ConvertTo-SecureString $SecretValue -AsPlainText -Force
    
    try {
        Write-Output "Setting [$SecretName] in [$KeyVaultName]`n"
        Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -SecretValue $convertedSecret | Out-Null
    }
    catch {
        Write-Error "ERROR: Could not add [$SecretName] to [$KeyVaultName] - $($_.Exception)"
    }
}
else {
    Write-Output "[$SecretName] already has the latest value in [$KeyVaultName]`n"
}

Write-Output "Exit Add-SecretToKeyVault`n"
