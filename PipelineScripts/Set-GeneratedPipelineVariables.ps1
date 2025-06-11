###############################################################################
# Script: Set-GeneratedPipelineVariables.ps1
# Purpose:  Generates ADO Pipeline variables based on parameters
# Parameters:
#       $AppName: App name used in resoures
#       $LocationCode: ITS Code for this location
#		$Environment : Environment to load variables for
#		$ContainerInstanceCodes: Comma separated list of Container Codes
#       $ContainerNamePrefix: Name prefix for each Database/Blob object
###############################################################################
param(
    [Parameter(Mandatory = $true)]
    [string] $AppName,
    [Parameter(Mandatory = $true)]
    [string] $LocationCode,
    [Parameter(Mandatory = $true)]
    [string] $Environment
)

. "$($PSScriptRoot)\Add-PipelineVariable.ps1"

Write-Host "`n`nEnter Set-GeneratedPipelineVariables.ps1`nParameters:"
Write-Host "AppName: $($AppName)"
Write-Host "LocationCode: $($LocationCode)"
Write-Host "Environment: $($Environment)`n"

# Resource Group names are all upper case by convention. Add here to guarantee convention.
$resourceGroupName = "AZRG-$($LocationCode)-AUD-$($AppName)-$($Environment)".ToUpper()
Add-PipelineVariable -VariableName 'resourceGroupName' -Value: $resourceGroupName

Write-Host "`n`nExit Set-GeneratedPipelineVariables.ps1"
