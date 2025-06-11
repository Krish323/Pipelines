###############################################################################
# Script: Get-BuildTools.ps1
# Purpose:  Clone Audit DevOps Share Tools Repository 
# Parameters:
#		$BuildToolsBranch : Name of the branch variable build
###############################################################################

param(
    [Parameter(Mandatory=$true)]
    [string] $BuildToolsBranch
)

Write-Host "`n`nDownloading Audit DevOps Share Tools Repository`n"

$BuildToolsFolder = "$($env:AGENT_BUILDDIRECTORY)\BuildTools";
Write-Output ("##vso[task.setvariable variable=BuildToolsFolder;]$BuildToolsFolder");

#Removing Builds Tools Folder Items
if (Test-Path $BuildToolsFolder) {
    Remove-Item -Path $BuildToolsFolder -Force -Recurse;
}

#Cloning The Repository
$cred = "serviceacct:$($env:SYSTEM_ACCESSTOKEN)";
$gitUri = "https://$cred@dev.azure.com/symphonyvsts/Audit%20DevOps/_git/audit-devops-shared-tools";
git clone $gitUri -b $BuildToolsBranch $BuildToolsFolder;

Write-Host "`n`nExit Get-BuildTools.ps1`n"