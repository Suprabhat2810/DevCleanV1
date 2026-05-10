#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    DevClean - Developer Workstation Cleanup CLI
.DESCRIPTION
    A developer-aware workstation optimization and cleanup system.
    Safely identifies and cleans reclaimable storage from development environments.
.AUTHOR
    Suprabhat Chowhan
.VERSION
    1.0.0
#>

param(
    [Parameter(Position = 0)]
    [string]$Command = "help",

    [Parameter(Position = 1)]
    [string]$SubCommand = "",

    [switch]$DryRun,
    [switch]$Interactive,
    [switch]$Force,
    [switch]$Permanent
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Bootstrap: resolve paths ──────────────────────────────────────────────────
$Script:RootDir     = $PSScriptRoot
$Script:SrcDir      = Join-Path $RootDir "src"
$Script:LibDir      = Join-Path $RootDir "lib"
$Script:LogFile     = Join-Path $RootDir "cleanup-log.json"
$Script:Version     = "1.0.0"

# ── Dot-source all modules ────────────────────────────────────────────────────
function Import-DevCleanModules {
    $modules = @(
        "utils\Get-FolderSize.ps1",
        "utils\Format-FileSize.ps1",
        "ui\Show-Banner.ps1",
        "ui\Show-Progress.ps1",
        "ui\Show-ScanTable.ps1",
        "ui\Show-EducationalNote.ps1",
        "ui\Show-RiskLabel.ps1",
        "scanner\Scan-Chrome.ps1",
        "scanner\Scan-Browsers.ps1",
        "scanner\Scan-NodeModules.ps1",
        "scanner\Scan-Gradle.ps1",
        "scanner\Scan-AndroidSdk.ps1",
        "scanner\Scan-WindowsTemp.ps1",
        "analyzer\Analyze-NodeModules.ps1",
        "analyzer\Analyze-AndroidSdk.ps1",
        "cleanup\Send-ToRecycleBin.ps1",
        "cleanup\Invoke-Cleanup.ps1",
        "logs\Write-CleanupLog.ps1"
    )

    foreach ($mod in $modules) {
        $path = Join-Path $Script:SrcDir $mod
        if (Test-Path $path) {
            . $path
        } else {
            Write-Warning "Module not found: $path"
        }
    }
}

Import-DevCleanModules

# ── Main dispatcher ───────────────────────────────────────────────────────────
Show-Banner

switch ($Command.ToLower()) {

    "scan" {
        Invoke-Scan
    }

    "cleanup" {
        $targets = @("browser","chrome","edge","brave","firefox","gradle","node","sdk","temp")

        if ($SubCommand -and $SubCommand -in $targets) {
            # Map individual browser names to the unified "browser" target
            $mappedTarget = if ($SubCommand -in @("chrome","edge","brave","firefox")) { "browser" } else { $SubCommand }
            Invoke-CleanupTarget -Target $mappedTarget -DryRun:$DryRun -Interactive:$Interactive -Permanent:$Permanent
        }
        elseif ($DryRun) {
            Invoke-CleanupAll -DryRun
        }
        elseif ($Interactive) {
            Invoke-CleanupAll -Interactive
        }
        else {
            Invoke-CleanupAll -DryRun:$DryRun -Interactive:$Interactive -Permanent:$Permanent
        }
    }

    "analyze" {
        switch ($SubCommand.ToLower()) {
            "sdk"  { Invoke-AnalyzeSdk }
            "node" { Invoke-AnalyzeNode }
            default {
                Write-Host ""
                Write-Host "  Available analyze targets:" -ForegroundColor Yellow
                Write-Host "    devclean analyze sdk" -ForegroundColor Cyan
                Write-Host "    devclean analyze node" -ForegroundColor Cyan
            }
        }
    }

    "undo" {
        Invoke-Undo
    }

    "help" {
        Show-Help
    }

    default {
        Write-Host ""
        Write-Host "  Unknown command: '$Command'" -ForegroundColor Red
        Write-Host "  Run 'devclean help' for usage." -ForegroundColor Gray
    }
}

# ── Help text ─────────────────────────────────────────────────────────────────
function Show-Help {
    Write-Host ""
    Write-Host "  USAGE" -ForegroundColor Yellow
    Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  devclean scan                   Scan all reclaimable storage" -ForegroundColor White
    Write-Host "  devclean cleanup                Clean all safe targets" -ForegroundColor White
    Write-Host "  devclean cleanup browser        All browser caches (auto-detected)" -ForegroundColor White
    Write-Host "  devclean cleanup chrome         Chrome cache" -ForegroundColor White
    Write-Host "  devclean cleanup edge           Edge cache" -ForegroundColor White
    Write-Host "  devclean cleanup brave          Brave cache" -ForegroundColor White
    Write-Host "  devclean cleanup firefox        Firefox/LibreWolf/Waterfox/Zen" -ForegroundColor White
    Write-Host "  devclean cleanup gradle         Gradle cache only" -ForegroundColor White
    Write-Host "  devclean cleanup node           node_modules only" -ForegroundColor White
    Write-Host "  devclean cleanup sdk            Android SDK temp files" -ForegroundColor White
    Write-Host "  devclean cleanup temp           Windows temp files" -ForegroundColor White
    Write-Host "  devclean cleanup --dry-run      Preview — no deletion" -ForegroundColor White
    Write-Host "  devclean cleanup --interactive  Step-by-step guided cleanup" -ForegroundColor White
    Write-Host "  devclean analyze sdk            Analyze Android SDK usage" -ForegroundColor White
    Write-Host "  devclean analyze node           Analyze node_modules activity" -ForegroundColor White
    Write-Host "  devclean undo                   View last cleanup session" -ForegroundColor White
    Write-Host "  devclean help                   Show this help" -ForegroundColor White
    Write-Host ""
    Write-Host "  FLAGS" -ForegroundColor Yellow
    Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  --dry-run      Simulate cleanup, no files deleted" -ForegroundColor Gray
    Write-Host "  --interactive  Confirm each category before cleanup" -ForegroundColor Gray
    Write-Host "  --permanent    Permanently delete (default: Recycle Bin)" -ForegroundColor Gray
    Write-Host "  --force        Skip confirmation prompts" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Version $Script:Version  |  github.com/suprabhat/devclean" -ForegroundColor DarkGray
    Write-Host ""
}
