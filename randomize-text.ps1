param (
    [string]$text
)
-join($text.ToCharArray() | Sort-Object {Get-Random})
