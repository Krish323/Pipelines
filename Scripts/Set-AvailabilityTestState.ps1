###############################################################################
# Script: Set-AvailabilityTestState.ps1
# Purpose:  Start/Stop all availability tests and metrical alerts in a resource group.
# Parameters:
#   $ResourceGroupName : Resource group name containing the Availability Tests
#   $EnableAvailabilityTests : Start/Stop the availability tests
###############################################################################
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $ResourceGroupName,
  [Parameter(Mandatory = $true)]
  [bool] $EnableAvailabilityTests
)

Write-Host "`nEnter Set-AvailabilityTestState.ps1`n`nParameters:"
Write-Host "ResourceGroupName: $($ResourceGroupName)"
Write-Host "EnableAvailabilityTests: $($EnableAvailabilityTests)"

Write-Host "`n`nGet all Web Tests in $($ResourceGroupName)"
$webTests = Get-AzApplicationInsightsWebTest -ResourceGroupName $ResourceGroupName

foreach ($webTest in $webTests) {
  Write-Host "`nProcessing web test: $($webTest.Name)"

  if ($webTest.Enabled -ne $EnableAvailabilityTests) {
    Write-Host "`tGetting resource obect"
    $resourceObject = Get-AzResource -ResourceId $webTest.id
    $resourceObject.Properties.Enabled = $EnableAvailabilityTests

    Write-Host "`tSetting state"
    $resourceObject | Set-AzResource -Force | Out-Null
  }
  else {
    Write-Host "`tWeb test is already in the correct state"
  }
}

Write-Host "`n`nGet all Metrical Alert Rules in $($ResourceGroupName)"
$metricalAlertRules = Get-AzMetricAlertRuleV2 -ResourceGroupName $ResourceGroupName

foreach ($metricalAlertRule in $metricalAlertRules) {
  Write-Host "`nProcessing metrical alert rule: $($metricalAlertRule.Name)"

  if ($metricalAlertRule.enabled -ne $EnableAvailabilityTests) {
    Write-Host "`tGetting resource obect"
    $resourceObject = Get-AzResource -ResourceId $metricalAlertRule.id
    $resourceObject.Properties.enabled = $EnableAvailabilityTests

    Write-Host "`tSetting state"
    $resourceObject | Set-AzResource -Force | Out-Null
  }
  else {
    Write-Host "`tMetrical alert rule is already in the correct state"
  }
}

Write-Host "`n`nSet-AvailabilityTestState.ps1 completed successfully"
