<#
.SYNOPSIS
Custom Powershell script to bootstrap a Cake build.
.DESCRIPTION
Script downloads .NET Core SDK if missing, restores helper packages for build
pipeline (including Cake itself) and starts build.cake script.
.PARAMETER Target
Build target to run.
.PARAMETER Configuration
Configuration to use.
.PARAMETER Verbosity
Specifies the amount of information to be displayed.
.PARAMETER ScriptArgs
Remaining arguments are added here.
#>

[CmdletBinding()]
Param(
    [string]$target = "Default",

    [ValidateSet("Release", "Debug")]
    [string]$configuration = "Release",

    [ValidateSet("Quiet", "Minimal", "Normal", "Verbose", "Diagnostic")]
    [string]$verbosity = "Verbose",

    [Parameter(Position=0,Mandatory=$false,ValueFromRemainingArguments=$true)]
    [string[]]$scriptArgs
)

$solutionRoot = Split-Path $MyInvocation.MyCommand.Path -Parent

###########################################################################
# Prepare .NET Core SDK
###########################################################################

$dotnetVersionFound = $null
$dotnetLocalPath = Join-Path $solutionRoot ".dotnet"
$dotnetLocalExe = Join-Path $dotnetLocalPath "dotnet.exe"
$dotnetInstallerUri = "https://raw.githubusercontent.com/dotnet/cli/rel/1.0.0-preview2/scripts/obtain/dotnet-install.ps1"

if (Get-Command dotnet -ErrorAction SilentlyContinue ) {

    $dotnetVersionFound = & dotnet --version

    Write-Host "Found .NET Core SDK version $dotnetVersionFound"
}
elseif (Get-Command $dotnetLocalExe -ErrorAction SilentlyContinue) {

    $dotnetVersionFound = & $dotnetLocalExe --version

    Write-Host "Found .NET Core SDK version $dotnetVersionFound"

    $foundInPath = $false
    foreach ($path in $env:PATH.Split(';', [StringSplitOptions]::RemoveEmptyEntries)) {
        if ($path -ilike $dotnetLocalPath) {
            $foundInPath = $true;
            break;
        }
    }

    if (!$foundInPath) {
        $env:PATH = "$dotnetLocalPath;$env:PATH"
    }
}
else {

    Write-Host "Installing the latest .NET Core SDK"

    if (Test-Path $dotnetLocalPath)
    {
        Remove-Item $dotnetLocalPath -Force -Recurse
    }

    if (!(Test-Path $dotnetLocalPath)) {
        New-Item $dotnetLocalPath -ItemType Directory | Out-Null
    }

    (New-Object System.Net.WebClient).DownloadFile($dotnetInstallerUri, "$dotnetLocalPath\dotnet-install.ps1") | Out-Null
    & $dotnetLocalPath\dotnet-install.ps1 -Version latest -InstallDir $dotnetLocalPath -NoPath | Out-Null

    $env:PATH = "$dotnetLocalPath;$env:PATH"
}

$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
$env:DOTNET_CLI_TELEMETRY_OPTOUT=1

###########################################################################
# Prepare Cake and helper tools
###########################################################################

###########################################################################
# Run build script
###########################################################################