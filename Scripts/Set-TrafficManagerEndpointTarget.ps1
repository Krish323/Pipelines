###############################################################################
# Script: Set-TrafficManagerEndpointTarget.ps1
# Purpose:  Adds Sql Server Firewall Exceptions for the Symantec WSS Agent
# Parameters:
#       $ResourceGroupName : Name of Resource Group containing the Function App
#       $TrafficManagerName: Traffic Manager Profile that contains the Endpoint.
#       $EndpointName: The name of the Endpoint to update.
#       $EndpointTarget: The net Target for the Endpoint.
###############################################################################
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $ResourceGroupName,
  [Parameter(Mandatory = $true)]
  [string] $TrafficManagerName,
  [Parameter(Mandatory = $true)]
  [string] $EndpointName,
  [Parameter(Mandatory = $true)]
  [string] $EndpointTarget
)

Write-Host "`n`nEnter Set-TrafficManagerEndpointTarget`nParameters:"
Write-Host "ResourceGroupName: $ResourceGroupName"
Write-Host "TrafficManagerName: $TrafficManagerName"
Write-Host "EndpointName: $EndpointName"
Write-Host "EndpointTarget: $EndpointTarget"

Write-Host "`nGet Traffic Manager Endpoint: $($EndpointName)"
$tmEndpoint = Get-AzTrafficManagerEndpoint -Name "$EndpointName" -ProfileName "$TrafficManagerName" -ResourceGroupName "$ResourceGroupName" -Type ExternalEndpoints

if ($null -eq $tmEndpoint) {
  throw "didn't find the endpoint"
}

if ($tmEndpoint.Target -ne $EndpointTarget) {
  Write-Host "Endpoint Target is currently: $($tmEndpoint.Target)"
  Write-Host "Updating Target to $($EndpointTarget)"
  $tmEndpoint.Target = $EndpointTarget
  Set-AzTrafficManagerEndpoint -TrafficManagerEndpoint $tmEndpoint | Out-Null
}
else {
  Write-Host "Endpoint Target is already correct. Nothing to do."
}

Write-Host "`n`nExit Set-TrafficManagerEndpointTarget"
