###############################################################################
# Script: Set-TrafficManagerEndpointStatus.ps1
# Purpose:  Adds Sql Server Firewall Exceptions for the Symantec WSS Agent
# Parameters:
#       $ResourceGroupName: Name of the Resource group on which the Storage Account is located
#		$SqlServerName: Sql Server Name to Update
#       $EndpointName: The name of the endpoint to enable. All other endpoints will be disabled.
###############################################################################
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$TrafficManagerName,
    [Parameter(Mandatory = $true)]
    [string]$EndpointName
)

Write-Host "`nEnter Set-TrafficManagerEndpointStatus"
Write-Host "`nParameters:"
Write-Host "ResourceGroupName: $ResourceGroupName"
Write-Host "TrafficManagerName: $TrafficManagerName"
Write-Host "EndpointName: $EndpointName"

Write-Host "Get Traffic Manager [$($TrafficManagerName)]`n"
$tmProfile = Get-AzTrafficManagerProfile -Name $TrafficManagerName -ResourceGroupName $resourceGroupName

if ($null -eq $tmProfile) {
    throw "Azure Resource [$($TrafficManagerName)] does not exist!"
}

Write-Host "[$($TrafficManagerName)] Endpoints:"
$tmProfile.Endpoints

# Loop through the profiles, enabling/disabling
# Can't use a Foreach loop for some reason on EMA-PROD-AZ-POOL. The variable declared in the foreach
# statement doesn't get passed an Endpoint object so .Name property is null.
$tmProfile.Endpoints | ForEach-Object {
    if ($_.Name -eq $EndpointName) {
        Write-Host "Enabling endpoint [$($TrafficManagerName)] - [$($_.Name)]"
        Enable-AzTrafficManagerEndpoint -Name $_.Name -ProfileName $TrafficManagerName -ResourceGroupName $resourceGroupName -Type ExternalEndpoints | Out-Null
    }
    else {
        Write-Host "Disabling endpoint [$($TrafficManagerName)] - [$($_.Name)]"
        Disable-AzTrafficManagerEndpoint -Name $_.Name -ProfileName $TrafficManagerName -ResourceGroupName $resourceGroupName -Type ExternalEndpoints -Force | Out-Null
    }
}

Write-Host "`n`nExit Set-TrafficManagerEndpointStatus"
