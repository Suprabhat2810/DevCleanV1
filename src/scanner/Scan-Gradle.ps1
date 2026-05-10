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
