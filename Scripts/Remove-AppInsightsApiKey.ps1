###############################################################################
# Script: Remove-AppInsightsApiKey.ps1
# Purpose: Removes an Api Key with the specified description
# Parameters:
#       $ResourceGroupName : Resource group containing the App Insights instance
#       $AppInsightsName : App Insights instance to generate the API Key on
#       $ApiKeyDescription : Api Key Description
# Outputs:
# Returns:
###############################################################################
param(
    [Parameter(Mandatory=$true)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $AppInsightsName,
    [Parameter(Mandatory=$true)]
    [string] $ApiKeyDescription
)

Write-Host "Enter Remove-AppInsightsApiKey"

Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

Write-Host "`nCheck if Api Key '$($ApiKeyDescription)' exists"
$apiKey = Get-AzApplicationInsightsApiKey -Name $AppInsightsName -ResourceGroupName $ResourceGroupName | Where-Object { $_.Description -eq $ApiKeyDescription }

if ($apiKey) {
    Write-Host "Deleting Api Key with description '$($ApiKeyDescription)'"
    Remove-AzApplicationInsightsApiKey -ResourceGroupName $ResourceGroupName -Name $AppInsightsName  -ApiKeyId $apiKey.id
}
else {
    Write-Host "No Api Key found on $($AppInsightsName)"
}

Write-Host "`nExit Remove-AppInsightsApiKey"