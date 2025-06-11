###############################################################################
# Script: Invoke-RotateStorageAccountKeys.ps1
# Purpose:  Store the storage account connection string as a secret into the 
#           environment keyvault
# Parameters:
#		$ResourceGroupName : Resource Group containing the storage account.
#		$StorageAccountName : Storage account name required for the connection string.
#		$KeyName : Storage account access key name.
#       $FunctionAppArray : JSON Array of function app names to rotate
###############################################################################
param(
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $StorageAccountName,
    [ValidateSet('key1', 'key2', 'both')]
    [string] $KeyName = 'both',
    [string] $FunctionAppArray = $null
)

Write-Host "`nEnter Invoke-RotateStorageAccountKeys`n`nParameters:"
Write-Host "ResourceGroupName: $($ResourceGroupName)"
Write-Host "StorageAccountName: $($StorageAccountName)"
Write-Host "KeyName: $($KeyName)"
Write-Host "FunctionAppArray:"
$FunctionAppArray

# Build a list of the Key(s) to rotate
if ($KeyName -eq 'both') {
    $keysToRotate = @('key1', 'key2')
}
else {
    $keysToRotate = @("$KeyName")
}

Write-Host " "

foreach ($keyToRotate in $keysToRotate){
    Write-Host "Rotating [$($keyToRotate)] on [$($StorageAccountName)]"
    New-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -KeyName $keyToRotate | Out-Null
}

###############################################################################
# Update the AzureWebJobsStorage app setting on Function Apps if the Key used
#   for storage account access (key1) was rotated
###############################################################################
if ($FunctionAppArray.Count -gt 0 -and $keysToRotate -contains 'key1') {
    Write-Host "`nGet the primary Storage Account Key value"
    $key1Value = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName | Where-Object { $_.KeyName -eq 'key1' }).Value
    $webJobStorageConnectionString = "DefaultEndpointsProtocol=https;AccountName=$($StorageAccountName);AccountKey=$($key1Value);EndpointSuffix=core.windows.net"

    $functionAppList = ConvertFrom-Json $FunctionAppArray

    foreach ($functionApp in $functionAppList) {
        Write-Host "`nProcessing Function App: [$($ResourceGroupName)]\[$($functionApp)]"
        Write-Host "`  Loading the Function App details"
        $appService = Get-AzWebApp -Name $functionApp -ResourceGroupName $ResourceGroupName

        Write-Host "`  Add existing AppSettings to Hashtable"
        $appSettingsHash = @{}
        foreach ($appSetting in $appService.SiteConfig.AppSettings) {
            $appSettingsHash[$appSetting.Name] = $appSetting.Value
        }

        Write-Host "`  Setting AzureWebJobsStorage value"
        $appSettingsHash["AzureWebJobsStorage"] = $webJobStorageConnectionString

        Write-Host "`  Updating App Settings"
        Set-AzWebApp -Name $functionApp -ResourceGroupName $ResourceGroupName -AppSettings $appSettingsHash -ErrorAction Stop | Out-Null

        Write-Host "`  The Function App $functionApp AzureWebJobsStorage was updated successfully"
    }
}

Write-Host "`nInvoke-RotateStorageAccountKeys completed successfully!"
