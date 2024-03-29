<#
.SYNOPSIS
    Pak - Installing Packages - but very opinionated
.DESCRIPTION
    Will first find then install list all found version, allowing the user to choose which to install
.PARAMETER Name
    A required parameter. Name of the package to install.
.PARAMETER AllVersions
    Show all available versions
.PARAMETER AllowPrerelease
    Show prerelease versions
.PARAMETER FullDescription
    Show the full description. Normally what fits on the remaining line is all that is shown of the desciption.
.PARAMETER NoUserInput
    No user input - if you are installing this means the latest version will be installed.
.PARAMETER IncludeDependencies
    Include the dependencies in the output
.LINK
    Install-Package https://docs.microsoft.com/en-us/powershell/module/packagemanagement/install-package?view=powershell-7.1
.EXAMPLE
    Pak 'Microsoft.Graph'
    Installs Microsoft.Graph
.EXAMPLE
    Pak 'Microsoft.Graph'
    If Microsoft.Graph is not installed.
    Finds Microsoft.Graph, Gives the user a choice to install the latest version found.

    Example output:

    ----------
    Finding Microsoft.Graph
    (1):  Microsoft.Graph | 1.5.0 | PSGallery |Microsoft Graph PowerShell module

    Choose one to install (1) (Ctrl-C to exit):
    ----------

    For this example you can choose 1 to install or Ctrl-C to exit
.EXAMPLE
    Pak 'Microsoft.Graph'
    If Microsoft.Graph is installed.
    Finds Microsoft.Graph, Gives the user a choice to install the latest version found.

    Example output:

    ----------
    Finding Microsoft.Graph
      (1):  Microsoft.Graph | 1.5.0 | PSGallery |Microsoft Graph PowerShell module
    * (-):  Microsoft.Graph | 1.0.1 | Installed Version.

    Choose one to install (1) (Ctrl-C to exit):
    ----------
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
    [ValidateSet("Install", "Query", "Uninstall", "Uninstall-Dependencies", IgnoreCase = $true)]
    [string]$Action = "Install",
    [switch]$AllVersions = $false,
    [switch]$AllowPrerelease = $false,
    [switch]$FullDescription = $false,
    [switch]$NoUserInput = $false,
    [switch]$IncludeDependencies = $false
)

function Get-NormalizedText() {
    param (
        [string]$Text
    )

    $text = $text.Replace("`r", " ")
    $text = $text.Replace("`n", " ")
    $text = $text.Replace("`t", " ")
    while ($text.Contains("  ")) {
        $text = $text.Replace("  ", " ")
    }
    $text
}

function Format-ToWidthAtWordBreaks() {
    param (
        [string]$Text,
        [string]$FirstLine,
        [int]$Width
    )

    $indent = [system.string]::New(" ", $FirstLine.Length)

    $text = Get-NormalizedText $text

    $words = $text -split " "

    $lines = @()
    $line = $FirstLine

    $words | foreach-object {
        $current = $_.Trim()
        if ((($line + $current).Length + 1 -ge $Width)) {
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

    $lines
}

function Format-ToWidth() {
    param (
        [string]$Text,
        [int]$Width,
        [switch]$WithElipses = $false
    )

    $text = Get-NormalizedText $text

    $text = $text.Substring(0, [math]::Min($Width - 1, $text.Length))
    if ($WithElipses -And $text.Length -ge $Width - 3) {
        $text = $text.Substring(0, $Width - 3)
        $text = $text + "..."
    }
    $text
}

##########
# Script Code
##########

$screenWidth = $Host.UI.RawUI.WindowSize.Width

if ($Action -ieq "Uninstall-Dependencies") {
    $IncludeDependencies = $true
}

Write-Output "Action $($Action)"
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

$dependencies = @{ "first-item-test" = @() }

Write-Output "packages.count = $($packages.Count)"
Write-Output "dependencies.Count = $($dependencies.Count)"

$i = 1
foreach ($package in $packages) {
    if ($null -ne $InstallFound -And $InstallFound.Name -eq $package.Name -And $InstallFound.Version -eq $package.Version) {
        $installed = $true
        $installedIndex = $i - 1
    } else {
        $installed = $false
    }

    $line = ""
    if ($installed) {
        $line = "* "
    }
    else {
        $line = "  "
    }
    $line += "($($i)):"
    while ($line.Length -lt 8) { $line += " " }
    $line += "$($package.Name) | $($package.Version) | $($package.Source) | "
    $w = ($screenWidth - $line.Length)
    if ($FullDescription) {
        $lines += Format-ToWidthAtWordBreaks -Text $package.Summary -FirstLine $line -Width $screenWidth
        $lines | ForEach-Object { Write-Output $_ }
    } else {
        $line += Format-ToWidth -Text $package.Summary -Width $w -WithElipses
        $line | Write-Output
    }
    
    if ($IncludeDependencies) {
        $e = ( $package.Dependencies | foreach-object { $a = $_; $b = $a -split { $_ -eq ":" -or $_ -eq "#" }; $c = $b[1] -split '/'; $d = @{Name=$c[0]; Version=$c[1]}; $d } )
        $e = $e | Sort-Object -Property Name

        $indent = "      "
        $dependencies += @{ $package.Name = $e }
        $data = $e | foreach-object { "$($_.Name)[$($_.Version.Replace('[','').Replace(']',''))]" }
        Format-ToWidthAtWordBreaks -Text $data -FirstLine "      " -Width $screenWidth | ForEach-Object { Write-Output $_ }
    }
    $i++
}

if ($installedIndex -eq -1 -And $InstallFound) {
    Write-Output "* (-):`t$($InstallFound.Name) | $($InstallFound.Version) | Installed Version."
}

#if ($IncludeDependencies) {
#    exit
#}

## $Installed | ConvertTo-Json

$output = $null


if ($Action -ieq "Install" -Or $Action -ieq "Uninstall" -Or $Action -ieq "Uninstall-Dependencies") {
    $i--
    if ($NoUserInput) {
        $Choose = 1
    }
    else {
        Write-Output ""
        if ($i -eq 1) {
            $Choose = Read-Host -Prompt "Choose one to install (1) (Ctrl-C to exit)"
        } 
        elseif ($i -le 4) {
            $choices = (1..$i) -Join ","
            $Choose = Read-Host -Prompt "Choose one to install ($($choices)) (Ctrl-C to exit)"
        }
        else {
            $Choose = Read-Host -Prompt "Choose one to install (1..$($i)) (Ctrl-C to exit)"
        }
    }
    $Choose = $Choose - 1
}

if ($Action -ieq "Install") {
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

if ($Action -ieq "Uninstall") {
    if ($Choose -ge 0 -And $Choose -le $i) {
        $Installed = $packages[$Choose]
    }
    Write-Output "Uninstalling $($Installed.Name) version $($Installed.Version)"
    $output = Uninstall-Package -Name $Installed.Name -RequiredVersion $Installed.Version -Force
}

if ($Action -ieq "Uninstall-Dependencies") {
    if ($Choose -ge 0 -And $Choose -le $i) {
        $Installed = $packages[$Choose]
    }
    $dependencySet = $dependencies[$Installed.Name]
    $dependencySet | ForEach-Object {
        $Current = $_
        Write-Output "Uninstalling $($Current.Name) version $($Current.Version)"
        $output = Uninstall-Package -Name $Current.Name -RequiredVersion $Current.Version -Force
    }
}