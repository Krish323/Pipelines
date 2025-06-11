using namespace Microsoft.Azure.Commands.Sql.DataSync.Model
using namespace System.Collections.Generic

###############################################################################
# Script: Set-SqlServerFirewallRules.ps1
# Purpose:  Manages Sql Server Firewall Rules
# Parameters:
#		$SqlServerName: Sql Server Name to update
#		$ExcludeStandardIpRules: Set true to not add Standard Deloitte IP Exceptions
###############################################################################
param (
    [Parameter(Mandatory = $true)]
    [string] $SourceResourceGroup,
    [Parameter(Mandatory = $true)]
    [string] $SourceSqlServer,
    [Parameter(Mandatory = $true)]
    [string] $SourceDatabaseName,
    [Parameter(Mandatory = $true)]
    [string] $DestinationSqlServer,
    [Parameter(Mandatory = $true)]
    [string] $DestinationDatabaseName,
    [Parameter(Mandatory = $true)]
    [string] $SyncDatabaseResourceGroup,
    [Parameter(Mandatory = $true)]
    [string] $SyncDatabaseSqlServer,
    [Parameter(Mandatory = $true)]
    [string] $SyncDatabaseName,
    [Parameter(Mandatory = $true)]
    [string] $MigrationSqlUsername,
    [Parameter(Mandatory = $true)]
    [string] $MigrationPassword
)

$ErrorActionPreference = 'Stop'

# Create FQDN's for Sql Servers
$sourceSqlServerFqdn = "$($SourceSqlServer).database.windows.net".ToLower()
$destinationSqlServerFqdn = "$($DestinationSqlServer).database.windows.net".ToLower()

# Create credential for DB connections
$credential = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $MigrationSqlUsername, ($MigrationPassword | ConvertTo-SecureString -AsPlainText -Force)

# Sql Data Sync requires Source & Destination DB's to have snapshot isolation turned on.
$snapshotIsolationQuery = '
ALTER DATABASE {0} SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE {0} SET READ_COMMITTED_SNAPSHOT ON;'

Write-Host "`nEnabling Snapshot Isolation on Source: $($SourceSqlServer)\$($SourceDatabaseName)"
Invoke-Sqlcmd -Query ($snapshotIsolationQuery -f $SourceDatabaseName) -Database $SourceDatabaseName -ServerInstance $sourceSqlServerFqdn -Credential $credential

Write-Host "Enabling Snapshot Isolation on Destination: $($DestinationSqlServer)\$($DestinationDatabaseName)"
Invoke-Sqlcmd -Query ($snapshotIsolationQuery -f $DestinationDatabaseName) -Database $DestinationDatabaseName -ServerInstance $destinationSqlServerFqdn -Credential $credential

# Delete any existing sync groups so we don't have to write new & update logic for each call.
Write-Host "`nGetting existing sync groups from $($SourceSqlServer)\$($SourceDatabaseName)"
$existingSyncGroups = Get-AzSqlSyncGroup -ResourceGroupName $SourceResourceGroup -ServerName $SourceSqlServer -DatabaseName $SourceDatabaseName

foreach ($syncGroup in $existingSyncGroups) {
    Write-Host "Removing existing sync group $($syncGroup.SyncGroupName)"
    $syncGroup | Remove-AzSqlSyncGroup -Force
}

# Build Sync Group info
$syncGroupName = "$($SourceSqlServer)-$($SourceDatabaseName)".ToLower()
$conflictResolutionPolicy = "HubWin" # can be HubWin or MemberWin
$intervalInSeconds = 300 # sync interval in seconds (must be no less than 300)

# # create a new sync group
Write-Host "`nCreating Sync Group "$syncGroupName"..."
New-AzSqlSyncGroup -ResourceGroupName $SourceResourceGroup `
                    -ServerName $SourceSqlServer `
                    -DatabaseName $SourceDatabaseName `
                    -Name $syncGroupName `
                    -SyncDatabaseName $SyncDatabaseName `
                    -SyncDatabaseServerName $SyncDatabaseSqlServer `
                    -SyncDatabaseResourceGroupName $SyncDatabaseResourceGroup `
                    -ConflictResolutionPolicy $conflictResolutionPolicy `
                    -IntervalInSeconds $intervalInSeconds `
                    -DatabaseCredential $credential | Format-list

# Build member database info
$destinationSyncMemberName = "$($DestinationSqlServer)-$($DestinationDatabaseName)".ToLower()
#$DestinationDatabaseName = "Navigator_Case_US"
$destinationDatabaseType = "AzureSqlDatabase" # Valid values: AzureSqlDatabase or SqlServerDatabase
$destinationSyncDirection = "Onewayhubtomember" # Valid values: Bidirectional, Onewaymembertohub, Onewayhubtomember

# # add a new sync member
Write-Host "Adding member"$destinationSyncMemberName" to the sync group..."
New-AzSqlSyncMember -ResourceGroupName $SourceResourceGroup `
                    -ServerName $SourceSqlServer `
                    -DatabaseName $SourceDatabaseName `
                    -SyncGroupName $syncGroupName `
                    -Name $destinationSyncMemberName `
                    -SyncDirection $destinationSyncDirection `
                    -MemberDatabaseType $destinationDatabaseType `
                    -MemberServerName $destinationSqlServerFqdn `
                    -MemberDatabaseName $DestinationDatabaseName `
                    -MemberDatabaseCredential $credential | Format-list

# refresh database schema from hub database
Write-Host "Refreshing database schema from hub database..."
Update-AzSqlSyncSchema -ResourceGroupName $SourceResourceGroup -ServerName $SourceSqlServer -DatabaseName $SourceDatabaseName -SyncGroupName $syncGroupName

# Wait for successful refresh.
# Remove seconds & milliseconds from current time to account for clock differences between local and azure.
$startTime = Get-Date
$startTime = $startTime.Subtract((New-Object -TypeName System.TimeSpan -ArgumentList  0, 0, 0, $startTime.Second, $startTime.Millisecond))
$startTime = $startTime.ToUniversalTime()
$timer=0
$timeout=90
$startTime

# check the log and see if refresh has gone through
$isSucceeded = $false
while ($isSucceeded -eq $false) {
    Start-Sleep -s 10
    $timer = $timer + 10
    Write-Host "Check for successful refresh..."
    $details = Get-AzSqlSyncSchema -SyncGroupName $syncGroupName -ServerName $SourceSqlServer -DatabaseName $SourceDatabaseName -ResourceGroupName $SourceResourceGroup
    $details.LastUpdateTime
    if ($details.LastUpdateTime -gt $startTime) {
        Write-Host "Refresh was successful"
        $isSucceeded = $true
    }
    if ($timer -eq $timeout) {
        Write-Host "Refresh timed out"
        break;
    }
}

# get the database schema
Write-Host "Adding tables and columns to the sync schema..."
$databaseSchema = Get-AzSqlSyncSchema -ResourceGroupName $SourceResourceGroup -ServerName $SourceSqlServer `
    -DatabaseName $SourceDatabaseName -SyncGroupName $SyncGroupName `

# Load list of tables/columns to be included. Names must quoted ie [schema].[table].[column].
Write-Host "Reading column inclusion list from member-firm-column-list.txt"
$metadataList = [System.Collections.ArrayList]::new((Get-Content "$($PSScriptRoot)\member-firm-column-list.txt"))

$newSchema = [AzureSqlSyncGroupSchemaModel]::new()
$newSchema.Tables = [List[AzureSqlSyncGroupSchemaTableModel]]::new();

# add columns and tables to the sync schema
foreach ($tableSchema in $databaseSchema.Tables) {
    $newTableSchema = [AzureSqlSyncGroupSchemaTableModel]::new()
    $newTableSchema.QuotedName = $tableSchema.QuotedName
    $newTableSchema.Columns = [List[AzureSqlSyncGroupSchemaColumnModel]]::new();
    $addAllColumns = $false
    if ($MetadataList.Contains($tableSchema.QuotedName)) {
        if ($tableSchema.HasError) {
            $fullTableName = $tableSchema.QuotedName
            Write-Host "Can't add table $fullTableName to the sync schema" -foregroundcolor "Red"
            Write-Host $tableSchema.ErrorId -foregroundcolor "Red"
            continue;
        }
        else {
            $addAllColumns = $true
        }
    }
    foreach($columnSchema in $tableSchema.Columns) {
        $fullColumnName = $tableSchema.QuotedName + "." + $columnSchema.QuotedName
        if ($addAllColumns -or $MetadataList.Contains($fullColumnName)) {
            if ((-not $addAllColumns) -and $tableSchema.HasError) {
                Write-Host "Can't add column $fullColumnName to the sync schema because of Table schema error" -foregroundcolor "Red"
                Write-Host $tableSchema.ErrorId -foregroundcolor "Red"
            }
            elseif ((-not $addAllColumns) -and $columnSchema.HasError) {
                Write-Host "Can't add column $fullColumnName to the sync schema because of Column Schema Error" -foregroundcolor "Red"
                Write-Host $columnSchema.ErrorId -foregroundcolor "Red"
            }
            else {
                Write-Host "Adding"$fullColumnName" to the sync schema"
                $newColumnSchema = [AzureSqlSyncGroupSchemaColumnModel]::new()
                $newColumnSchema.QuotedName = $columnSchema.QuotedName
                $newColumnSchema.DataSize = $columnSchema.DataSize
                $newColumnSchema.DataType = $columnSchema.DataType
                $newTableSchema.Columns.Add($newColumnSchema)
            }
        }
    }
    if ($newTableSchema.Columns.Count -gt 0) {
        $newSchema.Tables.Add($newTableSchema)
    }
}

# convert sync schema to JSON format
$schemaString = $newSchema | ConvertTo-Json -depth 5 -Compress

# work around a PowerShell bug
$schemaString = $schemaString.Replace('"Tables"', '"tables"').Replace('"Columns"', '"columns"').Replace('"QuotedName"', '"quotedName"').Replace('"MasterSyncMemberName"','"masterSyncMemberName"')

# save the sync schema to a temp file
$tempFile = $env:TEMP + "\syncSchema.json"

if (Test-Path $tempFile) {
    Remove-Item $tempFile -Force
}

$schemaString | Out-File $tempFile

# update sync schema
Write-Host "Updating the sync schema..."
Update-AzSqlSyncGroup -ResourceGroupName $SourceResourceGroup -ServerName $SourceSqlServer `
    -DatabaseName $SourceDatabaseName -Name $syncGroupName -Schema $tempFile

if (Test-Path $tempFile) {
    Remove-Item $tempFile -Force
}

$syncLogStartTime = Get-Date

# trigger sync manually
Write-Host "Trigger sync manually..."
Start-AzSqlSyncGroupSync -ResourceGroupName $SourceResourceGroup -ServerName $SourceSqlServer -DatabaseName $SourceDatabaseName -SyncGroupName $syncGroupName

# check the sync log and wait until the first sync succeeded
# Write-Host "Check the sync log..."
# $isSucceeded = $false
# for ($i = 0; ($i -lt 300) -and (-not $isSucceeded); $i = $i + 10) {
#     Start-Sleep -s 10
#     $syncLogEndTime = Get-Date
#     $syncLogList = Get-AzSqlSyncGroupLog -ResourceGroupName $SourceResourceGroup -ServerName $SourceSqlServer -DatabaseName $SourceDatabaseName `
#         -SyncGroupName $syncGroupName -StartTime $syncLogStartTime.ToUniversalTime() -EndTime $syncLogEndTime.ToUniversalTime()

#     if ($synclogList.Length -gt 0) {
#         foreach ($syncLog in $syncLogList) {
#             $syncLog
#             if ($syncLog.Details.Contains("Sync completed successfully")) {
#                 Write-Host $syncLog.TimeStamp : $syncLog.Details
#                 $isSucceeded = $true
#             }
#         }
#     }
# }

# if ($isSucceeded) {
#     # enable scheduled sync
#     Write-Host "Enable the scheduled sync with 300 seconds interval..."
#     Update-AzSqlSyncGroup  -ResourceGroupName $SourceResourceGroup -ServerName $SourceSqlServer -DatabaseName $SourceDatabaseName `
#         -Name $syncGroupName -IntervalInSeconds $intervalInSeconds
# }
# else {
#     # output all log if sync doesn't succeed in 300 seconds
#     $syncLogEndTime = Get-Date
#     $syncLogList = Get-AzSqlSyncGroupLog  -ResourceGroupName $SourceResourceGroup -ServerName $SourceSqlServer -DatabaseName $SourceDatabaseName `
#         -SyncGroupName $syncGroupName -StartTime $syncLogStartTime.ToUniversalTime() -EndTime $syncLogEndTime.ToUniversalTime()

#     if ($synclogList.Length -gt 0) {
#         foreach ($syncLog in $syncLogList) {
#             Write-Host $syncLog.TimeStamp : $syncLog.Details
#         }
#     }
# }