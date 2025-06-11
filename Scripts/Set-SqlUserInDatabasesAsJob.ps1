###############################################################################
# Script: Set-SqlUserInDatabasesAsJob.ps1
# Purpose:  Creates the passed in user name in a list of DB's
#           retrieving the password for the user from the specified KeyVault
# Parameters:
#       $AppDatabaseNames : CSV or JSON string containing the database names to create the user in.
#       $AppDatabaseNameFormat : Format of AppDatabaseNames - either csv or json
#       $SqlServerName : App Sql Server Name to Update
#       $AdminDbUserName : Sql Server Admin Username that has permissions to add the user
#       $AdminDbPassword : Sql Server Admin password
#       $AppKeyVaultName : Key Vault the Application User password is stored in
#       $PasswordSecretName : Secret Name the Application User password is stored in
#       $SqlUserName : Username to create
#       $SqlUserPassword : Optional. Password to use for the Sql User.
#       $DatabaseRoles : CSV list of Database Roles to grant to the user
#       $RandomPassword : If set, a random password is generated and used. This overrides -SqlUserPassword.
#       $ResetPassword : If set, the password be changed if it already exists. Otherwise,
#           existing passwords will not be updated.
#       $GrantExecute : If set, user will be able to execute Stored Procedures in the databases.
#       $MaxConcurrentJobs : Limits the number of DB's that will be updated at the same time. Set to 0 for no limit.
###############################################################################
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AppDatabaseNames,
    [Parameter(Mandatory = $true)]
    [ValidateSet('csv', 'json')]
    [string]$AppDatabaseNameFormat,
    [Parameter(Mandatory = $true)]
    [string]$SqlServerName,
    [Parameter(Mandatory = $true)]
    [string]$AdminDbUserName,
    [Parameter(Mandatory = $true)]
    [string]$AdminDbPassword,
    [Parameter(Mandatory = $true)]
    [string]$AppKeyVaultName,
    [string]$PasswordSecretName,
    [Parameter(Mandatory = $true)]
    [string]$SqlUserName,
    [string]$SqlUserPassword,
    [Parameter(Mandatory = $true)]
    [string]$DatabaseRoles,
    [switch]$RandomPassword,
    [switch]$ResetPassword,
    [switch]$GrantExecute,
    [int]$MaxConcurrentJobs = 15
)

# Verify we are in Powershell Net Core.
# Set-AzKeyVaultSecret (used in Set-PasswordInKeyVault.ps1) fails with the error below if this is executed
# in Powershell 5 or below.
#   Error: The server did not respond with an encrypted session key within the specified time-out period.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "Set-SqlUserInDatabasesAsJob.ps1 must be executed in Powershell Core"
}

Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

# Set Error Action to Continue (2) so logs can be printed in the finally block from all Jobs.
$currentErrorAction = $global:erroractionpreference
$global:erroractionpreference = 2

Write-Host "`n`nEnter Set-SqlUserInDatabasesAsJob.ps1"
Write-Host "SqlServerName: $($SqlServerName)"
if ($ResetPassword) {
    Write-Warning "Passwords will be reset!!!`n`n"
}
else {
    Write-Host "Passwords will synced in the DB`n`n"
}

# Convert the list of DB Names to an array
if ($AppDatabaseNameFormat -eq "csv") {
    Write-Host "Creating appDatabaseNamesArray from CSV"
    $appDatabaseNamesArray = $AppDatabaseNames.Split(',')
}
else {
    Write-Host "Creating appDatabaseNamesArray from JSON"
    $appDatabaseNamesArray = ConvertFrom-Json $AppDatabaseNames
}

Write-Host "Create array of Database Roles to add user to"
if ([System.string]::IsNullOrWhiteSpace($DatabaseRoles)) {
    $databaseRolesArray = @()
}
else {
    $databaseRolesArray = $DatabaseRoles.Split(',')
}

# Create path to scripts to pass to Job
$scriptFolder = $PSScriptRoot
$scriptError = $false

try {
    Write-Host "`nCreating jobs for each DB..."
    foreach ($databaseName in $appDatabaseNamesArray) {
        # Check if we need to limit the number of jobs that can run at the same time.
        if ($MaxConcurrentJobs -gt 0) {
            # Get all the jobs the jobs currently executing in this powershell session as an array.
            $running = @(Get-Job | Where-Object { $_.State -eq 'Running' })

            # Check if we are at the Max number
            if ($running.Count -ge $MaxConcurrentJobs) {
                # We are over the limit. Pause execution until 1 of the jobs finishes.
                $running | Wait-Job -Any | Out-Null
            }
        }

        # Start the next job
        Write-Host "Starting job for $databaseName"
        Start-Job -Name $databaseName -ScriptBlock {
            Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

            # ErrorActionPreference must be Stop so the job status is set to failed which allows
            # us to figure out if the pipeline should be failed.
            $ErrorActionPreference = "Stop"

            . "$($using:scriptFolder)\Convert-SecureStringToString.ps1"

            if ([string]::IsNullOrWhiteSpace($using:PasswordSecretName)) {
                $secretName = "$(($using:databaseName).replace('_', ''))Password"
            }
            else {
                $secretName = $using:PasswordSecretName
            }

            Write-Output "Creating User Password Secret if it doesn't exist. Secret Name: $($secretName)`n"
            & "$($using:scriptFolder)\Set-PasswordInKeyVault.ps1" -KeyVaultName $using:AppKeyVaultName -SecretName $secretName -CustomPassword $using:SqlUserPassword -Randomize:$using:RandomPassword -Reset:$using:ResetPassword

            Write-Output "`nGet User Password from [$($using:AppKeyVaultName)]`n"
            $result = Get-AzKeyVaultSecret -VaultName $using:AppKeyVaultName -Name $secretName
            $dbUserPassword = Convert-SecureStringToString $result.SecretValue

            Write-Output "`nBuild the Create User query`n"
            $query = & "$($using:scriptFolder)\Get-AddAzureSqlUserQuery.ps1" -Username "$($using:SqlUserName)" -Password "$($dbUserPassword)" -DatabaseRoles $using:databaseRolesArray -AddGrantExecute:$using:GrantExecute

            Write-Output "`nCreate User [$($using:SqlUserName)] in Database: [$($using:databaseName)]`n"
            & "$($using:scriptFolder)\Invoke-ExecuteSqlCommand.ps1" -SqlServerName $using:SqlServerName -DatabaseName $using:databaseName -DbUsername $using:AdminDbUserName -DbPassword $using:AdminDbPassword -Query $query

            Write-Output "`nUser update in database [$($using:databaseName)] successfully!`n"
        } | Out-Null
    }
}
finally {
    # Wait for all jobs to finish and results ready to be received
    Get-Job | Wait-Job | Out-Null

    Write-Host "`n`n*******************************************************************************"
    Write-Output "Job Results:"
    Write-Host "*******************************************************************************"

    # Process the results
    foreach ($job in Get-Job) {
        Write-Host "`n`n*******************************************************************************"
        Write-Host "Database: $($job.Name)"
        Write-Host "*******************************************************************************`n"

        # Get the job output
        $result = Receive-Job $job
        Write-Host $result

        # Check for failures
        if ($job.State -eq 'Failed') {
            $scriptError = $true
            Write-Host "`n##[error] Error Details:`n"
            $job.ChildJobs | ForEach-Object { Write-Host ($_.JobStateInfo.Reason | Out-String) }
        }

        # Remove the job from the queue
        Remove-Job $job
    }
}

# Restore orginal Error action
$global:erroractionpreference = $currentErrorAction

if ($scriptError) {
    # Throw an error to fail the job
    throw "Errors occurred updating Sql Users. Review the above log for details."
}
