param (
    [string]$text
)

$charArray = $text.ToCharArray()
[array]::Reverse($charArray)
$text = -join($charArray)
$text