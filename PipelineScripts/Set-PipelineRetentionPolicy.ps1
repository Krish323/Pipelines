###############################################################################
# Script: Set-PipelineRetentionPolicy.ps1
# Purpose:  Clone Audit DevOps Share Tools Repository 
# Parameters:
#		$AccessToken : API Auth token
#		$DefinitionId : Pipeline Definition ID
#		$OwnerId : User ID of pipeline execution
#		$RunId : Pipeline execution build ID
#		$CollectionUri : Organization name
#		$TeamProject : Project name
###############################################################################

param(
    [Parameter(Mandatory = $true)]
    [string] $AccessToken,
    [Parameter(Mandatory = $true)]
    [string] $DefinitionId,
    [Parameter(Mandatory = $true)]
    [string] $OwnerId,
    [Parameter(Mandatory = $true)]
    [string] $RunId,
    [Parameter(Mandatory = $true)]
    [string] $CollectionUri,
    [Parameter(Mandatory = $true)]
    [string] $TeamProject
)

Write-Host "`n`nEnter Set-PipelineRetentionPolicy.ps1`nParameters:"
Write-Host "DefinitionId: $($DefinitionId)"
Write-Host "OwnerId: $($OwnerId)"
Write-Host "RunId: $($RunId)"
Write-Host "CollectionUri: $($CollectionUri)"
Write-Host "TeamProject: $($TeamProject)"

Write-Host "`n`nSetting Pipeline Execution Retention Policy`n"

$contentType = "application/json";
$headers = @{ Authorization = $AccessToken };
$rawRequest = @{ daysValid = 36500; definitionId = $DefinitionId; ownerId = $OwnerId; protectPipeline = $true; runId = $RunId };
$request = ConvertTo-Json @($rawRequest);
$uri = "$CollectionUri$TeamProject/_apis/build/retention/leases?api-version=7.0";
Invoke-RestMethod -uri $uri -method POST -Headers $headers -ContentType $contentType -Body $request;

Write-Host "`n`nExit Set-PipelineRetentionPolicy.ps1`n"