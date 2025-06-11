[CmdletBinding()]
param (
    [string] $Environment,
    [string] $Geo,
    [string] $LocationCode,
    [string] $AppName = 'navigator',
    [string[]] $DbList = @('Navigator_Master')
)

Write-Host "`nParameters:"
Write-Host "AppName: $($AppName)"
Write-Host "Environemnt: $($Environment)"
Write-Host "Geo: $($Geo)"
Write-Host "LocationCode: $($LocationCode)"
Write-Host "DB List:"
$DbList

$sourceServerName = "{0}{1}sqlsvr{2}" -f $Environment.Substring(0, 1), $AppName, $Geo
$destinationServerName = "{0}{1}sql{2}" -f $Environment.Substring(0, 1), $AppName, $LocationCode
$sourceResourceGroupName = "APP-{1}-{0}-{2}-RG" -f $Geo, $AppName, $Environment
$destinationResourceGroupName = "AZRG-{0}-AUD-{1}-{2}" -f $LocationCode, $AppName, $Environment

$sourceResourceGroupName = $sourceResourceGroupName.ToUpper()
$destinationResourceGroupName = $destinationResourceGroupName.ToUpper()

Write-Host "`nSource Resource Group: $($sourceResourceGroupName)"
Write-Host "Source Sql Server: $($sourceServerName)"
Write-Host "`nDestination Resource Group: $($destinationResourceGroupName)"
Write-Host "Destination Sql Server: $($destinationServerName)"

foreach ($dbName in $dbList) {
    Write-Host "`n`nCheck if $($dbName) exists on $($destinationResourceGroupName)\$($destinationServerName)"
    $newDb = Get-AzSqlDatabase -DatabaseName $dbName -ServerName $destinationServerName -ResourceGroupName $destinationResourceGroupName -ErrorAction SilentlyContinue
    if ($newDb) {
        Write-Host "Deleting $($dbName) DB from $($destinationResourceGroupName)\$($destinationServerName)"
        Remove-AzSqlDatabase -DatabaseName $dbName -ServerName $destinationServerName -ResourceGroupName $destinationResourceGroupName -Force
    }
    else {
        Write-Host "$($dbName) DB not found on $($destinationResourceGroupName)\$($destinationServerName)"
    }

    Write-Host "Copying $($dbName) from $($sourceResourceGroupName)\$($sourceServerName) to $($destinationResourceGroupName)\$($destinationServerName)"
    New-AzSqlDatabaseCopy -DatabaseName $dbName -ServerName $sourceServerName  -ResourceGroupName $sourceResourceGroupName -CopyResourceGroupName $destinationResourceGroupName -CopyServerName $destinationServerName -CopyDatabaseName $dbName -ElasticPoolName "$destinationServerName-pool"
}
