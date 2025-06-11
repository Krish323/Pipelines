###############################################################################
# Script: Set-PipelineVariables.ps1
# Purpose:  Creates ADO Pipeline variables from a JSON variable file
# Parameters:
#		$VariableFileName : Name of the json variable file
#		$SubsectionPath : Optional. Subsection of the json document to create
#         variables from in the form Property1.Property2.PropertyN.
###############################################################################
param(
    [Parameter(Mandatory=$true)]
    [string] $VariableFileName,
    [string] $SubsectionPath = ""
)

. "$($PSScriptRoot)\Add-PipelineVariable.ps1"

Write-Host "`n`nEnter Set-PipelineVariables.ps1`nParameters:"
Write-Host "VariableFileName: $($VariableFileName)"
Write-Host "SubsectionPath: $($SubsectionPath)`n"

if (-Not(Test-Path -Path $VariableFileName)) {
    throw "Variable File not found: $(VariableFileName)"
}

# Load the JSONN file and convert to a PSCustomObject
$variablesFromFile = Get-Content -Path $VariableFileName | Out-String | ConvertFrom-Json

if (-not [system.string]::IsNullOrEmpty($SubsectionPath)) {
    # Split subsections into an array
    $subsections = $SubsectionPath.Split('.')

    foreach ($subsection in $subsections) {
        Write-Host "Loading subsection: $($subsection)"
        $variablesFromFile = $variablesFromFile.$subsection

        if ($null -eq $variablesFromFile) {
            throw "Subsection '$($subsection)' does not exist!"
        }
    }
}

# Loop through properties on this section of the file and add to Pipeline
$variablesFromFile.PSObject.Properties | ForEach-Object {
    Add-PipelineVariable -VariableName $_.Name -Value: $_.Value
}

Write-Host "Exit Set-PipelineVariables.ps1`n"
