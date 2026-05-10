#!/usr/bin/env pwsh
<#
.SYNOPSIS
    DevClean — One-line remote installer.
    Paste this in PowerShell to install DevClean from GitHub.

USAGE (paste in any PowerShell terminal):
    irm https://raw.githubusercontent.com/suprabhat/devclean/main/get.ps1 | iex

WHAT THIS DOES:
    1. Checks PowerShell 7+ is available
    2. Downloads DevClean from GitHub
    3. Installs to ~/.devclean
    4. Adds devclean to your user PATH
    5. Creates a devclean.cmd shim so it works from cmd.exe too
#>

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

# ── Config ────────────────────────────────────────────────────────────────────
$REPO_OWNER  = "suprabhat"
$REPO_NAME   = "devclean"
$BRANCH      = "main"
$INSTALL_DIR = Join-Path $env:USERPROFILE ".devclean"
$GITHUB_BASE = "https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH"

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║     DevClean — Remote Installer        ║" -ForegroundColor Cyan
Write-Host "  ║     Developed by Suprabhat Chowhan     ║" -ForegroundColor Cyan
Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── Pre-flight: Check PowerShell version ─────────────────────────────────────
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -lt 7) {
    Write-Host "  ✗  PowerShell 7+ is required." -ForegroundColor Red
    Write-Host "     You have: PowerShell $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Install PowerShell 7 with:" -ForegroundColor Yellow
    Write-Host "  winget install Microsoft.PowerShell" -ForegroundColor Cyan
    Write-Host "  Then re-run this installer in a 'pwsh' terminal." -ForegroundColor Gray
    Write-Host ""
    exit 1
}
Write-Host "  ✓  PowerShell $($psVersion.Major).$($psVersion.Minor) detected" -ForegroundColor Green

# ── Pre-flight: Check internet ────────────────────────────────────────────────
try {
    $null = Invoke-WebRequest -Uri "https://github.com" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  ✓  Internet connection OK" -ForegroundColor Green
} catch {
    Write-Host "  ✗  No internet connection. Cannot reach GitHub." -ForegroundColor Red
    exit 1
}

# ── Full file list to download ────────────────────────────────────────────────
$files = @(
    "devclean.ps1",
    "devclean.psd1",
    "src/ui/Show-Banner.ps1",
    "src/ui/Show-Progress.ps1",
    "src/ui/Show-ScanTable.ps1",
    "src/ui/Show-EducationalNote.ps1",
    "src/ui/Show-RiskLabel.ps1",
    "src/scanner/Scan-Chrome.ps1",
    "src/scanner/Scan-Browsers.ps1",
    "src/scanner/Scan-NodeModules.ps1",
    "src/scanner/Scan-Gradle.ps1",
    "src/scanner/Scan-AndroidSdk.ps1",
    "src/scanner/Scan-WindowsTemp.ps1",
    "src/analyzer/Analyze-NodeModules.ps1",
    "src/analyzer/Analyze-AndroidSdk.ps1",
    "src/cleanup/Invoke-Cleanup.ps1",
    "src/cleanup/Send-ToRecycleBin.ps1",
    "src/logs/Write-CleanupLog.ps1",
    "src/utils/Get-FolderSize.ps1",
    "src/utils/Format-FileSize.ps1"
)

# ── Create install directory tree ─────────────────────────────────────────────
Write-Host ""
Write-Host "  Installing to: $INSTALL_DIR" -ForegroundColor Gray
Write-Host ""

$subDirs = @("src\ui","src\scanner","src\analyzer","src\cleanup","src\logs","src\utils","lib")
foreach ($d in $subDirs) {
    $fullD = Join-Path $INSTALL_DIR $d
    if (-not (Test-Path $fullD)) { New-Item -ItemType Directory -Path $fullD -Force | Out-Null }
}

# ── Download each file ────────────────────────────────────────────────────────
$downloaded = 0
$failed     = 0

foreach ($file in $files) {
    $url      = "$GITHUB_BASE/$file"
    $destFile = $file -replace "/", "\"
    $destPath = Join-Path $INSTALL_DIR $destFile

    try {
        Invoke-WebRequest -Uri $url -OutFile $destPath -UseBasicParsing -ErrorAction Stop
        $downloaded++
        $pct = [math]::Round($downloaded / $files.Count * 100)
        $bar = ("█" * [math]::Round(30 * $pct / 100)) + ("░" * (30 - [math]::Round(30 * $pct / 100)))
        Write-Host "`r  [$bar] $pct%  $file" -NoNewline -ForegroundColor Cyan
    } catch {
        $failed++
        Write-Host "`n  ✗  Failed to download: $file" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host ""

if ($failed -gt 0) {
    Write-Host "  ⚠  $failed file(s) failed to download." -ForegroundColor Yellow
    Write-Host "     Try again or check your connection." -ForegroundColor Gray
}

Write-Host "  ✓  Downloaded $downloaded/$($files.Count) files" -ForegroundColor Green

# ── Create devclean.cmd shim ──────────────────────────────────────────────────
$cmdPath    = Join-Path $INSTALL_DIR "devclean.cmd"
$cmdContent = "@echo off`r`npwsh -NoLogo -NonInteractive -File `"%~dp0devclean.ps1`" %*`r`n"
[System.IO.File]::WriteAllText($cmdPath, $cmdContent, [System.Text.Encoding]::ASCII)
Write-Host "  ✓  Created devclean.cmd shim" -ForegroundColor Green

# ── Create devclean.sh shim for git bash / WSL users ─────────────────────────
$shPath    = Join-Path $INSTALL_DIR "devclean.sh"
$shContent = "#!/bin/sh`npwsh -NoLogo -NonInteractive -File `"$(($INSTALL_DIR -replace '\\','/'))/devclean.ps1`" `"`$@`"`n"
[System.IO.File]::WriteAllText($shPath, $shContent, [System.Text.Encoding]::UTF8)
Write-Host "  ✓  Created devclean.sh shim (for Git Bash)" -ForegroundColor Green

# ── Add to user PATH ──────────────────────────────────────────────────────────
$currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")

if ($currentPath -notlike "*$INSTALL_DIR*") {
    [System.Environment]::SetEnvironmentVariable("PATH", "$currentPath;$INSTALL_DIR", "User")
    Write-Host "  ✓  Added to PATH: $INSTALL_DIR" -ForegroundColor Green
} else {
    Write-Host "  ●  Already in PATH" -ForegroundColor DarkGray
}

# Also refresh the current session's PATH so it works immediately
$env:PATH = "$env:PATH;$INSTALL_DIR"

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ╔════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║     DevClean installed successfully!   ║" -ForegroundColor Green
Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  You can run DevClean RIGHT NOW in this terminal:" -ForegroundColor Gray
Write-Host ""
Write-Host "    devclean help" -ForegroundColor Cyan
Write-Host "    devclean scan" -ForegroundColor Cyan
Write-Host ""
Write-Host "  New terminals will also have 'devclean' available." -ForegroundColor Gray
Write-Host ""
Write-Host "  To uninstall:" -ForegroundColor DarkGray
Write-Host "    Remove-Item '$INSTALL_DIR' -Recurse -Force" -ForegroundColor DarkGray
Write-Host ""
