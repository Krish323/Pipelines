###############################################################################
# Script: Set-SqlServerFirewallRules.ps1
# Purpose:  Manages Sql Server Firewall Rules
# Parameters:
#		$SqlServerName: Sql Server Name to update
#		$ExcludeStandardIpRules: Set true to not add Standard Deloitte IP Exceptions
###############################################################################
param (
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $SqlServerName
)

Write-Host "Enter Set-SqlServerFirewallRules.ps1`n`nParameters:"
Write-Host "ResourceGroupName: $ResourceGroupName"
Write-Host "SqlServerName: $SqlServerName"

try {
    Write-Host "`nChecking if [$($SqlServerName )] exists"
    $azureResource = Get-AzSqlServer -Name $SqlServerName -ResourceGroupName $ResourceGroupName
}
catch {
    Write-Warning "`nAzure Resource [$($SqlServerName)] does not exist!`nSkipping Clear Firewall rules."
    Exit 0
}

Write-Host "`nChecking for existing Firewall Rules on [$($SqlServerName)]"
$existingFirewallRules = Get-AzSqlServerFirewallRule -ResourceGroupName $resourceGroupName -ServerName $SqlServerName

if ($existingFirewallRules.Length -gt 0) {
    Write-Host "Found existing rules that will be deleted:"
    $existingFirewallRules | format-table -AutoSize

    Write-Host "`nRemoving existing Firewall Rules"
    foreach ($rule in $existingFirewallRules) {
        Write-Host "Removing [$($rule.FirewallRuleName)]"
        Remove-AzSqlServerFirewallRule  -ResourceGroupName $resourceGroupName -ServerName $SqlServerName -FirewallRuleName $rule.FirewallRuleName | Out-Null
    }

    Write-Host "`nGetting Firewall Rules after clearing"
    $existingFirewallRules = Get-AzSqlServerFirewallRule -ResourceGroupName $resourceGroupName -ServerName $SqlServerName

    if ($existingFirewallRules.Length -gt 0) {
        Write-Host "`n[$($SqlServerName)] Firewall Rules after update:"
        $existingFirewallRules | format-table -AutoSize
        throw "Failed to clear existing Firewall Rules"
    }
}
else {
    Write-Host "No existing Firewall Rules found on [$($SqlServerName)] to clear"
}

Write-Host "`n`Checking for existing Virtual Network Rules on [$($SqlServerName)]"
$existingVirtualNetworkRules = Get-AzSqlServerVirtualNetworkRule -ResourceGroupName $resourceGroupName -ServerName $SqlServerName

if ($existingVirtualNetworkRules.Length -gt 0) {
    Write-Host "Found existing rules that will be deleted:"
    $existingVirtualNetworkRules | format-table -AutoSize

    Write-Host "`nRemoving existing Virtual Network Rules"
    foreach ($rule in $existingVirtualNetworkRules) {
        Write-Host "Removing [$($rule.VirtualNetworkRuleName)]"
        Remove-AzSqlServerVirtualNetworkRule -ResourceGroupName $resourceGroupName -ServerName $SqlServerName -VirtualNetworkRuleName $rule.VirtualNetworkRuleName | Out-Null
    }

    Write-Host "`nGetting Virtual Network Rules after clearing"
    $existingVirtualNetworkRules = Get-AzSqlServerVirtualNetworkRule -ResourceGroupName $resourceGroupName -ServerName $SqlServerName

    if ($existingFirewallRules.Length -gt 0) {
        Write-Host "`n[$($SqlServerName)] Virtual Network Rules after update:"
        $existingVirtualNetworkRules | format-table -AutoSize
        throw "Failed to clear existing Virtual Network Rules"
    }
}
else {
    Write-Host "No existing Virtual Network Rules found on [$($SqlServerName)] to clear"
}

Write-Host "`n`nExit Set-SqlServerFirewallRules.ps1"