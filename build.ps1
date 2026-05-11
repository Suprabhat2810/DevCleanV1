#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Merges all DevClean modules into one file and compiles to devclean.exe
    Run from inside your DevClean folder:
        cd C:\path\to\DevClean
        .\build.ps1
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "  DevClean Build Script v1.0" -ForegroundColor Cyan
Write-Host "  ─────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

# ── Check we are in the right folder ─────────────────────────────────────────
if (-not (Test-Path "devclean.ps1")) {
    Write-Host "  [ERROR] Run this from inside your DevClean folder!" -ForegroundColor Red
    Write-Host "  cd C:\path\to\DevClean" -ForegroundColor Yellow
    Write-Host "  .\build.ps1" -ForegroundColor Yellow
    exit 1
}

# ── Install ps2exe if missing ─────────────────────────────────────────────────
if (-not (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing ps2exe..." -ForegroundColor Yellow
    Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber
    Import-Module ps2exe -Force
    Write-Host "  [OK] ps2exe installed" -ForegroundColor Green
}

# ── All source files in dependency order ─────────────────────────────────────
$sourceFiles = @(
    "src\utils\Get-FolderSize.ps1",
    "src\utils\Format-FileSize.ps1",
    "src\ui\Show-Banner.ps1",
    "src\ui\Show-Progress.ps1",
    "src\ui\Show-ScanTable.ps1",
    "src\ui\Show-EducationalNote.ps1",
    "src\ui\Show-RiskLabel.ps1",
    "src\scanner\Scan-Chrome.ps1",
    "src\scanner\Scan-Browsers.ps1",
    "src\scanner\Scan-NodeModules.ps1",
    "src\scanner\Scan-Gradle.ps1",
    "src\scanner\Scan-AndroidSdk.ps1",
    "src\scanner\Scan-WindowsTemp.ps1",
    "src\analyzer\Analyze-NodeModules.ps1",
    "src\analyzer\Analyze-AndroidSdk.ps1",
    "src\cleanup\Send-ToRecycleBin.ps1",
    "src\cleanup\Invoke-Cleanup.ps1",
    "src\logs\Write-CleanupLog.ps1"
)

# ── Verify all files exist ────────────────────────────────────────────────────
$missing = $false
foreach ($f in $sourceFiles) {
    if (-not (Test-Path $f)) {
        Write-Host "  [MISSING] $f" -ForegroundColor Red
        $missing = $true
    }
}
if ($missing) { Write-Host ""; Write-Host "  Fix missing files then re-run." -ForegroundColor Red; exit 1 }

Write-Host "  [OK] All source files found" -ForegroundColor Green

# ── Build the merged script ───────────────────────────────────────────────────
Write-Host "  Merging $($sourceFiles.Count) files..." -ForegroundColor Gray

$lines = [System.Collections.Generic.List[string]]::new()

# Header + runtime variables
$lines.Add("#Requires -Version 5.1")
$lines.Add('$Script:Version = "1.0.0"')
$lines.Add('$Script:LogFile = Join-Path $env:USERPROFILE ".devclean\cleanup-log.json"')
$lines.Add("")

# Inline all modules
foreach ($file in $sourceFiles) {
    $content = Get-Content $file -Raw -Encoding UTF8
    # Strip any #Requires lines from sub-modules to avoid conflicts
    $content = $content -replace "(?m)^#Requires.*$", ""
    $lines.Add("# === $file ===")
    $lines.Add($content.Trim())
    $lines.Add("")
}

# ── Add the main entry point logic ───────────────────────────────────────────
# Write it inline rather than importing devclean.ps1 (avoids Import-DevCleanModules)
$lines.Add("# === MAIN ENTRY POINT ===")
$lines.Add(@'
param(
    [Parameter(Position = 0)] [string]$Command = "help",
    [Parameter(Position = 1)] [string]$SubCommand = "",
    [switch]$DryRun,
    [switch]$Interactive,
    [switch]$Force,
    [switch]$Permanent
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Show-Banner

switch ($Command.ToLower()) {
    "scan" {
        Invoke-Scan
    }
    "cleanup" {
        $targets = @("browser","chrome","edge","brave","firefox","gradle","node","sdk","temp")
        if ($SubCommand -and $SubCommand -in $targets) {
            $mappedTarget = if ($SubCommand -in @("chrome","edge","brave","firefox")) { "browser" } else { $SubCommand }
            Invoke-CleanupTarget -Target $mappedTarget -DryRun:$DryRun -Interactive:$Interactive -Permanent:$Permanent
        } elseif ($DryRun) {
            Invoke-CleanupAll -DryRun
        } elseif ($Interactive) {
            Invoke-CleanupAll -Interactive
        } else {
            Invoke-CleanupAll -DryRun:$DryRun -Interactive:$Interactive -Permanent:$Permanent
        }
    }
    "analyze" {
        switch ($SubCommand.ToLower()) {
            "sdk"  { Invoke-AnalyzeSdk }
            "node" { Invoke-AnalyzeNode }
            default {
                Write-Host ""
                Write-Host "  Available: devclean analyze sdk | devclean analyze node" -ForegroundColor Yellow
            }
        }
    }
    "undo" { Invoke-Undo }
    "help" {
        Write-Host ""
        Write-Host "  USAGE" -ForegroundColor Yellow
        Write-Host "  ──────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  devclean scan                    Scan all reclaimable storage" -ForegroundColor White
        Write-Host "  devclean cleanup                 Clean all safe targets" -ForegroundColor White
        Write-Host "  devclean cleanup browser         All browser caches" -ForegroundColor White
        Write-Host "  devclean cleanup chrome          Chrome cache" -ForegroundColor White
        Write-Host "  devclean cleanup edge            Edge cache" -ForegroundColor White
        Write-Host "  devclean cleanup brave           Brave cache" -ForegroundColor White
        Write-Host "  devclean cleanup firefox         Firefox/LibreWolf/Waterfox/Zen" -ForegroundColor White
        Write-Host "  devclean cleanup gradle          Gradle cache" -ForegroundColor White
        Write-Host "  devclean cleanup node            node_modules" -ForegroundColor White
        Write-Host "  devclean cleanup sdk             Android SDK temp files" -ForegroundColor White
        Write-Host "  devclean cleanup temp            Windows temp files" -ForegroundColor White
        Write-Host "  devclean cleanup --dry-run       Preview - no deletion" -ForegroundColor White
        Write-Host "  devclean cleanup --interactive   Step-by-step guided cleanup" -ForegroundColor White
        Write-Host "  devclean analyze sdk             Android SDK dependency analysis" -ForegroundColor White
        Write-Host "  devclean analyze node            node_modules activity analysis" -ForegroundColor White
        Write-Host "  devclean undo                    View last cleanup session" -ForegroundColor White
        Write-Host "  devclean help                    Show this help" -ForegroundColor White
        Write-Host ""
        Write-Host "  FLAGS" -ForegroundColor Yellow
        Write-Host "  ──────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  --dry-run      Simulate cleanup, no files deleted" -ForegroundColor Gray
        Write-Host "  --interactive  Confirm each category before cleanup" -ForegroundColor Gray
        Write-Host "  --permanent    Permanently delete (default: Recycle Bin)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Version 1.0.0  |  github.com/Suprabhat2810/DevCleanV1" -ForegroundColor DarkGray
        Write-Host ""
    }
    default {
        Write-Host ""
        Write-Host "  Unknown command: $Command" -ForegroundColor Red
        Write-Host "  Run devclean help for usage." -ForegroundColor Gray
    }
}
'@)

# Write merged file as UTF8 without BOM (ps2exe works best with this)
$mergedPath = Join-Path (Get-Location) "devclean-merged.ps1"
$utf8NoBom  = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines($mergedPath, $lines, $utf8NoBom)

$mergedKB = [math]::Round((Get-Item $mergedPath).Length / 1KB, 1)
Write-Host "  [OK] Merged file: devclean-merged.ps1 ($mergedKB KB)" -ForegroundColor Green

# ── Compile ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Compiling to devclean.exe (30-90 seconds)..." -ForegroundColor Gray
Write-Host ""

$exePath = Join-Path (Get-Location) "devclean.exe"

try {
    Invoke-ps2exe `
        -InputFile   $mergedPath `
        -OutputFile  $exePath `
        -NoConsole:$false `
        -Title       "DevClean" `
        -Description "Developer Workstation Cleanup CLI" `
        -Company     "Suprabhat Chowhan" `
        -Version     "1.0.0.0"
} catch {
    Write-Host "  [ERROR] Compilation failed: $_" -ForegroundColor Red
    exit 1
}

# ── Verify ────────────────────────────────────────────────────────────────────
if (-not (Test-Path $exePath)) {
    Write-Host "  [ERROR] devclean.exe was not created." -ForegroundColor Red
    exit 1
}

$exeMB = [math]::Round((Get-Item $exePath).Length / 1MB, 1)

if ($exeMB -lt 0.5) {
    Write-Host "  [ERROR] devclean.exe is too small ($exeMB MB) - compilation failed." -ForegroundColor Red
    exit 1
}

# Cleanup temp file
Remove-Item $mergedPath -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "  +──────────────────────────────────────────+" -ForegroundColor Green
Write-Host "  |   BUILD SUCCESSFUL                       |" -ForegroundColor Green
Write-Host "  |   devclean.exe = $($exeMB) MB                    |" -ForegroundColor Green  
Write-Host "  +──────────────────────────────────────────+" -ForegroundColor Green
Write-Host ""
Write-Host "  1. Test it locally first:" -ForegroundColor Yellow
Write-Host "     .\devclean.exe help" -ForegroundColor Cyan
Write-Host "     .\devclean.exe scan" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. Upload devclean.exe to your GitHub Release:" -ForegroundColor Yellow
Write-Host "     github.com/Suprabhat2810/DevCleanV1/releases" -ForegroundColor Cyan
Write-Host ""
