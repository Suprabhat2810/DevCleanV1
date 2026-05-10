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
