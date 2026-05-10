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
    Write-Host "  ══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ("  {0,-8}  {1,-28}  {2,10}  {3}" -f "RISK", "TARGET", "SIZE", "PATH") -ForegroundColor DarkGray
    Write-Host "  ──────────────────────────────────────────────────────────" -ForegroundColor DarkGray

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

    Write-Host "  ──────────────────────────────────────────────────────────" -ForegroundColor DarkGray
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
    Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "  │  " -NoNewline -ForegroundColor DarkGray
    Write-Host ("[{0} RISK]" -f $RiskLevel).PadRight(12) -NoNewline -ForegroundColor $color
    Write-Host " $Name" -NoNewline -ForegroundColor White
    Write-Host "".PadRight([math]::Max(0, 38 - $Name.Length)) -NoNewline
    Write-Host "│" -ForegroundColor DarkGray
    Write-Host "  │  Recoverable: " -NoNewline -ForegroundColor DarkGray
    Write-Host (Format-FileSize $SizeBytes).PadRight(47) -NoNewline -ForegroundColor Cyan
    Write-Host "│" -ForegroundColor DarkGray
    Write-Host "  │  Path:        " -NoNewline -ForegroundColor DarkGray
    $shortPath = if ($Path.Length -gt 47) { "..." + $Path.Substring($Path.Length - 44) } else { $Path.PadRight(47) }
    Write-Host $shortPath -NoNewline -ForegroundColor Gray
    Write-Host "│" -ForegroundColor DarkGray
    Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
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
    Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║           CLEANUP COMPLETE                ║" -ForegroundColor Green
    Write-Host "  ╠═══════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host ("  ║  Reclaimed:  {0,-30}║" -f (Format-FileSize $TotalBytes)) -ForegroundColor Green
    Write-Host ("  ║  Items:      {0,-30}║" -f "$ItemCount targets cleaned") -ForegroundColor Green
    Write-Host ("  ║  Duration:   {0,-30}║" -f "${Duration}s") -ForegroundColor Green
    Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
}
