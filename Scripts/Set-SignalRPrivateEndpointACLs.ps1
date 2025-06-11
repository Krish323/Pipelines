###############################################################################
# Script: Set-SignalRPrivateEndpointACLs.ps1
# Purpose:  Sets Network ACLs on SignalR service private endpoint to be in compliance with Cloud Architecture guidelines
# Parameters:
#		$ResourceGroupName : Resource Group containing SignalR service
#		$SignalRServiceName : Name of SignalR service to update
###############################################################################
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$SignalRServiceName
)
Write-Host "`nEnter Set-SignalRPrivateEndpointACLs.ps1`n"

Write-Host "`nParameters:"
Write-Host "ResourceGroupName: $ResourceGroupName"
Write-Host "SignalRServiceName: $SignalRServiceName`n"

Write-Host "Fetching [$($SignalRServiceName)] Endpoint Name"
$signalREndpointNames = (Get-AzPrivateEndpointConnection -ResourceGroupName $ResourceGroupName -ServiceName $SignalRServiceName -PrivateLinkResourceType Microsoft.SignalRService/SignalR).Name

Write-Host "Updating Private Endpoint Network ACLs`n"
foreach ($endpointName in $signalREndpointNames) {
    # Duplicate Az call required inside foreach to get the attached PE name as PowerShell is converting the object to a string of the data type name when trying to get a single object from the array
    $privateEndpointId = (Get-AzPrivateEndpointConnection -ResourceGroupName $ResourceGroupName -ServiceName $SignalRServiceName -PrivateLinkResourceType Microsoft.SignalRService/SignalR -Name $endpointName).PrivateEndpoint.Id
    # PrivateEndpoint.Name returns blank so have to get the name from resource ID
    $privateEndpointName = $privateEndpointId.split('/')[8]

    Write-Host "SignalR Endpoint Name: $endpointName"
    Write-Host "Private Endpoint Name: $privateEndpointName"
    # Set internal private endpoint traffic to only allow client connections and all others to only server connections
    if ($privateEndpointName -match 'internal') {
        Update-AzSignalRNetworkAcl -Name $SignalRServiceName -ResourceGroupName $ResourceGroupName -PrivateEndpointName $endpointName -DefaultAction Deny -Allow ClientConnection | Out-Null
        Write-Host "Successfully Updated ACL to ClientConnection`n"
    }
    else {
        Update-AzSignalRNetworkAcl -Name $SignalRServiceName -ResourceGroupName $ResourceGroupName -PrivateEndpointName $endpointName -DefaultAction Deny -Allow ServerConnection | Out-Null
        Write-Host "Successfully Updated ACL to ServerConnection`n"
    }
}
Write-Host "Private Endpoint Network ACLs Updated Successfully"

Write-Host "`nExit Set-SignalRPrivateEndpointACLs.ps1"