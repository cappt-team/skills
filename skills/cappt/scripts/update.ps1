# update.ps1 - Update cappt CLI to the latest version (Windows)
# Usage: pwsh -ExecutionPolicy Bypass -File update.ps1 [-Yes]
[CmdletBinding()]
param(
    [Alias('y')][switch]$Yes
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

$capptCmd = Get-Command cappt -ErrorAction SilentlyContinue
if (-not $capptCmd) {
    Write-Err "cappt is not installed. Run install.ps1 first."
    exit 1
}

$BIN_PATH   = $capptCmd.Source
$currentVer = & cappt version 2>$null
Write-Info "Current version: $currentVer  Path: $BIN_PATH"

$arch        = if ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq
                   [System.Runtime.InteropServices.Architecture]::Arm64) { 'arm64' } else { 'amd64' }
$platform    = "windows-$arch"
$binFileName = "cappt-${platform}.exe"

Write-Info "Checking for updates..."
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

$latestTag = $latestRelease.tag_name
$latestVer = $latestTag -replace '^v', ''
Write-Info "Latest version: $latestVer"

function Compare-SemVer {
    param([string]$v1, [string]$v2)
    $p1 = ($v1 -replace '^v','').Split('.') | ForEach-Object { [int]$_ }
    $p2 = ($v2 -replace '^v','').Split('.') | ForEach-Object { [int]$_ }
    for ($i = 0; $i -lt 3; $i++) {
        $a = if ($i -lt $p1.Count) { $p1[$i] } else { 0 }
        $b = if ($i -lt $p2.Count) { $p2[$i] } else { 0 }
        if ($a -ne $b) { return $a - $b }
    }
    return 0
}

if ((Compare-SemVer $latestVer $currentVer) -le 0) {
    Write-Ok "Already up to date ($currentVer)"
    exit 0
}

$releaseBase  = "https://github.com/${GITHUB_REPO}/releases/download/${latestTag}"
$downloadUrl  = "${releaseBase}/${binFileName}"
$checksumsUrl = "${releaseBase}/checksums.txt"

Write-Host ""
Write-Host "  Current: $currentVer"
Write-Host "  Latest:  $latestVer"
Write-Host "  Path:    $BIN_PATH"
Write-Host ""

if (-not $Yes) {
    $confirm = Read-Host "Confirm update? [y/N]"
    if ($confirm -notmatch '^[yY]$') {
        Write-Warn "Update cancelled"
        exit 0
    }
}

$tmpFile = Join-Path $env:TEMP "cappt_update_$([System.IO.Path]::GetRandomFileName()).exe"

Write-Info "Downloading cappt CLI v${latestVer}..."
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tmpFile -TimeoutSec 60
} catch {
    Write-Err "Download failed: $_"
    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Info "Fetching checksums..."
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

Copy-Item $tmpFile $BIN_PATH -Force
Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue

Write-Ok "cappt CLI updated to v${latestVer}: $BIN_PATH"
