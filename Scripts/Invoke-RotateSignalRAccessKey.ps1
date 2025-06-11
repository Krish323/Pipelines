###############################################################################
# Script: Invoke-RotateSignalRAccessKey.ps1
# Purpose:  Rotate SignalR keys
# Parameters:
#	  $ResourceGroupName : Resource Group containing the SignalR to rotate keys.
#	  $StorageAccountName : SignalR name required for the connection string.
#	  $KeyName : SignalR key name.
###############################################################################
param(
  [Parameter(Mandatory = $true)]
  [string] $ResourceGroupName,
  [Parameter(Mandatory = $true)]
  [string] $SignalRName,
  [ValidateSet('Primary', 'Secondary', 'both')]
  [string] $KeyName = 'both'
)

Write-Host "`nEnter Invoke-RotateStorageAccountKeys`n`nParameters:"
Write-Host "ResourceGroupName: $($ResourceGroupName)"
Write-Host "SignalRName: $($SignalRName)"
Write-Host "KeyName: $($KeyName)"

Write-Host "Enter Invoke-RotateSignalRAccessKey`n"
# Build a list of the Key(s) to rotate
if ($KeyName -eq 'both') {
  $keysToRotate = @('Primary', 'Secondary')
}
else {
  $keysToRotate = @("$KeyName")
}

Write-Host " "

foreach ($keyToRotate in $keysToRotate) {
  Write-Host "Rotating [$($keyToRotate)] on [$($SignalRName)]"
  New-AzSignalRKey -ResourceGroupName $ResourceGroupName -Name $SignalRName -KeyType $keyToRotate -PassThru
}

Write-Host "`nInvoke-RotateSignalRAccessKey completed successfully!"
