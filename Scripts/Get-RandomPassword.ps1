function Get-RandomPassword {
    <#
	    .SYNOPSIS
	    Returns a randomly generated string of characters.
	    .DESCRIPTION
	    Returns a randomly generated string of characters from a predifined list
	    .PARAMETER Length
	    The length of string that is returned.
        .INPUTS
	    System.Integer
	    .OUTPUTS
	    System.String
	#>
    param (
        [int] $Length = 32
    )

    # Build an array of characters that are allowed to be used in a password. Special characters
    # that are reserved characters in Powershell and Sql Server are excluded.
    $allowedCharacters = @("!", "#", "^", "*", "(", ")", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n","o","p","q","r","s","t","u","v","w","x","y","z")

    # Select the specified number of characters randomly.
    $randomPassword = ($allowedCharacters | Get-Random -Count $Length) -Join ''
    return $randomPassword
}