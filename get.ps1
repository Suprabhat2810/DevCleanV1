#!/usr/bin/env pwsh
<#
.SYNOPSIS
<<<<<<< HEAD
    DevClean - One-line installer from GitHub Releases.
USAGE:
=======
    DevClean — One-line installer from GitHub Releases.
    Downloads the compiled devclean.exe — no source code exposed.

USAGE (paste in any PowerShell 7 terminal):
>>>>>>> 0b13b07de4513f2de52a93fe56c64454573040f3
    irm https://github.com/Suprabhat2810/DevCleanV1/releases/latest/download/get.ps1 | iex
#>

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

# Force UTF-8 so box characters display correctly on PS5.1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ── Config ────────────────────────────────────────────────────────────────────
$GITHUB_USER  = "Suprabhat2810"
$REPO_NAME    = "DevCleanV1"
$EXE_NAME     = "devclean.exe"
$INSTALL_DIR  = Join-Path $env:USERPROFILE ".devclean"
$INSTALL_PATH = Join-Path $INSTALL_DIR $EXE_NAME
$DOWNLOAD_URL = "https://github.com/$GITHUB_USER/$REPO_NAME/releases/latest/download/$EXE_NAME"

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Host ""
<<<<<<< HEAD
Write-Host "  +----------------------------------------+" -ForegroundColor Cyan
Write-Host "  |        DevClean Installer              |" -ForegroundColor Cyan
Write-Host "  |   Developed by Suprabhat Chowhan       |" -ForegroundColor Cyan
Write-Host "  +----------------------------------------+" -ForegroundColor Cyan
Write-Host ""

# ── Pre-flight: warn PS5.1 users ──────────────────────────────────────────────
$psVer = $PSVersionTable.PSVersion
Write-Host "  [CHECK] PowerShell $($psVer.Major).$($psVer.Minor) detected" -ForegroundColor Cyan

if ($psVer.Major -lt 7) {
    Write-Host ""
    Write-Host "  [WARNING] You are using PowerShell $($psVer.Major).$($psVer.Minor)" -ForegroundColor Yellow
    Write-Host "  DevClean works best on PowerShell 7+." -ForegroundColor Yellow
    Write-Host "  Install it for the best experience:" -ForegroundColor Yellow
    Write-Host "    winget install Microsoft.PowerShell" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Continuing install on PS $($psVer.Major).$($psVer.Minor)..." -ForegroundColor Gray
    Write-Host ""
}

# ── Windows check ─────────────────────────────────────────────────────────────
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    Write-Host "  [ERROR] DevClean is Windows-only." -ForegroundColor Red
    exit 1
}
Write-Host "  [CHECK] Windows detected" -ForegroundColor Cyan

# ── Internet check ────────────────────────────────────────────────────────────
try {
    $null = Invoke-WebRequest -Uri "https://github.com" -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
    Write-Host "  [CHECK] Internet connection OK" -ForegroundColor Cyan
} catch {
    Write-Host "  [ERROR] Cannot reach GitHub. Check your internet connection." -ForegroundColor Red
=======
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
>>>>>>> 0b13b07de4513f2de52a93fe56c64454573040f3
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

<<<<<<< HEAD
# Use TLS 1.2 (required for PS5.1 to talk to GitHub)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

=======
>>>>>>> 0b13b07de4513f2de52a93fe56c64454573040f3
try {
    Invoke-WebRequest -Uri $DOWNLOAD_URL `
                      -OutFile $INSTALL_PATH `
                      -UseBasicParsing `
                      -ErrorAction Stop
} catch {
<<<<<<< HEAD
    Write-Host "  [ERROR] Download failed:" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Possible reasons:" -ForegroundColor Yellow
    Write-Host "  - No release published yet at the URL above" -ForegroundColor Gray
    Write-Host "  - Network or firewall blocking GitHub downloads" -ForegroundColor Gray
    Write-Host "  - Repo is still private" -ForegroundColor Gray
=======
    Write-Host "  ✗  Download failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Possible reasons:" -ForegroundColor Yellow
    Write-Host "  · No release published yet" -ForegroundColor Gray
    Write-Host "  · Network or firewall blocking GitHub" -ForegroundColor Gray
>>>>>>> 0b13b07de4513f2de52a93fe56c64454573040f3
    exit 1
}

# ── Verify download ───────────────────────────────────────────────────────────
if (-not (Test-Path $INSTALL_PATH)) {
<<<<<<< HEAD
    Write-Host "  [ERROR] File missing after download." -ForegroundColor Red
=======
    Write-Host "  ✗  File missing after download." -ForegroundColor Red
>>>>>>> 0b13b07de4513f2de52a93fe56c64454573040f3
    exit 1
}

$exeSize = (Get-Item $INSTALL_PATH).Length
<<<<<<< HEAD
if ($exeSize -lt 50000) {
    Write-Host "  [ERROR] devclean.exe is too small ($exeSize bytes)." -ForegroundColor Red
    Write-Host "  The exe was not compiled correctly. Please recompile with ps2exe." -ForegroundColor Yellow
    Remove-Item $INSTALL_PATH -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "  [OK] Downloaded devclean.exe ($('{0:N1}' -f ($exeSize/1MB)) MB)" -ForegroundColor Green

=======
Write-Host "  ✓  Downloaded devclean.exe ($('{0:N1}' -f ($exeSize/1MB)) MB)" -ForegroundColor Green

>>>>>>> 0b13b07de4513f2de52a93fe56c64454573040f3
# ── Add to PATH ───────────────────────────────────────────────────────────────
$currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*$INSTALL_DIR*") {
    [System.Environment]::SetEnvironmentVariable("PATH", "$currentPath;$INSTALL_DIR", "User")
<<<<<<< HEAD
    Write-Host "  [OK] Added to PATH" -ForegroundColor Green
=======
    Write-Host "  ✓  Added to PATH" -ForegroundColor Green
>>>>>>> 0b13b07de4513f2de52a93fe56c64454573040f3
} else {
    Write-Host "  [OK] Already in PATH" -ForegroundColor DarkGray
}
<<<<<<< HEAD
# Refresh current session immediately
$env:PATH = "$env:PATH;$INSTALL_DIR"

# ── Unblock exe ───────────────────────────────────────────────────────────────
try { Unblock-File -Path $INSTALL_PATH -ErrorAction SilentlyContinue } catch {}
Write-Host "  [OK] Unblocked exe (SmartScreen)" -ForegroundColor Green

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  +----------------------------------------+" -ForegroundColor Green
Write-Host "  |   DevClean installed successfully!     |" -ForegroundColor Green
Write-Host "  +----------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  Try it right now in THIS terminal:" -ForegroundColor Gray
Write-Host ""
Write-Host "    devclean help" -ForegroundColor Cyan
Write-Host "    devclean scan" -ForegroundColor Cyan
Write-Host ""
if ($psVer.Major -lt 7) {
    Write-Host "  NOTE: For best results open a 'pwsh' terminal (PowerShell 7)" -ForegroundColor Yellow
    Write-Host "        and run devclean from there." -ForegroundColor Yellow
    Write-Host ""
}
=======
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
>>>>>>> 0b13b07de4513f2de52a93fe56c64454573040f3
Write-Host "  To uninstall:" -ForegroundColor DarkGray
Write-Host "    Remove-Item '$INSTALL_DIR' -Recurse -Force" -ForegroundColor DarkGray
Write-Host ""
