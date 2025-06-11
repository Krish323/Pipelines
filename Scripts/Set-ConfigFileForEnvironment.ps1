###############################################################################
# Script: Set-ConfigFileForEnvironment.ps1
# Purpose:  Searches $ArtifactFolder recursively for $EnvironmentConfigPattern and $TargetConfigPattern.
#           If 1 file is found for each pattern, the Target is replaced with the EnvironmentConfig File.
# Parameters:
#       $ArtifactFolder : Root folder to search for $TargetConfigPattern
#		$EnvironmentConfigPattern : Config file for the current environment to replace
#           target config file with
#		$TargetConfigPattern : Pattern to search for in $ArtifactFolder. All files
#           that match this pattern will be replaced with $EnvironmentConfigPattern
###############################################################################
[CmdletBinding()]
Param
(
    [Parameter(Mandatory = $true)]
    [String]$ArtifactFolder,
    [Parameter(Mandatory = $true)]
    [String]$EnvironmentConfigPattern,
    [Parameter(Mandatory = $true)]
    [String]$TargetConfigPattern
)

Write-Host "Searching $($ArtifactFolder) for Environment Config: $($EnvironmentConfigPattern)`n"
$environmentConfig = Get-ChildItem -Path $ArtifactFolder -Filter $EnvironmentConfigPattern -Recurse

Write-Host "Found the following Environment Config file(s):"
$environmentConfig | ForEach-Object { Write-Host $_.FullName }

if ($environmentConfig.Count -ne 1) {
    throw "Invalid application configuration. A single environment config file matching the environment pattern was not found."
}

Write-Host "`n`nSearching $($ArtifactFolder) for Target Config: $($TargetConfigPattern)`n"
$targetConfig = Get-ChildItem -Path $ArtifactFolder -Filter $TargetConfigPattern -Recurse

Write-Host "Found the following Target Config files(s):"
$targetConfig | ForEach-Object { Write-Host $_.FullName }

if ($targetConfig.Count -ne 1) {
    throw "Invalid application configuration. A single target config file matching the target pattern was not found."
}

Write-Host "`n`nBackup original file"
Copy-Item -Path $targetConfig.FullName -Destination "$($targetConfig.FullName).bak" -Force

Write-Host "Replacing $($targetConfig.FullName) with $($environmentConfig.FullName)"
Copy-Item -Path $environmentConfig.FullName -Destination $targetConfig.FullName -Force

Write-Host "`nRemoving unneeded config files: $($environmentConfig.DirectoryName)"
Get-ChildItem -Path $environmentConfig.DirectoryName -Exclude 'config.js' | Remove-Item -Recurse -Force -Confirm:$false
