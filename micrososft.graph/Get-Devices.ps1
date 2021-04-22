    $credential = Get-Credential

    connect-azaccount -Credential $credential -Environment 'AzureCloud'

    $json = $authResult | ConvertTo-Json
    Write-Output "Auth Result: $($json)"

    