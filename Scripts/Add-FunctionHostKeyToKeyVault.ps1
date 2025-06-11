###############################################################################
# Script: Add-FunctionHostKeyToKeyVault.ps1
# Purpose:  Rotates the Default Host Key for an Azure Function
# Parameters:
#       $FunctionAppNames : API Management Service containing the Subscriptions to rotate
#       $KeyName : Optional. Name of Key to Rotate
#		$KeyVaultName : Public Key Vault name that stores Subscription Keys for Apps
#       $ResourceGroupName: Function App resource group
#       $FunctionAppList: Secret Name to store Default Host Key in 
#       $RotateKey : Set to generate a new value for the Function Key
# Outputs:
# Returns:
###############################################################################
param(
    [Parameter(Mandatory = $true)]
    [string] $FunctionAppNames, 
    [string] $KeyName = 'default',
    [Parameter(Mandatory = $true)]
    [string] $KeyVaultName,
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,    
    [Parameter(Mandatory = $true)]
    [string] $FunctionAppList,
    [switch] $RotateKey
)

Write-Host "`nEnter Add-FunctionHostKeyToKeyVault`n`nParameters:"
Write-Host "FunctionAppNames: $($FunctionAppNames)"
Write-Host "KeyName: $($KeyName)"
Write-Host "KeyVaultName: $($KeyVaultName)"
Write-Host "FunctionAppList: $($FunctionAppList)"
Write-Host "RotateKey: $($RotateKey)"

$functionAppNamesArray = ConvertFrom-Json $FunctionAppNames
$FunctionAppListArray = $FunctionAppList.Split(',')

try {
    foreach ($functionAppName in $functionAppNamesArray) {
        Write-Host "Getting publishing credentials of: $($functionAppName)"
        # Get publishing credentials and create authorization header
        $publishCredentials = Invoke-AzResourceAction -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.Web/sites/config" -ResourceName "$functionAppName/publishingcredentials" -Action list -ApiVersion 2021-02-01 -Force
        $authorization = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $publishCredentials.Properties.PublishingUserName, $publishCredentials.Properties.PublishingPassword)))
    
        # Get access token for Kudu API
        Write-Host "Getting access token for Kudu API of: $($functionAppName)"
        $accessToken = Invoke-RestMethod -Uri "https://$functionAppName.scm.azurewebsites.net/api/functions/admin/token" -Headers @{Authorization = ("Basic {0}" -f $authorization) } -Method GET
    
        if ($RotateKey) {
            Write-Host "Rotating function app host key of: $($functionAppName)"
            # Rotate the give function app host key
            Invoke-RestMethod -Method POST -Headers @{Authorization = ("Bearer {0}" -f $accessToken) } -ContentType "application/json" -Uri "https://$functionAppName.azurewebsites.net/admin/host/keys/$KeyName"
        }
    
        Write-Host "Getting function app host key of: $($functionAppName)"
        $hostKeyValue = $(Invoke-RestMethod -Method GET -Headers @{Authorization = ("Bearer {0}" -f $accessToken) } -ContentType "application/json" -Uri "https://$functionAppName.azurewebsites.net/admin/host/keys/$KeyName").value
    
        $index = $functionAppNamesArray.IndexOf($functionAppName)
        $secretName = $($FunctionAppListArray[$index] + "FnCode")
    
        Write-Host "Update Key Vault: $($KeyVaultName) - Secret: $($secretName)"
        & "$($PSScriptRoot)\Add-SecretToKeyVault.ps1" -KeyVaultName "$KeyVaultName" -SecretName "$secretName" -SecretValue "$hostKeyValue"
    }
}
catch {
    Write-Error $_ 
}


Write-Host "`nExit Add-FunctionHostKeyToKeyVault"
