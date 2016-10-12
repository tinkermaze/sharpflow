<#
.SYNOPSIS
Custom Powershell script to bootstrap a Cake build.
.DESCRIPTION
Script downloads .NET Core SDK if missing, restores helper packages for
build pipeline (including Cake) and starts build.cake script.
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

# helper function to add path to PATH if missing
Function Add-Path([string]$pathToAdd) {
    $foundInPath = $false
    foreach ($path in $env:PATH.Split(';', [StringSplitOptions]::RemoveEmptyEntries)) {
        if ($path -ilike $pathToAdd) {
            $foundInPath = $true;
            break;
        }
    }
    if (!$foundInPath) {
        $env:PATH = "$pathToAdd;$env:PATH"
    } 
}

# local dotnet installation (in .dotnet folder) has priority over system-wide
if (Get-Command $dotnetLocalExe -ErrorAction SilentlyContinue) {

    $dotnetVersionFound = & $dotnetLocalExe --version

    Write-Host "Found .NET Core SDK version $dotnetVersionFound (in $dotnetLocalPath)"

    Add-Path "$dotnetLocalPath"
}
elseif (Get-Command dotnet -ErrorAction SilentlyContinue) {

    $dotnetVersionFound = & dotnet --version

    Write-Host "Found .NET Core SDK version $dotnetVersionFound (system-wide)"
}
else {

    Write-Host "Installing the latest .NET Core SDK (into '$dotnetLocalPath')"

    if (Test-Path $dotnetLocalPath)
    {
        Remove-Item $dotnetLocalPath -Force -Recurse
    }

    if (!(Test-Path $dotnetLocalPath)) {
        New-Item $dotnetLocalPath -ItemType Directory | Out-Null
    }

    (New-Object System.Net.WebClient).DownloadFile($dotnetInstallerUri, "$dotnetLocalPath\dotnet-install.ps1") | Out-Null
    & $dotnetLocalPath\dotnet-install.ps1 -Version latest -InstallDir $dotnetLocalPath -NoPath | Out-Null

    Add-Path "$dotnetLocalPath"
}

$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
$env:DOTNET_CLI_TELEMETRY_OPTOUT=1

###########################################################################
# Prepare Cake and helper tools
###########################################################################

$buildPath = Join-Path $solutionRoot "build"
$toolsPath = Join-Path $solutionRoot "tools"

$toolsProjectJson = Join-Path $toolsPath "project.json"
$toolsProjectJsonSource = Join-Path $buildPath "tools_project.json"

$cakeFeed = "https://api.nuget.org/v3/index.json"

# make sure tools folder exists
if (!(Test-Path $toolsPath))
{
    Write-Verbose -Message "Creating tools directory"
    New-Item -Path $toolsPath -Type directory | Out-Null
}

# project.json defines packages used in build process
Copy-Item $toolsProjectJsonSource $toolsProjectJson -ErrorAction Stop

Write-Host "Restoring build tools (into $toolsPath)"
Invoke-Expression "& dotnet restore `"$toolsPath`" --packages `"$toolsPath`" -f `"$cakeFeed`"" | Out-Null;
if ($LastExitCode -ne 0)
{
    throw "Error occured while restoring build tools"
}

$cakeExe = (Get-ChildItem (Join-Path $toolsPath "Cake.CoreCLR/*/Cake.dll") -ErrorAction Stop).FullName | `
            Sort-Object $_ | `
            Select-Object -Last 1

# NuGet client is used only for uploading packages to MyGet and NuGet repos
$NugetUrl = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$NugetPath = Join-Path $toolsPath "nuget.exe"

if (!(Test-Path $NugetPath)) {
    Write-Host "Downloading Nuget client"
    (New-Object System.Net.WebClient).DownloadFile($NugetUrl, $NugetPath);
}

###########################################################################
# Run build script
###########################################################################

