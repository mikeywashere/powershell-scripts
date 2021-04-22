$list = @()

get-installedmodule | select-object Name, Version | ForEach-Object {
    $o = [pscustomobject]@{Name = $_.Name; Version = $_.Version }
    $list += $o
    Write-Output "Count: $($list.Count)"
}

$text = $list | ConvertTo-Json

Write-Output "Found: $($text)"

get-installedmodule | select-object name | ForEach-Object {
    write-host "updating module $($_.Name)"
    try {
        update-module -Name "$($_.Name)" -AllowPrerelease -AcceptLicense -Scope AllUsers -ErrorAction Ignore
    }
    catch {
        ## ignore
    }
    write-host "updating help for module $($_.Name)"
    try {
        get-help "$($_.Name)" -Online -ErrorAction:Ignore -InformationAction:Ignore
    }
    catch {
        ## ignore
    }
}