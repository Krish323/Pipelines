###############################################################################
# Script: Add-ResourceGroup.ps1
# Purpose:  Creates a Resource Group.
# Parameters:
#      ResourceGroupName: Name of Resoruce Group to create/udpate
#      Location: Resource Group Location
###############################################################################
[CmdletBinding()]
Param
(
    [Parameter(Mandatory)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory)]
    [string] $Location
)

Write-Host "`nParameters"
Write-Host "ResourceGroupName: $ResourceGroupName"
Write-Host "Location: $Location"
Write-Host "`n"

Write-Host "`n`nChecking if $($resourceGroupName) exists."
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

if (-not $resourceGroup) {
    Write-Host "Resource Group does not exist. Creating Resource Group"
    New-AzResourceGroup -Name $ResourceGroupName.ToUpper() -Location "$Location"
    
    Write-Host "`nResource Group [$($ResourceGroupName)] created successfully."
}

Write-Host "`nExit Add-ResourceGroup"
