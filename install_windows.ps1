[CmdletBinding()]
param(
    [string]$PackageSpec = "marker-pdf-naufalkmd[full]",
    [switch]$SkipInstall,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$pipxBinDir = if ($env:PIPX_BIN_DIR) { $env:PIPX_BIN_DIR } else { Join-Path $env:USERPROFILE ".local\bin" }

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message"
}

function Invoke-Step {
    param(
        [string]$Message,
        [scriptblock]$Action
    )

    Write-Step $Message
    if ($DryRun) {
        return
    }

    & $Action
}

function Get-ExecutablePath {
    param([string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Path
    }

    $patterns = @(
        (Join-Path $env:LOCALAPPDATA "Packages\PythonSoftwareFoundation.Python.*\LocalCache\local-packages\Python*\Scripts\$Name.exe"),
        (Join-Path $env:APPDATA "Python\Python*\Scripts\$Name.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python*\Scripts\$Name.exe"),
        (Join-Path $pipxBinDir "$Name.exe")
    )

    $matches = foreach ($pattern in $patterns) {
        Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
    }

    return $matches |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

function Get-PythonUserScriptsPaths {
    $patterns = @(
        (Join-Path $env:LOCALAPPDATA "Packages\PythonSoftwareFoundation.Python.*\LocalCache\local-packages\Python*\Scripts"),
        (Join-Path $env:APPDATA "Python\Python*\Scripts"),
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python*\Scripts")
    )

    $matches = foreach ($pattern in $patterns) {
        Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue
    }

    return $matches |
        Sort-Object FullName -Unique |
        Select-Object -ExpandProperty FullName
}

function Add-CurrentSessionPath {
    param([string]$PathEntry)

    if (-not $PathEntry -or -not (Test-Path $PathEntry)) {
        return
    }

    $pathEntries = $env:PATH -split ";"
    if ($pathEntries -contains $PathEntry) {
        return
    }

    $env:PATH = ($env:PATH.TrimEnd(";") + ";" + $PathEntry).Trim(";")
}

function Add-UserPath {
    param([string]$PathEntry)

    if (-not $PathEntry -or -not (Test-Path $PathEntry)) {
        return
    }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = @()
    if ($userPath) {
        $entries = $userPath -split ";" | Where-Object { $_ }
    }

    if ($entries -contains $PathEntry) {
        return
    }

    $newPath = (@($entries) + $PathEntry) -join ";"
    if (-not $DryRun) {
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    }
}

function Ensure-PipScriptsPath {
    foreach ($scriptsDir in Get-PythonUserScriptsPaths) {
        Invoke-Step "Adding Python Scripts directory to your user PATH: $scriptsDir" {
            Add-UserPath -PathEntry $scriptsDir
        }
        Add-CurrentSessionPath -PathEntry $scriptsDir
    }
}

function Ensure-Pipx {
    $pipxPath = Get-ExecutablePath -Name "pipx"
    if ($pipxPath) {
        return $pipxPath
    }

    $pipPath = Get-ExecutablePath -Name "pip"
    if (-not $pipPath) {
        throw "Could not find pip.exe. Install Python with pip first, or add pip to PATH."
    }

    Invoke-Step "Installing pipx with $pipPath" {
        & $pipPath install --user pipx
    }

    $pipxPath = Get-ExecutablePath -Name "pipx"
    if (-not $pipxPath) {
        throw "pipx.exe was not found after installation."
    }

    return $pipxPath
}

function Ensure-PipxPath {
    param([string]$PipxPath)

    $pipxDir = Split-Path -Parent $PipxPath
    Invoke-Step "Adding pipx and app directories to your user PATH" {
        Add-UserPath -PathEntry $pipxDir
        if (-not (Test-Path $pipxBinDir)) {
            New-Item -ItemType Directory -Path $pipxBinDir -Force | Out-Null
        }
        Add-UserPath -PathEntry $pipxBinDir
    }

    Add-CurrentSessionPath -PathEntry $pipxDir
    if (-not (Test-Path $pipxBinDir) -and -not $DryRun) {
        New-Item -ItemType Directory -Path $pipxBinDir -Force | Out-Null
    }
    Add-CurrentSessionPath -PathEntry $pipxBinDir

    Invoke-Step "Running pipx ensurepath" {
        & $PipxPath ensurepath
    }
}

function Install-MarkerWithPipx {
    param([string]$PipxPath)

    if ($SkipInstall) {
        return
    }

    Invoke-Step "Installing $PackageSpec with pipx" {
        & $PipxPath install $PackageSpec --force
    }
}

function Resolve-MarkerPath {
    $markerPath = Get-ExecutablePath -Name "marker"
    if ($markerPath) {
        return $markerPath
    }

    $candidate = Join-Path $pipxBinDir "marker.exe"
    if (Test-Path $candidate) {
        return $candidate
    }

    return $null
}

Ensure-PipScriptsPath
$pipxPath = Ensure-Pipx
Ensure-PipxPath -PipxPath $pipxPath
Install-MarkerWithPipx -PipxPath $pipxPath

$markerPath = Resolve-MarkerPath
if ($markerPath) {
    Write-Step "marker is available at $markerPath"
    Write-Host "Open a new PowerShell window, or run:"
    Write-Host "  & `"$markerPath`" --help"
} else {
    Write-Warning "marker.exe was not found yet. Open a new PowerShell window and run `marker --help`, or rerun this script with -DryRun to inspect the paths."
}
