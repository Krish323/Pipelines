###############################################################################
# Script: Set-ContainerMatrixPipelineVariables.ps1
# Purpose:  Creates pipeline variables for Container Instance Database and
#           Blob names as a yml pipeline matrix.
# Parameters:
#       $AppName: Application Name
#       $ContainerNamePrefix: Name prefix for each Database/Blob object
#       $ContainerInstanceCodes: Comma separated list of Container Codes
#       $AppDatabases: Comma separated list of non-container database names
#           that should be created.
#       $AppBlobs: Comma separated list of non-container blob storage names
#           that should be created.
###############################################################################
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $AppName,
    [Parameter(Mandatory = $true)]
    [string] $ContainerNamePrefix,
    [Parameter(Mandatory = $true)]
    [string] $ContainerInstanceCodes,
    [string] $AppDatabases = '',
    [string] $AppBlobs = ''
)

. "$($PSScriptRoot)\Add-PipelineVariable.ps1"

Write-Host "`n`nEnter Set-ContainerMatrixPipelineVariables.ps1`nParameters:"
Write-Host "AppName: $($AppName)"
Write-Host "ContainerInstanceCodes: $($ContainerInstanceCodes)"
Write-Host "ContainerNamePrefix: $($ContainerNamePrefix)"
Write-Host "AppDatabases: $($AppDatabases)"
Write-Host "AppBlobs: $($AppBlobs)"

Write-Host "Generate prefixes"
$AppName = $AppName.substring(0,1).toupper()+$AppName.substring(1).tolower()
$containerCodeArray = $ContainerInstanceCodes.Split(',')
$blobContainerNamePrefix = "{0}-{1}" -f $AppName, $ContainerNamePrefix.Replace('_', '-')
$dbContainerNamePrefix = "{0}_{1}" -f $AppName.ToUpper(), $ContainerNamePrefix
$containerBlobNames = ''
$containerDbNames = ''
$jsonContent = @{}

Write-Host "Create JSON Objects from list of container codes"
# Loop through properties on this section of the file and add to Pipeline
foreach ($containerCode in $containerCodeArray) {
    Write-Host "Processing $($containerCode)"
    # Blob container names must be at least 3 characters long and contain only
    # lowercase letters, numbers or -
    # Blob name format is [prefix]-[container_code]. navigator-us for example.
    $blobName = "$($blobContainerNamePrefix)-$($containerCode)".ToLower()
    $containerBlobNames += $blobName + ","

    # Database Name format is [Prefix]_[Container_Code]. Navigator_Case_CA for example
    $dbName = "{0}_{1}" -f $dbContainerNamePrefix, $containerCode.ToUpper()
    $containerDbNames += $dbName + ","

    # Job Name
    $jobName = "Container_Deploy_{1}" -f $dbContainerNamePrefix, $containerCode.ToUpper()

    $jsonContent += @{
        $jobName = @{ "blobName" = $blobName; "databaseName" = $dbName; "containerCode" = $containerCode }
    }
}

Write-Host "`nConvert JSON object to text"
$jsonText = $jsonContent | ConvertTo-Json -Compress

Write-Host "Remove trailing commas from lists`n"
$containerBlobNames = $containerBlobNames.Substring(0, $containerBlobNames.Length - 1)
$containerDbNames = $containerDbNames.Substring(0, $containerDbNames.Length - 1)

if ($AppDatabases) {
    # Application related DB's were passed in. Add
    $completeDbNamesList = $AppDatabases.Trim() + "," + $containerDbNames
}
else {
    $completeDbNamesList = $containerDbNames
}

if ($AppBlobs) {
    # Application related DB's were passed in. Add
    $completeBlobNamesList = $AppBlobs.Trim() + "," + $containerBlobNames
}
else {
    $completeBlobNamesList = $containerBlobNames
}

# Add containerMatrix as an output variable so it can be referenced across Jobs.
# This is only used as a deployment job matrix.
Add-PipelineVariable -VariableName 'containerMatrix' -Value: $jsonText -IsOutput:$true

# Add a variable for each as a comma separated list and JSON array.
# Do not set these as output variables because they are always used in the current job.
# They are passed to ARM Templates and Powershell scripts.
Add-PipelineVariable -VariableName 'containerBlobNames' -Value: $containerBlobNames
Add-PipelineVariable -VariableName 'containerBlobNamesJson' -Value: $containerBlobNames.Split(',')
Add-PipelineVariable -VariableName 'completeBlobNamesJson' -Value: $completeBlobNamesList.Split(',')
Add-PipelineVariable -VariableName 'containerDbNames' -Value: $containerDbNames
Add-PipelineVariable -VariableName 'containerDbNamesJson' -Value: $containerDbNames.Split(',')
Add-PipelineVariable -VariableName 'completeDbNamesListJson' -Value: $completeDbNamesList.Split(',')

Write-Host "`n`nExit Set-ContainerMatrixPipelineVariables.ps1`n"
