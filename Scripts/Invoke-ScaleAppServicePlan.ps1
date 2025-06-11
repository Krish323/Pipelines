###############################################################################
# Script: Invoke-ScaleAppServicePlan.ps1
# Purpose:  Scale up/down all app service plans in a resource group
# Parameters:
#		$ResourceGroupName : Resource group name containing the ASPs to scale
#		$WorkerSize : Size of the app service plan workers
#       $ScaleUp : Should the app service plan scale up or down?
###############################################################################
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    [parameter(Mandatory = $true)]
    [string]$Tier,
    [Parameter(Mandatory = $false)]
    [ValidateSet('Large', 'Medium', 'Small')]
    [string]$WorkerSize,
    [Parameter(Mandatory = $false)]
    [switch] $ScaleUp
)

Write-Host "`nEnter Invoke-ScaleAppServicePlan`n`nParameters:"
Write-Host "ResourceGroupName: $($ResourceGroupName)"
Write-Host "WorkerSize: $($WorkerSize)"
Write-Host "ScaleUp: $($ScaleUp)"

Write-Host "Get app service plans in $($ResourceGroupName)"
$appServicePlans = Get-AzAppServicePlan -ResourceGroupName $ResourceGroupName
$workSpaceId = "/subscriptions/8c71ef53-4473-4862-af36-bae6e40451b2/resourcegroups/audit_prod_rg_aaps_sec_oms/providers/microsoft.operationalinsights/workspaces/aaps-sec-oms"

foreach ($appServicePlan in $appServicePlans) {
    Write-Host "Get web apps in $($appServicePlan)"

    $webApps = Get-AzWebApp -AppServicePlan $appServicePlan | Where-Object { $_.Kind -notLike "*function*" }

    Write-Host "Checking for autoscale profile [$($appServicePlan.Name)-autoscale]"
    $autoscaleSettings = Get-AzAutoscaleSetting -ResourceGroupName $ResourceGroupName -Name "$($appServicePlan.Name)-autoscale"
    if ($ScaleUp) {
        Write-Host "Scaling up [$($appServicePlan.Name)] to [$($Tier)]"
        Set-AzAppServicePlan -Name $appServicePlan.Name -ResourceGroupName $resourceGroupName -Tier $Tier -NumberofWorkers 1 -WorkerSize $WorkerSize
        if ($autoscaleSettings) {
            Write-Host "Enabling autoscale profile [$($appServicePlan.Name)-autoscale]"
            Update-AzAutoscaleSetting -ResourceGroupName $ResourceGroupName -Name "$($appServicePlan.Name)-autoscale" -Enabled $true
        }

        # Add required Premium-only logs to diagnostic settings if scaling up to Premium SKU
        if ($Tier -Like "*Premium*") {
            # Sleep 10 seconds to allow time for SKU to change to Premium before attempting to enable Premium-only logs
            Start-Sleep -Seconds 10

            # Individual logs can't be toggled on/off as Set-AzDiagnosticSetting is deprecated. Entire object must be recreated with all logs included.
            $logs = @()
            $logs += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category AppServiceHTTPLogs
            $logs += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category AppServiceAuditLogs
            $logs += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category AppServiceIPSecAuditLogs
            $logs += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category AppServicePlatformLogs
            $logs += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category AppServiceAntivirusScanAuditLogs
            $logs += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category AppServiceFileAuditLogs
            foreach ($webApp in $webApps) {
                Write-Host "Adding diagnostic setting configuration to the webapp [$($webApp.Name)]"
                New-AzDiagnosticSetting -ResourceId $webApp.Id -Name "service" -WorkspaceId $workSpaceId -Log $logs
            }
        }
    }
    else {
        # Remove Premium-only logs from diagnostic settings before scaling down to Standard
        if ($Tier -Like "*Standard*") {
            $logs = @()
            $logs += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category AppServiceHTTPLogs
            $logs += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category AppServiceAuditLogs
            $logs += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category AppServiceIPSecAuditLogs
            $logs += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category AppServicePlatformLogs
            foreach ($webApp in $webApps) {
                Write-Host "Adding diagnostic setting configuration to the webapp [$($webApp.Name)]"
                New-AzDiagnosticSetting -ResourceId $webApp.Id -Name "service" -WorkspaceId $workSpaceId -Log $logs
            }
            # Sleep 10 seconds to allow time for Premium-only logs to be removed before changing SKU to Standard
            Start-Sleep -Seconds 10
        }
        
        if ($autoscaleSettings) {
            Write-Host "Disabling autoscale profile [$($appServicePlan.Name)-autoscale]"
            Update-AzAutoscaleSetting -ResourceGroupName $ResourceGroupName -Name "$($appServicePlan.Name)-autoscale" -Enabled $false
        }
        Write-Host "Scaling down [$($appServicePlan.Name)] to [$($Tier)]"
        Set-AzAppServicePlan -Name $appServicePlan.Name -ResourceGroupName $resourceGroupName -Tier $Tier -NumberofWorkers 1 -WorkerSize $WorkerSize
    }
}

Write-Host "`n`nExit Invoke-ScaleAppServicePlan.ps1"