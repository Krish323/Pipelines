###############################################################################
# Script: Set-PasswordInKeyVault.ps1
# Purpose:  Updates a secret in a KeyVault with either the supplied value or a
#           generated random value.
# Parameters:
#		$KeyVaultName : Name of KeyVault to update
#		$SecretName : Name of Secret to update
#		$CustomPassword : Use to set a specific password. Ignored if the Randomize switch is supplied.
#		$Randomize : Set switch to generate a random password. Overrides the CustomPassword value.
#		$Reset : Set switch to update the password even if it exists
#       #PasswordLength : Number of characters in randomly generated password
###############################################################################
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $KeyVaultName,
    [Parameter(Mandatory=$true)]
    [string] $SecretName,
    [string] $CustomPassword,
    [switch] $Randomize,
    [switch] $Reset,
    [int] $PasswordLength = 32
)

. "$($PSScriptRoot)\Convert-SecureStringToString.ps1"
. "$($PSScriptRoot)\Get-RandomPassword.ps1"

Write-Output "`nEnter Set-PasswordInKeyVault.ps1`n"

$useCustomPassword = $false

if (!$Randomize) {
    if ([System.String]::IsNullOrWhiteSpace($CustomPassword)) {
        throw "No value was supplied for the CustomPassword parameter and the Randomize switch is not set."
    }
    else {
        $useCustomPassword = $true
    }
}

Write-Output "Searching KeyVault $($KeyVaultName) for $($SecretName)`n"
$existingSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -ErrorAction Ignore

$newPassword = $null

# Update the password if it doesn't exist or the Reset switch is set
if (($null -eq $existingSecret) -or $Reset) {
    if ($null -eq $existingSecret) {
        Write-Output "Secret $($SecretName) does not exist. Adding secret.`n"
    }
    else {
        Write-Output "Secret $($SecretName) found and will be reset.`n"
    }

    if ($Randomize) {
        Write-Output "Generating a random password.`n"
        $newPassword = Get-RandomPassword

    }
    else {
        Write-Output "Using the supplied CustomPassword value.`n"
        $newPassword = $CustomPassword
    }
}
else {
    $existingValue = Convert-SecureStringToString $existingSecret.SecretValue

    if ($useCustomPassword -and `
        $existingValue -ne $CustomPassword) {
        Write-Output "Secret $($SecretName) exists but does not match CustomPassword. Updating secret.`n"
        $newPassword = $CustomPassword
    }
    else {
        Write-Output "Secret $($SecretName) exists and will not be updated.`n"
    }
}

if ($null -ne $newPassword) {
    & "$($PSScriptRoot)\Add-SecretToKeyVault.ps1" -KeyVaultName "$KeyVaultName" -SecretName "$SecretName" -SecretValue "$newPassword"
}
Write-Output "Exit Set-PasswordInKeyVault.ps1`n"
