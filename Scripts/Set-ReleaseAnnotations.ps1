###############################################################################
# Script: Set-ReleaseAnnotations.ps1
# Purpose:  Set the release annotations in environment app insights 
# Parameters:
#       $AppInsightsName : App Insight name
###############################################################################
param(
    [Parameter(Mandatory=$true)]
    [string] $AppInsightsName
)

Write-Host "Enter Set-ReleaseAnnotations.ps1`n"

Write-Host "Getting application insight resource id`n"

$appInsightResourceId = $(Get-AzResource -Name $AppInsightsName).ResourceId

$releaseProperties = @{
    "BuildNumber"="$env:Build_BuildNumber";
    "BuildRepositoryName"="$env:Build_Repository_Name";
    "BuildRepositoryProvider"="$env:Build_Repository_Provider";
    "BuildDefinitionName"="$env:Build_DefinitionName";
    "ReleaseDescription"="Triggered by $env:Build_DefinitionName $env:Build_BuildNumber";
    "BuildId"="$env:Build_BuildId";
    "BuildRequestedFor"="$env:Build_RequestedFor";
    "BuildUri"="$env:Build_BuildUri";
    "SourceBranch"="$env:Build_SourceBranch";
    "Label" = "Success"
 }

$annotation = @{
    Id = [GUID]::NewGuid();
    AnnotationName = "$env:Build_DefinitionName";
    EventTime = (Get-Date).ToUniversalTime().GetDateTimeFormats("s")[0];
    Category = "Deployment";
    Properties = ConvertTo-Json $releaseProperties -Compress
}

$body = (ConvertTo-Json $annotation -Compress) -replace '(\\+)"', '$1$1"' -replace "`"", "`"`""

Write-Host "Printing body that is going to be seend to Az rest API to set release annotations`n"

Write-Host ($body | Format-Table | Out-String)

Write-Host "Calling Az rest API to set release annotations`n"

az rest --method put --uri "$appInsightResourceId/Annotations?api-version=2015-05-01" --body "$body"

Write-Host "`nSet-ReleaseAnnotations.ps1 completed successfully!"
