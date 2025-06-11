###############################################################################
# Script: Invoke-ScaleDownElasticPool.ps1
# Purpose:  Scale down Elastic Pools in a given Resource Group.
# Parameters:
#		$ResourceGroupName : Resource group name of the Elastic Pool.
###############################################################################
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ResourceGroupName
)

Write-Host "`nEnter Invoke-ScaleDownElasticPool`n`nParameters:"
Write-Host "ResourceGroupName: $($ResourceGroupName)"

Write-Host "`nGet all sql server instances in the resource group."
$sqlServers = Get-AzSqlServer -ResourceGroupName $ResourceGroupName

foreach ($sqlServer in $sqlServers) {
  Write-Host "`nGet the elastic pool names associated with " $sqlServer.ServerName
  $elasticPools = Get-AzSqlElasticPool -ResourceGroupName $ResourceGroupName -ServerName $sqlServer.ServerName

  foreach ($elasticPool in $elasticPools) {
    Write-Host "`nScaling down $($elasticPool.ElasticPoolName) to [2] VCore"
    Set-AzSqlElasticPool -ResourceGroupName $ResourceGroupName -ServerName $sqlServer.ServerName -ElasticPoolName $elasticPool.ElasticPoolName -VCore 2 -DatabaseVCoreMax 2
  }
}

Write-Host "`n`nExit Invoke-ScaleDownElasticPool.ps1`n"