function Invoke-Scan {
    <#
    .SYNOPSIS
        Runs all scanners and displays the combined scan table.
    #>

    Write-Host "  Scanning your system for reclaimable storage..." -ForegroundColor Gray
    Write-Host ""

    $allResults = @()

    $scanners = @(
        @{ Label = "Browser Caches";     Fn = { Scan-Browsers } }
        @{ Label = "node_modules";       Fn = { Scan-NodeModules } }
        @{ Label = "Gradle Cache";       Fn = { Scan-Gradle } }
        @{ Label = "Android SDK";        Fn = { Scan-AndroidSdk } }
        @{ Label = "Windows Temp Files"; Fn = { Scan-WindowsTemp } }
    )

    foreach ($s in $scanners) {
        Show-ScanProgress -Target $s.Label
        try {
            $results = & $s.Fn
            $allResults += $results
        } catch {
            Write-Verbose "Scanner failed [$($s.Label)]: $_"
        }
    }

    Show-ScanTable -Results $allResults
}

function Invoke-CleanupAll {
    param(
        [switch]$DryRun,
        [switch]$Interactive,
        [switch]$Permanent
    )

    if ($DryRun) { Show-DryRunBanner }

    Write-Host "  Scanning before cleanup..." -ForegroundColor Gray
    Write-Host ""

    $allResults = @()
    $allResults += Scan-Browsers
    $allResults += Scan-NodeModules
    $allResults += Scan-Gradle
    $allResults += Scan-AndroidSdk
    $allResults += Scan-WindowsTemp

    if (-not $allResults -or $allResults.Count -eq 0) {
        Write-Host "  Nothing to clean." -ForegroundColor Green
        return
    }

    Show-ScanTable -Results $allResults

    if ($DryRun) {
        Write-Host "  Dry run complete. No files were deleted." -ForegroundColor Yellow
        Write-Host "  Run 'devclean cleanup' to perform actual cleanup." -ForegroundColor Gray
        Write-Host ""
        return
    }

    # Group by category
    $categories = $allResults | Group-Object Category

    $startTime    = Get-Date
    $totalCleaned = 0L
    $cleanedCount = 0
    $log          = @()

    foreach ($group in $categories) {
        $category  = $group.Name
        $items     = $group.Group
        $groupSize = ($items | Measure-Object -Property SizeBytes -Sum).Sum
        $topRisk   = ($items | Sort-Object { switch ($_.RiskLevel) { "HIGH"{4}"MEDIUM"{3}"LOW"{2}"SAFE"{1} } } -Descending | Select-Object -First 1).RiskLevel

        Show-EducationalNote -Target $category

        if ($Interactive) {
            $confirm = Show-ConfirmPrompt -Category $category.ToUpper() -SizeBytes $groupSize -RiskLevel $topRisk

            if ($confirm -eq "N")  { Write-Host "  Skipped." -ForegroundColor DarkGray; continue }
            if ($confirm -eq "S")  { Write-Host "  Skipping all remaining." -ForegroundColor DarkGray; break }
        }

        Write-Host "  Cleaning $($category.ToUpper())..." -ForegroundColor Cyan
        $i = 0

        foreach ($item in $items) {
            $i++
            Show-CleanupProgress -Label $item.Name -Current $i -Total $items.Count

            $success = Send-ToRecycleBin -Path $item.Path -Permanent:$Permanent

            if ($success) {
                $totalCleaned += $item.SizeBytes
                $cleanedCount++
                $log += [PSCustomObject]@{
                    path      = $item.Path
                    name      = $item.Name
                    category  = $item.Category
                    size      = Format-FileSize $item.SizeBytes
                    sizeBytes = $item.SizeBytes
                    timestamp = (Get-Date -Format "o")
                    mode      = if ($Permanent) { "permanent" } else { "recycle-bin" }
                }
            }
        }

        Write-Host ""
        Show-Success "Cleaned $($items.Count) item(s) from $($category.ToUpper())"
        Write-Host ""
    }

    $duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
    Show-RecoverySummary -TotalBytes $totalCleaned -ItemCount $cleanedCount -Duration $duration

    if ($log.Count -gt 0) {
        Write-CleanupLog -Entries $log
    }
}

function Invoke-CleanupTarget {
    param(
        [string]$Target,
        [switch]$DryRun,
        [switch]$Interactive,
        [switch]$Permanent
    )

    if ($DryRun) { Show-DryRunBanner }

    Write-Host "  Scanning $($Target.ToUpper())..." -ForegroundColor Gray
    Write-Host ""

    $results = switch ($Target.ToLower()) {
        "browser" { Scan-Browsers }
        "chrome"  { Scan-Browsers }
        "node"    { Scan-NodeModules }
        "gradle" { Scan-Gradle }
        "sdk"    { Scan-AndroidSdk }
        "temp"   { Scan-WindowsTemp }
        default  { Write-Host "  Unknown target: $Target" -ForegroundColor Red; return }
    }

    if (-not $results -or $results.Count -eq 0) {
        Write-Host "  Nothing found for target: $Target" -ForegroundColor Green
        return
    }

    $totalSize = ($results | Measure-Object -Property SizeBytes -Sum).Sum
    Show-ScanTable -Results $results

    if ($DryRun) {
        Write-Host "  Dry run complete. No files deleted." -ForegroundColor Yellow
        return
    }

    Show-EducationalNote -Target $Target

    if (-not $Interactive) {
        Write-Host "  Proceed with cleanup? " -NoNewline -ForegroundColor White
        Write-Host "(Y/N)" -ForegroundColor DarkGray
        Write-Host "  > " -NoNewline -ForegroundColor Cyan
        $confirm = $Host.UI.ReadLine()
        if ($confirm.Trim().ToUpper() -ne "Y") {
            Write-Host "  Cancelled." -ForegroundColor DarkGray
            return
        }
    }

    $log = @()
    $i   = 0

    foreach ($item in $results) {
        $i++
        Show-CleanupProgress -Label $item.Name -Current $i -Total $results.Count

        $success = Send-ToRecycleBin -Path $item.Path -Permanent:$Permanent
        if ($success) {
            $log += [PSCustomObject]@{
                path      = $item.Path
                name      = $item.Name
                category  = $Target
                size      = Format-FileSize $item.SizeBytes
                sizeBytes = $item.SizeBytes
                timestamp = (Get-Date -Format "o")
                mode      = if ($Permanent) { "permanent" } else { "recycle-bin" }
            }
        }
    }

    Write-Host ""
    $cleaned = ($log | Measure-Object -Property sizeBytes -Sum).Sum
    Show-RecoverySummary -TotalBytes $cleaned -ItemCount $log.Count -Duration 0

    if ($log.Count -gt 0) { Write-CleanupLog -Entries $log }
}

function Invoke-Undo {
    <#
    .SYNOPSIS
        Shows the last cleanup log and offers restoration instructions.
        Note: Items sent to Recycle Bin can be restored from there directly.
    #>

    if (-not (Test-Path $Script:LogFile)) {
        Write-Host ""
        Write-Host "  No cleanup log found." -ForegroundColor Gray
        Write-Host "  Run 'devclean cleanup' first." -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    try {
        $logData = Get-Content $Script:LogFile -Raw | ConvertFrom-Json
    } catch {
        Show-Error "Could not read cleanup-log.json: $_"
        return
    }

    $entries = $logData.sessions | Select-Object -Last 1

    if (-not $entries) {
        Write-Host "  No sessions found in log." -ForegroundColor Gray
        return
    }

    Write-Host ""
    Write-Host "  LAST CLEANUP SESSION" -ForegroundColor Yellow
    Write-Host "  ══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "  Timestamp:   $($entries.timestamp)" -ForegroundColor Gray
    Write-Host "  Items:       $($entries.entries.Count)" -ForegroundColor Gray
    Write-Host "  Reclaimed:   $($entries.totalReclaimed)" -ForegroundColor Cyan
    Write-Host "  Mode:        $($entries.mode)" -ForegroundColor Gray
    Write-Host ""

    foreach ($e in $entries.entries | Select-Object -First 20) {
        Write-Host "  · $($e.name)" -NoNewline -ForegroundColor White
        Write-Host "  ($($e.size))" -ForegroundColor DarkGray
        Write-Host "    $($e.path)" -ForegroundColor DarkGray
    }

    if ($entries.mode -eq "recycle-bin") {
        Write-Host ""
        Write-Host "  ℹ  Files were moved to the Recycle Bin." -ForegroundColor Cyan
        Write-Host "     Open Recycle Bin in Explorer to restore individual items." -ForegroundColor DarkGray
    } else {
        Write-Host ""
        Show-Warning "Files were permanently deleted. Manual restoration required."
    }

    Write-Host ""
}
