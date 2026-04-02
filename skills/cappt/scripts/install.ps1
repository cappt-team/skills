# install.ps1 - Download and install cappt CLI (Windows)
# Usage: pwsh -ExecutionPolicy Bypass -File install.ps1 [-Yes] [-Force]
[CmdletBinding()]
param(
    [Alias('y')][switch]$Yes,
    [Alias('f')][switch]$Force
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$BIN_NAME    = 'cappt.exe'
$GITHUB_REPO = 'cappt-team/skills'
$GITHUB_API  = "https://api.github.com/repos/${GITHUB_REPO}/releases"

function Write-Info { param($Msg) Write-Host "[INFO]  $Msg" -ForegroundColor Cyan }
function Write-Ok   { param($Msg) Write-Host "[OK]    $Msg" -ForegroundColor Green }
function Write-Warn { param($Msg) Write-Host "[WARN]  $Msg" -ForegroundColor Yellow }
function Write-Err  { param($Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

$arch        = if ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq
                   [System.Runtime.InteropServices.Architecture]::Arm64) { 'arm64' } else { 'amd64' }
$platform    = "windows-$arch"
$binFileName = "cappt-${platform}.exe"
$installDir  = Join-Path $env:USERPROFILE '.local\bin'
$binPath     = Join-Path $installDir $BIN_NAME

$capptCmd = Get-Command cappt -ErrorAction SilentlyContinue
if ($capptCmd -and -not $Force) {
    $installedVer = & cappt version 2>$null
    Write-Warn "cappt is already installed (version: $installedVer)"
    Write-Warn "Use -Force to reinstall"
    exit 0
}

Write-Info "Fetching latest version..."
try {
    $releasesJson = Invoke-RestMethod -Uri $GITHUB_API -TimeoutSec 30
} catch {
    Write-Err "Cannot reach GitHub API: $_"
    exit 1
}

$latestRelease = $releasesJson | Where-Object { $_.tag_name -match '^v' } | Select-Object -First 1
if (-not $latestRelease) {
    Write-Err "No release found (expected tag format: v*)"
    exit 1
}

$latestTag   = $latestRelease.tag_name
$cliVersion  = $latestTag -replace '^v', ''
$releaseBase = "https://github.com/${GITHUB_REPO}/releases/download/${latestTag}"
$downloadUrl = "${releaseBase}/${binFileName}"

Write-Host ""
Write-Host "  Installing cappt CLI v${cliVersion}"
Write-Host "  Platform: $platform"
Write-Host "  Destination: $binPath"
Write-Host "  Source: $downloadUrl"
Write-Host ""

if (-not $Yes) {
    $confirm = Read-Host "Confirm installation? [y/N]"
    if ($confirm -notmatch '^[yY]$') {
        Write-Warn "Installation cancelled"
        exit 0
    }
}

$tmpFile = Join-Path $env:TEMP "cappt_install_$([System.IO.Path]::GetRandomFileName()).exe"

Write-Info "Downloading cappt CLI v${cliVersion}..."
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tmpFile -TimeoutSec 60
} catch {
    Write-Err "Download failed: $_"
    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Info "Fetching checksums..."
$checksumsUrl = "${releaseBase}/checksums.txt"
$tmpChecksums = Join-Path $env:TEMP "cappt_checksums_$([System.IO.Path]::GetRandomFileName()).txt"
try {
    Invoke-WebRequest -Uri $checksumsUrl -OutFile $tmpChecksums -TimeoutSec 30
    Write-Info "Verifying integrity..."
    $checksumLine = Get-Content $tmpChecksums | Where-Object { $_ -match $binFileName } | Select-Object -First 1
    if ($checksumLine) {
        $expected = ($checksumLine -split '\s+')[0].ToLower()
        $actual   = (Get-FileHash -Algorithm SHA256 $tmpFile).Hash.ToLower()
        if ($actual -ne $expected) {
            Write-Err "SHA256 mismatch!"
            Write-Err "  Expected: $expected"
            Write-Err "  Actual:   $actual"
            Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
            exit 1
        }
        Write-Ok "Integrity check passed"
    } else {
        Write-Warn "No checksum entry for $platform, skipping verification"
    }
} catch {
    Write-Warn "Could not fetch checksums, skipping verification"
} finally {
    Remove-Item $tmpChecksums -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}
Copy-Item $tmpFile $binPath -Force
Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue

Write-Ok "cappt CLI v${cliVersion} installed: $binPath"

$userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$installDir*") {
    [System.Environment]::SetEnvironmentVariable('Path', "$userPath;$installDir", 'User')
    $env:Path = "$env:Path;$installDir"
    Write-Ok "Added $installDir to user PATH (restart terminal to apply globally)"
}

Write-Host ""
Write-Info "Next step: run 'cappt login' to authenticate"
Write-Host ""
