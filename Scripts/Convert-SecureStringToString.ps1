###############################################################################
# Function: Convert-SecureStringToString
# Purpose:  Creates the specified Azure Pipeline variable. If the value is an array
#           the value is added as a JSON array.
# Parameters:
#       $Value : Encrypted value to convert
###############################################################################
function Convert-SecureStringToString() {
    [CmdletBinding()]
    param (
        [securestring] $Value
    )
    
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    $plaintextValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    return $plaintextValue
}
