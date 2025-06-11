###############################################################################
# Script: Invoke-SqlDatabaseFailover.ps1
# Purpose:  Convert the secondary databases into primary
# Parameters:
#		$FailoverToResourceGroupName: Resource Group containing Sql Server to failover to
#		$FailoverToServerName: Sql Server Name to failover to
#		$FailoverFromResourceGroupName: Resource Group containing Sql Server that is currently the Primary
#		$FailoverFromServerName: Sql Server Name to failover From
#       $DatabaseNames: Array of Database Names on the Sql Server to failover
###############################################################################
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FailoverToResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$FailoverToServerName,
    [Parameter(Mandatory = $true)]
    [string]$FailoverFromResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$FailoverFromServerName,
    [Parameter(Mandatory = $true)]
    [string]$DatabaseName
)


Write-Host "`nEnter Invoke-SqlDatabaseFailover"


Write-Host "`nParameters:"
Write-Host "FailoverToResourceGroupName: $FailoverToResourceGroupName"
Write-Host "FailoverToServerName: $FailoverToServerName"
Write-Host "FailoverFromResourceGroupName: $FailoverFromResourceGroupName"
Write-Host "FailoverFromServerName: $FailoverFromServerName"
Write-Host "DatabaseName: $DatabaseName"

$sqlServer = Get-AzSqlServer -ResourceGroupName $FailoverToResourceGroupName -ServerName $FailoverToServerName

if ($null -eq $sqlServer) {
    Throw "Failover To Sql Server not found!!! Sql Server [$FailoverToServerName], Resource Group [$FailoverToResourceGroupName]"
}

$resourceGroup = Get-AzResourceGroup -Name $FailoverFromResourceGroupName

if ($null -eq $resourceGroup) {
    Throw "Failover From Resource Group not found!!! Resource Group [$FailoverFromResourceGroupName]"
}

Write-Host "Get Replication Link for Sql Database [$($FailoverToServerName)\$($DatabaseName)]"
$replicationLink = Get-AzSqlDatabaseReplicationLink -ServerName $FailoverToServerName -DatabaseName $DatabaseName -ResourceGroupName $FailoverToResourceGroupName -PartnerResourceGroupName $FailoverFromResourceGroupName -PartnerServerName $FailoverFromServerName -WarningAction silentlyContinue
    
if ($null -eq $replicationLink) {
    Throw "Replication is not configured on Sql Database [$($FailoverToServerName)\$($DatabaseName)] from [$($FailoverFromResourceGroupName)]"
}
elseif ($replicationLink.Role -ne 'Primary') {
    Write-Host "Sql Database [$($FailoverToServerName)\$($DatabaseName)] is not the Primary. Promoting database to Primary."
    Set-AzSqlDatabaseSecondary -ResourceGroupName $FailoverToResourceGroupName -ServerName $FailoverToServerName -DatabaseName $DatabaseName -PartnerResourceGroupName $FailoverFromResourceGroupName -Failover -Verbose -WarningAction silentlyContinue
    Write-Host "Sql Database [$($FailoverToServerName)\$($DatabaseName)] failover complete.`n`n"
}
else {
    Write-Host "Sql Database [$($FailoverToServerName)\$($DatabaseName)] is already configured as the Primary.`n`n"
}

Write-Host "Exit Invoke-SqlDatabaseFailover"
