###############################################################################
# Script: Invoke-LoadVariableFiles.ps1
# Purpose:  Creates ADO Pipeline variables from a JSON variable file
# Parameters:
#       $VariableFilesFolder: Folder containing all variable files
#		$SharedVariablesFile : Name of the shared variable file that contains the
#           name of the other variable files
#		$Environment : Environment to load variables for
#       $Geo: Geo to load variables for
#       $Lifecycle: Lifecycle to load variables for
###############################################################################
param(
    [Parameter(Mandatory = $true)]
    [string] $VariableFilesFolder,
    [Parameter(Mandatory = $true)]
    [string] $SharedVariablesFile,
    [Parameter(Mandatory = $true)]
    [string] $Environment,
    [Parameter(Mandatory = $true)]
    [string] $Geo,
    [Parameter(Mandatory = $true)]
    [string] $Lifecycle
)

. "$($PSScriptRoot)\Add-PipelineVariable.ps1"

Write-Host "`n`nEnter Invoke-LoadVariableFiles.ps1`nParameters:"
Write-Host "VariableFilesFolder: $($VariableFilesFolder)"
Write-Host "SharedVariablesFile: $($SharedVariablesFile)"
Write-Host "Environment: $($Environment)"
Write-Host "Geo: $($Geo)"
Write-Host "Lifecycle: $($Lifecycle)`n"

$sharedFileFullPath = "$($VariableFilesFolder)\$($SharedVariablesFile)"

if (-Not(Test-Path -Path "$sharedFileFullPath")) {
    throw "Variable File not found: $($sharedFileFullPath)"
}

$releaseVariables = Get-Content -Path $sharedFileFullPath | Out-String | ConvertFrom-Json
$variableFiles = $releaseVariables.VariableFiles

if ($null -eq $variableFiles) {
    throw "Unable to load varible manifests! Missing VariableFiles object in $($sharedFileFullPath)."
}

& "$($PSScriptRoot)\Set-PipelineVariables.ps1" -VariableFileName "$($VariableFilesFolder)\$($variableFiles.EnvironmentVariablesFile)" -SubsectionPath "$Environment"
& "$($PSScriptRoot)\Set-PipelineVariables.ps1" -VariableFileName "$sharedFileFullPath"
& "$($PSScriptRoot)\Set-PipelineVariables.ps1" -VariableFileName "$($VariableFilesFolder)\$($variableFiles.LifecycleVariablesFile)" -SubsectionPath "$($Lifecycle).$($Geo)"
& "$($PSScriptRoot)\Set-PipelineVariables.ps1" -VariableFileName "$($VariableFilesFolder)\$($variableFiles.GeoVariablesFile)" -SubsectionPath "$Geo"

Write-Host "`n`nExit Invoke-LoadVariableFiles.ps1"
