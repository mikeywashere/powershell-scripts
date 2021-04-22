<#
.SYNOPSIS
    IP - Install-Package but opinionated
.DESCRIPTION
    Will first find then install the latest version no matter which provider it is stored in
.PARAMETER Name
    A required parameter. Name of the package to install.
.LINK
    Install-Package https://docs.microsoft.com/en-us/powershell/module/packagemanagement/install-package?view=powershell-7.1
.EXAMPLE
    IP 'Microsoft.Graph'
    Installs Microsoft.Graph
.NOTES
    Author: Michael R. Schmidt
    Date:   April 20, 2021
#>
param (
    [Parameter(
        Mandatory = $true, 
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = "A required parameter. Name of the package."
    )]
    [string]$Name,
    [string]$Verb = "Install",
    [switch]$AllVersions = $false,
    [switch]$AllowPrerelease = $false,
    [switch]$FullDescription = $false
)

function Write-RemainingWidthAtWordBreaks() {
    param (
        [string]$text
    )

    $lines = @()

    $x = $Host.UI.RawUI.CursorPosition.X
    $w = $Host.UI.RawUI.WindowSize.Width
    $r = $w - $x

    $text = $text.Replace("`r", " ")
    $text = $text.Replace("`n", " ")
    $text = $text.Replace("`t", " ")
    while ($text.Contains("  ")) {
        $text = $text.Replace("  ", " ")
    }

    $indent = ""
    for ($i = 0; $i -le $x; $i++) {
        $indent = "$($indent) "
    }

    $words = $text -split " "

    #$words = "-$($words.count)- " + $words

    $line = ""

    $words | foreach-object {
        $current = $_.Trim()
        if (($lines.count -eq 0 -And ($line + $current).Length + 1 -ge $r) -Or
            ($lines.count -gt 0 -And ($line + $current).Length + 1 -ge $w)) {
            $lines = $lines + $line
            $line = $indent
        }
        if (-Not $line.EndsWith(" ")) {
            $line = "$($line) "
        }
        $line = "$($line)$($current)"
    }
    $cleanLine = $line.Trim()
    if ($cleanLine.Length -gt 0) {
        $lines = $lines + $line
    }

    $alltext = $lines -join "`r`n"
    $alltext
}

function Write-RemainingWidth() {
    param (
        [string]$text,
        [switch]$WithElipses = $false
    )

    $x = $Host.UI.RawUI.CursorPosition.X
    $w = $Host.UI.RawUI.WindowSize.Width
    $r = $w - $x

    $text = $text.Replace("`r", " ")
    $text = $text.Replace("`n", " ")
    $text = $text.Replace("  ", " ").Replace("  ", " ").Replace("  ", " ")

    $text = $text.Substring(0, [math]::Min($r - 1, $text.Length))
    if ($WithElipses -And $text.Length -ge $r - 3) {
        $text = $text.Substring(0, $r - 3)
        $text = $text + "..."
    }
    $text
}

function Write-Console() {
    param (
        [string]$text
    )

    [Console]::Write($text)
}

function Write-ConsoleWithNewLine() {
    param (
        [string]$text
    )

    [Console]::WriteLine($text)
}

$w = $Host.UI.RawUI.WindowSize.Width

Write-Output "Finding $($Name)"
if ($AllowPrerelease) {
    if ($AllVersions) {
        $packages = Find-Package -Name $Name -Allversions -AllowPrerelease | Sort-Object Version -Descending
    } else {
        $packages = Find-Package -Name $Name -AllowPrerelease | Sort-Object Version -Descending
    }
}
else {
    if ($AllVersions) {
        $packages = Find-Package -Name $Name -Allversions | Sort-Object Version -Descending
    }
    else {
        $packages = Find-Package -Name $Name | Sort-Object Version -Descending
    }
}
$InstallFound = Get-InstalledModule -Name $Name -ErrorAction Ignore
$installed = $false
$installedIndex = -1

$i = 1
foreach ($package in $packages) {
    if ($null -ne $InstallFound -And $InstallFound.Name -eq $package.Name -And $InstallFound.Version -eq $package.Version) {
        $installed = $true
        $installedIndex = $i - 1
    } else {
        $installed = $false
    }

    if ($installed) {
        Write-Console "* "
    }
    else {
        Write-Console "  "
    }
    Write-Console "($($i)):`t$($package.Name) | $($package.Version) | $($package.Source) |"
    if ($FullDescription) {
        Write-ConsoleWithNewLine "$(Write-RemainingWidthAtWordBreaks $package.Summary)"
    } else {
        Write-ConsoleWithNewLine "$(Write-RemainingWidth $package.Summary -WithElipses)"
    }
    
    if ($Verb -ieq "Dependencies") {
        $e = ( $package.Dependencies | foreach-object { $a = $_; $b = $a -split { $_ -eq ":" -or $_ -eq "#" }; $c = $b[1] -split '/'; $d = "$($c[0]) $($c[1])"; $d } )
        $e = $e | Sort-Object

        $indent = "      "
        $line = $indent
        $e | foreach-object {
            $current = $_.Trim()
            if (($line + $current).Length + 2 -ge $w) {
                Write-Output $line
                $line = $indent
            }
            if (-Not $line.EndsWith(" ")) {
                $line = $line + ", "
            }
            $line = $line + $current
        }
        $cleanLine = $line.Replace(" ", "")
        if ($cleanLine.EndsWith(",")) {
            $cleanLine = $cleanLine.Substring(0, $cleanLine.Length - 1)
        }
        if ($cleanLine.Length -gt 0) {
            Write-Output $line
        }
    }
    $i++
}

if ($installedIndex -eq -1 -And $InstallFound) {
    Write-Output "* (-):`t$($InstallFound.Name) | $($InstallFound.Version) | Installed Version."
}

if ($Verb -ieq "Dependencies") {
    exit
}

## $Installed | ConvertTo-Json

$output = $null

if ($Verb -ieq "Install") {
    Write-Output ""
    $Choose = Read-Host -Prompt "Choose one to install (1..$($i)) (Ctrl-C to exit)"

    $Choose = $Choose - 1
    # $version = [System.Version]::Parse("11.00.9600.17840")
    if ($Choose -ge 0 -And $Choose -le $i) {
        $toInstall = $packages[$Choose]
        if ($installedIndex -ne -1) {
            $prevInstall = $packages[$installedIndex]
        }

        if ($installedIndex -eq $Choose) {
            Write-Output "Updating $($toInstall.Name) to version $($toInstall.Version)"
            Update-Module -Name $toInstall.Name -RequiredVersion $toInstall.Version -Force -Scope AllUsers
        } else {
            if ($null -eq $prevInstall) { # not installed so just install
                Write-Output "Installing $($toInstall.Name) version $($toInstall.Version)"
                $output = Install-Package -Name $toInstall.Name -RequiredVersion $toInstall.Version -Force -Scope AllUsers -AllowClobber
            }
            else {
                $installedVersion = [System.Version]::Parse($prevInstall.Version)
                $chosenVersion = [System.Version]::Parse($toInstall.Version)

                if ($installedVersion -lt $chosenVersion) {
                    Write-Output "Updating $($toInstall.Name) to version $($toInstall.Version)"
                    $output = Update-Module -Name $toInstall.Name -RequiredVersion $toInstall.Version -Force -Scope AllUsers
                }
                if ($installedVersion -gt $chosenVersion) {
                    Write-Output "Uninstalling $($prevInstall.Name) version $($prevInstall.Version)"
                    $output = Uninstall-Package -Name $prevInstall.Name -RequiredVersion $prevInstall.Version -Force
                    Write-Output "Installing $($prevInstall.Name) version $($toInstall.Version)"
                    $output = Install-Package -Name $toInstall.Name -RequiredVersion $toInstall.Version -Force -Scope AllUsers -AllowClobber
                }
                if ($installedVersion -eq $chosenVersion) {
                    Write-Output "Updating $($toInstall.Name) to version $($toInstall.Version)"
                    $output = Update-Module -Name $toInstall.Name -RequiredVersion $toInstall.Version -Force -Scope AllUsers -AllowClobber
                }
            }
        }
    }
}
# $json = $output | ConvertTo-Json -Depth 5
# Write-Output "JSON:`r`n$($json)"

Write-Output ""
Write-Output "Script is finished"
