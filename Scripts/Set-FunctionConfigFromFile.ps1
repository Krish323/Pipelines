###############################################################################
# Script: Set-FunctionConfigFromFile.ps1
# Purpose:  Adds/Updates app settings and connection strings to an App Service
#       from settings loaded from a JSON file
# Parameters:
#       $ArtifactFolder : Folder containing extracted package
#       $SettingsFilePattern : File to search for to load settings from
#		$AppServiceName : Name of app service to update
#		$PreserveExistingKeyValues : When true doesn't update existing settins
#           on the app service. Default is $false.
###############################################################################
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ArtifactFolder,
    [Parameter(Mandatory = $true)]
    [string] $SettingsFilePattern,
    [Parameter(Mandatory = $true)]
    [string] $AppServiceName,
    [switch] $PreserveExistingKeyValues
)

Write-Host "Parameters:"
Write-Host "ArtifactFolder: $($ArtifactFolder)"
Write-Host "SettingsFilePattern: $($SettingsFilePattern)"
Write-Host "AppServiceName: $($AppServiceName)"
Write-Host "PreserveExistingKeyValues: $($PreserveExistingKeyValues)`n`n"

Write-Host "Get Function Resource Group"
$azureResource = Get-AzResource -Name $AppServiceName

if ($null -eq $azureResource) {
    throw "Azure Resource [$($AppServiceName)] does not exist!"
}
else {
    $appServiceResourceGroupName = $azureResource.ResourceGroupName
}

Write-Host "Searching $($ArtifactFolder) for Environment Config: $($SettingsFilePattern)`n"
$environmentConfig = Get-ChildItem -Path $ArtifactFolder -Filter $SettingsFilePattern -Recurse

Write-Host "Found the following Environment Config file(s):"
$environmentConfig | ForEach-Object { Write-Host $_.FullName }

if ($environmentConfig.Count -ne 1) {
    throw "Invalid application configuration. A single environment config file matching the environment pattern was not found."
}

Write-Host "Loading app settings file: $($environmentConfig.FullName)"
$config = Get-Content $environmentConfig.FullName | Where-Object { !($_.ToString().Trim().StartsWith('//')) } | ConvertFrom-Json
$connectionStrings = $config.ConnectionStrings.PsObject.Properties
$appSettings = $config.Values.PsObject.Properties

Write-Host "Loading web app: $($AppServiceName)"
$appService = Get-AzWebApp -Name $AppServiceName -ResourceGroupName $appServiceResourceGroupName

Write-Host "Add existing AppSettings to Hashtable"
$appSettingsHash = @{}
foreach ($appSetting in $appService.SiteConfig.AppSettings) {
    $appSettingsHash[$appSetting.Name] = $appSetting.Value;
}

Write-Host "Add existing ConnectionStrings to Hashtable"
$connectionStringsHash = @{}
foreach ($connectionString in $appService.SiteConfig.ConnectionStrings) {
    $connectionStringsHash[$connectionString.Name] = @{Type = $connectionString.Type.ToString(); Value = $connectionString.ConnectionString.ToString() }
}

Write-Host "`n`n--- Current App Settings ---$($appSettingsHash | Out-String)"
Write-Host "`n`n--- Current Connection Strings ---$($connectionStringsHash | Out-String)`n`n"

# Add any new settings and override any that already exist
Write-Host "Updating app settings"
foreach ($appSetting in $appSettings) {
    # If this key is already in the hash table and the -PreserverExistingKeyValues switch is set,
    # do not set the appsetting to what is in the config file
    if (!($appSettingsHash.ContainsKey($appSetting.Name) -and $PreserveExistingKeyValues)) {
        Write-Host "Setting - Name: $($appSetting.Name) Value: $($appSetting.Value)"
        $appSettingsHash[$appSetting.Name] = $appSetting.Value
    }
}

Write-Host "`n`n----- Connection Strings in $($environmentConfig.FullName) -----`n"
foreach ($connectionString in $connectionStrings) {
    if (!($connectionStringsHash.ContainsKey($connectionString.Name) -and $PreserveExistingKeyValues)) {
        Write-Host "Setting - Name: $($connectionString.Name) Value: $($connectionString.Value)"
        $connectionStringsHash[$connectionString.Name] = @{Type = 'Custom'; Value = $connectionString.Value }
    }
}

Write-Host "`n`n--- Updated App Settings ---$($appSettingsHash | Out-String)`n`n"
Write-Host "`n`n--- Updated Connection Strings ---$($connectionStringsHash | Out-String)`n`n"

"-- checking if the connecting string has null value or not---`n"
if ($connectionStringsHash.Count -eq 0) {
    Write-Host "Updating App Settings Only"
    Update-AzFunctionAppSetting -Name $AppServiceName -ResourceGroupName $appServiceResourceGroupName -AppSetting $appSettingsHash -Force
}
else {
    Write-Host "Updating App Settings and Connection Strings"
    Set-AzWebApp -Name $AppServiceName -ResourceGroupName $appServiceResourceGroupName -ConnectionStrings $connectionStringsHash
    Update-AzFunctionAppSetting -Name $AppServiceName -ResourceGroupName $appServiceResourceGroupName -AppSetting $appSettingsHash -Force
}

Write-Host "`nRemoving unneeded settings files: $($environmentConfig.DirectoryName)"
Get-ChildItem -Path $environmentConfig.DirectoryName | Remove-Item -Recurse -Force -Confirm:$false

Write-Host "Set-FunctionConfigFromFile completed successfully"