###############################################################################
# Script: Invoke-SqlGroupFailover.ps1
# Purpose:  Failover SQL group.
# Parameters:
#		$SqlServer : Target sql server to become primary.
#		$ResourceGroupName : Resource group name of sql server.
#       $FailoverGroupName : SQL Failover group name.
###############################################################################
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SqlServer,
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$FailoverGroupName
)

Write-Host "`nEnter Invoke-SqlGroupFailover`n`nParameters:"
Write-Host "SqlServer: $($SqlServer)"
Write-Host "ResourceGroupName: $($ResourceGroupName)"
Write-Host "FailoverGroup: $($FailoverGroupName)"

Write-host "Getting Failover Group $FailoverGroupName"
$failoverGroup = Get-AzSqlDatabaseFailoverGroup -ResourceGroupName $ResourceGroupName -ServerName $SqlServer -FailoverGroupName $FailoverGroupName -ErrorAction SilentlyContinue

if ($failoverGroup.ReplicationRole -ne 'Primary') {
    Write-host "Failing over to $SqlServer..."
    Switch-AzSqlDatabaseFailoverGroup -ResourceGroupName $ResourceGroupName -ServerName $SqlServer -FailoverGroupName $FailoverGroupName
    Write-host "Failed failover group successfully to" $SqlServer
}
else {
    Write-Host "$SqlServer is already the primary server. No failover required."
}

Write-Host "`n`nExit Invoke-SqlGroupFailover.ps1"