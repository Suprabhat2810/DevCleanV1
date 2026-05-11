function Get-FolderSize {
    <#
    .SYNOPSIS
        Fast folder size calculation using .NET enumeration.
        Significantly faster than Get-ChildItem -Recurse for large trees.
    #>
    param(
        [string]$Path,
        [switch]$IncludeHidden
    )

    if (-not (Test-Path $Path)) { return 0 }

    try {
        $totalSize = 0L
        $opts = [System.IO.EnumerationOptions]::new()
        $opts.RecurseSubdirectories = $true
        $opts.IgnoreInaccessible    = $true
        $opts.AttributesToSkip      = if ($IncludeHidden) { [System.IO.FileAttributes]::None } `
                                      else { [System.IO.FileAttributes]::System }

        foreach ($file in [System.IO.Directory]::EnumerateFiles($Path, "*", $opts)) {
            try {
                $totalSize += (New-Object System.IO.FileInfo($file)).Length
            } catch { <# skip locked files #> }
        }

        return $totalSize
    } catch {
        return 0L
    }
}

function Get-FolderItemCount {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return 0 }

    try {
        $opts = [System.IO.EnumerationOptions]::new()
        $opts.RecurseSubdirectories = $true
        $opts.IgnoreInaccessible    = $true

        return ([System.IO.Directory]::EnumerateFiles($Path, "*", $opts) | Measure-Object).Count
    } catch {
        return 0
    }
}

function Get-SubFolderSizes {
    <#
    .SYNOPSIS
        Returns a list of immediate subfolders with their sizes.
        Used by analyzers to find the largest children.
    #>
    param([string]$Path)

    $results = @()

    if (-not (Test-Path $Path)) { return $results }

    foreach ($dir in [System.IO.Directory]::GetDirectories($Path)) {
        $size = Get-FolderSize -Path $dir
        $results += [PSCustomObject]@{
            Path      = $dir
            Name      = Split-Path $dir -Leaf
            SizeBytes = $size
        }
    }

    return $results | Sort-Object SizeBytes -Descending
}


function Format-FileSize {
    param([long]$Bytes)

    if     ($Bytes -ge 1TB) { return "{0:N1} TB" -f ($Bytes / 1TB) }
    elseif ($Bytes -ge 1GB) { return "{0:N1} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { return "{0:N1} KB" -f ($Bytes / 1KB) }
    else                    { return "$Bytes B" }
}

function Format-Age {
    param([datetime]$LastModified)

    $age = (Get-Date) - $LastModified

    if     ($age.Days -ge 365) { return "{0} year(s) ago"  -f [math]::Floor($age.Days / 365) }
    elseif ($age.Days -ge 30)  { return "{0} month(s) ago" -f [math]::Floor($age.Days / 30) }
    elseif ($age.Days -ge 1)   { return "{0} day(s) ago"   -f $age.Days }
    else                       { return "Today" }
}


function Show-Banner {
    $banner = @"

  â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  â•‘              DevClean                 â•‘
  â•‘   Developed by Suprabhat Chowhan      â•‘
  â•‘   Version 1.0.0  |  Windows-first     â•‘
  â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

"@
    Write-Host $banner -ForegroundColor Cyan
}


function Show-ProgressBar {
    param(
        [string]$Label,
        [int]$Percent,
        [int]$BarWidth = 35,
        [string]$Color = "Cyan"
    )

    $filled  = [math]::Round($BarWidth * $Percent / 100)
    $empty   = $BarWidth - $filled
    $bar     = ("â–ˆ" * $filled) + ("â–‘" * $empty)
    $pctStr  = "$Percent%".PadLeft(4)

    Write-Host "  $Label" -NoNewline -ForegroundColor Gray
    Write-Host "  [$bar] $pctStr" -ForegroundColor $Color
}

function Show-ScanProgress {
    param([string]$Target, [string]$Status = "Scanning...")

    Write-Host "  " -NoNewline
    Write-Host "â—" -NoNewline -ForegroundColor Cyan
    Write-Host " $Target " -NoNewline -ForegroundColor White
    Write-Host $Status -ForegroundColor DarkGray
}

function Show-CleanupProgress {
    param(
        [string]$Label,
        [int]$Current,
        [int]$Total
    )

    $pct    = if ($Total -gt 0) { [math]::Round($Current / $Total * 100) } else { 100 }
    $filled = [math]::Round(40 * $pct / 100)
    $empty  = 40 - $filled
    $bar    = ("â–ˆ" * $filled) + ("â–‘" * $empty)

    Write-Host "`r  $Label  [$bar] $pct%" -NoNewline -ForegroundColor Cyan
    if ($Current -ge $Total) { Write-Host "" }
}

function Show-Spinner {
    param([string]$Message, [scriptblock]$Action)

    $frames  = @("â ‹","â ™","â ¹","â ¸","â ¼","â ´","â ¦","â §","â ‡","â ")
    $job     = Start-Job -ScriptBlock $Action
    $i       = 0

    while ($job.State -eq "Running") {
        $frame = $frames[$i % $frames.Length]
        Write-Host "`r  $frame $Message" -NoNewline -ForegroundColor Cyan
        Start-Sleep -Milliseconds 80
        $i++
    }

    Write-Host "`r  âœ“ $Message" -ForegroundColor Green
    $result = Receive-Job $job
    Remove-Job $job
    return $result
}


function Show-ScanTable {
    param([array]$Results)

    if (-not $Results -or $Results.Count -eq 0) {
        Write-Host ""
        Write-Host "  No reclaimable storage found." -ForegroundColor Green
        Write-Host ""
        return
    }

    $totalBytes = ($Results | Measure-Object -Property SizeBytes -Sum).Sum

    Write-Host ""
    Write-Host "  SCAN RESULTS" -ForegroundColor Yellow
    Write-Host "  â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•" -ForegroundColor DarkGray
    Write-Host ("  {0,-8}  {1,-28}  {2,10}  {3}" -f "RISK", "TARGET", "SIZE", "PATH") -ForegroundColor DarkGray
    Write-Host "  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€" -ForegroundColor DarkGray

    foreach ($r in $Results | Sort-Object RiskLevel) {
        $riskColor = Get-RiskColor $r.RiskLevel
        $label     = ("[{0}]" -f $r.RiskLevel).PadRight(9)
        $name      = $r.Name.PadRight(28)
        $size      = (Format-FileSize $r.SizeBytes).PadLeft(10)
        $path      = if ($r.Path.Length -gt 40) { "..." + $r.Path.Substring($r.Path.Length - 37) } else { $r.Path }

        Write-Host "  " -NoNewline
        Write-Host $label -NoNewline -ForegroundColor $riskColor
        Write-Host "  $name  $size  " -NoNewline -ForegroundColor White
        Write-Host $path -ForegroundColor DarkGray
    }

    Write-Host "  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€" -ForegroundColor DarkGray
    Write-Host ("  Total Recoverable Space: {0}" -f (Format-FileSize $totalBytes)) -ForegroundColor Green
    Write-Host ""
}

function Show-CategoryHeader {
    param(
        [string]$Name,
        [string]$RiskLevel,
        [long]$SizeBytes,
        [string]$Path
    )

    $color = Get-RiskColor $RiskLevel
    Write-Host ""
    Write-Host "  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”" -ForegroundColor DarkGray
    Write-Host "  â”‚  " -NoNewline -ForegroundColor DarkGray
    Write-Host ("[{0} RISK]" -f $RiskLevel).PadRight(12) -NoNewline -ForegroundColor $color
    Write-Host " $Name" -NoNewline -ForegroundColor White
    Write-Host "".PadRight([math]::Max(0, 38 - $Name.Length)) -NoNewline
    Write-Host "â”‚" -ForegroundColor DarkGray
    Write-Host "  â”‚  Recoverable: " -NoNewline -ForegroundColor DarkGray
    Write-Host (Format-FileSize $SizeBytes).PadRight(47) -NoNewline -ForegroundColor Cyan
    Write-Host "â”‚" -ForegroundColor DarkGray
    Write-Host "  â”‚  Path:        " -NoNewline -ForegroundColor DarkGray
    $shortPath = if ($Path.Length -gt 47) { "..." + $Path.Substring($Path.Length - 44) } else { $Path.PadRight(47) }
    Write-Host $shortPath -NoNewline -ForegroundColor Gray
    Write-Host "â”‚" -ForegroundColor DarkGray
    Write-Host "  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜" -ForegroundColor DarkGray
}

function Get-RiskColor {
    param([string]$RiskLevel)
    switch ($RiskLevel.ToUpper()) {
        "SAFE"   { return "Green" }
        "LOW"    { return "Cyan" }
        "MEDIUM" { return "Yellow" }
        "HIGH"   { return "Red" }
        default  { return "Gray" }
    }
}

function Show-RecoverySummary {
    param([long]$TotalBytes, [int]$ItemCount, [int]$Duration)

    Write-Host ""
    Write-Host "  â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—" -ForegroundColor Green
    Write-Host "  â•‘           CLEANUP COMPLETE                â•‘" -ForegroundColor Green
    Write-Host "  â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£" -ForegroundColor Green
    Write-Host ("  â•‘  Reclaimed:  {0,-30}â•‘" -f (Format-FileSize $TotalBytes)) -ForegroundColor Green
    Write-Host ("  â•‘  Items:      {0,-30}â•‘" -f "$ItemCount targets cleaned") -ForegroundColor Green
    Write-Host ("  â•‘  Duration:   {0,-30}â•‘" -f "${Duration}s") -ForegroundColor Green
    Write-Host "  â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•" -ForegroundColor Green
    Write-Host ""
}


function Show-EducationalNote {
    param([string]$Target)

    Write-Host ""
    switch ($Target.ToLower()) {

        "chrome" -or "browser" {
            Write-Host "  â”Œâ”€ What is Browser Cache? â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”" -ForegroundColor DarkGray
            Write-Host "  â”‚" -ForegroundColor DarkGray
            Write-Host "  â”‚  Browsers store cached web pages, images, scripts,     " -ForegroundColor Gray
            Write-Host "  â”‚  GPU shaders, and service workers on disk to speed up  " -ForegroundColor Gray
            Write-Host "  â”‚  browsing. This applies to ALL detected browsers:      " -ForegroundColor Gray
            Write-Host "  â”‚                                                          " -ForegroundColor Gray
            Write-Host "  â”‚  â— Chrome  â— Edge  â— Brave  â— Firefox  â— Opera         " -ForegroundColor Cyan
            Write-Host "  â”‚  â— Vivaldi  â— LibreWolf  â— Waterfox  â— Arc  â— Zen      " -ForegroundColor Cyan
            Write-Host "  â”‚                                                          " -ForegroundColor Gray
            Write-Host "  â”‚  These files are SAFE to remove.                        " -ForegroundColor Gray
            Write-Host "  â”‚  Browsers rebuild cache automatically as you browse.   " -ForegroundColor Gray
            Write-Host "  â”‚                                                          " -ForegroundColor Gray
            Write-Host "  â”‚  What is NOT touched:                                   " -ForegroundColor Gray
            Write-Host "  â”‚  Â· Passwords / saved logins                            " -ForegroundColor Green
            Write-Host "  â”‚  Â· Bookmarks and history                               " -ForegroundColor Green
            Write-Host "  â”‚  Â· Extensions and settings                             " -ForegroundColor Green
            Write-Host "  â”‚  Â· Brave Rewards wallet                                " -ForegroundColor Green
            Write-Host "  â”‚                                                          " -ForegroundColor Gray
            Write-Host "  â”‚  Temporary impact:                                       " -ForegroundColor Gray
            Write-Host "  â”‚  Â· Pages may load slightly slower for 10-30 minutes    " -ForegroundColor DarkGray
            Write-Host "  â”‚  Â· No re-login required                                " -ForegroundColor DarkGray
            Write-Host "  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜" -ForegroundColor DarkGray
        }

        "gradle" {
            Write-Host "  â”Œâ”€ What is the Gradle Cache? â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”" -ForegroundColor DarkGray
            Write-Host "  â”‚" -ForegroundColor DarkGray
            Write-Host "  â”‚  The Gradle cache stores downloaded dependencies,       " -ForegroundColor Gray
            Write-Host "  â”‚  build artifacts, and daemon PID files for Android      " -ForegroundColor Gray
            Write-Host "  â”‚  and Java projects.                                     " -ForegroundColor Gray
            Write-Host "  â”‚                                                          " -ForegroundColor Gray
            Write-Host "  â”‚  These files are SAFE to remove.                        " -ForegroundColor Gray
            Write-Host "  â”‚  Gradle will re-download only what it needs on next     " -ForegroundColor Gray
            Write-Host "  â”‚  build.                                                  " -ForegroundColor Gray
            Write-Host "  â”‚                                                          " -ForegroundColor Gray
            Write-Host "  â”‚  Temporary impact:                                       " -ForegroundColor Gray
            Write-Host "  â”‚  Â· First build after cleanup will be slower             " -ForegroundColor DarkGray
            Write-Host "  â”‚  Â· Dependencies will re-download from Maven Central     " -ForegroundColor DarkGray
            Write-Host "  â”‚                                                          " -ForegroundColor Gray
            Write-Host "  â”‚  Restoration: Run 'gradle build' in your project.       " -ForegroundColor DarkGray
            Write-Host "  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜" -ForegroundColor DarkGray
        }

        "node" {
            Write-Host "  â”Œâ”€ What are node_modules? â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”" -ForegroundColor DarkGray
            Write-Host "  â”‚" -ForegroundColor DarkGray
            Write-Host "  â”‚  node_modules contains installed npm/yarn/pnpm           " -ForegroundColor Gray
            Write-Host "  â”‚  dependencies for JavaScript/Node.js projects.           " -ForegroundColor Gray
            Write-Host "  â”‚                                                           " -ForegroundColor Gray
            Write-Host "  â”‚  Removing node_modules does NOT remove:                  " -ForegroundColor Gray
            Write-Host "  â”‚  Â· Your source code                                      " -ForegroundColor Green
            Write-Host "  â”‚  Â· package.json or package-lock.json                     " -ForegroundColor Green
            Write-Host "  â”‚  Â· Project configuration files                           " -ForegroundColor Green
            Write-Host "  â”‚                                                           " -ForegroundColor Gray
            Write-Host "  â”‚  Restoration:  npm install  (or yarn / pnpm install)     " -ForegroundColor Cyan
            Write-Host "  â”‚                                                           " -ForegroundColor Gray
            Write-Host "  â”‚  Temporary impact:                                        " -ForegroundColor Gray
            Write-Host "  â”‚  Â· Re-install required before next build                 " -ForegroundColor DarkGray
            Write-Host "  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜" -ForegroundColor DarkGray
        }

        "sdk" {
            Write-Host "  â”Œâ”€ What are Android SDK temp files? â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”" -ForegroundColor DarkGray
            Write-Host "  â”‚" -ForegroundColor DarkGray
            Write-Host "  â”‚  The Android SDK accumulates old NDK versions, unused   " -ForegroundColor Gray
            Write-Host "  â”‚  platform images, and duplicate build tools over time.  " -ForegroundColor Gray
            Write-Host "  â”‚                                                          " -ForegroundColor Gray
            Write-Host "  â”‚  DevClean scans your build.gradle files FIRST to        " -ForegroundColor Yellow
            Write-Host "  â”‚  detect which NDK/SDK versions are actively used.       " -ForegroundColor Yellow
            Write-Host "  â”‚                                                          " -ForegroundColor Gray
            Write-Host "  â”‚  Only UNREFERENCED versions are flagged for removal.    " -ForegroundColor Gray
            Write-Host "  â”‚                                                          " -ForegroundColor Gray
            Write-Host "  â”‚  Restoration: Re-install via Android Studio SDK Manager " -ForegroundColor DarkGray
            Write-Host "  â”‚  or 'sdkmanager' CLI.                                   " -ForegroundColor DarkGray
            Write-Host "  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜" -ForegroundColor DarkGray
        }

        "temp" {
            Write-Host "  â”Œâ”€ What are Windows Temp Files? â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”" -ForegroundColor DarkGray
            Write-Host "  â”‚" -ForegroundColor DarkGray
            Write-Host "  â”‚  Windows and applications store temporary files in:     " -ForegroundColor Gray
            Write-Host "  â”‚  Â· %TEMP% (user-level)                                  " -ForegroundColor Gray
            Write-Host "  â”‚  Â· C:\Windows\Temp (system-level)                       " -ForegroundColor Gray
            Write-Host "  â”‚                                                          " -ForegroundColor Gray
            Write-Host "  â”‚  These files accumulate from installers, crashes, and   " -ForegroundColor Gray
            Write-Host "  â”‚  system operations. They are safe to remove.            " -ForegroundColor Gray
            Write-Host "  â”‚                                                          " -ForegroundColor Gray
            Write-Host "  â”‚  Some files may be locked by running processes and      " -ForegroundColor DarkGray
            Write-Host "  â”‚  will be skipped automatically.                         " -ForegroundColor DarkGray
            Write-Host "  â”‚                                                          " -ForegroundColor Gray
            Write-Host "  â”‚  Restoration: Not required.                             " -ForegroundColor DarkGray
            Write-Host "  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}


function Show-RiskLabel {
    param(
        [string]$RiskLevel,
        [string]$Reason
    )

    $color = Get-RiskColor $RiskLevel

    Write-Host "  Risk Level: " -NoNewline -ForegroundColor Gray
    Write-Host "[$RiskLevel]" -NoNewline -ForegroundColor $color
    Write-Host "  â€” $Reason" -ForegroundColor DarkGray
}

function Show-DryRunBanner {
    Write-Host ""
    Write-Host "  â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—" -ForegroundColor Yellow
    Write-Host "  â•‘          DRY RUN MODE ENABLED            â•‘" -ForegroundColor Yellow
    Write-Host "  â•‘     No files will be deleted.            â•‘" -ForegroundColor Yellow
    Write-Host "  â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•" -ForegroundColor Yellow
    Write-Host ""
}

function Show-ConfirmPrompt {
    param(
        [string]$Category,
        [long]$SizeBytes,
        [string]$RiskLevel
    )

    $color = Get-RiskColor $RiskLevel
    Write-Host ""
    Write-Host "  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€" -ForegroundColor DarkGray
    Write-Host "  Target:     $Category" -ForegroundColor White
    Write-Host "  Recoverable: $(Format-FileSize $SizeBytes)" -ForegroundColor Cyan
    Write-Host "  Risk:       " -NoNewline -ForegroundColor Gray
    Write-Host "[$RiskLevel]" -ForegroundColor $color
    Write-Host ""
    Write-Host "  Proceed with cleanup? " -NoNewline -ForegroundColor White
    Write-Host "(Y/N/S to skip all)" -ForegroundColor DarkGray
    Write-Host "  > " -NoNewline -ForegroundColor Cyan

    $key = $Host.UI.ReadLine()
    return $key.Trim().ToUpper()
}

function Show-Warning {
    param([string]$Message)

    Write-Host ""
    Write-Host "  âš   WARNING" -ForegroundColor Yellow
    Write-Host "  $Message" -ForegroundColor Yellow
    Write-Host ""
}

function Show-Error {
    param([string]$Message)

    Write-Host ""
    Write-Host "  âœ—  ERROR: $Message" -ForegroundColor Red
    Write-Host ""
}

function Show-Success {
    param([string]$Message)

    Write-Host "  âœ“  $Message" -ForegroundColor Green
}

function Show-Info {
    param([string]$Message)

    Write-Host "  â—  $Message" -ForegroundColor Cyan
}


function Scan-Chrome {
    <#
    .SYNOPSIS
        Scans Google Chrome cache directories for reclaimable storage.
    #>

    $targets = @(
        @{ SubPath = "Cache";              Risk = "SAFE";   Label = "Chrome HTTP Cache" }
        @{ SubPath = "Cache2\entries";     Risk = "SAFE";   Label = "Chrome Cache2 Entries" }
        @{ SubPath = "GPUCache";           Risk = "SAFE";   Label = "Chrome GPU Shader Cache" }
        @{ SubPath = "Code Cache";         Risk = "SAFE";   Label = "Chrome Code Cache" }
        @{ SubPath = "DawnCache";          Risk = "SAFE";   Label = "Chrome Dawn GPU Cache" }
        @{ SubPath = "ShaderCache";        Risk = "SAFE";   Label = "Chrome Shader Cache" }
        @{ SubPath = "Media Cache";        Risk = "SAFE";   Label = "Chrome Media Cache" }
    )

    $chromeBase = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default"
    $results    = @()

    if (-not (Test-Path $chromeBase)) {
        return $results
    }

    foreach ($t in $targets) {
        $fullPath = Join-Path $chromeBase $t.SubPath
        if (Test-Path $fullPath) {
            $size = Get-FolderSize -Path $fullPath
            if ($size -gt 0) {
                $results += [PSCustomObject]@{
                    Name      = $t.Label
                    Path      = $fullPath
                    SizeBytes = $size
                    RiskLevel = $t.Risk
                    RiskReason = "Chrome caches rebuild automatically. No login data affected."
                    Category  = "chrome"
                    Scanner   = "chrome"
                }
            }
        }
    }

    return $results
}


function Scan-Browsers {
    <#
    .SYNOPSIS
        Scans cache directories for ALL major browsers installed on the system.
        Detects: Chrome, Edge, Brave, Firefox, Opera, Vivaldi, Arc, Waterfox,
                 LibreWolf, Thorium, Chromium, Samsung Internet, Yandex, Zen.
        Only scans browsers that are actually installed â€” skips missing ones.
    #>

    # â”€â”€ Browser profile definitions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    # Each entry: Name, BasePath (relative to $env:LOCALAPPDATA or $env:APPDATA),
    #             ProfileFolder, CacheFolders[], BaseRoot
    $browsers = @(

        # â”€â”€ Chromium-family â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        @{
            Name          = "Google Chrome"
            BaseRoot      = "LOCAL"
            BasePath      = "Google\Chrome\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","Cache2\entries","GPUCache","Code Cache","DawnCache","ShaderCache","Media Cache","Service Worker\CacheStorage","Service Worker\ScriptCache")
            Risk          = "SAFE"
            RiskReason    = "Chrome cache rebuilds automatically. No passwords or bookmarks affected."
            Category      = "browser"
        }
        @{
            Name          = "Microsoft Edge"
            BaseRoot      = "LOCAL"
            BasePath      = "Microsoft\Edge\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","Cache2\entries","GPUCache","Code Cache","DawnCache","ShaderCache","Media Cache","Service Worker\CacheStorage")
            Risk          = "SAFE"
            RiskReason    = "Edge cache rebuilds automatically. No passwords, bookmarks, or extensions affected."
            Category      = "browser"
        }
        @{
            Name          = "Brave Browser"
            BaseRoot      = "LOCAL"
            BasePath      = "BraveSoftware\Brave-Browser\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","Cache2\entries","GPUCache","Code Cache","DawnCache","ShaderCache","Media Cache","Service Worker\CacheStorage")
            Risk          = "SAFE"
            RiskReason    = "Brave cache rebuilds automatically. Brave Rewards wallet data is stored separately and is NOT affected."
            Category      = "browser"
        }
        @{
            Name          = "Opera"
            BaseRoot      = "APPDATA"
            BasePath      = "Opera Software\Opera Stable"
            ProfileGlob   = @(".")
            CacheFolders  = @("Cache","GPUCache","Code Cache","ShaderCache")
            Risk          = "SAFE"
            RiskReason    = "Opera cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Opera GX"
            BaseRoot      = "APPDATA"
            BasePath      = "Opera Software\Opera GX Stable"
            ProfileGlob   = @(".")
            CacheFolders  = @("Cache","GPUCache","Code Cache","ShaderCache")
            Risk          = "SAFE"
            RiskReason    = "Opera GX cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Vivaldi"
            BaseRoot      = "LOCAL"
            BasePath      = "Vivaldi\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","Cache2\entries","GPUCache","Code Cache","ShaderCache")
            Risk          = "SAFE"
            RiskReason    = "Vivaldi cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Chromium"
            BaseRoot      = "LOCAL"
            BasePath      = "Chromium\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","Cache2\entries","GPUCache","Code Cache","ShaderCache")
            Risk          = "SAFE"
            RiskReason    = "Chromium cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Thorium"
            BaseRoot      = "LOCAL"
            BasePath      = "Thorium\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","Cache2\entries","GPUCache","Code Cache")
            Risk          = "SAFE"
            RiskReason    = "Thorium cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Yandex Browser"
            BaseRoot      = "LOCAL"
            BasePath      = "Yandex\YandexBrowser\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","GPUCache","Code Cache")
            Risk          = "SAFE"
            RiskReason    = "Yandex Browser cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Samsung Internet"
            BaseRoot      = "LOCAL"
            BasePath      = "Samsung\SamsungBrowser\User Data"
            ProfileGlob   = @("Default")
            CacheFolders  = @("Cache","GPUCache")
            Risk          = "SAFE"
            RiskReason    = "Samsung Internet cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Arc Browser"
            BaseRoot      = "LOCAL"
            BasePath      = "Arc\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","Cache2\entries","GPUCache","Code Cache")
            Risk          = "SAFE"
            RiskReason    = "Arc cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Cá»‘c Cá»‘c"
            BaseRoot      = "LOCAL"
            BasePath      = "CocCoc\Browser\User Data"
            ProfileGlob   = @("Default")
            CacheFolders  = @("Cache","GPUCache","Code Cache")
            Risk          = "SAFE"
            RiskReason    = "Cá»‘c Cá»‘c cache rebuilds automatically."
            Category      = "browser"
        }

        # â”€â”€ Firefox-family â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        @{
            Name          = "Mozilla Firefox"
            BaseRoot      = "APPDATA"
            BasePath      = "Mozilla\Firefox\Profiles"
            ProfileGlob   = @("*")          # all profile folders
            CacheFolders  = @("cache2\entries","startupCache","thumbnails","OfflineCache")
            Risk          = "SAFE"
            RiskReason    = "Firefox cache rebuilds on next launch. Bookmarks, passwords, and extensions are stored separately."
            Category      = "browser"
            IsFirefox     = $true
        }
        @{
            Name          = "LibreWolf"
            BaseRoot      = "APPDATA"
            BasePath      = "librewolf\Profiles"
            ProfileGlob   = @("*")
            CacheFolders  = @("cache2\entries","startupCache","thumbnails")
            Risk          = "SAFE"
            RiskReason    = "LibreWolf cache rebuilds on next launch."
            Category      = "browser"
            IsFirefox     = $true
        }
        @{
            Name          = "Waterfox"
            BaseRoot      = "APPDATA"
            BasePath      = "Waterfox\Profiles"
            ProfileGlob   = @("*")
            CacheFolders  = @("cache2\entries","startupCache","thumbnails")
            Risk          = "SAFE"
            RiskReason    = "Waterfox cache rebuilds on next launch."
            Category      = "browser"
            IsFirefox     = $true
        }
        @{
            Name          = "Zen Browser"
            BaseRoot      = "APPDATA"
            BasePath      = "zen\Profiles"
            ProfileGlob   = @("*")
            CacheFolders  = @("cache2\entries","startupCache")
            Risk          = "SAFE"
            RiskReason    = "Zen Browser cache rebuilds on next launch."
            Category      = "browser"
            IsFirefox     = $true
        }
        @{
            Name          = "Pale Moon"
            BaseRoot      = "APPDATA"
            BasePath      = "Moonchild Productions\Pale Moon\Profiles"
            ProfileGlob   = @("*")
            CacheFolders  = @("cache2\entries","thumbnails")
            Risk          = "SAFE"
            RiskReason    = "Pale Moon cache rebuilds on next launch."
            Category      = "browser"
            IsFirefox     = $true
        }

        # â”€â”€ Standalone caches â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        @{
            Name          = "Internet Explorer"
            BaseRoot      = "LOCAL"
            BasePath      = "Microsoft\Windows\INetCache"
            ProfileGlob   = @(".")
            CacheFolders  = @("IE","Low\IE","Content.IE5")
            Risk          = "SAFE"
            RiskReason    = "Legacy IE cache. Safe to remove."
            Category      = "browser"
        }
    )

    # â”€â”€ Resolution helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    $results = @()
    $seen    = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($browser in $browsers) {

        $baseEnv  = if ($browser.BaseRoot -eq "LOCAL") { $env:LOCALAPPDATA } else { $env:APPDATA }
        $basePath = Join-Path $baseEnv $browser.BasePath

        # Resolve profile folders
        $profileDirs = @()

        if ($browser.ProfileGlob -contains ".") {
            # Flat layout (Opera, IE) â€” base path IS the profile
            if (Test-Path $basePath) { $profileDirs += $basePath }
        } elseif ($browser.ContainsKey("IsFirefox") -and $browser.IsFirefox) {
            # Firefox profiles are named like "abc12345.default-release"
            if (Test-Path $basePath) {
                $profileDirs += (Get-ChildItem $basePath -Directory -ErrorAction SilentlyContinue).FullName
            }
        } else {
            # Chromium multi-profile layout
            if (-not (Test-Path $basePath)) { continue }

            foreach ($glob in $browser.ProfileGlob) {
                $profileDirs += (Get-ChildItem $basePath -Directory -Filter $glob -ErrorAction SilentlyContinue).FullName
            }
        }

        if ($profileDirs.Count -eq 0) { continue }

        # Accumulate size across all profiles and cache dirs
        $totalSize     = 0L
        $foundPaths    = @()

        foreach ($profileDir in $profileDirs) {
            foreach ($cacheFolder in $browser.CacheFolders) {
                $cachePath = Join-Path $profileDir $cacheFolder
                if (-not (Test-Path $cachePath)) { continue }
                if (-not $seen.Add($cachePath))   { continue }  # deduplicate

                $size = Get-FolderSize -Path $cachePath
                if ($size -gt 0) {
                    $totalSize  += $size
                    $foundPaths += $cachePath
                }
            }
        }

        if ($totalSize -gt 0) {
            # Determine profile label
            $profileLabel = if ($profileDirs.Count -gt 1) { " ($($profileDirs.Count) profiles)" } else { "" }

            $results += [PSCustomObject]@{
                Name       = "$($browser.Name)$profileLabel Cache"
                Path       = $basePath       # top-level path shown in scan table
                Paths      = $foundPaths     # all individual cache paths for deletion
                SizeBytes  = $totalSize
                RiskLevel  = $browser.Risk
                RiskReason = $browser.RiskReason
                Category   = "browser"
                Scanner    = "browser"
                BrowserName = $browser.Name
            }
        }
    }

    return $results
}

# â”€â”€ Keep Scan-Chrome as a thin wrapper for backwards compatibility â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function Scan-Chrome {
    return Scan-Browsers | Where-Object { $_.BrowserName -eq "Google Chrome" }
}

function Get-InstalledBrowsers {
    <#
    .SYNOPSIS
        Returns a simple list of browser names that were detected on this system.
    #>
    $detected = Scan-Browsers
    return $detected | Select-Object -ExpandProperty BrowserName
}


function Scan-NodeModules {
    <#
    .SYNOPSIS
        Recursively finds node_modules directories across common dev locations.
        Skips node_modules nested inside other node_modules.
    #>
    param(
        [string[]]$SearchRoots = @(
            $env:USERPROFILE,
            "C:\dev",
            "C:\projects",
            "C:\repos",
            "C:\src",
            "C:\workspace"
        )
    )

    $results = @()
    $seen    = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($root in $SearchRoots) {
        if (-not (Test-Path $root)) { continue }

        try {
            $opts = [System.IO.EnumerationOptions]::new()
            $opts.RecurseSubdirectories = $true
            $opts.IgnoreInaccessible    = $true
            $opts.MaxRecursionDepth     = 8

            foreach ($dir in [System.IO.Directory]::EnumerateDirectories($root, "node_modules", $opts)) {

                # Skip nested node_modules (node_modules inside node_modules)
                $parent = Split-Path $dir -Parent
                if ($parent -match "node_modules") { continue }

                # Deduplicate
                if (-not $seen.Add($dir)) { continue }

                $size    = Get-FolderSize -Path $dir
                $project = Split-Path $parent -Leaf
                $lastMod = (Get-Item $parent -ErrorAction SilentlyContinue)?.LastWriteTime

                $results += [PSCustomObject]@{
                    Name       = "node_modules ($project)"
                    Path       = $dir
                    SizeBytes  = $size
                    RiskLevel  = "LOW"
                    RiskReason = "Source code and package.json are untouched. Run npm install to restore."
                    Category   = "node"
                    Scanner    = "node"
                    ProjectDir = $parent
                    LastModified = $lastMod
                }
            }
        } catch { <# skip inaccessible roots #> }
    }

    return $results
}


function Scan-Gradle {
    <#
    .SYNOPSIS
        Scans the Gradle user home cache for reclaimable storage.
    #>

    $gradleHome = $env:GRADLE_USER_HOME
    if (-not $gradleHome) {
        $gradleHome = Join-Path $env:USERPROFILE ".gradle"
    }

    $results = @()

    if (-not (Test-Path $gradleHome)) { return $results }

    $targets = @(
        @{
            SubPath    = "caches"
            Risk       = "LOW"
            Label      = "Gradle Dependency Cache"
            RiskReason = "Re-downloaded on next build from Maven Central / JCenter."
        }
        @{
            SubPath    = "daemon"
            Risk       = "LOW"
            Label      = "Gradle Daemon Files"
            RiskReason = "Daemon PID files and logs. Daemons restart automatically."
        }
        @{
            SubPath    = "wrapper\dists"
            Risk       = "LOW"
            Label      = "Gradle Wrapper Distributions"
            RiskReason = "Wrapper ZIPs re-downloaded when project is built."
        }
        @{
            SubPath    = "build-scan-data"
            Risk       = "SAFE"
            Label      = "Gradle Build Scan Data"
            RiskReason = "Build telemetry data. Safe to remove."
        }
        @{
            SubPath    = "native"
            Risk       = "SAFE"
            Label      = "Gradle Native Platform Cache"
            RiskReason = "Platform detection cache. Rebuilt automatically."
        }
    )

    foreach ($t in $targets) {
        $fullPath = Join-Path $gradleHome $t.SubPath
        if (Test-Path $fullPath) {
            $size = Get-FolderSize -Path $fullPath
            if ($size -gt 0) {
                $results += [PSCustomObject]@{
                    Name       = $t.Label
                    Path       = $fullPath
                    SizeBytes  = $size
                    RiskLevel  = $t.Risk
                    RiskReason = $t.RiskReason
                    Category   = "gradle"
                    Scanner    = "gradle"
                }
            }
        }
    }

    return $results
}


function Scan-AndroidSdk {
    <#
    .SYNOPSIS
        Scans Android SDK for reclaimable storage.
        Reads ANDROID_HOME / ANDROID_SDK_ROOT env vars and common default paths.
    #>

    $sdkRoot = $env:ANDROID_HOME
    if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_SDK_ROOT }
    if (-not $sdkRoot) { $sdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk" }

    $results = @()

    if (-not (Test-Path $sdkRoot)) { return $results }

    # â”€â”€ 1. System Images (largest, often multiple versions) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    $sysImgRoot = Join-Path $sdkRoot "system-images"
    if (Test-Path $sysImgRoot) {
        foreach ($apiDir in Get-ChildItem $sysImgRoot -Directory -ErrorAction SilentlyContinue) {
            foreach ($imgDir in Get-ChildItem $apiDir.FullName -Directory -ErrorAction SilentlyContinue) {
                foreach ($abiDir in Get-ChildItem $imgDir.FullName -Directory -ErrorAction SilentlyContinue) {
                    $size = Get-FolderSize -Path $abiDir.FullName
                    if ($size -gt 100MB) {
                        $results += [PSCustomObject]@{
                            Name       = "System Image $($apiDir.Name) [$($imgDir.Name)/$($abiDir.Name)]"
                            Path       = $abiDir.FullName
                            SizeBytes  = $size
                            RiskLevel  = "MEDIUM"
                            RiskReason = "Emulator image. Safe if you don't use this AVD config."
                            Category   = "sdk"
                            Scanner    = "sdk"
                            SubType    = "system-image"
                        }
                    }
                }
            }
        }
    }

    # â”€â”€ 2. Old NDK versions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    $ndkRoot = Join-Path $sdkRoot "ndk"
    if (Test-Path $ndkRoot) {
        foreach ($ndkVer in Get-ChildItem $ndkRoot -Directory -ErrorAction SilentlyContinue) {
            $size = Get-FolderSize -Path $ndkVer.FullName
            $results += [PSCustomObject]@{
                Name       = "NDK $($ndkVer.Name)"
                Path       = $ndkVer.FullName
                SizeBytes  = $size
                RiskLevel  = "MEDIUM"
                RiskReason = "NDK version â€” check if referenced by active projects before removing."
                Category   = "sdk"
                Scanner    = "sdk"
                SubType    = "ndk"
                Version    = $ndkVer.Name
            }
        }
    }

    # â”€â”€ 3. Temp / build-cache inside SDK â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    $tempPaths = @(
        @{ Sub = "temp";           Label = "SDK Temp Files";     Risk = "SAFE" }
        @{ Sub = "build-tools\staging"; Label = "Build Tools Staging"; Risk = "SAFE" }
    )

    foreach ($t in $tempPaths) {
        $fullPath = Join-Path $sdkRoot $t.Sub
        if (Test-Path $fullPath) {
            $size = Get-FolderSize -Path $fullPath
            if ($size -gt 0) {
                $results += [PSCustomObject]@{
                    Name       = $t.Label
                    Path       = $fullPath
                    SizeBytes  = $size
                    RiskLevel  = $t.Risk
                    RiskReason = "Temporary SDK files. Safe to remove."
                    Category   = "sdk"
                    Scanner    = "sdk"
                    SubType    = "temp"
                }
            }
        }
    }

    return $results
}


function Scan-WindowsTemp {
    <#
    .SYNOPSIS
        Scans Windows temporary file directories for reclaimable storage.
    #>

    $targets = @(
        @{
            Path       = $env:TEMP
            Label      = "User Temp (%TEMP%)"
            Risk       = "SAFE"
            RiskReason = "User-level temp files. Safe to remove."
        }
        @{
            Path       = $env:TMP
            Label      = "User TMP (%TMP%)"
            Risk       = "SAFE"
            RiskReason = "User-level temp files. Safe to remove."
        }
        @{
            Path       = "C:\Windows\Temp"
            Label      = "Windows System Temp"
            Risk       = "SAFE"
            RiskReason = "System temp files. Locked files are skipped automatically."
        }
        @{
            Path       = Join-Path $env:LOCALAPPDATA "Temp"
            Label      = "LocalAppData Temp"
            Risk       = "SAFE"
            RiskReason = "App-level temp files. Safe to remove."
        }
        @{
            Path       = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\INetCache"
            Label      = "IE/Edge Cache"
            Risk       = "SAFE"
            RiskReason = "Legacy Internet Explorer and Edge cache files."
        }
        @{
            Path       = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Temporary Internet Files"
            Label      = "Temporary Internet Files"
            Risk       = "SAFE"
            RiskReason = "Legacy browser cache. Safe to remove."
        }
    )

    # Deduplicate resolved paths
    $seen    = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $results = @()

    foreach ($t in $targets) {
        if (-not $t.Path) { continue }

        $resolved = [System.IO.Path]::GetFullPath($t.Path)
        if (-not $seen.Add($resolved)) { continue }
        if (-not (Test-Path $resolved)) { continue }

        $size = Get-FolderSize -Path $resolved
        if ($size -gt 0) {
            $results += [PSCustomObject]@{
                Name       = $t.Label
                Path       = $resolved
                SizeBytes  = $size
                RiskLevel  = $t.Risk
                RiskReason = $t.RiskReason
                Category   = "temp"
                Scanner    = "temp"
            }
        }
    }

    return $results
}


function Invoke-AnalyzeNode {
    <#
    .SYNOPSIS
        Analyzes node_modules directories for activity and safety.
        Reports inactive projects, git status, and restoration instructions.
    #>

    Write-Host ""
    Write-Host "  NODE_MODULES ANALYSIS" -ForegroundColor Yellow
    Write-Host "  â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•" -ForegroundColor DarkGray
    Write-Host ""

    Show-Info "Scanning for node_modules directories..."
    $modules = Scan-NodeModules
    
    if (-not $modules -or $modules.Count -eq 0) {
        Write-Host "  No node_modules directories found." -ForegroundColor Green
        return
    }

    Show-Info "Analyzing $($modules.Count) node_modules directories..."
    Write-Host ""

    $analyzed = @()

    foreach ($m in $modules) {
        $projectDir  = $m.ProjectDir
        $lastMod     = $m.LastModified
        $age         = if ($lastMod) { ((Get-Date) - $lastMod).Days } else { 999 }
        $isGitRepo   = Test-Path (Join-Path $projectDir ".git")
        $hasPkgJson  = Test-Path (Join-Path $projectDir "package.json")
        $hasLockFile = (Test-Path (Join-Path $projectDir "package-lock.json")) -or `
                       (Test-Path (Join-Path $projectDir "yarn.lock")) -or `
                       (Test-Path (Join-Path $projectDir "pnpm-lock.yaml"))

        # Risk classification
        if ($age -gt 180) {
            $risk       = "LOW"
            $riskReason = "Project inactive for $age days"
            $recommendation = "Safe to remove"
        } elseif ($age -gt 60) {
            $risk       = "LOW"
            $riskReason = "Project last used $age days ago"
            $recommendation = "Likely safe to remove"
        } else {
            $risk       = "HIGH"
            $riskReason = "Project recently active ($age days ago)"
            $recommendation = "Keep â€” project is active"
        }

        $analyzed += [PSCustomObject]@{
            Name           = $m.Name
            Path           = $m.Path
            ProjectDir     = $projectDir
            SizeBytes      = $m.SizeBytes
            RiskLevel      = $risk
            RiskReason     = $riskReason
            Recommendation = $recommendation
            AgeDays        = $age
            IsGitRepo      = $isGitRepo
            HasPackageJson = $hasPkgJson
            HasLockFile    = $hasLockFile
            LastModified   = $lastMod
        }
    }

    # Display results
    foreach ($a in $analyzed | Sort-Object AgeDays -Descending) {
        $riskColor = Get-RiskColor $a.RiskLevel

        Write-Host "  â”Œâ”€ " -NoNewline -ForegroundColor DarkGray
        Write-Host $a.Name -ForegroundColor White
        Write-Host "  â”‚  Size:        " -NoNewline -ForegroundColor DarkGray
        Write-Host (Format-FileSize $a.SizeBytes) -ForegroundColor Cyan
        Write-Host "  â”‚  Path:        " -NoNewline -ForegroundColor DarkGray
        Write-Host $a.ProjectDir -ForegroundColor Gray
        Write-Host "  â”‚  Last active: " -NoNewline -ForegroundColor DarkGray
        Write-Host (Format-Age $a.LastModified) -ForegroundColor Gray
        Write-Host "  â”‚  Git repo:    " -NoNewline -ForegroundColor DarkGray
        if ($a.IsGitRepo) { Write-Host "Yes" -ForegroundColor Green } else { Write-Host "No" -ForegroundColor DarkGray }
        Write-Host "  â”‚  package.json:" -NoNewline -ForegroundColor DarkGray
        if ($a.HasPackageJson) { Write-Host " Present" -ForegroundColor Green } else { Write-Host " Missing" -ForegroundColor Red }
        Write-Host "  â”‚  Risk:        " -NoNewline -ForegroundColor DarkGray
        Write-Host "[$($a.RiskLevel)]" -NoNewline -ForegroundColor $riskColor
        Write-Host " â€” $($a.RiskReason)" -ForegroundColor DarkGray
        Write-Host "  â”‚  Verdict:     " -NoNewline -ForegroundColor DarkGray
        Write-Host $a.Recommendation -ForegroundColor $(if ($a.RiskLevel -eq "HIGH") { "Yellow" } else { "Green" })
        Write-Host "  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€" -ForegroundColor DarkGray
        Write-Host ""
    }

    $totalSafe = ($analyzed | Where-Object { $_.RiskLevel -ne "HIGH" } | Measure-Object -Property SizeBytes -Sum).Sum
    $totalAll  = ($analyzed | Measure-Object -Property SizeBytes -Sum).Sum

    Write-Host "  Summary" -ForegroundColor Yellow
    Write-Host "  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€" -ForegroundColor DarkGray
    Write-Host "  Total node_modules found: $($analyzed.Count)" -ForegroundColor White
    Write-Host "  Total size:               $(Format-FileSize $totalAll)" -ForegroundColor Cyan
    Write-Host "  Safe to remove:           $(Format-FileSize $totalSafe)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Restore with:  npm install  |  yarn install  |  pnpm install" -ForegroundColor DarkGray
    Write-Host ""
}

function Get-NodeModuleRisk {
    param([PSCustomObject]$Module)

    $age = if ($Module.LastModified) { ((Get-Date) - $Module.LastModified).Days } else { 999 }

    if ($age -gt 180) { return "LOW" }
    if ($age -gt 60)  { return "LOW" }
    return "HIGH"
}


function Invoke-AnalyzeSdk {
    <#
    .SYNOPSIS
        Analyzes Android SDK/NDK usage by scanning build.gradle files.
        Identifies which NDK versions are actively referenced vs orphaned.
    #>

    Write-Host ""
    Write-Host "  ANDROID SDK DEPENDENCY ANALYSIS" -ForegroundColor Yellow
    Write-Host "  â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•" -ForegroundColor DarkGray
    Write-Host ""

    # â”€â”€ 1. Find SDK root â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    $sdkRoot = $env:ANDROID_HOME
    if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_SDK_ROOT }
    if (-not $sdkRoot) { $sdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk" }

    if (-not (Test-Path $sdkRoot)) {
        Show-Warning "Android SDK not found. Set ANDROID_HOME environment variable."
        return
    }

    Show-Info "SDK Root: $sdkRoot"

    # â”€â”€ 2. Get installed NDK versions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    $ndkRoot       = Join-Path $sdkRoot "ndk"
    $installedNdks = @()

    if (Test-Path $ndkRoot) {
        $installedNdks = (Get-ChildItem $ndkRoot -Directory -ErrorAction SilentlyContinue).Name
        Show-Info "Installed NDK versions: $($installedNdks -join ', ')"
    } else {
        Show-Info "No NDK versions installed."
    }

    # â”€â”€ 3. Scan build.gradle / build.gradle.kts files â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Write-Host ""
    Show-Info "Scanning build.gradle files for NDK references..."

    $searchRoots = @(
        $env:USERPROFILE,
        "C:\dev", "C:\projects", "C:\repos", "C:\src", "C:\workspace",
        (Join-Path $env:USERPROFILE "AndroidStudioProjects")
    )

    $referencedNdks    = [System.Collections.Generic.HashSet[string]]::new()
    $referencedSdks    = [System.Collections.Generic.HashSet[string]]::new()
    $gradleFilesFound  = 0
    $projectsFound     = @()

    foreach ($root in $searchRoots) {
        if (-not (Test-Path $root)) { continue }

        try {
            $opts = [System.IO.EnumerationOptions]::new()
            $opts.RecurseSubdirectories = $true
            $opts.IgnoreInaccessible    = $true
            $opts.MaxRecursionDepth     = 10

            foreach ($gradleFile in [System.IO.Directory]::EnumerateFiles($root, "build.gradle", $opts)) {
                $gradleFilesFound++
                $content = Get-Content $gradleFile -Raw -ErrorAction SilentlyContinue
                if (-not $content) { continue }

                # Parse ndkVersion
                $ndkMatches = [regex]::Matches($content, 'ndkVersion\s+["\x27]?([\d.]+)["\x27]?')
                foreach ($match in $ndkMatches) {
                    $ver = $match.Groups[1].Value.Trim()
                    [void]$referencedNdks.Add($ver)
                    $projectsFound += [PSCustomObject]@{
                        GradleFile = $gradleFile
                        Type       = "ndkVersion"
                        Value      = $ver
                    }
                }

                # Parse compileSdk / targetSdk / minSdk
                foreach ($prop in @("compileSdk","targetSdk","minSdk","compileSdkVersion","targetSdkVersion","minSdkVersion")) {
                    $sdkMatches = [regex]::Matches($content, "$prop\s+(\d+)")
                    foreach ($m in $sdkMatches) {
                        [void]$referencedSdks.Add($m.Groups[1].Value)
                    }
                }
            }

            # Also scan .kts files
            foreach ($ktsFile in [System.IO.Directory]::EnumerateFiles($root, "build.gradle.kts", $opts)) {
                $gradleFilesFound++
                $content = Get-Content $ktsFile -Raw -ErrorAction SilentlyContinue
                if (-not $content) { continue }

                $ndkMatches = [regex]::Matches($content, 'ndkVersion\s*=\s*["\x27]([\d.]+)["\x27]')
                foreach ($match in $ndkMatches) {
                    $ver = $match.Groups[1].Value.Trim()
                    [void]$referencedNdks.Add($ver)
                }
            }
        } catch { <# skip inaccessible #> }
    }

    Write-Host ""
    Write-Host "  PROJECT SCAN RESULTS" -ForegroundColor Yellow
    Write-Host "  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€" -ForegroundColor DarkGray
    Write-Host "  build.gradle files scanned: $gradleFilesFound" -ForegroundColor Gray
    Write-Host "  NDK versions referenced:    $($referencedNdks.Count)" -ForegroundColor Gray
    if ($referencedSdks.Count -gt 0) {
        Write-Host "  SDK API levels referenced:  $($referencedSdks -join ', ')" -ForegroundColor Gray
    }
    Write-Host ""

    # â”€â”€ 4. Cross-reference installed vs referenced â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    if ($installedNdks.Count -gt 0) {
        Write-Host "  NDK ANALYSIS" -ForegroundColor Yellow
        Write-Host "  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€" -ForegroundColor DarkGray

        foreach ($ndk in $installedNdks) {
            $isReferenced = $false

            foreach ($ref in $referencedNdks) {
                if ($ndk -like "$ref*" -or $ref -like "$ndk*") {
                    $isReferenced = $true
                    break
                }
            }

            $ndkPath = Join-Path $ndkRoot $ndk
            $ndkSize = Get-FolderSize -Path $ndkPath

            if ($isReferenced) {
                Write-Host "  âœ“  NDK $ndk" -NoNewline -ForegroundColor Green
                Write-Host " â€” $(Format-FileSize $ndkSize)" -NoNewline -ForegroundColor Gray
                Write-Host " â€” Referenced by active projects. Keep." -ForegroundColor DarkGray
            } else {
                Write-Host "  âš   NDK $ndk" -NoNewline -ForegroundColor Yellow
                Write-Host " â€” $(Format-FileSize $ndkSize)" -NoNewline -ForegroundColor Gray
                Write-Host " â€” Not referenced. Safe to remove." -ForegroundColor DarkGray
            }
        }
        Write-Host ""
    }

    # â”€â”€ 5. Show project references â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    if ($projectsFound.Count -gt 0) {
        Write-Host "  ACTIVE NDK REFERENCES FOUND" -ForegroundColor Yellow
        Write-Host "  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€" -ForegroundColor DarkGray
        foreach ($p in $projectsFound | Select-Object -First 10) {
            $shortPath = $p.GradleFile -replace [regex]::Escape($env:USERPROFILE), "~"
            Write-Host "  NDK $($p.Value.PadRight(12))" -NoNewline -ForegroundColor Cyan
            Write-Host $shortPath -ForegroundColor DarkGray
        }
        if ($projectsFound.Count -gt 10) {
            Write-Host "  ... and $($projectsFound.Count - 10) more" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  No active NDK references found in scanned projects." -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  To remove unused NDKs: devclean cleanup sdk --interactive" -ForegroundColor Cyan
    Write-Host ""
}


function Send-ToRecycleBin {
    <#
    .SYNOPSIS
        Moves a file or folder to the Windows Recycle Bin using Shell32 COM API.
        Falls back to Microsoft.VisualBasic if Shell32 fails.
    #>
    param(
        [string]$Path,
        [switch]$Permanent
    )

    if (-not (Test-Path $Path)) {
        Write-Verbose "Path not found, skipping: $Path"
        return $false
    }

    if ($Permanent) {
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            return $true
        } catch {
            Write-Verbose "Permanent delete failed: $_"
            return $false
        }
    }

    # â”€â”€ Try Microsoft.VisualBasic (most reliable) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue

        $isDir = (Get-Item $Path -ErrorAction SilentlyContinue) -is [System.IO.DirectoryInfo]

        if ($isDir) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                $Path,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
            )
        } else {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                $Path,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
            )
        }
        return $true
    } catch {
        Write-Verbose "VB recycle bin failed: $_ â€” trying Shell32"
    }

    # â”€â”€ Fallback: Shell32 COM â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    try {
        $shell  = New-Object -ComObject Shell.Application
        $parent = Split-Path $Path -Parent
        $leaf   = Split-Path $Path -Leaf
        $folder = $shell.Namespace($parent)
        $item   = $folder.ParseName($leaf)

        if ($item) {
            $item.InvokeVerb("delete")
            return $true
        }
    } catch {
        Write-Verbose "Shell32 recycle bin failed: $_"
    }

    # â”€â”€ Last resort: hard delete with warning â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    try {
        Show-Warning "Recycle Bin not available for: $Path â€” using permanent delete."
        Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        return $true
    } catch {
        Show-Error "Failed to delete: $Path`n  $_"
        return $false
    }
}

function Remove-FileSafely {
    <#
    .SYNOPSIS
        Removes a single file safely, skipping locked files.
    #>
    param([string]$Path, [switch]$Permanent)

    try {
        if ($Permanent) {
            Remove-Item -Path $Path -Force -ErrorAction Stop
        } else {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                $Path,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
            )
        }
        return $true
    } catch {
        Write-Verbose "Skipping locked file: $Path"
        return $false
    }
}


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
    Write-Host "  â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•" -ForegroundColor DarkGray
    Write-Host "  Timestamp:   $($entries.timestamp)" -ForegroundColor Gray
    Write-Host "  Items:       $($entries.entries.Count)" -ForegroundColor Gray
    Write-Host "  Reclaimed:   $($entries.totalReclaimed)" -ForegroundColor Cyan
    Write-Host "  Mode:        $($entries.mode)" -ForegroundColor Gray
    Write-Host ""

    foreach ($e in $entries.entries | Select-Object -First 20) {
        Write-Host "  Â· $($e.name)" -NoNewline -ForegroundColor White
        Write-Host "  ($($e.size))" -ForegroundColor DarkGray
        Write-Host "    $($e.path)" -ForegroundColor DarkGray
    }

    if ($entries.mode -eq "recycle-bin") {
        Write-Host ""
        Write-Host "  â„¹  Files were moved to the Recycle Bin." -ForegroundColor Cyan
        Write-Host "     Open Recycle Bin in Explorer to restore individual items." -ForegroundColor DarkGray
    } else {
        Write-Host ""
        Show-Warning "Files were permanently deleted. Manual restoration required."
    }

    Write-Host ""
}


function Write-CleanupLog {
    <#
    .SYNOPSIS
        Appends a cleanup session to cleanup-log.json.
        Maintains a rolling log of the last 50 sessions.
    #>
    param(
        [PSCustomObject[]]$Entries
    )

    $logPath = $Script:LogFile

    # Load existing log or create fresh
    if (Test-Path $logPath) {
        try {
            $logData = Get-Content $logPath -Raw | ConvertFrom-Json
            if (-not $logData.sessions) {
                $logData = [PSCustomObject]@{ sessions = @() }
            }
        } catch {
            $logData = [PSCustomObject]@{ sessions = @() }
        }
    } else {
        $logData = [PSCustomObject]@{ sessions = @() }
    }

    $totalBytes = ($Entries | Measure-Object -Property sizeBytes -Sum).Sum
    $mode       = ($Entries | Select-Object -First 1).mode

    $session = [PSCustomObject]@{
        timestamp      = (Get-Date -Format "o")
        totalReclaimed = Format-FileSize $totalBytes
        totalBytes     = $totalBytes
        mode           = $mode
        itemCount      = $Entries.Count
        entries        = $Entries
    }

    # Append and keep last 50 sessions
    $sessions = [System.Collections.ArrayList]@($logData.sessions)
    $sessions.Add($session) | Out-Null

    if ($sessions.Count -gt 50) {
        $sessions = $sessions | Select-Object -Last 50
    }

    $logData.sessions = $sessions

    try {
        $logData | ConvertTo-Json -Depth 10 | Set-Content -Path $logPath -Encoding UTF8
        Show-Info "Cleanup log saved: $logPath"
    } catch {
        Show-Warning "Could not write cleanup log: $_"
    }
}

function Read-CleanupLog {
    param([int]$LastN = 5)

    if (-not (Test-Path $Script:LogFile)) { return $null }

    try {
        $logData = Get-Content $Script:LogFile -Raw | ConvertFrom-Json
        return $logData.sessions | Select-Object -Last $LastN
    } catch {
        return $null
    }
}


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

# â”€â”€ Bootstrap: resolve paths â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
$Script:RootDir     = $PSScriptRoot
$Script:SrcDir      = Join-Path $RootDir "src"
$Script:LibDir      = Join-Path $RootDir "lib"
$Script:LogFile     = Join-Path $RootDir "cleanup-log.json"
$Script:Version     = "1.0.0"

# â”€â”€ Dot-source all modules â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

# â”€â”€ Main dispatcher â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

# â”€â”€ Help text â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function Show-Help {
    Write-Host ""
    Write-Host "  USAGE" -ForegroundColor Yellow
    Write-Host "  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€" -ForegroundColor DarkGray
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
    Write-Host "  devclean cleanup --dry-run      Preview â€” no deletion" -ForegroundColor White
    Write-Host "  devclean cleanup --interactive  Step-by-step guided cleanup" -ForegroundColor White
    Write-Host "  devclean analyze sdk            Analyze Android SDK usage" -ForegroundColor White
    Write-Host "  devclean analyze node           Analyze node_modules activity" -ForegroundColor White
    Write-Host "  devclean undo                   View last cleanup session" -ForegroundColor White
    Write-Host "  devclean help                   Show this help" -ForegroundColor White
    Write-Host ""
    Write-Host "  FLAGS" -ForegroundColor Yellow
    Write-Host "  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€" -ForegroundColor DarkGray
    Write-Host "  --dry-run      Simulate cleanup, no files deleted" -ForegroundColor Gray
    Write-Host "  --interactive  Confirm each category before cleanup" -ForegroundColor Gray
    Write-Host "  --permanent    Permanently delete (default: Recycle Bin)" -ForegroundColor Gray
    Write-Host "  --force        Skip confirmation prompts" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Version $Script:Version  |  github.com/suprabhat/devclean" -ForegroundColor DarkGray
    Write-Host ""
}

