###############################################################################
# Script: Remove-AzResources.ps1
# Purpose:  Delete all the resources in a given resource group except by a list
#           of types
# Parameters:
#		$ResourceGroupName : Resource group name of the resources to be deleted.
#       $ProtectedResourceTypeList: list of resources types to keep.
###############################################################################
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [array]$ProtectedResourceTypeList,
    [switch]$ProtectInternalPrivateEndpoints
)

Write-Host "`n`nEnter Remove-AzResources`nParameters:"
Write-Host "ResourceGroupName: $($ResourceGroupName)"
Write-Host "ProtectedResourceTypeList:"
$ProtectedResourceTypeList
Write-Host "ProtectInternalPrivateEndpoints: $($ProtectInternalPrivateEndpoints)"


Write-Host "`n`nCheck if there's Azure Resouce Locks in the resource group: $ResourceGroupName"
$allAzLocks = Get-AzResourceLock -ResourceGroupName $ResourceGroupName

while ($allAzLocks.count -ne 0) {
    # Loop over Resource Locks and delete each
    foreach ($azLock in $allAzLocks) {
        Write-Host "`nRemove Azure Resouce Lock: $($azLock.Name)"
        Remove-AzResourceLock -ResourceId $azLock.ResourceId -Force -Confirm:$False | Out-Null
    }

    Write-Host "`nCheck if there's Azure Resouce Locks in the resource group"
    $allAzLocks = Get-AzResourceLock -ResourceGroupName $ResourceGroupName
}

$resourceOrderRemovalOrder = [ordered]@{
    "Microsoft.Web/sites"                              = 0
    "Microsoft.Web/serverfarms"                        = 1
    "Microsoft.Insights/components"                    = 2
    "Microsoft.SignalRService/SignalR"                 = 3
    "Microsoft.Sql/servers"                            = 4
    "Microsoft.KeyVault/vaults"                        = 5
    "Microsoft.Storage/storageAccounts"                = 6
    "Microsoft.ManagedIdentity/userAssignedIdentities" = 7
    "Microsoft.Network/networkInterfaces"              = 8
    "Microsoft.Network/virtualNetworks"                = 9
    "Microsoft.Network/networkSecurityGroups"          = 10
    "Microsoft.Network/privateDnsZones"                = 11
}

$filter = @("Microsoft.Sql/servers/databases", "Microsoft.Sql/servers/elasticPools")

Write-Host "Converting the list of protected resource type to an array"
$protectedResourceTypeListArray = $ProtectedResourceTypeList.Split(',')

$filter += $protectedResourceTypeListArray

Write-Host "Getting all Azure Resources from $ResourceGroupName"
if ($ProtectInternalPrivateEndpoints) {
    $allAzResources = Get-AzResource -ResourceGroupName $ResourceGroupName | Where-Object { $_.ResourceType -notin $filter -And $_.Name -notmatch "pe.*internal" }
}
else {
    $allAzResources = Get-AzResource -ResourceGroupName $ResourceGroupName | Where-Object { $_.ResourceType -notin $filter }
}

while ($allAzResources.count -ne 0) {
    $orderedAzResources = $allAzResources | Sort-Object @{
        Expression = { $resourceOrderRemovalOrder[$_.ResourceType] }
        Descending = $False
    }

    foreach ($azResource in $orderedAzResources) {
        Write-Host "Processing $($azResource.Name)"
        Remove-AzResource -ResourceId $($azResource.ResourceId) -Force | Out-Null
    }

    Write-Host "Checking for leftover resources in resource group"
    if ($ProtectInternalPrivateEndpoints) {
        $allAzResources = Get-AzResource -ResourceGroupName $ResourceGroupName | Where-Object { $_.ResourceType -notin $filter -And $_.Name -notmatch "pe.*internal" }
    }
    else {
        $allAzResources = Get-AzResource -ResourceGroupName $ResourceGroupName | Where-Object { $_.ResourceType -notin $filter }
    }
}

Write-Host "`n`nExit Remove-AzResources"