###############################################################################
# Script: Set-AppServiceState.ps1
# Purpose:  Starts, Stops, or Restarts 1 or All App Services in a resource group
# Parameters:
#		$ResourceGroupName : Name of resource group containing the app services to update
#		$AppServiceName : Optional. Name of app service to update. All in resource group if empty.
#		$Action : Action to take on the app service(s)
#		$RestartWaitSeconds : Optional. Number of seconds to wait before restarting app service(s)
###############################################################################
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    [string]$AppServiceName,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Start", "Stop", "Restart")]
    [string]$Action,
    [int]$RestartWaitSeconds = 10
)

# Build a hashtable of arguments to pass to Get-AzWebApp since AppServiceName is
# an optional script parameter.
$webAppParams = @{ ResourceGroupName = $ResourceGroupName}

Write-Host "Enter Set-AppServiceState.ps1`n"
Write-Host "ResourceGroupName: $ResourceGroupName"
# '\w' is regular expression that matches a word. If $AppServiceName is null, empty, or spaces,
# it will not be matched.
if ($AppServiceName -match "\w") {
    Write-Host "AppServiceName: $AppServiceName"
    # Add the Name of the app service that was passed
    $webAppParams["Name"] = $AppServiceName
}
else {
    # No app service name supplied
    Write-Host "AppServiceName: All in Resource Group"
}
Write-Host "Action: $Action"

# Set the text to use in logging
if ($Action -in ('Stop', 'Restart')) {
    $actionDesc = "Stopping"
}
else {
    $actionDesc = "Starting"
}

# Get the list of web apps to set the status of, passing the hashtable of parameters we built above
Write-Host "`nGet list of app services to update`n"
$appServices = Get-AzWebApp @webAppParams

# Loop through the app services and apply the action(s)
foreach ($appService in $appServices) {
    Write-Host "$($actionDesc) App Service: $($appService.Name)"

    if ($Action -in ('Stop', 'Restart')) {
        Stop-AzWebApp -ResourceGroupName $ResourceGroupName -Name $appService.Name | Out-Null
    }
    else {
        Start-AzWebApp -ResourceGroupName $ResourceGroupName -Name $appService.Name | Out-Null
    }
}

if ($Action -eq 'Restart') {
    if ($RestartWaitSeconds -gt 0) {
        # Pause execution to give the app services time to completely stop
        Write-Host "`nWaiting $RestartWaitSeconds seconds to allow services to stop"
        Start-Sleep -Seconds $RestartWaitSeconds
    }

    Write-Host " "

    # Loop through the app services and restart
    foreach ($appService in $appServices) {
        Write-Host "Starting App Service: $($appService.Name)"
        Start-AzWebApp -ResourceGroupName $ResourceGroupName -Name $appService.Name | Out-Null
    }
}

Write-Host "`nExit Set-AppServiceState.ps1"
