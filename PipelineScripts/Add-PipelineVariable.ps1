###############################################################################
# Function: Add-PipelineVariable
# Purpose:  Creates the specified Azure Pipeline variable. If the value is an array
#           the value is added as a JSON array.
# Parameters:
#		$VariableName : Name of the Pipeline Variable to Add
#       $Value : Variable Value
#       $IsSecret :  Make the variable a secret so it's value doesn't display in logs
#       $IsOutput :  Make the variable an output variable for the task
###############################################################################
function Add-PipelineVariable() {
    [CmdletBinding()]
    param (
        [string] $VariableName,
        [object] $Value,
        [switch] $IsSecret,
        [switch] $IsOutput
    )
    
    Write-Host "Adding Variable: $($VariableName)"

    if ($IsSecret) {
        # Create text that creates a Secret Pipeline Variable for use in Write-Host
        $secretCommand = ';issecret=true;'
    }
    else {
        $secretCommand = ''
    }

    if ($IsOutput) {
        # Create text that creates an Output Pipeline Variable for use in Write-Host
        $outputCommand = ';isoutput=true;'
    }
    else {
        $outputCommand = ''
    }

    if ($Value -is [array]) {
        # Convert the array to JSON for the Pipeline to handle it correctly
        $variableValue = ConvertTo-Json $Value -Compress
    }
    else {
        # Use the variable as is
        $variableValue = $Value
    }

    # Add the variable to the pipeline
    Write-Host "##vso[task.setvariable variable=$($VariableName)$($secretCommand)$($outputCommand)]$($variableValue)"
}
