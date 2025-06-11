###############################################################################
# Script: Set-StorageAccountConnectionStringInKeyVault.ps1
# Purpose:  Store the storage account connection string as a secret into the 
#           specified keyvault
# Parameters:
#		$ResourceGroupName : Resource Group containing storage account.
#		$StorageAccountName : Storage account name required for the connection string.
#		$KeyName : Storage account access key name.
#		$KeyVaultName : Key vault to store the secrets.
#		$SecretName : Connection string secret name.
###############################################################################

param(
    [Paramter(Mandatory=$true)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory=$true)]
    [string] $StorageAccountName,
    [ValidateSet('key1', 'key2', 'both')]
    [string] $KeyName = 'key1',
    [Parameter(Mandatory=$true)]
    [string] $KeyVaultName,
    [Parameter(Mandatory=$true)]
    [string] $SecretName,
	[switch]$RotateKey
)

Write-Host "Enter Set-StorageAccountAccessKeyInKeyVault`n"

Write-Host "Get [$($StorageAccountName)] Resource Group"
Write-Host "ResourceGroupName: $($ResourceGroupName)"
Write-Host "StorageAccountName: $($StorageAccountName)"

Write-Host "Get [$($StorageAccountName)] Storage Account"
$storageAccount = Get-AzStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName

if ($null -eq $azureResource) {
    throw "Storage Acount [$($storageAccount)] does not exist!"
}

$accessKey = $null

if ($RotateKey) {
    Write-Host "Rotating [$($KeyName)] on [$($StorageAccountName)]"
    $keyList = New-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $StorageAccountName -KeyName $KeyName

    Write-Host "Getting rotated key value"
    $accessKey = ($keyList.Keys | Where-Object { $_.KeyName -eq $KeyName }).Value
}
else {
    Write-Host "Get [$($KeyName)] for $($StorageAccountName)"
    $accessKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $StorageAccountName | Where-Object { $_.KeyName -eq $KeyName }).Value
}

if ($null -eq $accessKey) {
    throw "Key [$($KeyName)] on [$($StorageAccountName)] not found!"
}

$connectionString = "DefaultEndpointsProtocol=https;AccountName=$($StorageAccountName);AccountKey=$($accessKey);EndpointSuffix=core.windows.net"

Write-Host "Updating [$($SecretName)] in [$KeyVaultName] for key"
& "$($PSScriptRoot)\Add-SecretToKeyVault.ps1" -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $connectionString

Write-Host "`nSet-StorageAccountAccessKeyInKeyVault completed successfully!"
