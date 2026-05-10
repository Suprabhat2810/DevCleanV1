function Show-ProgressBar {
    param(
        [string]$Label,
        [int]$Percent,
        [int]$BarWidth = 35,
        [string]$Color = "Cyan"
    )

    $filled  = [math]::Round($BarWidth * $Percent / 100)
    $empty   = $BarWidth - $filled
    $bar     = ("█" * $filled) + ("░" * $empty)
    $pctStr  = "$Percent%".PadLeft(4)

    Write-Host "  $Label" -NoNewline -ForegroundColor Gray
    Write-Host "  [$bar] $pctStr" -ForegroundColor $Color
}

function Show-ScanProgress {
    param([string]$Target, [string]$Status = "Scanning...")

    Write-Host "  " -NoNewline
    Write-Host "●" -NoNewline -ForegroundColor Cyan
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
    $bar    = ("█" * $filled) + ("░" * $empty)

    Write-Host "`r  $Label  [$bar] $pct%" -NoNewline -ForegroundColor Cyan
    if ($Current -ge $Total) { Write-Host "" }
}

function Show-Spinner {
    param([string]$Message, [scriptblock]$Action)

    $frames  = @("⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏")
    $job     = Start-Job -ScriptBlock $Action
    $i       = 0

    while ($job.State -eq "Running") {
        $frame = $frames[$i % $frames.Length]
        Write-Host "`r  $frame $Message" -NoNewline -ForegroundColor Cyan
        Start-Sleep -Milliseconds 80
        $i++
    }

    Write-Host "`r  ✓ $Message" -ForegroundColor Green
    $result = Receive-Job $job
    Remove-Job $job
    return $result
}
