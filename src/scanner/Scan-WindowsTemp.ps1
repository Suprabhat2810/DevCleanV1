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
