###############################################################################
# Script: Get-AppInsightsConnectionString.ps1
# Purpose: Gets AppInsight Connection String and places in pipeline variable
# Parameters:
#       $ResourceGroupName : Resource group containing the App Insights instance
#       $AppInsightsName : App Insights instance to generate the API Key on
#       $PipelineVariableName: User assigned identity pipeline variable name
# Outputs:
# Returns:
###############################################################################
param(
    [Parameter(Mandatory=$true)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $AppInsightsName,
    [Parameter(Mandatory=$true)]
    [string] $PipelineVariableName
)

. "$($PSScriptRoot)\..\PipelineScripts\Add-PipelineVariable.ps1"

Write-Host "Enter Get-AppInsightsConnectionString.ps1"

Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

Write-Host "Resource Group Name: $ResourceGroupName"
Write-Host "AppInsights Name: $AppInsightsName"
 
try {
    $appInsights = Get-AzApplicationInsights -ResourceGroupName "$ResourceGroupName" -Name "$AppInsightsName"
}
catch {
    Write-Host $_
    throw "Unable to get AppInsights $AppInsightName in Resource Group $ResourceGroupName"
}
 
$connectionString = $appInsights.ConnectionString

Add-PipelineVariable -VariableName $PipelineVariableName -Value: $connectionString

Write-Host "`nGet-AppInsightsConnectiongString.ps1 completed successfully!"