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
            $dirs = Get-ChildItem -Path $root -Filter "node_modules" -Recurse -Directory `
                        -ErrorAction SilentlyContinue -Force |
                    Select-Object -First 200

            foreach ($dirInfo in $dirs) {
                $dir    = $dirInfo.FullName
                $parent = Split-Path $dir -Parent

                # Skip nested node_modules
                if ($parent -match "node_modules") { continue }

                # Deduplicate
                if (-not $seen.Add($dir)) { continue }

                $size       = Get-FolderSize -Path $dir
                $project    = Split-Path $parent -Leaf
                $parentItem = Get-Item $parent -ErrorAction SilentlyContinue
                $lastMod    = if ($parentItem) { $parentItem.LastWriteTime } else { $null }

                $results += [PSCustomObject]@{
                    Name         = "node_modules ($project)"
                    Path         = $dir
                    SizeBytes    = $size
                    RiskLevel    = "LOW"
                    RiskReason   = "Source code and package.json are untouched. Run npm install to restore."
                    Category     = "node"
                    Scanner      = "node"
                    ProjectDir   = $parent
                    LastModified = $lastMod
                }
            }
        } catch { <# skip inaccessible roots #> }
    }

    return $results
}
