function Show-RiskLabel {
    param(
        [string]$RiskLevel,
        [string]$Reason
    )

    $color = Get-RiskColor $RiskLevel

    Write-Host "  Risk Level: " -NoNewline -ForegroundColor Gray
    Write-Host "[$RiskLevel]" -NoNewline -ForegroundColor $color
    Write-Host "  — $Reason" -ForegroundColor DarkGray
}

function Show-DryRunBanner {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "  ║          DRY RUN MODE ENABLED            ║" -ForegroundColor Yellow
    Write-Host "  ║     No files will be deleted.            ║" -ForegroundColor Yellow
    Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Yellow
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
    Write-Host "  ──────────────────────────────────────────" -ForegroundColor DarkGray
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
    Write-Host "  ⚠  WARNING" -ForegroundColor Yellow
    Write-Host "  $Message" -ForegroundColor Yellow
    Write-Host ""
}

function Show-Error {
    param([string]$Message)

    Write-Host ""
    Write-Host "  ✗  ERROR: $Message" -ForegroundColor Red
    Write-Host ""
}

function Show-Success {
    param([string]$Message)

    Write-Host "  ✓  $Message" -ForegroundColor Green
}

function Show-Info {
    param([string]$Message)

    Write-Host "  ●  $Message" -ForegroundColor Cyan
}
