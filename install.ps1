#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    DevClean installer — adds 'devclean' as a global command.
#>

param([switch]$Uninstall)

$installDir  = Join-Path $env:USERPROFILE ".devclean"
$scriptSrc   = Join-Path $PSScriptRoot "devclean.ps1"
$wrapperPath = Join-Path $installDir "devclean.cmd"
$ps1Target   = Join-Path $installDir "devclean.ps1"

function Add-ToUserPath {
    param([string]$Dir)
    $current = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($current -notlike "*$Dir*") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$current;$Dir", "User")
        Write-Host "  ✓ Added $Dir to PATH" -ForegroundColor Green
    } else {
        Write-Host "  ● $Dir already in PATH" -ForegroundColor DarkGray
    }
}

function Remove-FromUserPath {
    param([string]$Dir)
    $current = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $updated = ($current -split ";" | Where-Object { $_ -ne $Dir }) -join ";"
    [System.Environment]::SetEnvironmentVariable("PATH", $updated, "User")
    Write-Host "  ✓ Removed $Dir from PATH" -ForegroundColor Green
}

if ($Uninstall) {
    Write-Host ""
    Write-Host "  Uninstalling DevClean..." -ForegroundColor Yellow
    if (Test-Path $installDir) {
        Remove-Item $installDir -Recurse -Force
        Write-Host "  ✓ Removed $installDir" -ForegroundColor Green
    }
    Remove-FromUserPath $installDir
    Write-Host "  DevClean uninstalled." -ForegroundColor Green
    Write-Host ""
    return
}

Write-Host ""
Write-Host "  ╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║     DevClean Installer v1.0.0          ║" -ForegroundColor Cyan
Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Installing to: $installDir" -ForegroundColor Gray
Write-Host ""

# Create install dir and copy all files
if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir | Out-Null }

Copy-Item -Path $PSScriptRoot\* -Destination $installDir -Recurse -Force

# Create .cmd shim so 'devclean' works from any terminal
$cmdContent = @"
@echo off
pwsh -NoLogo -NonInteractive -File "%~dp0devclean.ps1" %*
"@
Set-Content -Path $wrapperPath -Value $cmdContent -Encoding ASCII

Add-ToUserPath $installDir

Write-Host "  ✓ DevClean installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "  Restart your terminal, then run:" -ForegroundColor Gray
Write-Host "  devclean help" -ForegroundColor Cyan
Write-Host ""
