# uninstall.ps1 - Remove cappt CLI and local config (Windows)
# Usage: pwsh -ExecutionPolicy Bypass -File uninstall.ps1 [-Yes]
[CmdletBinding()]
param(
    [Alias('y')][switch]$Yes
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Ok   { param($Msg) Write-Host "[OK]    $Msg" -ForegroundColor Green }
function Write-Warn { param($Msg) Write-Host "[WARN]  $Msg" -ForegroundColor Yellow }
function Write-Err  { param($Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

$capptCmd = Get-Command cappt -ErrorAction SilentlyContinue
if (-not $capptCmd) {
    Write-Warn "cappt is not installed"
    exit 0
}

$BIN_PATH = $capptCmd.Source
$CFG_DIR  = Join-Path $env:USERPROFILE '.config\cappt'

Write-Host ""
Write-Host "  The following will be removed:"
Write-Host "  [binary] $BIN_PATH"
if (Test-Path $CFG_DIR) { Write-Host "  [config] $CFG_DIR" }
Write-Host ""

if (-not $Yes) {
    $confirm = Read-Host "Confirm uninstall? [y/N]"
    if ($confirm -notmatch '^[yY]$') {
        Write-Warn "Uninstall cancelled"
        exit 0
    }
}

if (Test-Path $CFG_DIR) {
    Remove-Item $CFG_DIR -Recurse -Force
    Write-Ok "Removed config: $CFG_DIR"
}

# cappt.exe is not running here, so direct deletion works
Remove-Item $BIN_PATH -Force
Write-Ok "Removed binary: $BIN_PATH"

# Remove install dir from user PATH if it's now empty
$installDir = Split-Path $BIN_PATH
if (-not (Get-ChildItem $installDir -ErrorAction SilentlyContinue)) {
    Remove-Item $installDir -Force -ErrorAction SilentlyContinue
    $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $newPath  = ($userPath -split ';' | Where-Object { $_ -ne $installDir }) -join ';'
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
}

Write-Host ""
Write-Ok "Uninstall complete"
