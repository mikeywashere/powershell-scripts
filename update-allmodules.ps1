get-installedmodule | select-object name | ForEach-Object {
    write-host "updating $($_.Name)"
    update-module -Name "$($_.Name)" -AllowPrerelease -AcceptLicense -Scope AllUsers
    get-help "$($_.Name)" -Online 
}