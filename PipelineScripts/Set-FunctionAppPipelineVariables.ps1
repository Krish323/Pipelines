###############################################################################
# Script: Set-FunctionAppPipelineVariables.ps1
# Purpose:  Creates pipeline variables for Container Instance Database and
#           Blob names as a yml pipeline matrix.
# Parameters:
#       $AppName: Application Name
#       $LocationCode: Location code of the resources that will be deployed
#       $EnvironmentAlias: Environment alias
#       $FunctionAppNames: Comma separated list of function app names
#           that should be created.
###############################################################################
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $AppName,
    [Parameter(Mandatory = $true)]
    [string] $LocationCode,
    [Parameter(Mandatory = $true)]
    [string] $EnvironmentAlias,
    [Parameter(Mandatory = $true)]
    [string] $FunctionAppNames
)

. "$($PSScriptRoot)\Add-PipelineVariable.ps1"

Write-Host "`n`nEnter Set-FunctionAppPipelineVariables.ps1`nParameters:"
Write-Host "AppName: $($AppName)"
Write-Host "LocationCode: $($LocationCode)"
Write-Host "EnvironmentAlias: $($EnvironmentAlias)"
Write-Host "FunctionAppNames: $($FunctionAppNames)`n`n"

$functionAppArray = $FunctionAppNames.Split(',')
$functionAppList = ''

Write-Host "Create JSON Objects from list of function apps"
# Loop through properties on this section of the file and add to Pipeline
foreach ($functionApp in $functionAppArray) {
    Write-Host "Processing $($functionAppName)"
    # Function App name format is [EnvironmentAlias][AppName]fn[functionAppName][LocationCode]. dnavigatorfnqnause2 for example.
    $functionAppName = "$($EnvironmentAlias)$($AppName)fn$($functionApp)$($LocationCode)".ToLower()
    $functionAppList += $functionAppName + ","
}

Write-Host "Remove trailing commas from lists`n"
$functionAppList = $functionAppList.Substring(0, $functionAppList.Length - 1)

# Add a variable for each as a comma separated list and JSON array.
# Do not set these as output variables because they are always used in the current job.
# They are passed to ARM Templates and Powershell scripts.
Add-PipelineVariable -VariableName 'functionAppNamesListJson' -Value: $functionAppList.Split(',')

Write-Host "`n`nExit Set-FunctionAppPipelineVariables.ps1`n"
