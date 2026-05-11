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
Write-Host "  DevClean Build Script v1.1" -ForegroundColor Cyan
Write-Host "  -----------------------------" -ForegroundColor DarkGray
Write-Host ""

# -- Check we are in the right folder -----------------------------------------
if (-not (Test-Path "devclean.ps1")) {
    Write-Host "  [ERROR] Run this from inside your DevClean folder!" -ForegroundColor Red
    Write-Host "  cd C:\path\to\DevClean" -ForegroundColor Yellow
    exit 1
}

# -- Install ps2exe if missing -------------------------------------------------
if (-not (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing ps2exe..." -ForegroundColor Yellow
    Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber
    Import-Module ps2exe -Force
    Write-Host "  [OK] ps2exe installed" -ForegroundColor Green
}

# -- All source files in dependency order -------------------------------------
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

# -- Verify all files exist ----------------------------------------------------
$missing = $false
foreach ($f in $sourceFiles) {
    if (-not (Test-Path $f)) {
        Write-Host "  [MISSING] $f" -ForegroundColor Red
        $missing = $true
    }
}
if ($missing) {
    Write-Host ""
    Write-Host "  Fix missing files then re-run." -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] All source files found" -ForegroundColor Green

# -- Build merged script -------------------------------------------------------
# CRITICAL: param() MUST be the very first statement in a PS script.
# Structure: param() -> version vars -> all functions -> main switch logic

Write-Host "  Merging $($sourceFiles.Count) files..." -ForegroundColor Gray

$utf8NoBom  = New-Object System.Text.UTF8Encoding $false
$mergedPath = Join-Path (Get-Location) "devclean-merged.ps1"
$writer     = New-Object System.IO.StreamWriter($mergedPath, $false, $utf8NoBom)

# 1. PARAM BLOCK - must be first
$writer.WriteLine("#Requires -Version 5.1")
$writer.WriteLine("")
$writer.WriteLine("param(")
$writer.WriteLine("    [Parameter(Position = 0)] [string]`$Command = 'help',")
$writer.WriteLine("    [Parameter(Position = 1)] [string]`$SubCommand = '',")
$writer.WriteLine("    [switch]`$DryRun,")
$writer.WriteLine("    [switch]`$Interactive,")
$writer.WriteLine("    [switch]`$Force,")
$writer.WriteLine("    [switch]`$Permanent")
$writer.WriteLine(")")
$writer.WriteLine("")

# 2. RUNTIME VARIABLES
$writer.WriteLine('[Console]::OutputEncoding = [System.Text.Encoding]::UTF8')
$writer.WriteLine('$OutputEncoding = [System.Text.Encoding]::UTF8')
$writer.WriteLine('$Script:Version = "1.0.0"')
$writer.WriteLine('$Script:LogFile = Join-Path $env:USERPROFILE ".devclean\cleanup-log.json"')
$writer.WriteLine("")

# 3. ALL FUNCTION MODULES
foreach ($file in $sourceFiles) {
    $content = Get-Content $file -Raw -Encoding UTF8
    # Strip #Requires lines from sub-modules
    $content = $content -replace "(?m)^#Requires[^\r\n]*[\r\n]*", ""
    # Strip any param() blocks that may exist in sub-files
    $content = $content -replace "(?ms)^param\s*\(.*?\)\s*\n", ""
    $writer.WriteLine("# === $file ===")
    $writer.WriteLine($content.Trim())
    $writer.WriteLine("")
}

# 4. MAIN ENTRY SWITCH - at the bottom, after all functions are defined
$writer.WriteLine("# === MAIN ENTRY POINT ===")
$writer.WriteLine("Show-Banner")
$writer.WriteLine("")
$writer.WriteLine('switch ($Command.ToLower()) {')
$writer.WriteLine('    "scan" {')
$writer.WriteLine('        Invoke-Scan')
$writer.WriteLine('    }')
$writer.WriteLine('    "cleanup" {')
$writer.WriteLine('        $targets = @("browser","chrome","edge","brave","firefox","gradle","node","sdk","temp")')
$writer.WriteLine('        if ($SubCommand -and $SubCommand -in $targets) {')
$writer.WriteLine('            $mappedTarget = if ($SubCommand -in @("chrome","edge","brave","firefox")) { "browser" } else { $SubCommand }')
$writer.WriteLine('            Invoke-CleanupTarget -Target $mappedTarget -DryRun:$DryRun -Interactive:$Interactive -Permanent:$Permanent')
$writer.WriteLine('        } elseif ($DryRun) {')
$writer.WriteLine('            Invoke-CleanupAll -DryRun')
$writer.WriteLine('        } elseif ($Interactive) {')
$writer.WriteLine('            Invoke-CleanupAll -Interactive')
$writer.WriteLine('        } else {')
$writer.WriteLine('            Invoke-CleanupAll -DryRun:$DryRun -Interactive:$Interactive -Permanent:$Permanent')
$writer.WriteLine('        }')
$writer.WriteLine('    }')
$writer.WriteLine('    "analyze" {')
$writer.WriteLine('        switch ($SubCommand.ToLower()) {')
$writer.WriteLine('            "sdk"  { Invoke-AnalyzeSdk }')
$writer.WriteLine('            "node" { Invoke-AnalyzeNode }')
$writer.WriteLine('            default {')
$writer.WriteLine('                Write-Host ""')
$writer.WriteLine('                Write-Host "  Available: devclean analyze sdk | devclean analyze node" -ForegroundColor Yellow')
$writer.WriteLine('            }')
$writer.WriteLine('        }')
$writer.WriteLine('    }')
$writer.WriteLine('    "undo" { Invoke-Undo }')
$writer.WriteLine('    "help" {')
$writer.WriteLine('        Write-Host ""')
$writer.WriteLine('        Write-Host "  USAGE" -ForegroundColor Yellow')
$writer.WriteLine('        Write-Host "  --------------------------------------------------" -ForegroundColor DarkGray')
$writer.WriteLine('        Write-Host "  devclean scan                    Scan all reclaimable storage" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean cleanup                 Clean all safe targets" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean cleanup browser         All browser caches" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean cleanup chrome          Chrome cache" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean cleanup edge            Edge cache" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean cleanup brave           Brave cache" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean cleanup firefox         Firefox/LibreWolf/Waterfox/Zen" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean cleanup gradle          Gradle cache" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean cleanup node            node_modules" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean cleanup sdk             Android SDK temp files" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean cleanup temp            Windows temp files" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean cleanup --dry-run       Preview - no deletion" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean cleanup --interactive   Step-by-step guided cleanup" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean analyze sdk             Android SDK dependency analysis" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean analyze node            node_modules activity analysis" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean undo                    View last cleanup session" -ForegroundColor White')
$writer.WriteLine('        Write-Host "  devclean help                    Show this help" -ForegroundColor White')
$writer.WriteLine('        Write-Host ""')
$writer.WriteLine('        Write-Host "  FLAGS" -ForegroundColor Yellow')
$writer.WriteLine('        Write-Host "  --------------------------------------------------" -ForegroundColor DarkGray')
$writer.WriteLine('        Write-Host "  --dry-run      Simulate cleanup, no files deleted" -ForegroundColor Gray')
$writer.WriteLine('        Write-Host "  --interactive  Confirm each category before cleanup" -ForegroundColor Gray')
$writer.WriteLine('        Write-Host "  --permanent    Permanently delete (default: Recycle Bin)" -ForegroundColor Gray')
$writer.WriteLine('        Write-Host ""')
$writer.WriteLine('        Write-Host "  Version 1.0.0  |  github.com/Suprabhat2810/DevCleanV1" -ForegroundColor DarkGray')
$writer.WriteLine('        Write-Host ""')
$writer.WriteLine('    }')
$writer.WriteLine('    default {')
$writer.WriteLine('        Write-Host ""')
$writer.WriteLine('        Write-Host "  Unknown command: $Command" -ForegroundColor Red')
$writer.WriteLine('        Write-Host "  Run devclean help for usage." -ForegroundColor Gray')
$writer.WriteLine('    }')
$writer.WriteLine('}')

$writer.Flush()
$writer.Close()

$mergedKB = [math]::Round((Get-Item $mergedPath).Length / 1KB, 1)
Write-Host "  [OK] Merged: devclean-merged.ps1 ($mergedKB KB)" -ForegroundColor Green

# -- Syntax check --------------------------------------------------------------
Write-Host "  Checking syntax..." -ForegroundColor Gray
$parseErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($mergedPath, [ref]$null, [ref]$parseErrors)
if ($parseErrors -and $parseErrors.Count -gt 0) {
    Write-Host "  [ERROR] Syntax errors in merged file:" -ForegroundColor Red
    foreach ($e in $parseErrors) {
        Write-Host "  Line $($e.Extent.StartLineNumber): $($e.Message)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "  Merged file kept at: $mergedPath" -ForegroundColor Yellow
    Write-Host "  Open it in VS Code to inspect." -ForegroundColor Yellow
    exit 1
}
Write-Host "  [OK] Syntax check passed" -ForegroundColor Green

# -- Compile -------------------------------------------------------------------
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

# -- Verify --------------------------------------------------------------------
if (-not (Test-Path $exePath)) {
    Write-Host "  [ERROR] devclean.exe was not created." -ForegroundColor Red
    exit 1
}

$exeMB = [math]::Round((Get-Item $exePath).Length / 1MB, 2)
if ($exeMB -lt 0.05) {
    Write-Host "  [ERROR] devclean.exe too small ($exeMB MB) - compilation failed." -ForegroundColor Red
    exit 1
}
if ($exeMB -lt 0.5) {
    Write-Host "  [WARN] devclean.exe is only $exeMB MB - may not contain all modules." -ForegroundColor Yellow
}

# Cleanup temp merged file
Remove-Item $mergedPath -Force -ErrorAction SilentlyContinue

# -- Smoke test ----------------------------------------------------------------
Write-Host ""
Write-Host "  Running smoke test: .\devclean.exe help" -ForegroundColor Gray
try {
    $proc = Start-Process -FilePath $exePath -ArgumentList "help" -PassThru -NoNewWindow
    $exited = $proc.WaitForExit(10000)  # 10 second timeout
    if (-not $exited) {
        $proc.Kill()
        Write-Host "  [WARN] Smoke test timed out (exe may work fine in a real terminal)" -ForegroundColor Yellow
    } elseif ($proc.ExitCode -ne 0) {
        Write-Host "  [WARN] Smoke test exited with code $($proc.ExitCode)" -ForegroundColor Yellow
    } else {
        Write-Host "  [OK] Smoke test passed" -ForegroundColor Green
    }
} catch {
    Write-Host "  [WARN] Smoke test failed: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host "  |   BUILD SUCCESSFUL                       |" -ForegroundColor Green
Write-Host "  |   devclean.exe = $($exeMB) MB             |" -ForegroundColor Green
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  1. Test locally:" -ForegroundColor Yellow
Write-Host "     .\devclean.exe help" -ForegroundColor Cyan
Write-Host "     .\devclean.exe scan" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. Upload devclean.exe to GitHub Release:" -ForegroundColor Yellow
Write-Host "     github.com/Suprabhat2810/DevCleanV1/releases" -ForegroundColor Cyan
Write-Host ""
