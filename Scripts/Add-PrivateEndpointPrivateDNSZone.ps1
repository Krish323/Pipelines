###############################################################################
# Script: Add-PrivateEndpointPrivateDnsZone.ps1
# Purpose:  Attach private endpoint to Deloitte private DNS zone.
# Parameters:
#      PrivateEndpointName: Internal private endpoint name
#      ResourceGroupName: Name of Resource Group where the private endpoint 
#       belongs to
#      SubnetId: Subnet ID which the private endpoint belongs to
#      PrivateDnsZoneId: Private DNS zone ID where the private endpoint will
#        be attach to
###############################################################################
[CmdletBinding()]
Param
(
  [Parameter(Mandatory)]
  [string] $PrivateEndpointName,
  [Parameter(Mandatory)]
  [string] $ResourceGroupName,
  [Parameter(Mandatory)]
  [string] $SubnetId,
  [Parameter(Mandatory)]
  [string] $PrivateDnsZoneId
)

Write-Host "`n`nEnter Add-PrivateEndpointPrivateDnsZone.ps1`nParameters:"
Write-Host "PrivateEndpointName: $PrivateEndpointName"
Write-Host "ResourceGroupName: $ResourceGroupName"
Write-Host "SubnetId: $SubnetId"
Write-Host "PrivateDnsZoneId: $PrivateDnsZoneId"

Write-Host "`nChecking if the private endpoint [$PrivateEndpointName] has a private DNS attached"
$privateDnsZone = Get-AzPrivateDnsZoneGroup -ResourceGroupName $ResourceGroupName -PrivateEndpointName $PrivateEndpointName

if ($privateDnsZone.PrivateDnsZoneConfigs.Count -gt 0) {
  Write-Host "The private endpoint $PrivateEndpointName is attached to private DNS zone: $($privateDnsZone.PrivateDnsZoneConfigs[0].PrivateDnsZoneId)"
  exit
}

# Getting the virtual network name and resource group from subnet id
$parts = $SubnetId.Split("/")
$virtualNetworkResourceGroupName = $parts[4]
$virtualNetworkName = $parts[8]
$subscriptionId = $parts.Split("/")[2]

Write-Host "`nVirtual Network Name: $virtualNetworkName"
Write-Host "Virtual Network Resource Group Name: $virtualNetworkResourceGroupName"
Write-Host "Subscription ID: $subscriptionId"
$virtualNetworkId = $(Get-AzVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $VirtualNetworkResourceGroupName).Id
  
# Getting the private endpoint id and the subscription id of it
$privateEndpointId = $(Get-AzPrivateEndpoint -Name $PrivateEndpointName -ResourceGroupName $ResourceGroupName).Id

$PrivateDnsZones = @()
$PrivateDnsZones += $PrivateDnsZoneId
Write-Host "PrivateDnsZones ID: $PrivateDnsZoneId"

$dnsZoneIdObjArray = @()
foreach ($id in $PrivateDnsZones) {
    $dnsZoneIdObj = New-Object -TypeName PSCustomObject 
    $dnsZoneIdObj | Add-Member -MemberType NoteProperty -Name "dnsZoneId" -Value $id
    $dnsZoneIdObjArray += $dnsZoneIdObj
}

$body = @{
  privateEndpointResourceId  = $privateEndpointId
  dnsZones                   = $dnsZoneIdObjArray
  notifyTo                   = "usassurancedevopsame@deloitte.com"
  Scope                      = "/subscriptions/$subscriptionId"
}
$jsonbody = $body | ConvertTo-Json -Compress
  
Write-Host "`nGetting access token now"
$token = (Get-AzAccessToken).Token
$headers = @{"Authorization" = "Bearer $($token)" }
$oneCloudApi = "https://onecloudapi.deloitte.com/privateendpoint/v2/PrivateEndpointDns"

for ($i = 1; $i -le 3; $i++) {
  try {
    Write-Host "`nAttempt $i : Attaching private endpoint to private DNS zone"
    $dnsResult = Invoke-RestMethod -Uri $oneCloudApi -Method Post -Headers $headers -Body $jsonbody -ContentType 'application/json' -ErrorAction "Stop"
    break;
  }
  catch {
    Write-Host $_
    Start-Sleep -Seconds 1
  }
}
  
$apiValidationString = "Private Endpoint successfully added to Private DNS Zone Group."
if ($dnsResult -eq $apiValidationString) {
  Write-Host "`nThe private endpoint $PrivateEndpointName has been attached succesfully to private DNS zone: $PrivateDnsZoneId"
}
else {
  throw $dnsResult
} 
Write-Host "`n`nExit Add-PrivateEndpointPrivateDnsZone.ps1"