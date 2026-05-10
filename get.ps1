#!/usr/bin/env pwsh
<#
.SYNOPSIS
    DevClean — One-line installer from GitHub Releases.
    Downloads the compiled devclean.exe — no source code exposed.

USAGE (paste in any PowerShell 7 terminal):
    irm https://github.com/Suprabhat2810/DevCleanV1/releases/latest/download/get.ps1 | iex
#>

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

# ── Config ────────────────────────────────────────────────────────────────────
$GITHUB_USER  = "Suprabhat2810"
$REPO_NAME    = "DevCleanV1"
$EXE_NAME     = "devclean.exe"
$INSTALL_DIR  = Join-Path $env:USERPROFILE ".devclean"
$INSTALL_PATH = Join-Path $INSTALL_DIR $EXE_NAME
$DOWNLOAD_URL = "https://github.com/$GITHUB_USER/$REPO_NAME/releases/latest/download/$EXE_NAME"

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║        DevClean Installer              ║" -ForegroundColor Cyan
Write-Host "  ║   Developed by Suprabhat Chowhan       ║" -ForegroundColor Cyan
Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── Pre-flight checks ─────────────────────────────────────────────────────────
$psVer = $PSVersionTable.PSVersion
if ($psVer.Major -lt 5) {
    Write-Host "  ✗  PowerShell 5+ required. You have: $($psVer.Major).$($psVer.Minor)" -ForegroundColor Red
    Write-Host "     Install PowerShell 7: winget install Microsoft.PowerShell" -ForegroundColor Yellow
    exit 1
}
Write-Host "  ✓  PowerShell $($psVer.Major).$($psVer.Minor) detected" -ForegroundColor Green

if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
    Write-Host "  ✗  DevClean is Windows-only." -ForegroundColor Red
    exit 1
}
Write-Host "  ✓  Windows detected" -ForegroundColor Green

try {
    $null = Invoke-WebRequest -Uri "https://github.com" -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
    Write-Host "  ✓  Internet connection OK" -ForegroundColor Green
} catch {
    Write-Host "  ✗  Cannot reach GitHub. Check your internet connection." -ForegroundColor Red
    exit 1
}

# ── Create install directory ──────────────────────────────────────────────────
Write-Host ""
Write-Host "  Install location: $INSTALL_DIR" -ForegroundColor Gray
if (-not (Test-Path $INSTALL_DIR)) {
    New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
}

# ── Download devclean.exe ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Downloading devclean.exe from GitHub Releases..." -ForegroundColor Gray
Write-Host "  $DOWNLOAD_URL" -ForegroundColor DarkGray
Write-Host ""

try {
    Invoke-WebRequest -Uri $DOWNLOAD_URL `
                      -OutFile $INSTALL_PATH `
                      -UseBasicParsing `
                      -ErrorAction Stop
} catch {
    Write-Host "  ✗  Download failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Possible reasons:" -ForegroundColor Yellow
    Write-Host "  · No release published yet" -ForegroundColor Gray
    Write-Host "  · Network or firewall blocking GitHub" -ForegroundColor Gray
    exit 1
}

# ── Verify download ───────────────────────────────────────────────────────────
if (-not (Test-Path $INSTALL_PATH)) {
    Write-Host "  ✗  File missing after download." -ForegroundColor Red
    exit 1
}

$exeSize = (Get-Item $INSTALL_PATH).Length
Write-Host "  ✓  Downloaded devclean.exe ($('{0:N1}' -f ($exeSize/1MB)) MB)" -ForegroundColor Green

# ── Add to PATH ───────────────────────────────────────────────────────────────
$currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*$INSTALL_DIR*") {
    [System.Environment]::SetEnvironmentVariable("PATH", "$currentPath;$INSTALL_DIR", "User")
    Write-Host "  ✓  Added to PATH" -ForegroundColor Green
} else {
    Write-Host "  ●  Already in PATH" -ForegroundColor DarkGray
}
$env:PATH = "$env:PATH;$INSTALL_DIR"

# ── Unblock exe (Windows SmartScreen) ────────────────────────────────────────
try { Unblock-File -Path $INSTALL_PATH -ErrorAction SilentlyContinue } catch {}
Write-Host "  ✓  Unblocked exe (SmartScreen)" -ForegroundColor Green

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ╔════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║    DevClean installed successfully!    ║" -ForegroundColor Green
Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Try it now:" -ForegroundColor Gray
Write-Host "    devclean help" -ForegroundColor Cyan
Write-Host "    devclean scan" -ForegroundColor Cyan
Write-Host ""
Write-Host "  To uninstall:" -ForegroundColor DarkGray
Write-Host "    Remove-Item '$INSTALL_DIR' -Recurse -Force" -ForegroundColor DarkGray
Write-Host ""
