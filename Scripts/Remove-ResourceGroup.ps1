###############################################################################
# Script: Remove-ResourceGroup.ps1
# Purpose:  Deletes a resource group
# Parameters:
#   $ResourceGroupName : Name of resource group to delete
###############################################################################
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName
)

Write-Host "Enter Remove-ResourceGroup.ps1"

#Check if the resource group exists
$resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $resourceGroup) {
    Write-Host "Resource Group [$($ResourceGroupName)] does not exist"
    Write-Host "Exit Remove-ResourceGroup.ps1"
    exit
}

Write-Host "Get Key Vaults in resource group [$($ResourceGroupName)]"
$keyVaults = Get-AzKeyVault -ResourceGroupName $ResourceGroupName

Write-Host "Get locks on resources in resource group [$($ResourceGroupName)]`n"
$existingLocks = Get-AzResourceLock -ResourceGroupName $ResourceGroupName

foreach ($lock in $existingLocks) {
    Write-Host "Deleting [$($lock.Name)] lock on resource [$($lock.ResourceName)]"
    Remove-AzResourceLock -LockId $lock.LockId -Force | Out-Null
}

# Waiting for 5 minutes for lock removal to be effective
Write-Host "`nWaiting 5 minutes grace period for lock removal."
Start-Sleep -Seconds 300

Write-Host "`nDeleting Resource Group [$($ResourceGroupName)]"
Remove-AzResourceGroup -Name $ResourceGroupName -Force

Write-Host " "

# Purge Soft Deleted Key Vaults
foreach ($keyVault in $keyVaults) {
    Write-Host "Purging Key Vault [$($keyVault.VaultName)]"
    Remove-AzKeyVault -VaultName $keyVault.VaultName -InRemovedState -Location $keyVault.Location -Force
}

Write-Host "`nExit Remove-ResourceGroup.ps1"
