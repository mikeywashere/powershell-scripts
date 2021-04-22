<#
  .SYNOPSIS
  Generates a random password of a given length.

  .DESCRIPTION
  The Generate-RandomPassword.ps1 script generates a random password of the given length.

  .PARAMETER Length
  Specifies the length of the password to generate. The minumum is 8 and there is no maximum.
  Note that it can take a significant amount of time to generate very long (1000's of characters)
  as the method if not efficient

  .PARAMETER NoSpecialCharacters
  Specifies if Generate-RandomPassword.ps1 should create a password without special characters.

  .INPUTS
  None. You cannot pipe objects to Generate-RandomPassword.ps1.

  .OUTPUTS
  A random password. Generate-RandomPassword.ps1 outputs a random password.

  .EXAMPLE
  PS> .\Generate-RandomPassword.ps1 20
  Generates a 20 character passwrod that will include special characters.
  .EXAMPLE
  PS> .\Generate-RandomPassword.ps1 -Length 32 -NoSpecialCharacters
  Generates a 32 character passwrod that will not include special characters.

#>

Param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [ValidateRange(8, 4096)]
    [int]$Length,

    [switch]$NoSpecialCharacters = $false,

    [OutputType("string")]
)

$normalCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
$specialCharacters = "``~!@#$%^&*()_-+={[}]:;`"'<,>.?/"
$allCharacters = "$($normalCharacters)$($specialCharacters)"

$charSet = $allCharacters

if ($NoSpecialCharacters) {
    $charSet = $normalCharacters
}

-Join(1..$Length | ForEach-Object {$charSet.ToCharArray() | Sort-Object { Get-Random } | Select-Object -First 1})