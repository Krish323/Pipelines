###############################################################################
# Script: Get-UserAssignedIdentityClientId.ps1
# Purpose:  Get the user assigned identity client id and set it up as pipeline
#           variable
# Parameters:
#       $UserAssignedIdentityName : User assigned identity name
#       $PipelineVariableName: User assigned identity pipeline variable name
###############################################################################
param(
    [Parameter(Mandatory=$true)]
    [string] $UserAssignedIdentityName,
    [Parameter(Mandatory=$true)]
    [string] $PipelineVariableName,
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName
)

. "$($PSScriptRoot)\..\PipelineScripts\Add-PipelineVariable.ps1"

Write-Host "Enter Get-UserAssignedIdentityClientId.ps1`n"

Write-Host "Getting user assigned identity client id for $($UserAssignedIdentityName)`n"

$userIdentity = Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name $UserAssignedIdentityName

if ($null -eq $userIdentity) {
    throw "The identity [$($UserAssignedIdentityName)] does not exist!"
}

$clientId = $userIdentity.ClientId

Write-Host "`n`nClient ID: $($clientId)"

Write-Host "`n`nSetting user assigned identity client id as pipeline variable`n"

Add-PipelineVariable -VariableName $PipelineVariableName -Value: $clientId

Write-Host "`Get-UserAssignedIdentityClientId.ps1 completed successfully!"
