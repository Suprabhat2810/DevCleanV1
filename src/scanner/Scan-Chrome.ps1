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
